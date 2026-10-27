import CoreGraphics
import Foundation

/// Point in normalized, upright, display-oriented image space (origin top-left).
struct NormalizedPoint: Equatable {
  var x: Float
  var y: Float
}

struct NormalizedRect: Equatable {
  var left: Float
  var top: Float
  var right: Float
  var bottom: Float

  var width: Float { max(0, right - left) }
  var height: Float { max(0, bottom - top) }
  var area: Float { width * height }
  var centerX: Float { (left + right) / 2 }

  func intersectionOverUnion(_ other: NormalizedRect) -> Float {
    let intersection = NormalizedRect(
      left: max(left, other.left), top: max(top, other.top),
      right: min(right, other.right), bottom: min(bottom, other.bottom)
    ).area
    let union = area + other.area - intersection
    return union <= 0 ? 0 : intersection / union
  }

  static func bounding(_ points: [NormalizedPoint]) -> NormalizedRect {
    var rect = NormalizedRect(
      left: .greatestFiniteMagnitude, top: .greatestFiniteMagnitude,
      right: -.greatestFiniteMagnitude, bottom: -.greatestFiniteMagnitude)
    for point in points {
      rect.left = min(rect.left, point.x)
      rect.top = min(rect.top, point.y)
      rect.right = max(rect.right, point.x)
      rect.bottom = max(rect.bottom, point.y)
    }
    return rect
  }
}

struct DetectedFace {
  let landmarks: [NormalizedPoint]
  let bounds: NormalizedRect

  init(landmarks: [NormalizedPoint]) {
    self.landmarks = landmarks
    self.bounds = NormalizedRect.bounding(landmarks)
  }
}

struct TrackedFace {
  let trackId: Int
  let landmarks: [NormalizedPoint]
  let bounds: NormalizedRect
}

struct FaceTrackingSnapshot {
  let detectedFaceCount: Int
  let beautifiedFaces: [TrackedFace]
  let timestamp: TimeInterval

  static let empty = FaceTrackingSnapshot(detectedFaceCount: 0, beautifiedFaces: [], timestamp: 0)
}

enum FaceSelectionPolicy {
  case primaryFace
  case allFaces
}

/// Port of `FaceTracker.kt`: IoU track association, One Euro stabilization of
/// mask landmarks, multi-face policy with primary-face hysteresis.
/// Not thread-safe; call from the detector callback queue only.
final class FaceTracker {
  private struct Track {
    let id: Int
    var bounds: NormalizedRect
    var filtersX: [Int: OneEuroFilter] = [:]
    var filtersY: [Int: OneEuroFilter] = [:]
  }

  private let maxFaces: Int
  private let policy: FaceSelectionPolicy
  private let matchIouThreshold: Float
  private let primarySwitchAreaRatio: Float
  private var tracks: [Track] = []
  private var nextTrackId = 1
  private var primaryTrackId: Int?

  init(
    maxFaces: Int, policy: FaceSelectionPolicy, matchIouThreshold: Float = 0.3,
    primarySwitchAreaRatio: Float = 1.3
  ) {
    self.maxFaces = maxFaces
    self.policy = policy
    self.matchIouThreshold = matchIouThreshold
    self.primarySwitchAreaRatio = primarySwitchAreaRatio
  }

  func update(_ detections: [DetectedFace], timestamp: TimeInterval) -> FaceTrackingSnapshot {
    guard !detections.isEmpty else {
      reset()
      return FaceTrackingSnapshot(detectedFaceCount: 0, beautifiedFaces: [], timestamp: timestamp)
    }

    var unmatched = tracks
    var updated: [Track] = []
    var faces: [TrackedFace] = []
    for detection in detections.sorted(by: { $0.bounds.area > $1.bounds.area }) {
      var track: Track
      if let bestIndex = unmatched.indices.max(by: {
        unmatched[$0].bounds.intersectionOverUnion(detection.bounds)
          < unmatched[$1].bounds.intersectionOverUnion(detection.bounds)
      }), unmatched[bestIndex].bounds.intersectionOverUnion(detection.bounds) >= matchIouThreshold {
        track = unmatched.remove(at: bestIndex)
      } else {
        track = Track(id: nextTrackId, bounds: detection.bounds)
        nextTrackId += 1
      }
      track.bounds = detection.bounds
      let landmarks = stabilize(&track, detection.landmarks, timestamp: timestamp)
      updated.append(track)
      faces.append(TrackedFace(trackId: track.id, landmarks: landmarks, bounds: detection.bounds))
    }
    tracks = updated

    let selected: [TrackedFace]
    switch policy {
    case .allFaces:
      selected = Array(faces.sorted(by: { $0.bounds.area > $1.bounds.area }).prefix(maxFaces))
    case .primaryFace:
      selected = [selectPrimary(faces)]
    }
    return FaceTrackingSnapshot(
      detectedFaceCount: detections.count, beautifiedFaces: selected, timestamp: timestamp)
  }

