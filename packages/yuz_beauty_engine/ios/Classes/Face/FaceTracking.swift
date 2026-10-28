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

  /// Landmarks consumed by masks and warps; only these are filtered.
  static let stabilizedIndices: [Int] = Array(
    Set(FaceMaskGeometry.referencedIndices + FaceWarpBuilder.referencedIndices)
  ).sorted()

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
    for index in FaceTracker.stabilizedIndices where index < landmarks.count {
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

/// Port of `FaceMaskGeometry.kt` (same rings, packing and constants). Metal
/// textures have a top-left origin, so coordinates are not flipped and the
/// mask kernel runs with verticalSign = -1.
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
  static let mouthInner: [Int] = [
    78, 95, 88, 178, 87, 14, 317, 402, 318, 324, 308, 415, 310, 311, 312, 13, 82, 81, 80, 191,
  ]
  static let leftCheek = 205
  static let rightCheek = 425
  static let meshLandmarkCount = 468
  static let packedPoints = 128

  private static let ovalScale: Float = 0.98
  private static let browDilation: Float = 1.25
  private static let cheekRadiusX: Float = 0.13
  private static let cheekRadiusY: Float = 0.10
  private static let boundsMargin: Float = 0.15

  static let referencedIndices: [Int] = Array(
    Set(faceOval + leftEye + rightEye + leftBrow + rightBrow + lipsOuter + mouthInner + [leftCheek, rightCheek])
  ).sorted()

  /// Matches `FaceMaskData` in BeautyShaders.swift: 64 packed float4 then 6 float4.
  struct MaskUniforms {
    var packedPoints: [SIMD4<Float>]
    var leftEyeBox: SIMD4<Float>
    var rightEyeBox: SIMD4<Float>
    var mouthBox: SIMD4<Float>
    var leftCheek: SIMD4<Float>
    var rightCheek: SIMD4<Float>
    var faceBounds: SIMD4<Float>

    var flattened: [SIMD4<Float>] {
      packedPoints + [leftEyeBox, rightEyeBox, mouthBox, leftCheek, rightCheek, faceBounds]
    }
  }

  static let float4PerFace = 70

  static func build(_ landmarks: [NormalizedPoint], aspect: Float) -> MaskUniforms? {
    guard landmarks.count >= meshLandmarkCount else { return nil }
    var points: [SIMD2<Float>] = []
    points.reserveCapacity(packedPoints)
    func append(_ indices: [Int], _ scale: Float) {
      let c = centroid(landmarks, indices)
      for index in indices {
        let point = SIMD2(landmarks[index].x, landmarks[index].y)
        points.append(c + (point - c) * scale)
      }
    }
    append(faceOval, ovalScale)
    append(leftEye, 1)
    append(rightEye, 1)
    append(leftBrow, browDilation)
    append(rightBrow, browDilation)
    append(lipsOuter, 1)
    append(mouthInner, 1)
    let packed = stride(from: 0, to: points.count, by: 2).map {
      SIMD4(points[$0].x, points[$0].y, points[$0 + 1].x, points[$0 + 1].y)
    }

    func box(_ indices: [Int]) -> SIMD4<Float> {
      let rect = NormalizedRect.bounding(indices.map { landmarks[$0] })
      return SIMD4(rect.centerX, (rect.top + rect.bottom) / 2, rect.width / 2, rect.height / 2)
    }
    let oval = NormalizedRect.bounding(faceOval.map { landmarks[$0] })
    let rx = oval.width * cheekRadiusX
    let ry = oval.width * cheekRadiusY * aspect
    func cheek(_ index: Int) -> SIMD4<Float> { SIMD4(landmarks[index].x, landmarks[index].y, rx, ry) }
    let mx = oval.width * boundsMargin
    let my = oval.height * boundsMargin
    return MaskUniforms(
      packedPoints: packed, leftEyeBox: box(leftEye), rightEyeBox: box(rightEye), mouthBox: box(lipsOuter),
      leftCheek: cheek(leftCheek), rightCheek: cheek(rightCheek),
      faceBounds: SIMD4(oval.left - mx, oval.top - my, oval.right + mx, oval.bottom + my))
  }

  static func centroid(_ landmarks: [NormalizedPoint], _ indices: [Int]) -> SIMD2<Float> {
    var sum = SIMD2<Float>(0, 0)
    for index in indices { sum += SIMD2(landmarks[index].x, landmarks[index].y) }
    return sum / Float(indices.count)
  }
}

/// Reshape controls, each 0...1 (0 = off).
struct ReshapeSettings: Equatable {
  var faceSlim: Float = 0
  var jawline: Float = 0
  var chin: Float = 0
  var eyeEnlarge: Float = 0
  var noseSlim: Float = 0
  var lips: Float = 0
  var forehead: Float = 0

  var isIdentity: Bool {
    faceSlim <= 0 && jawline <= 0 && chin <= 0 && eyeEnlarge <= 0 && noseSlim <= 0 && lips <= 0
      && forehead <= 0
  }
}

