import Foundation

/// Measured (never estimated) per-second statistics; see PerformanceTracker.kt.
final class PerformanceTracker {
  struct Snapshot {
    let renderedFps: Double
    let cameraFps: Double
    let averageGpuFrameMillis: Double
    let averageDetectorMillis: Double
    let droppedFrames: Int
  }

  private let lock = NSLock()
  private var renderedFrames = 0
  private var cameraFrames = 0
  private var droppedFrames = 0
  private var gpuSecondsTotal: Double = 0
  private var detectorSecondsTotal: Double = 0
  private var detectorRuns = 0
  private var windowStart = ProcessInfo.processInfo.systemUptime

  func onCameraFrame() { locked { cameraFrames += 1 } }

  func onFrameRendered(gpuSeconds: Double) {
    locked {
      renderedFrames += 1
      gpuSecondsTotal += gpuSeconds
    }
  }

  func onFrameDropped() { locked { droppedFrames += 1 } }

  func onDetectorRun(seconds: Double) {
    locked {
      detectorRuns += 1
      detectorSecondsTotal += seconds
    }
  }

  func drain() -> Snapshot {
    locked {
      let now = ProcessInfo.processInfo.systemUptime
      let seconds = max(now - windowStart, 1e-6)
      windowStart = now
      let snapshot = Snapshot(
        renderedFps: Double(renderedFrames) / seconds,
        cameraFps: Double(cameraFrames) / seconds,
        averageGpuFrameMillis: renderedFrames == 0 ? 0 : gpuSecondsTotal / Double(renderedFrames) * 1000,
        averageDetectorMillis: detectorRuns == 0 ? 0 : detectorSecondsTotal / Double(detectorRuns) * 1000,
        droppedFrames: droppedFrames)
      renderedFrames = 0
      cameraFrames = 0
      droppedFrames = 0
      gpuSecondsTotal = 0
      detectorSecondsTotal = 0
      detectorRuns = 0
      return snapshot
    }
  }

  private func locked<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }
}
