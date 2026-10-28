import AVFoundation
import CoreVideo
import Foundation
import os

enum VideoRecorderError: Error {
  case writerFailed(String)
  case tooShort
}

struct VideoRecordingOutput {
  let url: URL
  let durationMillis: Int
  let width: Int
  let height: Int
  let hasAudio: Bool
}

/// H.264 + AAC MP4 writer fed with processed (beautified) BGRA frames and
/// microphone sample buffers from the same capture session, so both share
/// the session's host clock. All appends happen on `queue`. The file is
/// written to a temporary path and moved into place only when complete.
final class VideoRecorder {
  private static let log = Logger(subsystem: "app.yuz.beauty_engine", category: "VideoRecorder")

  let width: Int
  let height: Int
  private let output: URL
  private let temp: URL
  private let writer: AVAssetWriter
  private let videoInput: AVAssetWriterInput
  private let adaptor: AVAssetWriterInputPixelBufferAdaptor
  private let audioInput: AVAssetWriterInput?
  private let queue = DispatchQueue(label: "app.yuz.beauty_engine.recorder")

  // Confined to `queue`.
  private var sessionStart: CMTime?
  private var lastVideoTime: CMTime = .invalid
  private var audioAppended = false
  private var finished = false

  init(output: URL, width: Int, height: Int, bitrate: Int, withAudio: Bool) throws {
    // Everything is built in locals and assigned at the end, so no stored
    // property is read before initialization completes.
    let evenWidth = width - width % 2
    let evenHeight = height - height % 2
    let partial = output.deletingLastPathComponent().appendingPathComponent(".\(output.lastPathComponent).part.mp4")
    try FileManager.default.createDirectory(
      at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? FileManager.default.removeItem(at: partial)

    let assetWriter = try AVAssetWriter(outputURL: partial, fileType: .mp4)
    let derivedBitrate = min(max(Int(Double(evenWidth * evenHeight) * 30 * 0.12), 2_000_000), 20_000_000)
    let videoSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: evenWidth,
      AVVideoHeightKey: evenHeight,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: bitrate > 0 ? min(max(bitrate, 2_000_000), 20_000_000) : derivedBitrate,
        AVVideoExpectedSourceFrameRateKey: 30,
        AVVideoMaxKeyFrameIntervalKey: 30,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
      ],
    ]
    let video = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    video.expectsMediaDataInRealTime = true
    let pixelAdaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: video,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
      ])
    guard assetWriter.canAdd(video) else { throw VideoRecorderError.writerFailed("cannot add video input") }
    assetWriter.add(video)

    var audio: AVAssetWriterInput?
    if withAudio {
      let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderBitRateKey: 128_000,
      ]
      let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
      input.expectsMediaDataInRealTime = true
      if assetWriter.canAdd(input) {
        assetWriter.add(input)
        audio = input
      }
    }
    guard assetWriter.startWriting() else {
      throw VideoRecorderError.writerFailed(assetWriter.error?.localizedDescription ?? "startWriting failed")
    }

    self.output = output
    self.width = evenWidth
    self.height = evenHeight
    temp = partial
    writer = assetWriter
    videoInput = video
    adaptor = pixelAdaptor
    audioInput = audio
  }

  /// The session starts at the first frame; audio before it is dropped so
  /// the file never begins with a black frame.
  func appendVideo(_ pixelBuffer: CVPixelBuffer, at time: CMTime) {
    queue.async { [self] in
      guard !finished, writer.status == .writing else { return }
      if sessionStart == nil {
        writer.startSession(atSourceTime: time)
        sessionStart = time
      }
      guard lastVideoTime == .invalid || time > lastVideoTime else { return }
      guard videoInput.isReadyForMoreMediaData else { return }
      if adaptor.append(pixelBuffer, withPresentationTime: time) {
        lastVideoTime = time
      } else {
        Self.log.error("Video append failed: \(self.writer.error?.localizedDescription ?? "unknown", privacy: .public)")
      }
    }
  }

  func appendAudio(_ sampleBuffer: CMSampleBuffer) {
    queue.async { [self] in
      guard !finished, let audioInput, let start = sessionStart, writer.status == .writing else { return }
      guard CMSampleBufferGetPresentationTimeStamp(sampleBuffer) >= start else { return }
      guard audioInput.isReadyForMoreMediaData else { return }
      if audioInput.append(sampleBuffer) { audioAppended = true }
    }
  }

  func finish() async throws -> VideoRecordingOutput {
    let state: (start: CMTime?, last: CMTime, audio: Bool) = queue.sync {
      finished = true
      return (sessionStart, lastVideoTime, audioAppended)
    }
    guard let start = state.start, state.last.isValid, state.last > start else {
      cancel()
      throw VideoRecorderError.tooShort
    }
    writer.endSession(atSourceTime: state.last)
    videoInput.markAsFinished()
    audioInput?.markAsFinished()
    await writer.finishWriting()
    guard writer.status == .completed else {
      try? FileManager.default.removeItem(at: temp)
      throw VideoRecorderError.writerFailed(writer.error?.localizedDescription ?? "finishWriting failed")
    }
    try? FileManager.default.removeItem(at: output)
    try FileManager.default.moveItem(at: temp, to: output)
    let seconds = CMTimeGetSeconds(CMTimeSubtract(state.last, start))
    return VideoRecordingOutput(
      url: output, durationMillis: Int((seconds * 1000).rounded()), width: width, height: height,
      hasAudio: state.audio)
  }

  func cancel() {
    queue.sync { finished = true }
    if writer.status == .writing { writer.cancelWriting() }
    try? FileManager.default.removeItem(at: temp)
  }
}
