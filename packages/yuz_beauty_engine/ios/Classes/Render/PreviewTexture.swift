import CoreVideo
import Flutter
import Foundation

/// FlutterTexture that serves the most recent processed frame. Flutter pulls
/// frames on its raster thread; producers push from the capture/GPU threads.
final class PreviewTexture: NSObject, FlutterTexture {
  private let lock = NSLock()
  private var latest: CVPixelBuffer?

  func update(_ pixelBuffer: CVPixelBuffer) {
    lock.lock()
    latest = pixelBuffer
    lock.unlock()
  }

  func latestPixelBuffer() -> CVPixelBuffer? {
    lock.lock()
    defer { lock.unlock() }
    return latest
  }

  func clear() {
    lock.lock()
    latest = nil
    lock.unlock()
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    lock.lock()
    defer { lock.unlock() }
    guard let latest else { return nil }
    return Unmanaged.passRetained(latest)
  }
}
