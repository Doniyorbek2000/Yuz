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
    self.output = output
    self.width = width - width % 2
    self.height = height - height % 2
    temp = output.deletingLastPathComponent().appendingPathComponent(".\(output.lastPathComponent).part.mp4")
    try FileManager.default.createDirectory(
      at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? FileManager.default.removeItem(at: temp)

    writer = try AVAssetWriter(outputURL: temp, fileType: .mp4)
    let pixels = self.width * self.height
    let derivedBitrate = min(max(Int(Double(pixels) * 30 * 0.12), 2_000_000), 20_000_000)
    let videoSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: self.width,
      AVVideoHeightKey: self.height,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: bitrate > 0 ? min(max(bitrate, 2_000_000), 20_000_000) : derivedBitrate,
        AVVideoExpectedSourceFrameRateKey: 30,
        AVVideoMaxKeyFrameIntervalKey: 30,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
      ],
    ]
    videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    videoInput.expectsMediaDataInRealTime = true
    adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: videoInput,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
      ])
    guard writer.canAdd(videoInput) else { throw VideoRecorderError.writerFailed("cannot add video input") }
    writer.add(videoInput)

    if withAudio {
      let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderBitRateKey: 128_000,
      ]
      let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
      input.expectsMediaDataInRealTime = true
      if writer.canAdd(input) {
        writer.add(input)
        audioInput = input
      } else {
        audioInput = nil
      }
    } else {
      audioInput = nil
    }
    guard writer.startWriting() else {
      throw VideoRecorderError.writerFailed(writer.error?.localizedDescription ?? "startWriting failed")
    }
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
