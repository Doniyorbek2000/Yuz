package app.yuz.beauty_engine.video.edit

import android.graphics.Bitmap
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import app.yuz.beauty_engine.render.CameraTextureTransform
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

data class ProbedVideo(
    val durationUs: Long,
    val codedWidth: Int,
    val codedHeight: Int,
    val rotationDegrees: Int,
    val hasAudio: Boolean,
) {
    val uprightWidth: Int get() = CameraTextureTransform.uprightSize(codedWidth, codedHeight, rotationDegrees).first
    val uprightHeight: Int get() = CameraTextureTransform.uprightSize(codedWidth, codedHeight, rotationDegrees).second
}

object VideoProbe {
    fun probe(path: String): ProbedVideo {
        if (!File(path).isFile) throw IOException("Video not found: $path")
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(path)
            var video: MediaFormat? = null
            var hasAudio = false
            for (index in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(index)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("video/") && video == null) video = format
                if (mime.startsWith("audio/")) hasAudio = true
            }
            val format = video ?: throw IOException("No video track in $path")
            val rotation = if (format.containsKey(MediaFormat.KEY_ROTATION)) format.getInteger(MediaFormat.KEY_ROTATION) else retrieverRotation(path)
            val duration = if (format.containsKey(MediaFormat.KEY_DURATION)) format.getLong(MediaFormat.KEY_DURATION) else retrieverDurationUs(path)
            if (duration <= 0) throw IOException("Unknown duration for $path")
            return ProbedVideo(
                durationUs = duration,
                codedWidth = format.getInteger(MediaFormat.KEY_WIDTH),
                codedHeight = format.getInteger(MediaFormat.KEY_HEIGHT),
                rotationDegrees = ((rotation % 360) + 360) % 360,
                hasAudio = hasAudio,
            )
        } catch (error: IllegalArgumentException) {
            throw IOException("Unsupported video: $path", error)
        } finally {
            extractor.release()
        }
    }

    /**
     * Writes [count] evenly spaced JPEG frames (long edge [maxEdge]) into
     * [outputDirectory]; returns their paths in time order.
     */
    fun thumbnails(path: String, count: Int, maxEdge: Int, outputDirectory: File): List<String> {
        require(count in 1..60) { "count must be 1..60" }
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            val durationUs = (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L) * 1_000
            if (durationUs <= 0) throw IOException("Unknown duration for $path")
            outputDirectory.mkdirs()
            return (0 until count).map { index ->
                val timeUs = durationUs * (2L * index + 1) / (2L * count)
                val frame = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    ?: throw IOException("No frame at $timeUs us in $path")
                val scaled = scaleToLongEdge(frame, maxEdge)
                val file = File(outputDirectory, "thumb_$index.jpg")
                FileOutputStream(file).use { stream -> scaled.compress(Bitmap.CompressFormat.JPEG, 85, stream) }
                if (scaled !== frame) scaled.recycle()
                frame.recycle()
                file.path
            }
        } catch (error: IllegalArgumentException) {
            throw IOException("Unsupported video: $path", error)
        } finally {
            retriever.release()
        }
    }

    private fun scaleToLongEdge(bitmap: Bitmap, maxEdge: Int): Bitmap {
        val longEdge = maxOf(bitmap.width, bitmap.height)
        if (longEdge <= maxEdge) return bitmap
        val scale = maxEdge.toFloat() / longEdge
        return Bitmap.createScaledBitmap(bitmap, maxOf(1, (bitmap.width * scale).toInt()), maxOf(1, (bitmap.height * scale).toInt()), true)
    }

    private fun retrieverRotation(path: String): Int = withRetriever(path) {
        it.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
    }

    private fun retrieverDurationUs(path: String): Long = withRetriever(path) {
        (it.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L) * 1_000
    }

    private inline fun <T> withRetriever(path: String, block: (MediaMetadataRetriever) -> T): T {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            return block(retriever)
        } finally {
            retriever.release()
        }
    }
}