  func reset() {
    tracks = []
    primaryTrackId = nil
  }

  private func selectPrimary(_ faces: [TrackedFace]) -> TrackedFace {
    let largest = faces.max(by: { $0.bounds.area < $1.bounds.area })!
    var chosen = largest
    if let current = faces.first(where: { $0.trackId == primaryTrackId }),
      largest.bounds.area < current.bounds.area * primarySwitchAreaRatio
    {
      chosen = current
    }
    primaryTrackId = chosen.trackId
    return chosen
  }

  private func stabilize(
    _ track: inout Track, _ landmarks: [NormalizedPoint], timestamp: TimeInterval
  ) -> [NormalizedPoint] {
    var output = landmarks
    for index in FaceMaskGeometry.referencedIndices where index < landmarks.count {
      var filterX = track.filtersX[index] ?? OneEuroFilter()
      var filterY = track.filtersY[index] ?? OneEuroFilter()
      let x = filterX.filter(Double(landmarks[index].x), timestamp: timestamp)
      let y = filterY.filter(Double(landmarks[index].y), timestamp: timestamp)
      track.filtersX[index] = filterX
      track.filtersY[index] = filterY
      output[index] = NormalizedPoint(x: Float(x), y: Float(y))
    }
    return output
  }
}

/// Port of `FaceMaskGeometry.kt`. Metal textures have a top-left origin, so
/// unlike the GL variant no vertical flip is applied.
enum FaceMaskGeometry {
  static let faceOval: [Int] = [
    10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288,
    397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136,
    172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109,
  ]
  static let leftEye: [Int] = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]
  static let rightEye: [Int] = [263, 249, 390, 373, 374, 380, 381, 382, 362, 398, 384, 385, 386, 387, 388, 466]
  static let leftBrow: [Int] = [70, 63, 105, 66, 107, 55, 65, 52, 53, 46]
  static let rightBrow: [Int] = [300, 293, 334, 296, 336, 285, 295, 282, 283, 276]
  static let lipsOuter: [Int] = [
    61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 409, 270, 269, 267, 0, 37, 39, 40, 185,
  ]
  static let meshLandmarkCount = 468
  static let referencedIndices: [Int] = Array(
    Set(faceOval + leftEye + rightEye + leftBrow + rightBrow + lipsOuter)
  ).sorted()

  private static let eyeDilation: Float = 1.45
  private static let browDilation: Float = 1.25
  private static let lipDilation: Float = 1.12
  private static let ovalScale: Float = 0.98

  /// Flattened polygons in the exact layout of `FacePolygons` in the Metal source.
  static func polygons(for landmarks: [NormalizedPoint]) -> [SIMD2<Float>]? {
    guard landmarks.count >= meshLandmarkCount else { return nil }
    return ring(landmarks, faceOval, ovalScale) + ring(landmarks, leftEye, eyeDilation)
      + ring(landmarks, rightEye, eyeDilation) + ring(landmarks, leftBrow, browDilation)
      + ring(landmarks, rightBrow, browDilation) + ring(landmarks, lipsOuter, lipDilation)
  }

  static let pointsPerFace = 36 + 16 + 16 + 10 + 10 + 20

  private static func ring(_ landmarks: [NormalizedPoint], _ indices: [Int], _ scale: Float)
    -> [SIMD2<Float>]
  {
    var centroid = SIMD2<Float>(0, 0)
    for index in indices { centroid += SIMD2(landmarks[index].x, landmarks[index].y) }
    centroid /= Float(indices.count)
    return indices.map { index in
      let point = SIMD2(landmarks[index].x, landmarks[index].y)
      return centroid + (point - centroid) * scale
    }
  }
}
