import AVFoundation
import Foundation
import MediaPipeTasksVision
import os

/// MediaPipe Face Landmarker in live-stream mode with single-frame
/// backpressure: frames that arrive while inference is running are skipped.
/// Sample buffers are already upright and mirrored by the capture connection,
/// so landmarks map 1:1 onto the rendered frame.
final class FaceLandmarkDetector: NSObject, FaceLandmarkerLiveStreamDelegate {
  typealias ResultHandler = (_ faces: [DetectedFace], _ inferenceSeconds: TimeInterval) -> Void

  private static let staleInFlightSeconds: TimeInterval = 0.5
  private static let log = Logger(subsystem: "app.yuz.beauty_engine", category: "FaceDetector")

  private var landmarker: FaceLandmarker?
  private let lock = NSLock()
  private var inFlight = false
  private var submittedAt: TimeInterval = 0
  private var lastTimestampMillis = 0
  var onResult: ResultHandler?

  /// Returns nil when the bundled model is missing or no delegate works.
  static func make(maxFaces: Int) -> FaceLandmarkDetector? {
    guard let modelPath = modelPath() else {
      log.error("face_landmarker.task missing from YuzBeautyEngineResources bundle")
      return nil
    }
    let detector = FaceLandmarkDetector()
    for delegate in [Delegate.GPU, Delegate.CPU] {
      let options = FaceLandmarkerOptions()
      options.baseOptions.modelAssetPath = modelPath
      options.baseOptions.delegate = delegate
      options.runningMode = .liveStream
      options.numFaces = min(max(maxFaces, 1), 4)
      options.minFaceDetectionConfidence = 0.5
      options.minFacePresenceConfidence = 0.5
      options.minTrackingConfidence = 0.5
      options.outputFaceBlendshapes = false
      options.outputFacialTransformationMatrixes = false
      options.faceLandmarkerLiveStreamDelegate = detector
      if let landmarker = try? FaceLandmarker(options: options) {
        detector.landmarker = landmarker
        return detector
      }
      log.warning("Face landmarker delegate \(String(describing: delegate)) unavailable")
    }
    return nil
  }

  private static func modelPath() -> String? {
    let classBundle = Bundle(for: FaceLandmarkDetector.self)
    if let url = classBundle.url(forResource: "YuzBeautyEngineResources", withExtension: "bundle"),
      let resources = Bundle(url: url),
      let path = resources.path(forResource: "face_landmarker", ofType: "task")
    {
      return path
    }
    return classBundle.path(forResource: "face_landmarker", ofType: "task")
  }

  /// Submits a frame unless one is still being processed. Returns whether it was submitted.
  @discardableResult
  func analyze(sampleBuffer: CMSampleBuffer) -> Bool {
    let now = ProcessInfo.processInfo.systemUptime
    lock.lock()
    if inFlight && now - submittedAt < Self.staleInFlightSeconds {
      lock.unlock()
      return false
    }
    let timestamp = max(Int(now * 1000), lastTimestampMillis + 1)
    lastTimestampMillis = timestamp
    inFlight = true
    submittedAt = now
    lock.unlock()

    do {
      let image = try MPImage(sampleBuffer: sampleBuffer, orientation: .up)
      try landmarker?.detectAsync(image: image, timestampInMilliseconds: timestamp)
      return true
    } catch {
      markIdle()
      Self.log.warning("detectAsync failed: \(error.localizedDescription)")
      return false
    }
  }

  func faceLandmarker(
    _ faceLandmarker: FaceLandmarker, didFinishDetection result: FaceLandmarkerResult?,
    timestampInMilliseconds: Int, error: Error?
  ) {
    lock.lock()
    let inference = ProcessInfo.processInfo.systemUptime - submittedAt
    inFlight = false
    lock.unlock()
    if let error {
      Self.log.warning("Face landmarker error: \(error.localizedDescription)")
      return
    }
    let faces = (result?.faceLandmarks ?? []).compactMap { landmarks -> DetectedFace? in
      guard landmarks.count >= FaceMaskGeometry.meshLandmarkCount else { return nil }
      return DetectedFace(landmarks: landmarks.map { NormalizedPoint(x: $0.x, y: $0.y) })
    }
    onResult?(faces, inference)
  }

  private func markIdle() {
    lock.lock()
    inFlight = false
    lock.unlock()
  }

  func close() {
    onResult = nil
    landmarker = nil
  }
}
