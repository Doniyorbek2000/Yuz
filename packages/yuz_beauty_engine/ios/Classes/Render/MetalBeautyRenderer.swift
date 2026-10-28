import CoreVideo
import Foundation
import Metal

/// 0xAARRGGBB makeup colours; defaults match MakeupColors.kt.
struct MakeupColors: Equatable {
  var lipstick: UInt32 = 0xFFB4_404F
  var blush: UInt32 = 0xFFE8_838A
  var eyebrow: UInt32 = 0xFF4A_3426
  var eyeshadow: UInt32 = 0xFF9A_6B5C
  var eyeliner: UInt32 = 0xFF1C_1614

  static func rgb(_ color: UInt32) -> SIMD4<Float> {
    SIMD4(
      Float((color >> 16) & 0xFF) / 255, Float((color >> 8) & 0xFF) / 255, Float(color & 0xFF) / 255, 1)
  }
}

/// Every engine control, normalized 0...1 (mirrors BeautySettings.kt).
struct BeautySettings: Equatable {
  var skinSmoothing: Float = 0
  var texturePreservation: Float = 0.5
  var skinBrightening: Float = 0
  var skinTone: Float = 0
  var blemishReduction: Float = 0
  var shineReduction: Float = 0
  var glow: Float = 0
  var eyeBrightening: Float = 0
  var teethWhitening: Float = 0
  var darkCircles: Float = 0
  var reshape = ReshapeSettings()
  var lipstick: Float = 0
  var blush: Float = 0
  var eyebrows: Float = 0
  var eyeshadow: Float = 0
  var eyeliner: Float = 0
  var makeupIntensity: Float = 1
  var colors = MakeupColors()
  var filterIntensity: Float = 0
  var sharpen: Float = 0

  var makeupActive: Bool {
    makeupIntensity > 0 && [lipstick, blush, eyebrows, eyeshadow, eyeliner].contains { $0 > 0 }
  }

  var compositeActive: Bool {
    [
      skinSmoothing, skinBrightening, skinTone, blemishReduction, shineReduction, glow, eyeBrightening,
      teethWhitening, darkCircles,
    ].contains { $0 > 0 } || makeupActive || filterIntensity > 0 || sharpen > 0
  }

  var isIdentity: Bool { !compositeActive && reshape.isIdentity }
}

enum RendererError: Error {
  case noMetalDevice
  case pipelineCreation(String)
  case resourceCreation(String)
}

/// GPU beauty pipeline on Metal compute. Pass order and constants mirror the
/// Android `BeautyRenderer`:
///
///   camera BGRA ─► [faceWarp] ─► source
///   source ─► smoothH/smoothed (½) ; source ─► baseBlur (¼)
///   landmarks ─► maskA/B/C (¼) ─► Gaussian feather
///   composite(+ LUT) ─► BGRA pixel buffer handed to Flutter
///
/// Thread-safety: `render` and `setLut` are called from the capture queue.
final class MetalBeautyRenderer {
  static let rangeSigma: Float = 0.10
  static let maskBlurIterations = 2
  static let linerBlurIterations = 1
  static let baseBlurIterations = 2
  static let maxFaces = 4
  static let lutSize = 512
  static let lutBytes = 512 * 512 * 4
  private static let framesInFlight = 2
  /// Long edge at which the bilateral blur uses 1-texel steps (BeautyRenderer.kt).
  static let referenceLongEdge: Float = 1280

  /// Keeps the smoothing radius a constant fraction of the image (preview == export).
  static func smoothingStepScale(width: Int, height: Int) -> Float {
    max(1, Float(max(width, height)) / referenceLongEdge)
  }

  private let device: MTLDevice
  private let commandQueue: MTLCommandQueue
  private let blurPipeline: MTLComputePipelineState
  private let gaussianPipeline: MTLComputePipelineState
  private let warpPipeline: MTLComputePipelineState
  private let maskPipeline: MTLComputePipelineState
  private let compositePipeline: MTLComputePipelineState
  private var textureCache: CVMetalTextureCache?
  private let inFlight = DispatchSemaphore(value: framesInFlight)
  private let faceBuffers: [MTLBuffer]
  private var frameIndex = 0
  private let lut: MTLTexture
  private var lutLoaded = false

