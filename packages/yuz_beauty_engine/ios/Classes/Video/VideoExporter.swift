import AVFoundation
import CoreImage
import CoreVideo
import Foundation
import MediaPipeTasksVision
import os

enum VideoExportError: Error {
  case invalid(String)
  case unreadable(String)
  case failed(String)
  case cancelled
}

struct VideoExportClip {
  let url: URL
  let startMillis: Int
  let endMillis: Int
  let speed: Double
}

struct VideoExportOverlay {
  let url: URL
  let startMillis: Int
  let endMillis: Int
}

struct VideoExportJob {
  let clips: [VideoExportClip]
  let output: URL
  let settings: BeautySettings
  let lut: Data?
  let overlays: [VideoExportOverlay]
  let music: URL?
  let musicVolume: Float
  let originalVolume: Float
  let maxLongEdge: Int
}

struct VideoExportOutput {
  let url: URL
  let durationMillis: Int
  let width: Int
  let height: Int
  let hasAudio: Bool
}

extension BeautySettings {
  /// Effects that read the face landmarks (masks or warps); mirrors BeautySettings.kt.
  var usesFaces: Bool {
    [
      skinSmoothing, skinBrightening, skinTone, blemishReduction, shineReduction, glow, eyeBrightening,
      teethWhitening, darkCircles,
    ].contains { $0 > 0 } || makeupActive || !reshape.isIdentity
  }

  /// Keeps only the colour look (filter LUT and sharpening).
  var colorOnly: BeautySettings {
    var settings = BeautySettings()
    settings.filterIntensity = filterIntensity
    settings.sharpen = sharpen
    return settings
  }
}

/// Offline editor renderer (port of VideoExporter.kt). AVComposition does
/// trimming, speed and letterboxing; every frame then runs through the same
/// Metal beauty pipeline as the camera (VIDEO-mode face tracking), gets the
/// text/sticker overlays composited, and is written with the mixed
/// soundtrack (clip sound at normal speed + looping music with fade-out).
final class VideoExporter {
  static let maxLongEdge = 1920
  private static let minSpeed = 0.25
  private static let maxSpeed = 4.0
  private static let musicFadeSeconds = 1.5
  private static let detectionLongEdge: CGFloat = 480
  private static let log = Logger(subsystem: "app.yuz.beauty_engine", category: "VideoExport")

  private let ciContext = CIContext(options: [.cacheIntermediates: false])

