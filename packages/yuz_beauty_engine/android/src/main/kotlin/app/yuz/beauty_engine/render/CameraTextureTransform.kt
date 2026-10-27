package app.yuz.beauty_engine.render

/**
 * Builds the column-major 4x4 UV matrix that maps upright display UVs to
 * sensor-buffer UVs:
 *
 *   bufferUv = surfaceTextureMatrix * T(0.5) * Rccw(rotation) * S(mirror) * T(-0.5) * displayUv
 *
 * `rotationDegrees` is the clockwise rotation needed to make the buffer
 * upright (CameraX TransformationInfo.rotationDegrees). Mirroring flips the
 * display horizontally (front camera selfie view).
 */
object CameraTextureTransform {
    fun displayToBuffer(rotationDegrees: Int, mirrorHorizontally: Boolean): FloatArray {
        val normalized = ((rotationDegrees % 360) + 360) % 360
        require(normalized % 90 == 0) { "rotation must be a multiple of 90, got $rotationDegrees" }
        val (cos, sin) = when (normalized) {
            0 -> 1f to 0f
            90 -> 0f to 1f
            180 -> -1f to 0f
            else -> 0f to -1f
        }
        val mirror = if (mirrorHorizontally) -1f else 1f
        // Linear part L = R * S, where R = [[cos, -sin], [sin, cos]], S = diag(mirror, 1).
        val a = cos * mirror
        val b = -sin
        val c = sin * mirror
        val d = cos
        // Translation keeps the centre fixed: t = 0.5 - L * 0.5.
        val tx = 0.5f - (a * 0.5f + b * 0.5f)
        val ty = 0.5f - (c * 0.5f + d * 0.5f)
        return floatArrayOf(
            a, c, 0f, 0f,
            b, d, 0f, 0f,
            0f, 0f, 1f, 0f,
            tx, ty, 0f, 1f,
        )
    }

    /** Column-major 4x4 multiply: returns left * right. */
    fun multiply(left: FloatArray, right: FloatArray): FloatArray {
        val out = FloatArray(16)
        for (column in 0 until 4) {
            for (row in 0 until 4) {
                var sum = 0f
                for (k in 0 until 4) {
                    sum += left[k * 4 + row] * right[column * 4 + k]
                }
                out[column * 4 + row] = sum
            }
        }
        return out
    }

    /** Applies a column-major matrix to (u, v, 0, 1). */
    fun apply(matrix: FloatArray, u: Float, v: Float): Pair<Float, Float> =
        (matrix[0] * u + matrix[4] * v + matrix[12]) to (matrix[1] * u + matrix[5] * v + matrix[13])

    /** Upright output size for a sensor-oriented buffer. */
    fun uprightSize(bufferWidth: Int, bufferHeight: Int, rotationDegrees: Int): Pair<Int, Int> =
        if (((rotationDegrees % 180) + 180) % 180 == 90) bufferHeight to bufferWidth else bufferWidth to bufferHeight
}
