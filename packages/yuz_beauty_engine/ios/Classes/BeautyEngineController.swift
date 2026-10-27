import AVFoundation
import CoreImage
import Flutter
import Foundation
import os

/// Implements the Pigeon host API on iOS. Camera configuration runs on the
/// session queue, frames on the video queue, GPU work on Metal's queues.
/// Mutable state shared between them is guarded by `stateLock`.
final class BeautyEngineController: NSObject, BeautyEngineHostApi,
  AVCaptureVideoDataOutputSampleBufferDelegate
{
  private static let log = Logger(subsystem: "app.yuz.beauty_engine", category: "Controller")
  private static let firstFrameTimeout: TimeInterval = 5
  private static let faceStaleSeconds: TimeInterval = 0.3
  private static let statusHeartbeatSeconds: TimeInterval = 1
  private static let torchSettleSeconds: UInt64 = 400_000_000
  private static let autoFlashLumaThreshold: Float = 0.18
  private static let reducedDetectionThermalLevel = 2
  private static let criticalThermalLevel = 3

  private let registry: FlutterTextureRegistry
  private let events: BeautyEngineEventsApi
  private let previewTexture = PreviewTexture()
  private let performance = PerformanceTracker()
  private lazy var ciContext = CIContext(options: [.cacheIntermediates: false])

  private let stateLock = NSLock()
  private var camera: CameraSession?
  private var renderer: MetalBeautyRenderer?
  private var detector: FaceLandmarkDetector?
  private var tracker: FaceTracker?
  private var textureId: Int64 = -1
  private var settings = BeautySettings()
  private var latestFaces = FaceTrackingSnapshot.empty
  private var flashMode: FlashMode = .off
  private var frameCounter = 0
  private var sceneLuma: Float = 0.5
  private var firstFrameWaiter: FirstFrameWaiter?
  private var lastSentStatus: (Int, Int)?
  private var lastStatusSentAt: TimeInterval = 0
  private var performanceTimer: DispatchSourceTimer?
  private var notificationTokens: [NSObjectProtocol] = []
  private var thermalLevel = 0

  init(registry: FlutterTextureRegistry, events: BeautyEngineEventsApi) {
    self.registry = registry
    self.events = events
    super.init()
  }

  // MARK: - BeautyEngineHostApi

  func initialize(config: EngineConfig) async throws -> PreviewDescriptor {
    guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
      throw Self.error(.permissionDenied, "Camera permission has not been granted")
    }
    await disposeSession()

    let renderer: MetalBeautyRenderer
    do {
      renderer = try MetalBeautyRenderer()
    } catch {
      throw Self.error(.gpuInitializationFailed, "Metal initialization failed: \(error)")
    }
    let camera = CameraSession()
    camera.sampleBufferDelegate = self
    let detector = config.enableFaceTracking ? FaceLandmarkDetector.make(maxFaces: Int(config.maxFaces)) : nil
    let tracker = FaceTracker(
      maxFaces: min(max(Int(config.maxFaces), 1), 4),
      policy: config.multiFacePolicy == .allFaces ? .allFaces : .primaryFace)
    detector?.onResult = { [weak self] faces, inference in
      self?.handleDetections(faces, inferenceSeconds: inference)
    }

    let textureId = registry.register(previewTexture)
    withState {
      self.camera = camera
      self.renderer = renderer
      self.detector = detector
      self.tracker = tracker
      self.textureId = textureId
      self.latestFaces = .empty
      self.thermalLevel = Self.normalizedThermalLevel()
    }
    observeNotifications()

    do {
      let size = try await configureAndAwaitFirstFrame(
        camera: camera, lens: config.lens,
        format: CameraFormatRequest(aspectRatio: config.aspectRatio, quality: config.quality))
      startPerformanceReporting()
      return PreviewDescriptor(
        textureId: textureId, width: Int64(size.width), height: Int64(size.height), lens: config.lens,
        isMirrored: config.lens == .front, faceTrackingAvailable: detector != nil)
    } catch {
      await disposeSession()
      throw Self.mapError(error)
    }
  }

  func switchLens(lens: CameraLens) async throws -> PreviewDescriptor {
    guard let camera = withState({ self.camera }) else {
      throw Self.error(.cameraUnavailable, "Engine is not initialized")
    }
    withState {
      tracker?.reset()
      latestFaces = .empty
    }
    let format = withState { currentFormat } ?? CameraFormatRequest(aspectRatio: .ratio16x9, quality: .high1080)
    do {
      let size = try await configureAndAwaitFirstFrame(camera: camera, lens: lens, format: format)
      return PreviewDescriptor(
        textureId: withState { textureId }, width: Int64(size.width), height: Int64(size.height),
        lens: lens, isMirrored: lens == .front, faceTrackingAvailable: withState { detector != nil })
    } catch {
      throw Self.mapError(error)
    }
  }

  func getCapabilities() throws -> CameraCapabilities {
    let device = withState { camera?.device }
    return CameraCapabilities(
      hasFrontCamera: CameraSession.hasCamera(.front),
      hasBackCamera: CameraSession.hasCamera(.back),
      hasFlash: device?.hasTorch ?? false,
      minZoomRatio: Double(device?.minAvailableVideoZoomFactor ?? 1),
      maxZoomRatio: Double(min(device?.maxAvailableVideoZoomFactor ?? 1, 10)),
      minExposureBias: Double(device?.minExposureTargetBias ?? 0),
      maxExposureBias: Double(device?.maxExposureTargetBias ?? 0))
  }

  func setBeautyParameters(parameters: BeautyParameters) throws {
    let clamp: (Double) -> Float = { Float(min(max($0, 0), 1)) }
    withState {
      settings = BeautySettings(
        skinSmoothing: clamp(parameters.skinSmoothing),
        texturePreservation: clamp(parameters.texturePreservation),
        skinBrightening: clamp(parameters.skinBrightening))
    }
  }

  func setFlashMode(mode: FlashMode) throws {
    withState { flashMode = mode }
    setTorch(mode == .torch)
  }

  func setZoomRatio(ratio: Double) throws {
    guard let device = withState({ camera?.device }) else { return }
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }
    let upper = min(device.maxAvailableVideoZoomFactor, 10)
    device.videoZoomFactor = min(max(CGFloat(ratio), device.minAvailableVideoZoomFactor), upper)
  }

  func setExposureBias(ev: Double) throws {
    guard let device = withState({ camera?.device }) else { return }
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }
    let bias = min(max(Float(ev), device.minExposureTargetBias), device.maxExposureTargetBias)
    device.setExposureTargetBias(bias, completionHandler: nil)
  }

  func capturePhoto(outputFilePath: String) async throws -> PhotoCaptureResult {
    let (device, mode, luma) = withState { (camera?.device, flashMode, sceneLuma) }
    guard device != nil else { throw Self.error(.cameraUnavailable, "Camera is not running") }
    let useTorch =
      (device?.hasTorch ?? false)
      && (mode == .on || (mode == .auto && luma < Self.autoFlashLumaThreshold))
    if useTorch {
      setTorch(true)
      try? await Task.sleep(nanoseconds: Self.torchSettleSeconds)
    }
    defer { if useTorch { setTorch(mode == .torch) } }

    guard let frame = previewTexture.latestPixelBuffer() else {
      throw Self.error(.captureFailed, "No processed frame available yet")
    }
    let url = URL(fileURLWithPath: outputFilePath)
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      let image = CIImage(cvPixelBuffer: frame)
      guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        throw Self.error(.captureFailed, "sRGB colour space unavailable")
      }
      try ciContext.writeJPEGRepresentation(
        of: image, to: url, colorSpace: colorSpace,
        options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.95])
    } catch let error as BeautyEngineFlutterError {
      throw error
    } catch {
      throw Self.error(.captureFailed, "JPEG encoding failed: \(error.localizedDescription)")
    }
    return PhotoCaptureResult(
      filePath: outputFilePath, width: Int64(CVPixelBufferGetWidth(frame)),
      height: Int64(CVPixelBufferGetHeight(frame)))
  }

  func pause() async throws {
    guard let camera = withState({ self.camera }) else { return }
    stopPerformanceReporting()
    await withCheckedContinuation { continuation in
      camera.sessionQueue.async {
        camera.stop()
        continuation.resume()
      }
    }
  }

  func resume() async throws {
    guard let camera = withState({ self.camera }) else { return }
    await withCheckedContinuation { continuation in
      camera.sessionQueue.async {
        camera.start()
        continuation.resume()
      }
    }
    startPerformanceReporting()
  }

  func dispose() async throws {
    await disposeSession()
  }

  // MARK: - Frames

  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    performance.onCameraFrame()

    let snapshot = withState {
      () -> (MetalBeautyRenderer?, FaceLandmarkDetector?, BeautySettings, FaceTrackingSnapshot, Int, Int, Int64, FirstFrameWaiter?) in
      frameCounter += 1
      return (renderer, detector, settings, latestFaces, frameCounter, thermalLevel, textureId, firstFrameWaiter)
    }
    let (renderer, detector, settings, faces, counter, thermal, textureId, waiter) = snapshot
    waiter?.resolve(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))

    if counter % 10 == 0 {
      let luma = Self.estimateLuma(pixelBuffer)
      withState { sceneLuma = luma }
    }

    let skipDetection =
      thermal >= Self.criticalThermalLevel
      || (thermal >= Self.reducedDetectionThermalLevel && counter % 2 == 1)
    if let detector, !skipDetection {
      detector.analyze(sampleBuffer: sampleBuffer)
    }

    let facesForRender: [TrackedFace]?
    if detector == nil || thermal >= Self.criticalThermalLevel {
      facesForRender = nil
    } else if ProcessInfo.processInfo.systemUptime - faces.timestamp > Self.faceStaleSeconds {
      facesForRender = []
    } else {
      facesForRender = faces.beautifiedFaces
    }

    guard let renderer else { return }
    let start = ProcessInfo.processInfo.systemUptime
    let submitted = renderer.render(input: pixelBuffer, settings: settings, faces: facesForRender) {
      [weak self] processed in
      guard let self else { return }
      self.previewTexture.update(processed)
      self.performance.onFrameRendered(gpuSeconds: ProcessInfo.processInfo.systemUptime - start)
      DispatchQueue.main.async { [registry = self.registry] in
        registry.textureFrameAvailable(textureId)
      }
    }
    if !submitted { performance.onFrameDropped() }
  }

  func captureOutput(
    _ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
  ) {
    performance.onFrameDropped()
  }

  // MARK: - Internals

  private var currentFormat: CameraFormatRequest?

  private func configureAndAwaitFirstFrame(
    camera: CameraSession, lens: CameraLens, format: CameraFormatRequest
  ) async throws -> (width: Int, height: Int) {
    let waiter = FirstFrameWaiter()
    withState {
      firstFrameWaiter = waiter
      currentFormat = format
    }
    defer { withState { if firstFrameWaiter === waiter { firstFrameWaiter = nil } } }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      camera.sessionQueue.async {
        do {
          try camera.configure(lens: lens, format: format)
          camera.start()
          continuation.resume()
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
    let mode = withState { flashMode }
    if mode == .torch { setTorch(true) }
    return try await waiter.wait(timeout: Self.firstFrameTimeout)
  }

  private func handleDetections(_ faces: [DetectedFace], inferenceSeconds: TimeInterval) {
    performance.onDetectorRun(seconds: inferenceSeconds)
    let now = ProcessInfo.processInfo.systemUptime
    let result: (FaceTrackingSnapshot, Bool)? = withState {
      guard let tracker else { return nil }
      let snapshot = tracker.update(faces, timestamp: now)
      latestFaces = snapshot
      let status = (snapshot.detectedFaceCount, snapshot.beautifiedFaces.count)
      let changed = lastSentStatus.map { $0 != status } ?? true
      guard changed || now - lastStatusSentAt >= Self.statusHeartbeatSeconds else { return (snapshot, false) }
      lastSentStatus = status
      lastStatusSentAt = now
      return (snapshot, true)
    }
    guard let result, result.1 else { return }
    let snapshot = result.0
    let status = FaceTrackingStatus(
      faceCount: Int64(snapshot.detectedFaceCount),
      beautifiedFaceCount: Int64(snapshot.beautifiedFaces.count),
      timestampMillis: Int64(Date().timeIntervalSince1970 * 1000))
    Task { @MainActor [events] in try? await events.onFaceTrackingStatus(status: status) }
  }

  private func stopPerformanceReporting() {
    let timer = withState { () -> DispatchSourceTimer? in
      let current = performanceTimer
      performanceTimer = nil
      return current
    }
    timer?.cancel()
  }

  private func startPerformanceReporting() {
    stopPerformanceReporting()
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + 1, repeating: 1)
    timer.setEventHandler { [weak self] in
      guard let self else { return }
      let snapshot = self.performance.drain()
      let sample = PerformanceSample(
        renderedFps: snapshot.renderedFps, cameraFps: snapshot.cameraFps,
        averageGpuFrameMillis: snapshot.averageGpuFrameMillis,
        averageDetectorMillis: snapshot.averageDetectorMillis,
        droppedFrames: Int64(snapshot.droppedFrames),
        thermalLevel: Int64(self.withState { self.thermalLevel }))
      Task { @MainActor [events = self.events] in try? await events.onPerformanceSample(sample: sample) }
    }
    timer.resume()
    withState { performanceTimer = timer }
  }

  private func observeNotifications() {
    let center = NotificationCenter.default
    notificationTokens.append(
      center.addObserver(
        forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
      ) { [weak self] _ in
        guard let self else { return }
        let level = Self.normalizedThermalLevel()
        self.withState { self.thermalLevel = level }
        if level >= Self.criticalThermalLevel {
          self.emitError(.thermalThrottling, "Device is overheating; face tracking paused")
        }
      })
    notificationTokens.append(
      center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: nil, queue: .main) {
        [weak self] notification in
        let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
        let code: EngineErrorCode = error?.code == .mediaServicesWereReset ? .cameraDisconnected : .unknown
        self?.emitError(code, "Capture session runtime error: \(error?.localizedDescription ?? "unknown")")
      })
    notificationTokens.append(
      center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: nil, queue: .main) {
        [weak self] notification in
        let raw = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int
        let reason = raw.flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
        let code: EngineErrorCode =
          reason == .videoDeviceInUseByAnotherClient ? .cameraInUse : .cameraUnavailable
        self?.emitError(code, "Capture session interrupted (\(raw ?? -1))")
      })
  }

  private func emitError(_ code: EngineErrorCode, _ message: String) {
    let error = EngineError(code: code, message: message)
    Task { @MainActor [events] in try? await events.onEngineError(error: error) }
  }

  private func disposeSession() async {
    let (camera, detector, textureId, timer) = withState {
      () -> (CameraSession?, FaceLandmarkDetector?, Int64, DispatchSourceTimer?) in
      let values = (self.camera, self.detector, self.textureId, self.performanceTimer)
      self.camera = nil
      self.renderer = nil
      self.detector = nil
      self.tracker = nil
      self.textureId = -1
      self.performanceTimer = nil
      self.firstFrameWaiter?.fail(Self.error(.cameraUnavailable, "Engine disposed"))
      self.firstFrameWaiter = nil
      return values
    }
    timer?.cancel()
    notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    notificationTokens.removeAll()
    detector?.close()
    if let camera {
      await withCheckedContinuation { continuation in
        camera.sessionQueue.async {
          camera.teardown()
          continuation.resume()
        }
      }
    }
    previewTexture.clear()
    if textureId >= 0 { registry.unregisterTexture(textureId) }
  }

  private func setTorch(_ enabled: Bool) {
    guard let device = withState({ camera?.device }), device.hasTorch else { return }
    do {
      try device.lockForConfiguration()
      device.torchMode = enabled ? .on : .off
      device.unlockForConfiguration()
    } catch {
      Self.log.warning("Torch configuration failed: \(error.localizedDescription)")
    }
  }

  @discardableResult
  private func withState<T>(_ body: () -> T) -> T {
    stateLock.lock()
    defer { stateLock.unlock() }
    return body()
  }

  private static func normalizedThermalLevel() -> Int {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: return 0
    case .fair: return 1
    case .serious: return 2
    case .critical: return 3
    @unknown default: return 3
    }
  }

  private static func estimateLuma(_ pixelBuffer: CVPixelBuffer) -> Float {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0.5 }
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let bytes = base.assumingMemoryBound(to: UInt8.self)
    var sum: Float = 0
    var samples: Float = 0
    for row in stride(from: height / 16, to: height, by: max(1, height / 8)) {
      for column in stride(from: width / 16, to: width, by: max(1, width / 8)) {
        let offset = row * rowBytes + column * 4
        // BGRA byte order.
        let b = Float(bytes[offset]), g = Float(bytes[offset + 1]), r = Float(bytes[offset + 2])
        sum += (0.299 * r + 0.587 * g + 0.114 * b) / 255
        samples += 1
      }
    }
    return samples > 0 ? sum / samples : 0.5
  }

  static func error(_ code: EngineErrorCode, _ message: String) -> BeautyEngineFlutterError {
    BeautyEngineFlutterError(code: code.flutterCode, message: message, details: nil)
  }

  private static func mapError(_ error: Error) -> Error {
    switch error {
    case let flutterError as BeautyEngineFlutterError:
      return flutterError
    case CameraSessionError.deviceUnavailable(let lens):
      return Self.error(.cameraUnavailable, "No \(lens == .front ? "front" : "back") camera")
    case CameraSessionError.configurationFailed(let reason):
      return Self.error(.cameraUnavailable, reason)
    case is FirstFrameWaiter.Timeout:
      return Self.error(.cameraUnavailable, "Camera did not deliver a frame in time")
    default:
      return Self.error(.unknown, error.localizedDescription)
    }
  }
}