  func export(
    _ job: VideoExportJob, isCancelled: @escaping () -> Bool, progress: @escaping (Double) -> Void
  ) async throws -> VideoExportOutput {
    guard !job.clips.isEmpty else { throw VideoExportError.invalid("no clips") }
    let built = try await buildComposition(job)
    let temp = job.output.deletingLastPathComponent().appendingPathComponent(
      ".\(job.output.lastPathComponent).part.mp4")
    try FileManager.default.createDirectory(
      at: job.output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? FileManager.default.removeItem(at: temp)
    do {
      let hasAudio = try await render(built, job: job, to: temp, isCancelled: isCancelled, progress: progress)
      try? FileManager.default.removeItem(at: job.output)
      try FileManager.default.moveItem(at: temp, to: job.output)
      progress(1)
      return VideoExportOutput(
        url: job.output, durationMillis: Int((CMTimeGetSeconds(built.duration) * 1000).rounded()),
        width: Int(built.renderSize.width), height: Int(built.renderSize.height), hasAudio: hasAudio)
    } catch {
      try? FileManager.default.removeItem(at: temp)
      throw error
    }
  }

  // MARK: - Composition

  private struct BuiltComposition {
    let composition: AVMutableComposition
    let videoComposition: AVMutableVideoComposition
    let audioMix: AVMutableAudioMix?
    let audioTracks: [AVMutableCompositionTrack]
    let videoTrack: AVMutableCompositionTrack
    let renderSize: CGSize
    let duration: CMTime
  }

  private func buildComposition(_ job: VideoExportJob) async throws -> BuiltComposition {
    let composition = AVMutableComposition()
    guard
      let videoTrack = composition.addMutableTrack(
        withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    else { throw VideoExportError.failed("cannot create video track") }
    var originalAudio: AVMutableCompositionTrack?
    var instructions: [AVMutableVideoCompositionInstruction] = []
    var renderSize = CGSize.zero
    var cursor = CMTime.zero
    let timescale: CMTimeScale = 600

    for (index, clip) in job.clips.enumerated() {
      guard clip.speed >= Self.minSpeed, clip.speed <= Self.maxSpeed else {
        throw VideoExportError.invalid("clip \(index): speed \(clip.speed) outside 0.25...4")
      }
      let asset = AVURLAsset(url: clip.url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
      guard let sourceVideo = try await asset.loadTracks(withMediaType: .video).first else {
        throw VideoExportError.unreadable(clip.url.path)
      }
      let assetDuration = try await asset.load(.duration)
      let naturalSize = try await sourceVideo.load(.naturalSize)
      let transform = try await sourceVideo.load(.preferredTransform)
      let upright = naturalSize.applying(transform)
      let uprightSize = CGSize(width: abs(upright.width), height: abs(upright.height))
      if index == 0 { renderSize = Self.outputSize(for: uprightSize, maxLongEdge: job.maxLongEdge) }

      let start = CMTime(value: CMTimeValue(max(clip.startMillis, 0)), timescale: 1000)
      let end = CMTimeMinimum(CMTime(value: CMTimeValue(clip.endMillis), timescale: 1000), assetDuration)
      guard CMTimeGetSeconds(end - start) >= 0.1 else {
        throw VideoExportError.invalid("clip \(index): trimmed range is shorter than 100 ms")
      }
      let sourceRange = CMTimeRange(start: start, end: end)
      try videoTrack.insertTimeRange(sourceRange, of: sourceVideo, at: cursor)

      let keepsSound = clip.speed == 1 && job.originalVolume > 0
      if keepsSound, let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first {
        if originalAudio == nil {
          originalAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        }
        try originalAudio?.insertTimeRange(sourceRange, of: sourceAudio, at: cursor)
      }

      var outputDuration = sourceRange.duration
      if clip.speed != 1 {
        outputDuration = CMTimeMultiplyByFloat64(sourceRange.duration, multiplier: 1 / clip.speed)
          .convertScale(timescale, method: .roundHalfAwayFromZero)
        videoTrack.scaleTimeRange(CMTimeRange(start: cursor, duration: sourceRange.duration), toDuration: outputDuration)
      }

      let instruction = AVMutableVideoCompositionInstruction()
      instruction.timeRange = CMTimeRange(start: cursor, duration: outputDuration)
      instruction.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
      let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
      layer.setTransform(
        Self.fitTransform(preferred: transform, natural: naturalSize, upright: uprightSize, into: renderSize),
        at: cursor)
      instruction.layerInstructions = [layer]
      instructions.append(instruction)
      cursor = cursor + outputDuration
    }

    var mixParameters: [AVMutableAudioMixInputParameters] = []
    var audioTracks: [AVMutableCompositionTrack] = []
    if let originalAudio {
      let parameters = AVMutableAudioMixInputParameters(track: originalAudio)
      parameters.setVolume(job.originalVolume, at: .zero)
      mixParameters.append(parameters)
      audioTracks.append(originalAudio)
    }
    if let musicURL = job.music, job.musicVolume > 0 {
      let musicAsset = AVURLAsset(url: musicURL)
      guard let musicSource = try await musicAsset.loadTracks(withMediaType: .audio).first else {
        throw VideoExportError.unreadable(musicURL.path)
      }
      let musicDuration = try await musicAsset.load(.duration)
      guard CMTimeGetSeconds(musicDuration) > 0.1,
        let musicTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
      else { throw VideoExportError.unreadable(musicURL.path) }
      // Loop the music until the end of the edit.
      var position = CMTime.zero
      while position < cursor {
        let length = CMTimeMinimum(musicDuration, cursor - position)
        try musicTrack.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: musicSource, at: position)
        position = position + length
      }
      let parameters = AVMutableAudioMixInputParameters(track: musicTrack)
      parameters.setVolume(job.musicVolume, at: .zero)
      let fade = CMTimeMinimum(CMTime(seconds: Self.musicFadeSeconds, preferredTimescale: timescale), cursor)
      parameters.setVolumeRamp(
        fromStartVolume: job.musicVolume, toEndVolume: 0, timeRange: CMTimeRange(start: cursor - fade, duration: fade))
      mixParameters.append(parameters)
      audioTracks.append(musicTrack)
    }

    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = renderSize
    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    videoComposition.instructions = instructions
    var audioMix: AVMutableAudioMix?
    if !mixParameters.isEmpty {
      let mix = AVMutableAudioMix()
      mix.inputParameters = mixParameters
      audioMix = mix
    }
    return BuiltComposition(
      composition: composition, videoComposition: videoComposition, audioMix: audioMix, audioTracks: audioTracks,
      videoTrack: videoTrack, renderSize: renderSize, duration: cursor)
  }

  /// First clip's upright aspect, long edge <= maxLongEdge (never upscaled), even sizes.
  static func outputSize(for upright: CGSize, maxLongEdge requested: Int) -> CGSize {
    let limit = Double(min(max(requested, 256), maxLongEdge))
    let longEdge = Double(max(upright.width, upright.height))
    let scale = min(1, limit / max(longEdge, 1))
    func even(_ value: Double) -> CGFloat { CGFloat(max(2, (Int(value) / 2) * 2)) }
    return CGSize(width: even(Double(upright.width) * scale), height: even(Double(upright.height) * scale))
  }

  /// Applies the track's orientation, then scales and centres it inside the frame (letterbox).
  private static func fitTransform(
    preferred: CGAffineTransform, natural: CGSize, upright: CGSize, into frame: CGSize
  ) -> CGAffineTransform {
    // preferredTransform may translate the rotated rect anywhere; normalize to the origin first.
    let rotatedRect = CGRect(origin: .zero, size: natural).applying(preferred)
    let normalized = preferred.concatenating(
      CGAffineTransform(translationX: -rotatedRect.minX, y: -rotatedRect.minY))
    let scale = min(frame.width / max(upright.width, 1), frame.height / max(upright.height, 1))
    let scaledWidth = upright.width * scale
    let scaledHeight = upright.height * scale
    return normalized
      .concatenating(CGAffineTransform(scaleX: scale, y: scale))
      .concatenating(
        CGAffineTransform(translationX: (frame.width - scaledWidth) / 2, y: (frame.height - scaledHeight) / 2))
  }

  // MARK: - Rendering

  private func render(
    _ built: BuiltComposition, job: VideoExportJob, to url: URL, isCancelled: @escaping () -> Bool,
    progress: @escaping (Double) -> Void
  ) async throws -> Bool {
    let reader = try AVAssetReader(asset: built.composition)
    let videoOutput = AVAssetReaderVideoCompositionOutput(
      videoTracks: [built.videoTrack],
      videoSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        // The Metal renderer wraps frames through a CVMetalTextureCache.
        kCVPixelBufferMetalCompatibilityKey as String: true,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
      ])
    videoOutput.videoComposition = built.videoComposition
    videoOutput.alwaysCopiesSampleData = false
    guard reader.canAdd(videoOutput) else { throw VideoExportError.failed("cannot read video") }
    reader.add(videoOutput)

    var audioOutput: AVAssetReaderAudioMixOutput?
    if !built.audioTracks.isEmpty {
      let output = AVAssetReaderAudioMixOutput(
        audioTracks: built.audioTracks,
        audioSettings: [
          AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 2,
          AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
          AVLinearPCMIsNonInterleaved: false,
        ])
      output.audioMix = built.audioMix
      if reader.canAdd(output) {
        reader.add(output)
        audioOutput = output
      }
    }

    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let width = Int(built.renderSize.width)
    let height = Int(built.renderSize.height)
    let bitrate = min(max(Int(Double(width * height) * 30 * 0.12), 2_000_000), 20_000_000)
    let videoInput = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: bitrate, AVVideoMaxKeyFrameIntervalKey: 30,
          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        ],
      ])
    videoInput.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: videoInput,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferMetalCompatibilityKey as String: true,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
      ])
    guard writer.canAdd(videoInput) else { throw VideoExportError.failed("cannot write video") }
    writer.add(videoInput)
    var audioInput: AVAssetWriterInput?
    if audioOutput != nil {
      let input = AVAssetWriterInput(
        mediaType: .audio,
        outputSettings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 2,
          AVEncoderBitRateKey: 160_000,
        ])
      input.expectsMediaDataInRealTime = false
      if writer.canAdd(input) {
        writer.add(input)
        audioInput = input
      }
    }

    let frames = try FrameProcessor(job: job, renderSize: built.renderSize, ciContext: ciContext)

    guard reader.startReading() else {
      throw VideoExportError.failed(reader.error?.localizedDescription ?? "cannot start reading")
    }
    guard writer.startWriting() else {
      reader.cancelReading()
      throw VideoExportError.failed(writer.error?.localizedDescription ?? "cannot start writing")
    }
    writer.startSession(atSourceTime: .zero)

    let totalSeconds = max(CMTimeGetSeconds(built.duration), 0.001)
    let failure = LockedValue<Error?>(nil)
    let group = DispatchGroup()
    let videoQueue = DispatchQueue(label: "app.yuz.beauty_engine.export.video")
    let audioQueue = DispatchQueue(label: "app.yuz.beauty_engine.export.audio")

    group.enter()
    videoInput.requestMediaDataWhenReady(on: videoQueue) {
      while videoInput.isReadyForMoreMediaData {
        if isCancelled() || failure.value != nil {
          videoInput.markAsFinished()
          group.leave()
          return
        }
        guard let sample = videoOutput.copyNextSampleBuffer() else {
          videoInput.markAsFinished()
          group.leave()
          return
        }
        let time = CMSampleBufferGetPresentationTimeStamp(sample)
        do {
          guard let source = CMSampleBufferGetImageBuffer(sample) else { continue }
          let frame = try autoreleasepool { try frames.process(source, at: time, pool: adaptor.pixelBufferPool) }
          if !adaptor.append(frame, withPresentationTime: time) {
            throw VideoExportError.failed(writer.error?.localizedDescription ?? "append failed")
          }
          progress(min(1, CMTimeGetSeconds(time) / totalSeconds) * 0.98)
        } catch {
          failure.value = error
          videoInput.markAsFinished()
          group.leave()
          return
        }
      }
    }

    if let audioOutput, let audioInput {
      group.enter()
      audioInput.requestMediaDataWhenReady(on: audioQueue) {
        while audioInput.isReadyForMoreMediaData {
          if isCancelled() || failure.value != nil {
            audioInput.markAsFinished()
            group.leave()
            return
          }
          guard let sample = audioOutput.copyNextSampleBuffer() else {
            audioInput.markAsFinished()
            group.leave()
            return
          }
          if !audioInput.append(sample) {
            failure.value = VideoExportError.failed(writer.error?.localizedDescription ?? "audio append failed")
            audioInput.markAsFinished()
            group.leave()
            return
          }
        }
      }
    }

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      group.notify(queue: .global(qos: .userInitiated)) { continuation.resume() }
    }
    frames.close()

    if isCancelled() {
      reader.cancelReading()
      writer.cancelWriting()
      throw VideoExportError.cancelled
    }
    if let error = failure.value {
      reader.cancelReading()
      writer.cancelWriting()
      throw error
    }
    if reader.status == .failed {
      writer.cancelWriting()
      throw VideoExportError.failed(reader.error?.localizedDescription ?? "reading failed")
    }
    writer.endSession(atSourceTime: built.duration)
    await writer.finishWriting()
    guard writer.status == .completed else {
      throw VideoExportError.failed(writer.error?.localizedDescription ?? "finishWriting failed")
    }
    return audioInput != nil
  }
}