/// One deformation for the `faceWarp` kernel, in image space (top-left).
struct FaceWarp {
  enum Kind: Float {
    case bulge = 0
    case translate = 1
  }

  var center: SIMD2<Float>
  var radius: Float
  var kind: Kind
  var offset = SIMD2<Float>(0, 0)
  var strength: Float = 0
}

/// Port of `FaceWarpBuilder.kt` (same landmarks and constants).
enum FaceWarpBuilder {
  static let maxWarps = 16
  private static let noseTip = 4
  private static let foreheadIndex = 10
  private static let chinIndex = 152
  private static let faceLeft = 234
  private static let faceRight = 454
  private static let slimLeft = [93, 132, 58]
  private static let slimRight = [323, 361, 288]
  private static let jawLeft = 172
  private static let jawRight = 397
  private static let noseLeft = 129
  private static let noseRight = 358
  private static let upperLip = 13
  private static let lowerLip = 14
  private static let mouthLeft = 61
  private static let mouthRight = 291
  private static let leftEyeOuter = 33
  private static let leftEyeInner = 133
  private static let rightEyeOuter = 263
  private static let rightEyeInner = 362

  static let referencedIndices: [Int] = Array(
    Set(
      [
        noseTip, foreheadIndex, chinIndex, faceLeft, faceRight, jawLeft, jawRight, noseLeft, noseRight,
        upperLip, lowerLip, mouthLeft, mouthRight, leftEyeOuter, leftEyeInner, rightEyeOuter, rightEyeInner,
      ] + slimLeft + slimRight + FaceMaskGeometry.leftEye + FaceMaskGeometry.rightEye)
  ).sorted()

  static func build(_ landmarks: [NormalizedPoint], settings: ReshapeSettings, aspect: Float) -> [FaceWarp] {
    guard !settings.isIdentity, landmarks.count >= FaceMaskGeometry.meshLandmarkCount else { return [] }
    func p(_ index: Int) -> SIMD2<Float> { SIMD2(landmarks[index].x, landmarks[index].y) }
    let faceWidth = abs(p(faceRight).x - p(faceLeft).x) * aspect
    let faceHeight = abs(p(chinIndex).y - p(foreheadIndex).y)
    guard faceWidth > 1e-4, faceHeight > 1e-4 else { return [] }
    let centerX = (p(faceLeft).x + p(faceRight).x) / 2
    var warps: [FaceWarp] = []

    if settings.eyeEnlarge > 0 {
      for (ring, outer, inner) in [
        (FaceMaskGeometry.leftEye, leftEyeOuter, leftEyeInner),
        (FaceMaskGeometry.rightEye, rightEyeOuter, rightEyeInner),
      ] {
        let eyeWidth = abs(p(inner).x - p(outer).x) * aspect
        warps.append(
          FaceWarp(
            center: FaceMaskGeometry.centroid(landmarks, ring), radius: eyeWidth * 1.25, kind: .bulge,
            strength: 0.22 * settings.eyeEnlarge))
      }
    }
    if settings.faceSlim > 0 {
      for index in slimLeft + slimRight {
        let point = p(index)
        warps.append(
          FaceWarp(
            center: point, radius: faceWidth * 0.32, kind: .translate,
            offset: SIMD2((centerX - point.x) * 0.10 * settings.faceSlim, 0)))
      }
    }
    if settings.jawline > 0 {
      for index in [jawLeft, jawRight] {
        let point = p(index)
        warps.append(
          FaceWarp(
            center: point, radius: faceWidth * 0.28, kind: .translate,
            offset: SIMD2(
              (centerX - point.x) * 0.12 * settings.jawline, -0.025 * faceHeight * settings.jawline)))
      }
    }
    if settings.chin > 0 {
      warps.append(
        FaceWarp(
          center: p(chinIndex), radius: faceWidth * 0.35, kind: .translate,
          offset: SIMD2(0, -0.05 * faceHeight * settings.chin)))
    }
    if settings.noseSlim > 0 {
      let noseWidth = abs(p(noseRight).x - p(noseLeft).x) * aspect
      for index in [noseLeft, noseRight] {
        let point = p(index)
        warps.append(
          FaceWarp(
            center: point, radius: noseWidth * 0.9, kind: .translate,
            offset: SIMD2((p(noseTip).x - point.x) * 0.30 * settings.noseSlim, 0)))
      }
    }
    if settings.lips > 0 {
      let mouthWidth = abs(p(mouthRight).x - p(mouthLeft).x) * aspect
      warps.append(
        FaceWarp(
          center: (p(upperLip) + p(lowerLip)) / 2, radius: mouthWidth * 0.75, kind: .bulge,
          strength: 0.15 * settings.lips))
    }
    if settings.forehead > 0 {
      warps.append(
        FaceWarp(
          center: p(foreheadIndex), radius: faceWidth * 0.5, kind: .translate,
          offset: SIMD2(0, 0.05 * faceHeight * settings.forehead)))
    }
    return Array(warps.prefix(maxWarps))
  }
}
