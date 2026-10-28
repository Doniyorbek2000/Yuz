import CoreImage
import CoreVideo
import Foundation
import ImageIO
import MediaPipeTasksVision
import os

enum StillImageError: Error {
  case unreadable(String)
  case renderFailed
  case encodeFailed(String)
}

/// Applies the camera's GPU beauty pipeline to photos (port of
/// StillImageProcessor.kt). Owns its own Metal renderer and IMAGE-mode face
/// landmarker, independent of the camera session. Jobs are serialized on
/// `queue`.
final class StillImageProcessor {
  struct Output {
    let width: Int
    let height: Int
    let sourceWidth: Int
    let sourceHeight: Int
    let faceCount: Int
    let faceTrackingAvailable: Bool
  }

  static let maxOutputEdge = 8192
  static let maxPixels = 24_000_000
  private static let maxFaces = 4
  private static let log = Logger(subsystem: "app.yuz.beauty_engine", category: "Still")

  private let queue = DispatchQueue(label: "app.yuz.beauty_engine.still", qos: .userInitiated)
  private var renderer: MetalBeautyRenderer?
  private var landmarker: FaceLandmarker?
  private var landmarkerUnavailable = false
  private lazy var ciContext = CIContext(options: [.cacheIntermediates: false])

  func process(
    inputPath: String, outputPath: String, maxLongEdge: Int, settings: BeautySettings, lut: Data?,
    jpegQuality: Int, maxFaces: Int
  ) async throws -> Output {
    try await withCheckedThrowingContinuation { continuation in
      queue.async {
        do {
          let output = try autoreleasepool {
            try self.run(
              inputPath: inputPath, outputPath: outputPath, maxLongEdge: maxLongEdge, settings: settings,
              lut: lut, jpegQuality: jpegQuality, maxFaces: maxFaces)
          }
          continuation.resume(returning: output)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private func run(
    inputPath: String, outputPath: String, maxLongEdge: Int, settings: BeautySettings, lut: Data?,
    jpegQuality: Int, maxFaces: Int
  ) throws -> Output {
    let url = URL(fileURLWithPath: inputPath)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let storedWidth = properties[kCGImagePropertyPixelWidth] as? Int,
      let storedHeight = properties[kCGImagePropertyPixelHeight] as? Int, storedWidth > 0, storedHeight > 0
    else {
      throw StillImageError.unreadable(inputPath)
    }
    let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
    let swapsAxes = (5...8).contains(orientation)
    let uprightWidth = swapsAxes ? storedHeight : storedWidth
    let uprightHeight = swapsAxes ? storedWidth : storedHeight
    let targetLongEdge = Self.targetLongEdge(width: uprightWidth, height: uprightHeight, requested: maxLongEdge)

    // Decodes upright (EXIF applied) and downsampled in one step; never upscales.
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: targetLongEdge,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      throw StillImageError.unreadable(inputPath)
    }
    let pixelBuffer = try Self.makePixelBuffer(from: image)
    let faces = detectFaces(pixelBuffer, maxFaces: maxFaces)

    let activeRenderer: MetalBeautyRenderer
    if let renderer {
      activeRenderer = renderer
    } else {
      activeRenderer = try MetalBeautyRenderer()
      renderer = activeRenderer
    }
    activeRenderer.setLut(lut)

    let done = DispatchSemaphore(value: 0)
    var processed: CVPixelBuffer?
    var submitted = false
    for _ in 0..<50 where !submitted {
      submitted = activeRenderer.render(input: pixelBuffer, settings: settings, faces: faces) { output in
        processed = output
        done.signal()
      }
      if !submitted { Thread.sleep(forTimeInterval: 0.02) }
    }
    guard submitted, done.wait(timeout: .now() + 30) == .success, let processed else {
      throw StillImageError.renderFailed
    }

    try writeJpeg(processed, to: URL(fileURLWithPath: outputPath), quality: jpegQuality)
    return Output(
      width: CVPixelBufferGetWidth(processed), height: CVPixelBufferGetHeight(processed),
      sourceWidth: uprightWidth, sourceHeight: uprightHeight, faceCount: faces?.count ?? 0,
      faceTrackingAvailable: faces != nil)
  }

  /// Same plan as StillImageGeometry.kt: requested size, GPU cap, pixel cap, no upscaling.
  static func targetLongEdge(width: Int, height: Int, requested: Int) -> Int {
    let longEdge = max(width, height)
    var scale = 1.0
    if requested > 0 && requested < longEdge { scale = Double(requested) / Double(longEdge) }
    if Double(longEdge) * scale > Double(maxOutputEdge) { scale = Double(maxOutputEdge) / Double(longEdge) }
    let pixels = Double(width) * Double(height) * scale * scale
    if pixels > Double(maxPixels) { scale *= (Double(maxPixels) / pixels).squareRoot() }
    return max(1, Int((Double(longEdge) * scale).rounded()))
  }

  private static func makePixelBuffer(from image: CGImage) throws -> CVPixelBuffer {
    let attributes: [String: Any] = [
      kCVPixelBufferCGImageCompatibilityKey as String: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
      kCVPixelBufferMetalCompatibilityKey as String: true,
      kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
    ]
    var buffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
      nil, image.width, image.height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer)
    guard status == kCVReturnSuccess, let buffer else { throw StillImageError.renderFailed }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard
      let context = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer), width: image.width, height: image.height,
        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    else {
      throw StillImageError.renderFailed
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return buffer
  }

  /// nil when the face model is unavailable (colour-only processing).
  private func detectFaces(_ pixelBuffer: CVPixelBuffer, maxFaces: Int) -> [TrackedFace]? {
    guard let landmarker = obtainLandmarker() else { return nil }
    do {
      let image = try MPImage(pixelBuffer: pixelBuffer)
      let result = try landmarker.detect(image: image)
      let faces = result.faceLandmarks.compactMap { landmarks -> DetectedFace? in
        guard landmarks.count >= FaceMaskGeometry.meshLandmarkCount else { return nil }
        return DetectedFace(landmarks: landmarks.map { NormalizedPoint(x: $0.x, y: $0.y) })
      }
      let tracker = FaceTracker(maxFaces: min(max(maxFaces, 1), Self.maxFaces), policy: .allFaces)
      return tracker.update(faces, timestamp: ProcessInfo.processInfo.systemUptime).beautifiedFaces
    } catch {
      Self.log.warning("Still face detection failed: \(error.localizedDescription)")
      return []
    }
  }

  private func obtainLandmarker() -> FaceLandmarker? {
    if let landmarker { return landmarker }
    if landmarkerUnavailable { return nil }
    guard let modelPath = FaceLandmarkDetector.modelPath() else {
      landmarkerUnavailable = true
      return nil
    }
    for delegate in [Delegate.GPU, Delegate.CPU] {
      let options = FaceLandmarkerOptions()
      options.baseOptions.modelAssetPath = modelPath
      options.baseOptions.delegate = delegate
      options.runningMode = .image
      options.numFaces = Self.maxFaces
      options.minFaceDetectionConfidence = 0.5
      options.minFacePresenceConfidence = 0.5
      if let created = try? FaceLandmarker(options: options) {
        landmarker = created
        return created
      }
    }
    landmarkerUnavailable = true
    return nil
  }

  private func writeJpeg(_ buffer: CVPixelBuffer, to url: URL, quality: Int) throws {
    let image = CIImage(cvPixelBuffer: buffer)
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
      throw StillImageError.encodeFailed("sRGB unavailable")
    }
    let directory = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let temp = directory.appendingPathComponent(".\(url.lastPathComponent).part")
    let level = Double(min(max(quality, 1), 100)) / 100
    try ciContext.writeJPEGRepresentation(
      of: image, to: temp, colorSpace: colorSpace,
      options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: level])
    // Atomic replace: a crash never leaves a half-written output.
    if FileManager.default.fileExists(atPath: url.path) {
      _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
    } else {
      try FileManager.default.moveItem(at: temp, to: url)
    }
  }
}
