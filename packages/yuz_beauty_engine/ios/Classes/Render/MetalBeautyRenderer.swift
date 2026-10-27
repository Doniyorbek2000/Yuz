import CoreVideo
import Foundation
import Metal

struct BeautySettings: Equatable {
  var skinSmoothing: Float = 0
  var texturePreservation: Float = 0.5
  var skinBrightening: Float = 0

  var isIdentity: Bool { skinSmoothing <= 0 && skinBrightening <= 0 }
}

enum RendererError: Error {
  case noMetalDevice
  case pipelineCreation(String)
  case resourceCreation(String)
}

/// GPU beauty pipeline on Metal compute. Pass order and constants mirror the
/// Android `BeautyRenderer`:
///
///   camera BGRA ─► smoothH/smoothed (½, cross-bilateral)
///               ─► face mask (¼, polygons + Gaussian feather)
///   composite ─► BGRA pixel buffer handed to Flutter
///
/// Thread-safety: `render` is called from the capture queue only.
final class MetalBeautyRenderer {
  static let rangeSigma: Float = 0.10
  static let maskBlurIterations = 2
  static let maxFaces = 4

  private let device: MTLDevice
  private let commandQueue: MTLCommandQueue
  private let blurPipeline: MTLComputePipelineState
  private let gaussianPipeline: MTLComputePipelineState
  private let maskPipeline: MTLComputePipelineState
  private let compositePipeline: MTLComputePipelineState
  private var textureCache: CVMetalTextureCache?
  private let inFlight = DispatchSemaphore(value: 2)

  private var width = 0
  private var height = 0
  private var smoothHorizontal: MTLTexture?
  private var smoothed: MTLTexture?
  private var maskRaw: MTLTexture?
  private var maskHorizontal: MTLTexture?
  private var mask: MTLTexture?
  private var outputPool: CVPixelBufferPool?