/// Lock-protected value shared by the writer's video and audio queues.
final class LockedValue<Value> {
  private let lock = NSLock()
  private var stored: Value

  init(_ value: Value) { stored = value }

  var value: Value {
    get {
      lock.lock()
      defer { lock.unlock() }
      return stored
    }
    set {
      lock.lock()
      stored = newValue
      lock.unlock()
    }
  }
}

/// Per-frame beauty + overlays. Used from the writer's video queue only.
private final class FrameProcessor {
  private let settings: BeautySettings
  private let renderer: MetalBeautyRenderer
  private let ciContext: CIContext
  private let renderSize: CGSize
  private let overlays: [(image: CIImage, start: Double, end: Double)]
  private var landmarker: FaceLandmarker?
  private let tracker = FaceTracker(maxFaces: 4, policy: .allFaces)
  private var lastDetectionMillis = -1
  private var lastFaces: [TrackedFace] = []

  init(job: VideoExportJob, renderSize: CGSize, ciContext: CIContext) throws {
    settings = job.settings
    renderer = try MetalBeautyRenderer()
    renderer.setLut(job.lut)
    self.ciContext = ciContext
    self.renderSize = renderSize
    overlays = try job.overlays.map { overlay in
      guard let image = CIImage(contentsOf: overlay.url) else { throw VideoExportError.unreadable(overlay.url.path) }
      // Overlays are rendered at the output size; scale defensively if not.
      let scaled = image.transformed(
        by: CGAffineTransform(
          scaleX: renderSize.width / max(image.extent.width, 1), y: renderSize.height / max(image.extent.height, 1)))
      return (scaled, Double(overlay.startMillis) / 1000, Double(overlay.endMillis) / 1000)
    }
    if settings.usesFaces { landmarker = Self.makeLandmarker() }
  }

