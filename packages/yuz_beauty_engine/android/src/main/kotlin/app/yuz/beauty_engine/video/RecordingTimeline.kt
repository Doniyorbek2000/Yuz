package app.yuz.beauty_engine.video

import kotlin.math.abs

/**
 * Maps capture timestamps (nanoseconds) of video frames and audio chunks to
 * muxer presentation times (microseconds from the start of the recording).
 *
 * Camera frames carry SurfaceTexture timestamps which, depending on the
 * device, are in the monotonic clock or in the boot-time clock; audio is
 * timestamped with [System.nanoTime] (monotonic). The first video frame
 * decides whether an offset is needed so both tracks share one clock.
 *
 * Not thread-safe; the caller serializes access per track (video on the GL
 * thread, audio on the audio thread) and only [videoClockOffsetNanos] is shared.
 */
class RecordingTimeline(private val startNanos: Long) {
    @Volatile
    private var videoClockOffsetNanos: Long? = null
    private var lastVideoUs = -1L
    private var lastAudioUs = -1L

    /**
     * Returns the presentation time for a frame, or null when the frame must
     * be dropped (before the start, or not strictly after the previous one).
     */
    fun videoPresentationUs(frameNanos: Long, nowNanos: Long): Long? {
        val offset = videoClockOffsetNanos ?: run {
            val difference = nowNanos - frameNanos
            (if (abs(difference) > CLOCK_DOMAIN_THRESHOLD_NANOS) difference else 0L).also { videoClockOffsetNanos = it }
        }
        val monotonic = frameNanos + offset
        if (monotonic < startNanos) return null
        val us = (monotonic - startNanos) / 1_000
        if (us <= lastVideoUs) return null
        lastVideoUs = us
        return us
    }

    /**
     * Audio chunks are never dropped (gaps would be audible); timestamps are
     * forced to increase instead. Chunks captured before the start return null.
     */
    fun audioPresentationUs(chunkNanos: Long): Long? {
        if (chunkNanos < startNanos) return null
        var us = (chunkNanos - startNanos) / 1_000
        if (us <= lastAudioUs) us = lastAudioUs + 1
        lastAudioUs = us
        return us
    }

    /** Duration covered by the samples seen so far. */
    val durationUs: Long get() = maxOf(lastVideoUs, lastAudioUs, 0L)

    companion object {
        /** Clocks that differ by more than this are treated as different domains. */
        const val CLOCK_DOMAIN_THRESHOLD_NANOS = 1_000_000_000L
    }
}

/** Encoder parameters derived from the rendered frame size. */
data class VideoEncoderSpec(val width: Int, val height: Int, val bitrate: Int, val frameRate: Int) {
    companion object {
        const val FRAME_RATE = 30
        private const val BITS_PER_PIXEL_FRAME = 0.12
        private const val MIN_BITRATE = 2_000_000
        private const val MAX_BITRATE = 20_000_000

        /**
         * H.264 needs even dimensions. The exact (even) frame size is used when
         * the device encoder supports it, so nothing is scaled; otherwise the
         * size is aligned down to 16 and the frame is scaled into it.
         */
        fun forOutput(
            width: Int,
            height: Int,
            requestedBitrate: Int = 0,
            isSizeSupported: (Int, Int) -> Boolean = { _, _ -> false },
        ): VideoEncoderSpec {
            require(width >= 16 && height >= 16) { "frame too small: ${width}x$height" }
            val evenWidth = width - width % 2
            val evenHeight = height - height % 2
            val exact = isSizeSupported(evenWidth, evenHeight)
            val alignedWidth = if (exact) evenWidth else width - width % 16
            val alignedHeight = if (exact) evenHeight else height - height % 16
            val bitrate = if (requestedBitrate > 0) {
                requestedBitrate.coerceIn(MIN_BITRATE, MAX_BITRATE)
            } else {
                (alignedWidth.toDouble() * alignedHeight * FRAME_RATE * BITS_PER_PIXEL_FRAME).toInt()
                    .coerceIn(MIN_BITRATE, MAX_BITRATE)
            }
            return VideoEncoderSpec(alignedWidth, alignedHeight, bitrate, FRAME_RATE)
        }
    }
}

/**
 * Timestamps PCM chunks from the number of frames read, anchored at the
 * monotonic time of the first chunk. Counting samples (instead of reading
 * the clock per chunk) keeps audio free of scheduling jitter.
 */
class AudioSampleClock(private val sampleRate: Int) {
    private var anchorNanos = -1L
    private var framesRead = 0L

    /** Returns the capture time of the first frame of a chunk of [frames] frames read at [readCompletedNanos]. */
    fun chunkStartNanos(frames: Int, readCompletedNanos: Long): Long {
        if (anchorNanos < 0) anchorNanos = readCompletedNanos - framesToNanos(frames.toLong())
        val start = anchorNanos + framesToNanos(framesRead)
        framesRead += frames
        return start
    }

    private fun framesToNanos(frames: Long): Long = frames * 1_000_000_000L / sampleRate
}