extension EngineErrorCode {
  /// Same strings as the Android engine (Kotlin enum names).
  var flutterCode: String {
    switch self {
    case .permissionDenied: return "PERMISSION_DENIED"
    case .cameraUnavailable: return "CAMERA_UNAVAILABLE"
    case .cameraInUse: return "CAMERA_IN_USE"
    case .cameraDisconnected: return "CAMERA_DISCONNECTED"
    case .gpuInitializationFailed: return "GPU_INITIALIZATION_FAILED"
    case .faceModelUnavailable: return "FACE_MODEL_UNAVAILABLE"
    case .captureFailed: return "CAPTURE_FAILED"
    case .thermalThrottling: return "THERMAL_THROTTLING"
    case .unknown: return "UNKNOWN"
    }
  }
}

/// Resolves once the first frame of a (re)configured session arrives.
final class FirstFrameWaiter {
  struct Timeout: Error {}

  private let lock = NSLock()
  private var continuation: CheckedContinuation<(width: Int, height: Int), Error>?
  private var result: Result<(width: Int, height: Int), Error>?

  func resolve(width: Int, height: Int) {
    complete(.success((width, height)))
  }

  func fail(_ error: Error) {
    complete(.failure(error))
  }

  func wait(timeout: TimeInterval) async throws -> (width: Int, height: Int) {
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
      self?.complete(.failure(Timeout()))
    }
    return try await withCheckedThrowingContinuation { continuation in
      lock.lock()
      if let result {
        lock.unlock()
        continuation.resume(with: result)
        return
      }
      self.continuation = continuation
      lock.unlock()
    }
  }

  private func complete(_ value: Result<(width: Int, height: Int), Error>) {
    lock.lock()
    guard result == nil else {
      lock.unlock()
      return
    }
    result = value
    let pending = continuation
    continuation = nil
    lock.unlock()
    pending?.resume(with: value)
  }
}