  func process(_ source: CVPixelBuffer, at time: CMTime, pool: CVPixelBufferPool?) throws -> CVPixelBuffer {
    let faces = detectFaces(source, at: time)
    let beautified = try renderSync(source, faces: faces)
    let seconds = CMTimeGetSeconds(time)
    let visible = overlays.filter { seconds >= $0.start && seconds < $0.end }
    if visible.isEmpty, CVPixelBufferGetWidth(beautified) == Int(renderSize.width),
      CVPixelBufferGetHeight(beautified) == Int(renderSize.height)
    {
      return beautified
    }
    guard let pool else { throw VideoExportError.failed("writer has no pixel buffer pool") }
    var output: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &output) == kCVReturnSuccess, let output else {
      throw VideoExportError.failed("cannot allocate output frame")
    }
    var image = CIImage(cvPixelBuffer: beautified)
    for overlay in visible { image = overlay.image.composited(over: image) }
    ciContext.render(image, to: output, bounds: CGRect(origin: .zero, size: renderSize), colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    return output
  }

  func close() {
    landmarker = nil
  }

  private func renderSync(_ input: CVPixelBuffer, faces: [TrackedFace]?) throws -> CVPixelBuffer {
    let done = DispatchSemaphore(value: 0)
    var processed: CVPixelBuffer?
    var submitted = false
    for _ in 0..<100 where !submitted {
      submitted = renderer.render(input: input, settings: settings, faces: faces) { output in
        processed = output
        done.signal()
      }
      if !submitted { Thread.sleep(forTimeInterval: 0.005) }
    }
    guard submitted, done.wait(timeout: .now() + 10) == .success, let processed else {
      throw VideoExportError.failed("GPU render timed out")
    }
    return processed
  }