  init() throws {
    guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
      throw RendererError.noMetalDevice
    }
    self.device = device
    self.commandQueue = queue
    let library: MTLLibrary
    do {
      library = try device.makeLibrary(source: BeautyShaders.source, options: nil)
    } catch {
      throw RendererError.pipelineCreation("Metal library: \(error)")
    }
    func pipeline(_ name: String) throws -> MTLComputePipelineState {
      guard let function = library.makeFunction(name: name) else {
        throw RendererError.pipelineCreation("missing kernel \(name)")
      }
      return try device.makeComputePipelineState(function: function)
    }
    blurPipeline = try pipeline("edgePreservingBlur")
    gaussianPipeline = try pipeline("gaussianBlur")
    maskPipeline = try pipeline("faceMask")
    compositePipeline = try pipeline("beautyComposite")
    guard CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache) == kCVReturnSuccess else {
      throw RendererError.resourceCreation("CVMetalTextureCache")
    }
  }

  /// Renders `input` and calls `completion` on a Metal completion thread with
  /// the processed buffer, or with `input` itself when no effect is active.
  /// Returns false (frame dropped) when two frames are already in flight.
  @discardableResult
  func render(
    input: CVPixelBuffer, settings: BeautySettings, faces: [TrackedFace]?,
    completion: @escaping (CVPixelBuffer) -> Void
  ) -> Bool {
    if settings.isIdentity {
      completion(input)
      return true
    }
    guard inFlight.wait(timeout: .now()) == .success else { return false }

    let frameWidth = CVPixelBufferGetWidth(input)
    let frameHeight = CVPixelBufferGetHeight(input)
    do {
      try ensureResources(width: frameWidth, height: frameHeight)
    } catch {
      inFlight.signal()
      completion(input)
      return true
    }

    guard
      let source = makeTexture(from: input, usage: .shaderRead),
      let pool = outputPool,
      let output = makeOutputBuffer(pool: pool),
      let destination = makeTexture(from: output, usage: [.shaderRead, .shaderWrite]),
      let commandBuffer = commandQueue.makeCommandBuffer()
    else {
      inFlight.signal()
      completion(input)
      return true
    }

    encodeSeparable(
      commandBuffer, pipeline: blurPipeline, source: source.texture, intermediate: smoothHorizontal!,
      destination: smoothed!, rangeSigma: Self.rangeSigma)

    var faceMaskEnabled: Float = 0
    if let faces {
      faceMaskEnabled = 1
      encodeFaceMask(commandBuffer, faces: faces)
    }

    if let encoder = commandBuffer.makeComputeCommandEncoder() {
      var params = (settings.skinSmoothing, settings.texturePreservation, settings.skinBrightening, faceMaskEnabled)
      encoder.setComputePipelineState(compositePipeline)
      encoder.setTexture(source.texture, index: 0)
      encoder.setTexture(smoothed, index: 1)
      encoder.setTexture(mask, index: 2)
      encoder.setTexture(destination.texture, index: 3)
      encoder.setBytes(&params, length: MemoryLayout<Float>.stride * 4, index: 0)
      dispatch(encoder, pipeline: compositePipeline, width: frameWidth, height: frameHeight)
      encoder.endEncoding()
    }

    commandBuffer.addCompletedHandler { [inFlight] buffer in
      // Keep the CVMetalTexture wrappers alive until the GPU is done.
      withExtendedLifetime((source, destination)) {}
      inFlight.signal()
      completion(buffer.status == .completed ? output : input)
    }
    commandBuffer.commit()
    return true
  }

  func flushCache() {
    if let textureCache { CVMetalTextureCacheFlush(textureCache, 0) }
  }

  private func encodeFaceMask(_ commandBuffer: MTLCommandBuffer, faces: [TrackedFace]) {
    // Polygons go through setBytes (copied at encode time, max 3.4 KB for 4
    // faces) so frames in flight never share a CPU-written buffer.
    var points: [SIMD2<Float>] = []
    points.reserveCapacity(FaceMaskGeometry.pointsPerFace * Self.maxFaces)
    var faceCount: UInt32 = 0
    for face in faces.prefix(Self.maxFaces) {
      guard let polygons = FaceMaskGeometry.polygons(for: face.landmarks) else { continue }
      points.append(contentsOf: polygons)
      faceCount += 1
    }
    if points.isEmpty { points.append(SIMD2<Float>(0, 0)) }

    if let encoder = commandBuffer.makeComputeCommandEncoder() {
      var params = (faceCount, UInt32(0))
      encoder.setComputePipelineState(maskPipeline)
      encoder.setTexture(maskRaw, index: 0)
      points.withUnsafeBytes { bytes in
        encoder.setBytes(bytes.baseAddress!, length: bytes.count, index: 0)
      }
      encoder.setBytes(&params, length: MemoryLayout<UInt32>.stride * 2, index: 1)
      dispatch(encoder, pipeline: maskPipeline, width: maskRaw!.width, height: maskRaw!.height)
      encoder.endEncoding()
    }

    var source: MTLTexture = maskRaw!
    for _ in 0..<Self.maskBlurIterations {
      encodeSeparable(
        commandBuffer, pipeline: gaussianPipeline, source: source, intermediate: maskHorizontal!,
        destination: mask!, rangeSigma: 0)
      source = mask!
    }
  }

  private func encodeSeparable(
    _ commandBuffer: MTLCommandBuffer, pipeline: MTLComputePipelineState, source: MTLTexture,
    intermediate: MTLTexture, destination: MTLTexture, rangeSigma: Float
  ) {
    let passes: [(MTLTexture, MTLTexture, SIMD2<Float>)] = [
      (source, intermediate, SIMD2(1 / Float(intermediate.width), 0)),
      (intermediate, destination, SIMD2(0, 1 / Float(destination.height))),
    ]
    for (input, output, step) in passes {
      guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
      var params = (step, rangeSigma, Float(0))
      encoder.setComputePipelineState(pipeline)
      encoder.setTexture(input, index: 0)
      encoder.setTexture(output, index: 1)
      encoder.setBytes(&params, length: MemoryLayout<Float>.stride * 4, index: 0)
      dispatch(encoder, pipeline: pipeline, width: output.width, height: output.height)
      encoder.endEncoding()
    }
  }

  private func dispatch(
    _ encoder: MTLComputeCommandEncoder, pipeline: MTLComputePipelineState, width: Int, height: Int
  ) {
    let threadWidth = pipeline.threadExecutionWidth
    let threadHeight = max(1, pipeline.maxTotalThreadsPerThreadgroup / threadWidth)
    let threadsPerGroup = MTLSize(width: threadWidth, height: threadHeight, depth: 1)
    let groups = MTLSize(
      width: (width + threadWidth - 1) / threadWidth,
      height: (height + threadHeight - 1) / threadHeight, depth: 1)
    encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threadsPerGroup)
  }

  private func ensureResources(width newWidth: Int, height newHeight: Int) throws {
    guard newWidth != width || newHeight != height else { return }
    func texture(_ w: Int, _ h: Int, _ format: MTLPixelFormat) throws -> MTLTexture {
      let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: format, width: max(1, w), height: max(1, h), mipmapped: false)
      descriptor.usage = [.shaderRead, .shaderWrite]
      descriptor.storageMode = .private
      guard let texture = device.makeTexture(descriptor: descriptor) else {
        throw RendererError.resourceCreation("texture \(w)x\(h)")
      }
      return texture
    }
    smoothHorizontal = try texture(newWidth / 2, newHeight / 2, .rgba8Unorm)
    smoothed = try texture(newWidth / 2, newHeight / 2, .rgba8Unorm)
    maskRaw = try texture(newWidth / 4, newHeight / 4, .rgba8Unorm)
    maskHorizontal = try texture(newWidth / 4, newHeight / 4, .rgba8Unorm)
    mask = try texture(newWidth / 4, newHeight / 4, .rgba8Unorm)

    let attributes: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: newWidth,
      kCVPixelBufferHeightKey as String: newHeight,
      kCVPixelBufferMetalCompatibilityKey as String: true,
      kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
    ]
    var pool: CVPixelBufferPool?
    let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey as String: 3] as CFDictionary
    guard
      CVPixelBufferPoolCreate(nil, poolAttributes, attributes as CFDictionary, &pool) == kCVReturnSuccess
    else {
      throw RendererError.resourceCreation("pixel buffer pool")
    }
    outputPool = pool
    width = newWidth
    height = newHeight
  }

  private func makeOutputBuffer(pool: CVPixelBufferPool) -> CVPixelBuffer? {
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
    return buffer
  }

  private final class TextureHandle {
    let cvTexture: CVMetalTexture
    let texture: MTLTexture

    init(cvTexture: CVMetalTexture, texture: MTLTexture) {
      self.cvTexture = cvTexture
      self.texture = texture
    }
  }

  private func makeTexture(from pixelBuffer: CVPixelBuffer, usage: MTLTextureUsage) -> TextureHandle? {
    guard let textureCache else { return nil }
    var cvTexture: CVMetalTexture?
    let attributes = [kCVMetalTextureUsage as String: usage.rawValue] as CFDictionary
    let status = CVMetalTextureCacheCreateTextureFromImage(
      nil, textureCache, pixelBuffer, attributes, .bgra8Unorm,
      CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer), 0, &cvTexture)
    guard status == kCVReturnSuccess, let cvTexture, let texture = CVMetalTextureGetTexture(cvTexture)
    else { return nil }
    return TextureHandle(cvTexture: cvTexture, texture: texture)
  }
}
