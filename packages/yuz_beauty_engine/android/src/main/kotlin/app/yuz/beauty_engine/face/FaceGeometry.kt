package app.yuz.beauty_engine.face

import kotlin.math.max
import kotlin.math.min

/** A point in normalized, upright, display-mirrored image space (origin top-left). */
data class NormalizedPoint(val x: Float, val y: Float)

data class NormalizedRect(val left: Float, val top: Float, val right: Float, val bottom: Float) {
    val width: Float get() = max(0f, right - left)
    val height: Float get() = max(0f, bottom - top)
    val area: Float get() = width * height
    val centerX: Float get() = (left + right) / 2f
    val centerY: Float get() = (top + bottom) / 2f

    fun intersectionOverUnion(other: NormalizedRect): Float {
        val intersection = NormalizedRect(
            max(left, other.left),
            max(top, other.top),
            min(right, other.right),
            min(bottom, other.bottom),
        ).area
        val union = area + other.area - intersection
        return if (union <= 0f) 0f else intersection / union
    }

    companion object {
        fun bounding(points: List<NormalizedPoint>): NormalizedRect {
            require(points.isNotEmpty()) { "points must not be empty" }
            var left = Float.MAX_VALUE
            var top = Float.MAX_VALUE
            var right = -Float.MAX_VALUE
            var bottom = -Float.MAX_VALUE
            for (point in points) {
                left = min(left, point.x)
                top = min(top, point.y)
                right = max(right, point.x)
                bottom = max(bottom, point.y)
            }
            return NormalizedRect(left, top, right, bottom)
        }
    }
}

/** One detected face: the full 478-point MediaPipe mesh in display space. */
class DetectedFace(val landmarks: List<NormalizedPoint>) {
    val bounds: NormalizedRect = NormalizedRect.bounding(landmarks)
}