  /// nil when the model is unavailable (colour-only skin detection).
  private func detectFaces(_ buffer: CVPixelBuffer, at time: CMTime) -> [TrackedFace]? {
    guard settings.usesFaces else { return [] }
    guard let landmarker else { return nil }
    let millis = Int((CMTimeGetSeconds(time) * 1000).rounded())
    // VIDEO mode requires strictly increasing timestamps.
    guard millis > lastDetectionMillis else { return lastFaces }
    lastDetectionMillis = millis
    do {
      let image = try MPImage(pixelBuffer: buffer)
      let result = try landmarker.detect(videoFrame: image, timestampInMilliseconds: millis)
      let detected = result.faceLandmarks.compactMap { landmarks -> DetectedFace? in
        guard landmarks.count >= FaceMaskGeometry.meshLandmarkCount else { return nil }
        return DetectedFace(landmarks: landmarks.map { NormalizedPoint(x: $0.x, y: $0.y) })
      }
      lastFaces = tracker.update(detected, timestamp: Double(millis) / 1000).beautifiedFaces
      return lastFaces
    } catch {
      return []
    }
  }

  private static func makeLandmarker() -> FaceLandmarker? {
    guard let modelPath = FaceLandmarkDetector.modelPath() else { return nil }
    for delegate in [Delegate.GPU, Delegate.CPU] {
      let options = FaceLandmarkerOptions()
      options.baseOptions.modelAssetPath = modelPath
      options.baseOptions.delegate = delegate
      options.runningMode = .video
      options.numFaces = 4
      options.minFaceDetectionConfidence = 0.5
      options.minFacePresenceConfidence = 0.5
      options.minTrackingConfidence = 0.5
      if let created = try? FaceLandmarker(options: options) { return created }
    }
    return nil
  }
}

