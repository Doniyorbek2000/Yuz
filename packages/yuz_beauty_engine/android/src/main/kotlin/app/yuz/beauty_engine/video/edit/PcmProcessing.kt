package app.yuz.beauty_engine.video.edit

/**
 * Streaming linear resampler from any rate/channel layout to interleaved
 * stereo float at [outputRate]. Keeps the fractional read position and the
 * last input frame between chunks, so chunk boundaries are seamless.
 */
class StereoResampler(private val inputRate: Int, private val inputChannels: Int, private val outputRate: Int) {
    init {
        require(inputRate > 0 && outputRate > 0) { "sample rates must be positive" }
        require(inputChannels > 0) { "channel count must be positive" }
    }

    private val step = inputRate.toDouble() / outputRate

    /**
     * Fractional input position of the next output frame. Index 0 is the
     * last frame of the previous chunk once one has been seen, so the
     * interpolation runs across chunk boundaries.
     */
    private var position = 0.0
    private var previousLeft = 0f
    private var previousRight = 0f
    private var hasPrevious = false

    /** Converts 16-bit interleaved PCM; returns interleaved stereo floats in -1..1. */
    fun process(pcm: ShortArray, length: Int = pcm.size): FloatArray {
        val frames = length / inputChannels
        if (frames == 0) return FloatArray(0)
        val offset = if (hasPrevious) 1 else 0
        val total = frames + offset
        fun left(index: Int): Float = if (index < offset) previousLeft else channel(pcm, index - offset, 0)
        fun right(index: Int): Float = if (index < offset) previousRight else channel(pcm, index - offset, 1)
        val out = FloatArray((((total - position) / step).toInt() + 2) * 2)
        var written = 0
        var t = position
        while (true) {
            val base = t.toInt()
            if (base + 1 >= total) break
            val fraction = (t - base).toFloat()
            out[written++] = left(base) + (left(base + 1) - left(base)) * fraction
            out[written++] = right(base) + (right(base + 1) - right(base)) * fraction
            t += step
        }
        previousLeft = channel(pcm, frames - 1, 0)
        previousRight = channel(pcm, frames - 1, 1)
        hasPrevious = true
        position = t - (total - 1)
        return out.copyOf(written)
    }

    private fun channel(pcm: ShortArray, frame: Int, side: Int): Float {
        val channelIndex = if (inputChannels == 1) 0 else minOf(side, inputChannels - 1)
        return pcm[frame * inputChannels + channelIndex] / 32768f
    }
}

/** Mixes stereo float buffers and converts to 16-bit PCM. */
object PcmMixer {
    /**
     * out = original * originalGain + music * musicGain * fade, clamped.
     * [fadeOut] is applied to the music only and ramps to 0 over its length,
     * ending at [totalFrames]; [startFrame] is the output position of the chunk.
     */
    fun mix(
        original: FloatArray?,
        originalGain: Float,
        music: FloatArray?,
        musicGain: Float,
        frames: Int,
        startFrame: Long,
        totalFrames: Long,
        fadeOutFrames: Long,
    ): ShortArray {
        val out = ShortArray(frames * 2)
        for (frame in 0 until frames) {
            val absolute = startFrame + frame
            val remaining = totalFrames - absolute
            val fade = if (fadeOutFrames > 0 && remaining < fadeOutFrames) {
                (remaining.coerceAtLeast(0).toFloat() / fadeOutFrames)
            } else {
                1f
            }
            for (side in 0..1) {
                val i = frame * 2 + side
                var sample = 0f
                if (original != null && i < original.size) sample += original[i] * originalGain
                if (music != null && i < music.size) sample += music[i] * musicGain * fade
                out[i] = (sample.coerceIn(-1f, 1f) * 32767f).toInt().toShort()
            }
        }
        return out
    }
}

/**
 * FIFO of interleaved stereo floats. Producers append arbitrary chunk sizes;
 * the mixer takes exactly the frames it needs (zero-padded when short).
 */
class StereoFifo {
    private var buffer = FloatArray(8192)
    private var start = 0
    private var end = 0

    val frames: Int get() = (end - start) / 2

    fun append(samples: FloatArray) {
        if (samples.isEmpty()) return
        if (end + samples.size > buffer.size) {
            val live = end - start
            val target = if (live + samples.size > buffer.size) maxOf(buffer.size * 2, live + samples.size) else buffer.size
            val next = if (target == buffer.size) buffer else FloatArray(target)
            System.arraycopy(buffer, start, next, 0, live)
            buffer = next
            start = 0
            end = live
        }
        System.arraycopy(samples, 0, buffer, end, samples.size)
        end += samples.size
    }

    /** Removes [count] frames (silence for any missing part). */
    fun take(count: Int): FloatArray {
        val out = FloatArray(count * 2)
        val available = minOf(count * 2, end - start)
        System.arraycopy(buffer, start, out, 0, available)
        start += available
        if (start == end) {
            start = 0
            end = 0
        }
        return out
    }

    /** Drops [count] frames (or everything when fewer are buffered). */
    fun skip(count: Int) {
        start = minOf(end, start + count * 2)
        if (start == end) {
            start = 0
            end = 0
        }
    }

    fun clear() {
        start = 0
        end = 0
    }
}
