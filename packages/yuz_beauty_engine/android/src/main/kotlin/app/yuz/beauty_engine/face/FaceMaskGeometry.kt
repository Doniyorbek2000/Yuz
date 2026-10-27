package app.yuz.beauty_engine.face

/**
 * Builds the polygons consumed by `face_mask.frag` from MediaPipe Face Mesh
 * landmarks. Index loops follow the public MediaPipe face mesh topology
 * (FACEMESH_FACE_OVAL, *_EYE, *_EYEBROW, LIPS outer contour) ordered as
 * closed rings.
 *
 * Output coordinates are GL texture UVs: u = x, v = 1 - y (GL origin is
 * bottom-left, landmarks are top-left).
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

    /** Every landmark index referenced by the mask; only these are stabilized. */
    val REFERENCED_INDICES: IntArray =
        (FACE_OVAL + LEFT_EYE + RIGHT_EYE + LEFT_BROW + RIGHT_BROW + LIPS_OUTER).distinct().sorted().toIntArray()

    const val MESH_LANDMARK_COUNT = 468

    // Dilation factors around each region's centroid. Eyes are dilated to
    // cover lashes and lids, lips slightly to protect the lip line.
    private const val EYE_DILATION = 1.45f
    private const val BROW_DILATION = 1.25f
    private const val LIP_DILATION = 1.12f
    private const val OVAL_SCALE = 0.98f

    class MaskPolygons(
        val faceOval: FloatArray,
        val leftEye: FloatArray,
        val rightEye: FloatArray,
        val leftBrow: FloatArray,
        val rightBrow: FloatArray,
        val lips: FloatArray,
    )

    fun build(landmarks: List<NormalizedPoint>): MaskPolygons {
        require(landmarks.size >= MESH_LANDMARK_COUNT) {
            "expected at least $MESH_LANDMARK_COUNT landmarks, got ${landmarks.size}"
        }
        return MaskPolygons(
            faceOval = ring(landmarks, FACE_OVAL, OVAL_SCALE),
            leftEye = ring(landmarks, LEFT_EYE, EYE_DILATION),
            rightEye = ring(landmarks, RIGHT_EYE, EYE_DILATION),
            leftBrow = ring(landmarks, LEFT_BROW, BROW_DILATION),
            rightBrow = ring(landmarks, RIGHT_BROW, BROW_DILATION),
            lips = ring(landmarks, LIPS_OUTER, LIP_DILATION),
        )
    }

    /** Returns interleaved (u, v) pairs scaled about the ring centroid. */
    internal fun ring(landmarks: List<NormalizedPoint>, indices: IntArray, scale: Float): FloatArray {
        var centroidX = 0f
        var centroidY = 0f
        for (index in indices) {
            centroidX += landmarks[index].x
            centroidY += landmarks[index].y
        }
        centroidX /= indices.size
        centroidY /= indices.size

        val out = FloatArray(indices.size * 2)
        indices.forEachIndexed { i, index ->
            val point = landmarks[index]
            val x = centroidX + (point.x - centroidX) * scale
            val y = centroidY + (point.y - centroidY) * scale
            out[i * 2] = x
            out[i * 2 + 1] = 1f - y
        }
        return out
    }
}
