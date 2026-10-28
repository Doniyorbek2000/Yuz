package app.yuz.beauty_engine.still

import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * EXIF orientation (TIFF tag 0x0112, values 1..8) as "flip horizontally,
 * then rotate clockwise", the order used by ExifInterface.
 */
data class ExifTransform(val rotationDegrees: Int, val flipHorizontal: Boolean) {
    /** True when width and height swap after the transform. */
    val swapsAxes: Boolean get() = rotationDegrees % 180 == 90

    companion object {
        fun forOrientation(orientation: Int): ExifTransform = when (orientation) {
            2 -> ExifTransform(0, true)
            3 -> ExifTransform(180, false)
            4 -> ExifTransform(180, true)
            5 -> ExifTransform(90, true)
            6 -> ExifTransform(90, false)
            7 -> ExifTransform(270, true)
            8 -> ExifTransform(270, false)
            else -> ExifTransform(0, false)
        }
    }
}

/** Output size planning for still images. */
object StillImageGeometry {
    /** Hard cap on output pixels to bound GPU and heap memory (~24 MP). */
    const val MAX_PIXELS = 24_000_000L

    data class Plan(
        val uprightWidth: Int,
        val uprightHeight: Int,
        val targetWidth: Int,
        val targetHeight: Int,
        val inSampleSize: Int,
    )

    /**
     * @param storedWidth bitmap width as stored in the file (before EXIF).
     * @param maxLongEdge requested long edge, 0 = original.
     * @param gpuMaxTextureSize GL_MAX_TEXTURE_SIZE / Metal limit.
     */
    fun plan(storedWidth: Int, storedHeight: Int, transform: ExifTransform, maxLongEdge: Int, gpuMaxTextureSize: Int): Plan {
        require(storedWidth > 0 && storedHeight > 0) { "invalid image size ${storedWidth}x$storedHeight" }
        val uprightWidth = if (transform.swapsAxes) storedHeight else storedWidth
        val uprightHeight = if (transform.swapsAxes) storedWidth else storedHeight
        val longEdge = max(uprightWidth, uprightHeight)

        var scale = 1.0
        if (maxLongEdge in 1 until longEdge) scale = maxLongEdge.toDouble() / longEdge
        if (longEdge * scale > gpuMaxTextureSize) scale = gpuMaxTextureSize.toDouble() / longEdge
        val pixels = uprightWidth.toLong() * uprightHeight * scale * scale
        if (pixels > MAX_PIXELS) scale *= sqrt(MAX_PIXELS / pixels)

        val targetWidth = max(1, (uprightWidth * scale).roundToInt())
        val targetHeight = max(1, (uprightHeight * scale).roundToInt())

        // Largest power of two that still decodes at least the target size.
        var sample = 1
        while (uprightWidth / (sample * 2) >= targetWidth && uprightHeight / (sample * 2) >= targetHeight) sample *= 2

        return Plan(uprightWidth, uprightHeight, targetWidth, targetHeight, sample)
    }
}
