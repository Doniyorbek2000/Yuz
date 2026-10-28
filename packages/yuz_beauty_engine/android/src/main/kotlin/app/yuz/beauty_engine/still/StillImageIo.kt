package app.yuz.beauty_engine.still

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer

class DecodedImage(val bitmap: Bitmap, val sourceWidth: Int, val sourceHeight: Int)

/** Decodes a photo upright (EXIF applied) at the planned size, ARGB_8888. */
object StillImageDecoder {
    fun decode(path: String, maxLongEdge: Int, gpuMaxTextureSize: Int): DecodedImage {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw IOException("Unsupported or unreadable image: $path")

        val orientation = runCatching {
            ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        val transform = ExifTransform.forOrientation(orientation)
        val plan = StillImageGeometry.plan(bounds.outWidth, bounds.outHeight, transform, maxLongEdge, gpuMaxTextureSize)

        val options = BitmapFactory.Options().apply {
            inSampleSize = plan.inSampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val stored = BitmapFactory.decodeFile(path, options) ?: throw IOException("Decoding failed: $path")

        val storedTargetWidth = if (transform.swapsAxes) plan.targetHeight else plan.targetWidth
        val storedTargetHeight = if (transform.swapsAxes) plan.targetWidth else plan.targetHeight
        val matrix = Matrix().apply {
            postScale(storedTargetWidth.toFloat() / stored.width, storedTargetHeight.toFloat() / stored.height)
            if (transform.flipHorizontal) postScale(-1f, 1f)
            if (transform.rotationDegrees != 0) postRotate(transform.rotationDegrees.toFloat())
        }
        val upright = Bitmap.createBitmap(stored, 0, 0, stored.width, stored.height, matrix, true)
        if (upright !== stored) stored.recycle()
        val result = if (upright.width != plan.targetWidth || upright.height != plan.targetHeight) {
            // Rounding inside createBitmap can be off by one pixel; snap to the plan.
            Bitmap.createScaledBitmap(upright, plan.targetWidth, plan.targetHeight, true).also {
                if (it !== upright) upright.recycle()
            }
        } else {
            upright
        }
        return DecodedImage(result, plan.uprightWidth, plan.uprightHeight)
    }
}

/** Writes GL read-back pixels (RGBA, bottom row first) as an upright JPEG. */
object JpegWriter {
    fun write(rgbaBottomUp: ByteBuffer, width: Int, height: Int, file: File, quality: Int) {
        val bottomUp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        try {
            rgbaBottomUp.rewind()
            bottomUp.copyPixelsFromBuffer(rgbaBottomUp)
            val flip = Matrix().apply { preScale(1f, -1f) }
            val upright = Bitmap.createBitmap(bottomUp, 0, 0, width, height, flip, false)
            try {
                file.parentFile?.mkdirs()
                val temp = File(file.parentFile, ".${file.name}.part")
                FileOutputStream(temp).use { stream ->
                    check(upright.compress(Bitmap.CompressFormat.JPEG, quality.coerceIn(1, 100), stream)) {
                        "JPEG encoding failed"
                    }
                }
                // Atomic replace: a crash never leaves a half-written output.
                if (!temp.renameTo(file)) {
                    temp.delete()
                    throw IOException("Cannot move JPEG into place: $file")
                }
            } finally {
                upright.recycle()
            }
        } finally {
            bottomUp.recycle()
        }
    }
}