  private var width = 0
  private var height = 0
  private var warped: MTLTexture?
  private var smoothHorizontal: MTLTexture?
  private var smoothed: MTLTexture?
  private var detailTemp: MTLTexture?
  private var detailBlur: MTLTexture?
  private var baseTemp: MTLTexture?
  private var baseBlur: MTLTexture?
  private var masks: [MTLTexture] = []
  private var maskTemp: MTLTexture?
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
    warpPipeline = try pipeline("faceWarp")
    maskPipeline = try pipeline("faceMask")
    compositePipeline = try pipeline("beautyComposite")

    // One face buffer per in-flight frame (+1) so the CPU never overwrites data the GPU reads.
    let faceBytes = MemoryLayout<SIMD4<Float>>.stride * FaceMaskGeometry.float4PerFace * Self.maxFaces
    var buffers: [MTLBuffer] = []
    for _ in 0...Self.framesInFlight {
      guard let buffer = device.makeBuffer(length: faceBytes, options: .storageModeShared) else {
        throw RendererError.resourceCreation("face buffer")
      }
      buffers.append(buffer)
    }
    faceBuffers = buffers

    let lutDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba8Unorm, width: Self.lutSize, height: Self.lutSize, mipmapped: false)
    lutDescriptor.usage = [.shaderRead]
    guard let lutTexture = device.makeTexture(descriptor: lutDescriptor) else {
      throw RendererError.resourceCreation("LUT texture")
    }
    lut = lutTexture

    guard CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache) == kCVReturnSuccess else {
      throw RendererError.resourceCreation("CVMetalTextureCache")
    }
  }

  /// Uploads a 512x512 RGBA LUT (first row = top) or disables the filter.
  func setLut(_ rgba: Data?) {
    guard let rgba, rgba.count == Self.lutBytes else {
      lutLoaded = false
      return
    }
    rgba.withUnsafeBytes { bytes in
      guard let base = bytes.baseAddress else { return }
      lut.replace(
        region: MTLRegionMake2D(0, 0, Self.lutSize, Self.lutSize), mipmapLevel: 0, withBytes: base,
        bytesPerRow: Self.lutSize * 4)
    }
    lutLoaded = true
  }

  /// Renders `input` and calls `completion` on a Metal completion thread with
  /// the processed buffer, or with `input` itself when no effect is active.
  /// Returns false (frame dropped) when the GPU is already busy with two frames.
  @discardableResult
  func render(
    input: CVPixelBuffer, settings: BeautySettings, faces: [TrackedFace]?,
    completion: @escaping (CVPixelBuffer) -> Void
  ) -> Bool {
    let warpsPossible = !(faces?.isEmpty ?? true) && !settings.reshape.isIdentity
    if !settings.compositeActive && !warpsPossible {
      completion(input)
      return true
    }
    guard inFlight.wait(timeout: .now()) == .success else { return false }

    let frameWidth = CVPixelBufferGetWidth(input)
    let frameHeight = CVPixelBufferGetHeight(input)
    let aspect = Float(frameWidth) / Float(max(frameHeight, 1))
    do {
      try ensureResources(width: frameWidth, height: frameHeight)
    } catch {
      inFlight.signal()
      completion(input)
      return true
    }

    guard
      let camera = makeTexture(from: input, usage: .shaderRead),
      let pool = outputPool,
      let output = makeOutputBuffer(pool: pool),
      let destination = makeTexture(from: output, usage: [.shaderRead, .shaderWrite]),
      let commandBuffer = commandQueue.makeCommandBuffer()
    else {
      inFlight.signal()
      completion(input)
      return true
    }

    var source: MTLTexture = camera.texture
    if let faces, warpsPossible {
      let warps = Array(
        faces.flatMap { FaceWarpBuilder.build($0.landmarks, settings: settings.reshape, aspect: aspect) }
          .prefix(FaceWarpBuilder.maxWarps))
      if !warps.isEmpty, let warped {
        encodeWarps(commandBuffer, input: camera.texture, output: warped, warps: warps, aspect: aspect)
        source = warped
      }
    }

    encodeSeparable(
      commandBuffer, pipeline: blurPipeline, source: source, intermediate: smoothHorizontal!,
      destination: smoothed!, rangeSigma: Self.rangeSigma,
      stepScale: Self.smoothingStepScale(width: frameWidth, height: frameHeight))
    if settings.sharpen > 0 {
      encodeSeparable(
        commandBuffer, pipeline: gaussianPipeline, source: source, intermediate: detailTemp!,
        destination: detailBlur!, rangeSigma: 0)
    }
    var baseSource = source
    for _ in 0..<Self.baseBlurIterations {
      encodeSeparable(
        commandBuffer, pipeline: gaussianPipeline, source: baseSource, intermediate: baseTemp!,
        destination: baseBlur!, rangeSigma: 0)
      baseSource = baseBlur!
    }
    if let faces { encodeFaceMasks(commandBuffer, faces: faces, aspect: aspect) }

    if let encoder = commandBuffer.makeComputeCommandEncoder() {
      let active = settings.compositeActive
      func gate(_ value: Float) -> Float { active ? value : 0 }
      let makeup = settings.makeupIntensity
      var values = [Float](repeating: 0, count: BeautyShaders.Value.allCases.count)
      values[BeautyShaders.Value.faceMaskEnabled.rawValue] = faces == nil ? 0 : 1
      values[BeautyShaders.Value.skinSmoothing.rawValue] = gate(settings.skinSmoothing)
      values[BeautyShaders.Value.texturePreservation.rawValue] = settings.texturePreservation
      values[BeautyShaders.Value.skinBrightening.rawValue] = gate(settings.skinBrightening)
      values[BeautyShaders.Value.skinTone.rawValue] = gate(settings.skinTone)
      values[BeautyShaders.Value.blemishReduction.rawValue] = gate(settings.blemishReduction)
      values[BeautyShaders.Value.shineReduction.rawValue] = gate(settings.shineReduction)
      values[BeautyShaders.Value.glow.rawValue] = gate(settings.glow)
      values[BeautyShaders.Value.eyeBrightening.rawValue] = gate(settings.eyeBrightening)
      values[BeautyShaders.Value.teethWhitening.rawValue] = gate(settings.teethWhitening)
      values[BeautyShaders.Value.darkCircles.rawValue] = gate(settings.darkCircles)
      values[BeautyShaders.Value.lipstick.rawValue] = gate(settings.lipstick * makeup)
      values[BeautyShaders.Value.blush.rawValue] = gate(settings.blush * makeup)
      values[BeautyShaders.Value.eyebrows.rawValue] = gate(settings.eyebrows * makeup)
      values[BeautyShaders.Value.eyeshadow.rawValue] = gate(settings.eyeshadow * makeup)
      values[BeautyShaders.Value.eyeliner.rawValue] = gate(settings.eyeliner * makeup)
      values[BeautyShaders.Value.lutIntensity.rawValue] = lutLoaded ? gate(settings.filterIntensity) : 0
      values[BeautyShaders.Value.sharpen.rawValue] = gate(settings.sharpen)
      var colors: [SIMD4<Float>] = [
        MakeupColors.rgb(settings.colors.lipstick), MakeupColors.rgb(settings.colors.blush),
        MakeupColors.rgb(settings.colors.eyebrow), MakeupColors.rgb(settings.colors.eyeshadow),
        MakeupColors.rgb(settings.colors.eyeliner),
      ]
      encoder.setComputePipelineState(compositePipeline)
      encoder.setTexture(source, index: 0)
      encoder.setTexture(smoothed, index: 1)
      encoder.setTexture(baseBlur, index: 2)
      encoder.setTexture(masks[0], index: 3)
      encoder.setTexture(masks[1], index: 4)
      encoder.setTexture(masks[2], index: 5)
      encoder.setTexture(lut, index: 6)
      encoder.setTexture(destination.texture, index: 7)
      encoder.setTexture(detailBlur, index: 8)
      encoder.setBytes(&values, length: MemoryLayout<Float>.stride * values.count, index: 0)
      encoder.setBytes(&colors, length: MemoryLayout<SIMD4<Float>>.stride * colors.count, index: 1)
      dispatch(encoder, pipeline: compositePipeline, width: frameWidth, height: frameHeight)
      encoder.endEncoding()
    }

    commandBuffer.addCompletedHandler { [inFlight] buffer in
      // Keep the CVMetalTexture wrappers alive until the GPU is done.
      withExtendedLifetime((camera, destination)) {}
      inFlight.signal()
      completion(buffer.status == .completed ? output : input)
    }
    commandBuffer.commit()
    return true
  }

  func flushCache() {
    if let textureCache { CVMetalTextureCacheFlush(textureCache, 0) }
  }

  private func encodeWarps(
    _ commandBuffer: MTLCommandBuffer, input: MTLTexture, output: MTLTexture, warps: [FaceWarp], aspect: Float
  ) {
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
    var a = [SIMD4<Float>](repeating: SIMD4(0, 0, 1, 0), count: FaceWarpBuilder.maxWarps)
    var b = [SIMD4<Float>](repeating: .zero, count: FaceWarpBuilder.maxWarps)
    for (i, warp) in warps.enumerated() {
      a[i] = SIMD4(warp.center.x, warp.center.y, warp.radius, warp.kind.rawValue)
      b[i] = SIMD4(warp.offset.x, warp.offset.y, warp.strength, 0)
    }
    var meta = SIMD2<Float>(Float(warps.count), aspect)
    encoder.setComputePipelineState(warpPipeline)
    encoder.setTexture(input, index: 0)
    encoder.setTexture(output, index: 1)
    encoder.setBytes(&a, length: MemoryLayout<SIMD4<Float>>.stride * a.count, index: 0)
    encoder.setBytes(&b, length: MemoryLayout<SIMD4<Float>>.stride * b.count, index: 1)
    encoder.setBytes(&meta, length: MemoryLayout<SIMD2<Float>>.stride, index: 2)
    dispatch(encoder, pipeline: warpPipeline, width: output.width, height: output.height)
    encoder.endEncoding()
  }

  private func encodeFaceMasks(_ commandBuffer: MTLCommandBuffer, faces: [TrackedFace], aspect: Float) {
    frameIndex = (frameIndex + 1) % faceBuffers.count
    let buffer = faceBuffers[frameIndex]
    let pointer = buffer.contents().bindMemory(
      to: SIMD4<Float>.self, capacity: FaceMaskGeometry.float4PerFace * Self.maxFaces)
    var faceCount = 0
    for face in faces.prefix(Self.maxFaces) {
      guard let uniforms = FaceMaskGeometry.build(face.landmarks, aspect: aspect) else { continue }
      for (index, value) in uniforms.flattened.enumerated() {
        pointer[faceCount * FaceMaskGeometry.float4PerFace + index] = value
      }
      faceCount += 1
    }

    if let encoder = commandBuffer.makeComputeCommandEncoder() {
      // Metal textures are top-left: "up" in the image is -y.
      var meta = SIMD2<Float>(Float(faceCount), -1)
      encoder.setComputePipelineState(maskPipeline)
      encoder.setTexture(masks[0], index: 0)
      encoder.setTexture(masks[1], index: 1)
      encoder.setTexture(masks[2], index: 2)
      encoder.setBuffer(buffer, offset: 0, index: 0)
      encoder.setBytes(&meta, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
      dispatch(encoder, pipeline: maskPipeline, width: masks[0].width, height: masks[0].height)
      encoder.endEncoding()
    }
    guard faceCount > 0, let temp = maskTemp else { return }
    for (index, mask) in masks.enumerated() {
      let iterations = index == 2 ? Self.linerBlurIterations : Self.maskBlurIterations
      for _ in 0..<iterations {
        encodeSeparable(
          commandBuffer, pipeline: gaussianPipeline, source: mask, intermediate: temp, destination: mask,
          rangeSigma: 0)
      }
    }
  }

  private func encodeSeparable(
    _ commandBuffer: MTLCommandBuffer, pipeline: MTLComputePipelineState, source: MTLTexture,
    intermediate: MTLTexture, destination: MTLTexture, rangeSigma: Float, stepScale: Float = 1
  ) {
    let passes: [(MTLTexture, MTLTexture, SIMD2<Float>)] = [
      (source, intermediate, SIMD2(stepScale / Float(intermediate.width), 0)),
      (intermediate, destination, SIMD2(0, stepScale / Float(destination.height))),
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
    func texture(_ w: Int, _ h: Int) throws -> MTLTexture {
      let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm, width: max(1, w), height: max(1, h), mipmapped: false)
      descriptor.usage = [.shaderRead, .shaderWrite]
      descriptor.storageMode = .private
      guard let texture = device.makeTexture(descriptor: descriptor) else {
        throw RendererError.resourceCreation("texture \(w)x\(h)")
      }
      return texture
    }
    warped = try texture(newWidth, newHeight)
    smoothHorizontal = try texture(newWidth / 2, newHeight / 2)
    smoothed = try texture(newWidth / 2, newHeight / 2)
    detailTemp = try texture(newWidth / 2, newHeight / 2)
    detailBlur = try texture(newWidth / 2, newHeight / 2)
    baseTemp = try texture(newWidth / 4, newHeight / 4)
    baseBlur = try texture(newWidth / 4, newHeight / 4)
    masks = try (0..<3).map { _ in try texture(newWidth / 4, newHeight / 4) }
    maskTemp = try texture(newWidth / 4, newHeight / 4)

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
