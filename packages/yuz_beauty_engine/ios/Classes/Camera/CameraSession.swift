import AVFoundation
import Foundation

enum CameraSessionError: Error {
  case deviceUnavailable(CameraLens)
  case configurationFailed(String)
}

struct CameraFormatRequest {
  let aspectRatio: CaptureAspectRatio
  let quality: PreviewQuality

  var targetLongEdge: Int32 {
    switch quality {
    case .low720: return 1280
    case .high1080: return 1920
    }
  }

  var targetRatio: Double {
    switch aspectRatio {
    case .ratio4x3: return 4.0 / 3.0
    case .ratio16x9: return 16.0 / 9.0
    }
  }
}

/// Owns the AVCaptureSession. Configuration runs on `sessionQueue`; frames
/// are delivered upright (portrait) and mirrored for the front camera on
/// `videoQueue`, with late frames discarded by AVFoundation.
final class CameraSession: NSObject {
  let sessionQueue = DispatchQueue(label: "app.yuz.beauty_engine.session")
  let videoQueue = DispatchQueue(label: "app.yuz.beauty_engine.video", qos: .userInteractive)
  let audioQueue = DispatchQueue(label: "app.yuz.beauty_engine.audio", qos: .userInitiated)

  private let session = AVCaptureSession()
  private let videoOutput = AVCaptureVideoDataOutput()
  private let audioOutput = AVCaptureAudioDataOutput()
  private var audioInput: AVCaptureDeviceInput?
  private var input: AVCaptureDeviceInput?
  private(set) var device: AVCaptureDevice?
  private(set) var lens: CameraLens = .front

  weak var sampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?
  weak var audioSampleBufferDelegate: AVCaptureAudioDataOutputSampleBufferDelegate?

  /// Adds the microphone only while recording: an always-attached mic would
  /// interrupt other apps' audio whenever the camera is open. Must be called
  /// on `sessionQueue`. Returns false when the microphone is unavailable.
  @discardableResult
  func setAudioEnabled(_ enabled: Bool) -> Bool {
    if !enabled {
      guard audioInput != nil || session.outputs.contains(audioOutput) else { return true }
      session.beginConfiguration()
      if let audioInput { session.removeInput(audioInput) }
      if session.outputs.contains(audioOutput) { session.removeOutput(audioOutput) }
      session.commitConfiguration()
      audioOutput.setSampleBufferDelegate(nil, queue: nil)
      audioInput = nil
      return true
    }
    guard audioInput == nil else { return true }
    guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
      let microphone = AVCaptureDevice.default(for: .audio),
      let input = try? AVCaptureDeviceInput(device: microphone)
    else { return false }
    session.beginConfiguration()
    defer { session.commitConfiguration() }
    guard session.canAddInput(input), session.canAddOutput(audioOutput) else { return false }
    session.addInput(input)
    session.addOutput(audioOutput)
    audioOutput.setSampleBufferDelegate(audioSampleBufferDelegate, queue: audioQueue)
    audioInput = input
    return true
  }

  var isRunning: Bool { session.isRunning }

  static func hasCamera(_ lens: CameraLens) -> Bool {
    captureDevice(for: lens) != nil
  }

  private static func captureDevice(for lens: CameraLens) -> AVCaptureDevice? {
    let position: AVCaptureDevice.Position = lens == .front ? .front : .back
    return AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: position
    ).devices.first
  }

  /// Configures the session for `lens`. Must be called on `sessionQueue`.
  func configure(lens: CameraLens, format request: CameraFormatRequest) throws {
    guard let device = Self.captureDevice(for: lens) else {
      throw CameraSessionError.deviceUnavailable(lens)
    }
    session.beginConfiguration()
    defer { session.commitConfiguration() }

    if let input { session.removeInput(input) }
    let newInput = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(newInput) else {
      throw CameraSessionError.configurationFailed("cannot add camera input")
    }
    session.addInput(newInput)
    input = newInput
    self.device = device
    self.lens = lens

    if !session.outputs.contains(videoOutput) {
      videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
      videoOutput.alwaysDiscardsLateVideoFrames = true
      guard session.canAddOutput(videoOutput) else {
        throw CameraSessionError.configurationFailed("cannot add video output")
      }
      session.addOutput(videoOutput)
    }
    videoOutput.setSampleBufferDelegate(sampleBufferDelegate, queue: videoQueue)

    session.sessionPreset = .inputPriority
    try applyFormat(device: device, request: request)

    if let connection = videoOutput.connection(with: .video) {
      if #available(iOS 17.0, *) {
        if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
      } else if connection.isVideoOrientationSupported {
        connection.videoOrientation = .portrait
      }
      if connection.isVideoMirroringSupported {
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = lens == .front
      }
    }
  }

  func start() {
    if !session.isRunning { session.startRunning() }
  }

  func stop() {
    if session.isRunning { session.stopRunning() }
  }

  func teardown() {
    stop()
    session.beginConfiguration()
    session.inputs.forEach { session.removeInput($0) }
    session.outputs.forEach { session.removeOutput($0) }
    session.commitConfiguration()
    videoOutput.setSampleBufferDelegate(nil, queue: nil)
    audioOutput.setSampleBufferDelegate(nil, queue: nil)
    audioInput = nil
    input = nil
    device = nil
  }

  /// Picks the largest format whose aspect matches and whose long edge does
  /// not exceed the requested quality, and locks it to 30 fps when possible.
  private func applyFormat(device: AVCaptureDevice, request: CameraFormatRequest) throws {
    let candidates = device.formats.filter { format in
      let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
      let longEdge = max(dimensions.width, dimensions.height)
      let shortEdge = max(1, min(dimensions.width, dimensions.height))
      let ratio = Double(longEdge) / Double(shortEdge)
      let supports30 = format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 30 }
      return longEdge <= request.targetLongEdge && abs(ratio - request.targetRatio) < 0.02 && supports30
    }
    guard
      let best = candidates.max(by: { lhs, rhs in
        let l = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
        let r = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
        return Int(l.width) * Int(l.height) < Int(r.width) * Int(r.height)
      })
    else {
      session.sessionPreset = request.quality == .high1080 ? .hd1920x1080 : .hd1280x720
      return
    }
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }
    device.activeFormat = best
    let frameDuration = CMTime(value: 1, timescale: 30)
    device.activeVideoMinFrameDuration = frameDuration
    device.activeVideoMaxFrameDuration = frameDuration
  }
}
