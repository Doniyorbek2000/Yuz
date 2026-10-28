package app.yuz.beauty_engine.face

import kotlin.math.max
import kotlin.math.min

/**
 * Builds the uniforms consumed by `face_mask.frag` from MediaPipe Face Mesh
 * landmarks. Index loops follow the public MediaPipe face mesh topology
 * (FACE_OVAL, eyes, eyebrows, outer and inner lip contours) as closed rings.
 *
 * Rings are packed two points per vec4 in this order (point counts):
 * oval 36, left eye 16, right eye 16, left brow 10, right brow 10, outer lips
 * 20, inner mouth 20 = 128 points. Coordinates are normalized; with
 * [flipVertical] they are converted from landmark space (origin top-left) to
 * OpenGL texture space (origin bottom-left).
 */
object FaceMaskGeometry {
    val FACE_OVAL = intArrayOf(
        10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288,
        397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136,
        172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109,
    )
    val LEFT_EYE = intArrayOf(
        33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246,
    )
    val RIGHT_EYE = intArrayOf(
        263, 249, 390, 373, 374, 380, 381, 382, 362, 398, 384, 385, 386, 387, 388, 466,
    )
    val LEFT_BROW = intArrayOf(70, 63, 105, 66, 107, 55, 65, 52, 53, 46)
    val RIGHT_BROW = intArrayOf(300, 293, 334, 296, 336, 285, 295, 282, 283, 276)
    val LIPS_OUTER = intArrayOf(
        61, 146, 91, 181, 84, 17, 314, 405, 321, 375,
        291, 409, 270, 269, 267, 0, 37, 39, 40, 185,
    )
    val MOUTH_INNER = intArrayOf(
        78, 95, 88, 178, 87, 14, 317, 402, 318, 324,
        308, 415, 310, 311, 312, 13, 82, 81, 80, 191,
    )
    const val LEFT_CHEEK = 205
    const val RIGHT_CHEEK = 425

    const val MESH_LANDMARK_COUNT = 468
    const val PACKED_POINTS = 128

    private const val OVAL_SCALE = 0.98f
    private const val BROW_DILATION = 1.25f
    private const val CHEEK_RADIUS_X = 0.13f
    private const val CHEEK_RADIUS_Y = 0.10f
    private const val BOUNDS_MARGIN = 0.15f

    /** Every landmark index used by masks; the tracker stabilizes these. */
    val REFERENCED_INDICES: IntArray =
        (FACE_OVAL + LEFT_EYE + RIGHT_EYE + LEFT_BROW + RIGHT_BROW + LIPS_OUTER + MOUTH_INNER +
            intArrayOf(LEFT_CHEEK, RIGHT_CHEEK)).distinct().sorted().toIntArray()

    /** Uniform payload for one face. Boxes are (centre.x, centre.y, halfWidth, halfHeight). */
    class MaskUniforms(
        val packedPoints: FloatArray,
        val leftEyeBox: FloatArray,
        val rightEyeBox: FloatArray,
        val mouthBox: FloatArray,
        val leftCheek: FloatArray,
        val rightCheek: FloatArray,
        val faceBounds: FloatArray,
    )

    /**
     * @param aspect frame width / height, used to keep cheek ellipses round in pixels.
     */
    fun build(landmarks: List<NormalizedPoint>, aspect: Float, flipVertical: Boolean): MaskUniforms {
        require(landmarks.size >= MESH_LANDMARK_COUNT) {
            "expected at least $MESH_LANDMARK_COUNT landmarks, got ${landmarks.size}"
        }
        fun y(value: Float) = if (flipVertical) 1f - value else value

        val packed = FloatArray(PACKED_POINTS * 2)
        var cursor = 0
        fun append(indices: IntArray, scale: Float) {
            val (cx, cy) = centroid(landmarks, indices)
            for (index in indices) {
                val point = landmarks[index]
                packed[cursor++] = cx + (point.x - cx) * scale
                packed[cursor++] = y(cy + (point.y - cy) * scale)
            }
        }
        append(FACE_OVAL, OVAL_SCALE)
        append(LEFT_EYE, 1f)
        append(RIGHT_EYE, 1f)
        append(LEFT_BROW, BROW_DILATION)
        append(RIGHT_BROW, BROW_DILATION)
        append(LIPS_OUTER, 1f)
        append(MOUTH_INNER, 1f)
        check(cursor == packed.size)

        fun box(indices: IntArray): FloatArray {
            val rect = NormalizedRect.bounding(indices.map { landmarks[it] })
            return floatArrayOf(rect.centerX, y(rect.centerY), rect.width / 2f, rect.height / 2f)
        }

        val oval = NormalizedRect.bounding(FACE_OVAL.map { landmarks[it] })
        val cheekRx = oval.width * CHEEK_RADIUS_X
        val cheekRy = oval.width * CHEEK_RADIUS_Y * aspect
        fun cheek(index: Int) = floatArrayOf(landmarks[index].x, y(landmarks[index].y), cheekRx, cheekRy)

        val marginX = oval.width * BOUNDS_MARGIN
        val marginY = oval.height * BOUNDS_MARGIN
        val top = y(oval.top - marginY)
        val bottom = y(oval.bottom + marginY)
        val bounds = floatArrayOf(oval.left - marginX, min(top, bottom), oval.right + marginX, max(top, bottom))

        return MaskUniforms(
            packedPoints = packed,
            leftEyeBox = box(LEFT_EYE),
            rightEyeBox = box(RIGHT_EYE),
            mouthBox = box(LIPS_OUTER),
            leftCheek = cheek(LEFT_CHEEK),
            rightCheek = cheek(RIGHT_CHEEK),
            faceBounds = bounds,
        )
    }

    internal fun centroid(landmarks: List<NormalizedPoint>, indices: IntArray): Pair<Float, Float> {
        var x = 0f
        var y = 0f
        for (index in indices) {
            x += landmarks[index].x
            y += landmarks[index].y
        }
        return (x / indices.size) to (y / indices.size)
    }
}