/// Probing and thumbnails for the editor timeline.
enum VideoInspector {
  struct Metadata {
    let durationMillis: Int
    let width: Int
    let height: Int
    let rotationDegrees: Int
    let hasAudio: Bool
  }

  static func probe(_ url: URL) async throws -> Metadata {
    guard FileManager.default.fileExists(atPath: url.path) else { throw VideoExportError.unreadable(url.path) }
    let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
      throw VideoExportError.unreadable(url.path)
    }
    let duration = try await asset.load(.duration)
    let natural = try await track.load(.naturalSize)
    let transform = try await track.load(.preferredTransform)
    let upright = natural.applying(transform)
    let angle = atan2(transform.b, transform.a) * 180 / .pi
    let rotation = (Int(angle.rounded()) + 360) % 360
    let hasAudio = !(try await asset.loadTracks(withMediaType: .audio)).isEmpty
    return Metadata(
      durationMillis: Int((CMTimeGetSeconds(duration) * 1000).rounded()), width: Int(abs(upright.width).rounded()),
      height: Int(abs(upright.height).rounded()), rotationDegrees: rotation, hasAudio: hasAudio)
  }

  static func thumbnails(_ url: URL, count: Int, maxEdge: Int, directory: URL) async throws -> [String] {
    guard (1...60).contains(count) else { throw VideoExportError.invalid("count must be 1...60") }
    let asset = AVURLAsset(url: url)
    let duration = try await asset.load(.duration)
    let seconds = CMTimeGetSeconds(duration)
    guard seconds > 0 else { throw VideoExportError.unreadable(url.path) }
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: maxEdge, height: maxEdge)
    generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
    generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let context = CIContext()
    var paths: [String] = []
    for index in 0..<count {
      let time = CMTime(seconds: seconds * Double(2 * index + 1) / Double(2 * count), preferredTimescale: 600)
      let image: CGImage
      if #available(iOS 16, *) {
        image = try await generator.image(at: time).image
      } else {
        image = try generator.copyCGImage(at: time, actualTime: nil)
      }
      let file = directory.appendingPathComponent("thumb_\(index).jpg")
      guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { throw VideoExportError.failed("sRGB") }
      try context.writeJPEGRepresentation(
        of: CIImage(cgImage: image), to: file, colorSpace: colorSpace,
        options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.85])
      paths.append(file.path)
    }
    return paths
  }
}
