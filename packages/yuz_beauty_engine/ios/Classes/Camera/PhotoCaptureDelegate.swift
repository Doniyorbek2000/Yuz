import AVFoundation
import Foundation

enum PhotoCaptureError: Error {
  case failed(String)
}

/// Bridges AVCapturePhotoCaptureDelegate to async/await for one capture.
final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
  private var continuation: CheckedContinuation<Data, Error>?
  /// Keeps the delegate alive until AVFoundation calls back (it holds it weakly).
  private var retainedSelf: PhotoCaptureDelegate?

  static func capture(with output: AVCapturePhotoOutput, settings: AVCapturePhotoSettings) async throws -> Data {
    let delegate = PhotoCaptureDelegate()
    return try await withCheckedThrowingContinuation { continuation in
      delegate.continuation = continuation
      delegate.retainedSelf = delegate
      output.capturePhoto(with: settings, delegate: delegate)
    }
  }

  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    defer { retainedSelf = nil }
    guard let continuation else { return }
    self.continuation = nil
    if let error {
      continuation.resume(throwing: error)
    } else if let data = photo.fileDataRepresentation() {
      continuation.resume(returning: data)
    } else {
      continuation.resume(throwing: PhotoCaptureError.failed("no photo data"))
    }
  }
}
