package app.yuz.beauty_engine.video.edit

import kotlin.math.roundToLong

/** One source clip, already probed: [sourceDurationUs] is the clip length. */
data class ClipInput(
    val path: String,
    val sourceDurationUs: Long,
    val startUs: Long,
    val endUs: Long,
    val speed: Double,
    val uprightWidth: Int,
    val uprightHeight: Int,
    val hasAudio: Boolean,
)

/** A clip placed on the output timeline. */
data class PlannedSegment(
    val clip: ClipInput,
    val startUs: Long,
    val endUs: Long,
    val speed: Double,
    val outputStartUs: Long,
    val outputDurationUs: Long,
) {
    val outputEndUs: Long get() = outputStartUs + outputDurationUs

    /** Original sound is kept only at normal speed (no time-stretching). */
    val keepsSound: Boolean get() = clip.hasAudio && speed == 1.0

    /** Maps a source presentation time inside the trim range to the output timeline. */
    fun outputTimeUs(sourceUs: Long): Long =
        outputStartUs + ((sourceUs - startUs).coerceAtLeast(0) / speed).roundToLong()
}

data class EditPlan(val segments: List<PlannedSegment>, val durationUs: Long, val width: Int, val height: Int)

object VideoEditPlanner {
    const val MIN_SEGMENT_US = 100_000L
    const val MIN_SPEED = 0.25
    const val MAX_SPEED = 4.0

    /**
     * Validates trims and speeds and lays the clips end to end. The output
     * size follows the first clip's upright aspect, fitted inside
     * [maxLongEdge] (never upscaled) with even dimensions for H.264.
     */
    fun plan(clips: List<ClipInput>, maxLongEdge: Int): EditPlan {
        require(clips.isNotEmpty()) { "at least one clip is required" }
        require(maxLongEdge >= 16) { "maxLongEdge must be >= 16" }
        var cursor = 0L
        val segments = clips.mapIndexed { index, clip ->
            require(clip.speed in MIN_SPEED..MAX_SPEED) { "clip $index: speed ${clip.speed} outside $MIN_SPEED..$MAX_SPEED" }
            val start = clip.startUs.coerceIn(0, clip.sourceDurationUs)
            val end = clip.endUs.coerceIn(start, clip.sourceDurationUs)
            require(end - start >= MIN_SEGMENT_US) { "clip $index: trimmed range is shorter than ${MIN_SEGMENT_US / 1000} ms" }
            val duration = ((end - start) / clip.speed).roundToLong()
            PlannedSegment(clip, start, end, clip.speed, cursor, duration).also { cursor += duration }
        }
        val first = clips.first()
        val (width, height) = outputSize(first.uprightWidth, first.uprightHeight, maxLongEdge)
        return EditPlan(segments, cursor, width, height)
    }

    fun outputSize(sourceWidth: Int, sourceHeight: Int, maxLongEdge: Int): Pair<Int, Int> {
        require(sourceWidth > 0 && sourceHeight > 0) { "invalid source size ${sourceWidth}x$sourceHeight" }
        val longEdge = maxOf(sourceWidth, sourceHeight)
        val scale = minOf(1.0, maxLongEdge.toDouble() / longEdge)
        fun even(value: Double) = maxOf(2, (value.toInt() / 2) * 2)
        return even(sourceWidth * scale) to even(sourceHeight * scale)
    }
}

/** Integer pixel rectangle (origin bottom-left, as glViewport expects). */
data class Viewport(val x: Int, val y: Int, val width: Int, val height: Int)

object Letterbox {
    /** Largest rectangle with the source aspect centered inside the destination. */
    fun fit(sourceWidth: Int, sourceHeight: Int, destinationWidth: Int, destinationHeight: Int): Viewport {
        require(sourceWidth > 0 && sourceHeight > 0 && destinationWidth > 0 && destinationHeight > 0)
        val scale = minOf(destinationWidth.toDouble() / sourceWidth, destinationHeight.toDouble() / sourceHeight)
        val width = minOf(destinationWidth, Math.round(sourceWidth * scale).toInt()).coerceAtLeast(1)
        val height = minOf(destinationHeight, Math.round(sourceHeight * scale).toInt()).coerceAtLeast(1)
        return Viewport((destinationWidth - width) / 2, (destinationHeight - height) / 2, width, height)
    }
}

/** A full-frame overlay image shown during [startUs, endUs) of the output. */
data class OverlayWindow(val path: String, val startUs: Long, val endUs: Long) {
    fun isVisibleAt(outputUs: Long) = outputUs >= startUs && outputUs < endUs
}
