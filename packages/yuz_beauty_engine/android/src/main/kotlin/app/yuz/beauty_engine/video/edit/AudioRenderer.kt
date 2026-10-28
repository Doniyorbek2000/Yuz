package app.yuz.beauty_engine.video.edit

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.Closeable
import java.io.IOException
import java.nio.ByteOrder
import java.util.concurrent.CancellationException
import java.util.concurrent.atomic.AtomicBoolean

/** One encoded AAC access unit, copied out of the codec. */
class EncodedPacket(val data: ByteArray, val presentationTimeUs: Long, val flags: Int)

class EncodedAudio(val format: MediaFormat, val packets: List<EncodedPacket>)

/**
 * Decodes the audio track of a file between [startUs] and [endUs] and
 * returns it as 44.1 kHz stereo floats on demand. With [loop] the source
 * restarts at the beginning when it ends (background music).
 */
class PcmSource(
    private val path: String,
    private val startUs: Long,
    private val endUs: Long,
    private val loop: Boolean,
) : Closeable {
    private var extractor: MediaExtractor? = null
    private var decoder: MediaCodec? = null
    private var resampler: StereoResampler? = null
    private val fifo = StereoFifo()
    private val info = MediaCodec.BufferInfo()
    private var inputDone = false
    private var outputDone = false
    private var exhausted = false
    private var decodedAnything = false

    init {
        open()
    }

    /** Returns exactly [frames] stereo frames (silence once the source has ended). */
    fun read(frames: Int, cancelled: AtomicBoolean): FloatArray {
        while (fifo.frames < frames && !exhausted) {
            if (cancelled.get()) throw CancellationException("export cancelled")
            if (!pump()) {
                if (loop && decodedAnything) {
                    reopen()
                } else {
                    exhausted = true
                }
            }
        }
        return fifo.take(frames)
    }

    /** Decodes some more; returns false at end of stream. */
    private fun pump(): Boolean {
        val codec = decoder ?: return false
        val source = extractor ?: return false
        if (!inputDone) {
            val index = codec.dequeueInputBuffer(TIMEOUT_US)
            if (index >= 0) {
                val buffer = checkNotNull(codec.getInputBuffer(index))
                val size = source.readSampleData(buffer, 0)
                val time = source.sampleTime
                if (size < 0 || time > endUs) {
                    codec.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                    inputDone = true
                } else {
                    codec.queueInputBuffer(index, 0, size, time, 0)
                    source.advance()
                }
            }
        }
        if (outputDone) return false
        val index = codec.dequeueOutputBuffer(info, TIMEOUT_US)
        when {
            index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> resampler = createResampler(codec)
            index >= 0 -> {
                val buffer = checkNotNull(codec.getOutputBuffer(index))
                if (info.size > 0) {
                    buffer.position(info.offset)
                    buffer.limit(info.offset + info.size)
                    val shorts = buffer.order(ByteOrder.nativeOrder()).asShortBuffer()
                    val pcm = ShortArray(shorts.remaining())
                    shorts.get(pcm)
                    appendTrimmed(pcm, info.presentationTimeUs)
                }
                codec.releaseOutputBuffer(index, false)
                if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
            }
        }
        // Data appended by the final buffer stays in the FIFO for read().
        return !outputDone
    }

    /** Keeps only the samples inside [startUs, endUs). */
    private fun appendTrimmed(pcm: ShortArray, chunkUs: Long) {
        val codec = checkNotNull(decoder)
        val converter = resampler ?: createResampler(codec).also { resampler = it }
        val format = codec.outputFormat
        val rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        val frames = pcm.size / channels
        val skip = if (chunkUs < startUs) ((startUs - chunkUs) * rate / 1_000_000).toInt().coerceAtMost(frames) else 0
        val chunkEndUs = chunkUs + frames * 1_000_000L / rate
        val keepUntil = if (chunkEndUs > endUs) ((endUs - chunkUs) * rate / 1_000_000).toInt().coerceIn(skip, frames) else frames
        if (keepUntil <= skip) return
        val slice = pcm.copyOfRange(skip * channels, keepUntil * channels)
        fifo.append(converter.process(slice))
        decodedAnything = true
    }

    private fun createResampler(codec: MediaCodec): StereoResampler {
        val format = codec.outputFormat
        return StereoResampler(
            format.getInteger(MediaFormat.KEY_SAMPLE_RATE),
            format.getInteger(MediaFormat.KEY_CHANNEL_COUNT),
            OUTPUT_SAMPLE_RATE,
        )
    }

    private fun open() {
        val source = MediaExtractor()
        try {
            source.setDataSource(path)
            val track = (0 until source.trackCount).firstOrNull { index ->
                source.getTrackFormat(index).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: throw IOException("No audio track in $path")
            source.selectTrack(track)
            source.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            val format = source.getTrackFormat(track)
            val codec = MediaCodec.createDecoderByType(checkNotNull(format.getString(MediaFormat.KEY_MIME)))
            codec.configure(format, null, null, 0)
            codec.start()
            extractor = source
            decoder = codec
            inputDone = false
            outputDone = false
        } catch (error: Exception) {
            source.release()
            throw if (error is IOException) error else IOException("Audio of $path cannot be decoded", error)
        }
    }

    private fun reopen() {
        releaseCodec()
        open()
    }

    private fun releaseCodec() {
        decoder?.let { codec ->
            runCatching { codec.stop() }
            codec.release()
        }
        decoder = null
        extractor?.release()
        extractor = null
    }

    override fun close() = releaseCodec()

    companion object {
        const val OUTPUT_SAMPLE_RATE = 44_100
        private const val TIMEOUT_US = 10_000L
    }
}

/**
 * Renders the soundtrack of an edit: original clip sound (normal-speed
 * clips only) mixed with optional looping music that fades out at the end,
 * encoded to AAC in memory. Returns null when the edit has no sound at all.
 */
object AudioRenderer {
    private const val CHUNK_FRAMES = 1024
    private const val BITRATE = 160_000
    private const val FADE_OUT_US = 1_500_000L
    private const val TIMEOUT_US = 10_000L

    fun render(
        plan: EditPlan,
        musicPath: String?,
        musicVolume: Float,
        originalVolume: Float,
        cancelled: AtomicBoolean,
        onProgress: (Double) -> Unit,
    ): EncodedAudio? {
        val useOriginal = originalVolume > 0f && plan.segments.any { it.keepsSound }
        val useMusic = musicPath != null && musicVolume > 0f
        if (!useOriginal && !useMusic) return null

        val rate = PcmSource.OUTPUT_SAMPLE_RATE
        val totalFrames = plan.durationUs * rate / 1_000_000
        val fadeFrames = if (useMusic) FADE_OUT_US * rate / 1_000_000 else 0L
        val music = if (useMusic) PcmSource(musicPath!!, 0, Long.MAX_VALUE, loop = true) else null
        val encoder = createEncoder()
        val packets = ArrayList<EncodedPacket>()
        var outputFormat: MediaFormat? = null
        val info = MediaCodec.BufferInfo()

        fun drain(untilEnd: Boolean) {
            while (true) {
                val index = encoder.dequeueOutputBuffer(info, if (untilEnd) TIMEOUT_US else 0)
                when {
                    index == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!untilEnd) return
                    index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> outputFormat = encoder.outputFormat
                    index >= 0 -> {
                        val buffer = checkNotNull(encoder.getOutputBuffer(index))
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0 && info.size > 0) {
                            val data = ByteArray(info.size)
                            buffer.position(info.offset)
                            buffer.get(data)
                            packets += EncodedPacket(data, info.presentationTimeUs, info.flags)
                        }
                        encoder.releaseOutputBuffer(index, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                    }
                }
            }
        }

        fun queue(pcm: ShortArray, framesBefore: Long, endOfStream: Boolean) {
            var offset = 0
            do {
                if (cancelled.get()) throw CancellationException("export cancelled")
                val index = encoder.dequeueInputBuffer(TIMEOUT_US)
                if (index < 0) {
                    drain(untilEnd = false)
                    continue
                }
                val buffer = checkNotNull(encoder.getInputBuffer(index)).order(ByteOrder.nativeOrder())
                buffer.clear()
                val count = minOf(pcm.size - offset, buffer.capacity() / 2)
                buffer.asShortBuffer().put(pcm, offset, count)
                val ptsUs = (framesBefore + offset / 2) * 1_000_000L / rate
                offset += count
                val flags = if (endOfStream && offset >= pcm.size) MediaCodec.BUFFER_FLAG_END_OF_STREAM else 0
                encoder.queueInputBuffer(index, 0, count * 2, ptsUs, flags)
            } while (offset < pcm.size)
        }

        try {
            var written = 0L
            for (segment in plan.segments) {
                val segmentFrames = segment.outputEndUs * rate / 1_000_000 - written
                val original = if (useOriginal && segment.keepsSound) {
                    PcmSource(segment.clip.path, segment.startUs, segment.endUs, loop = false)
                } else {
                    null
                }
                try {
                    var remaining = segmentFrames
                    while (remaining > 0) {
                        val frames = minOf(CHUNK_FRAMES.toLong(), remaining).toInt()
                        val originalChunk = original?.read(frames, cancelled)
                        val musicChunk = music?.read(frames, cancelled)
                        val mixed = PcmMixer.mix(originalChunk, originalVolume, musicChunk, musicVolume, frames, written, totalFrames, fadeFrames)
                        queue(mixed, written, endOfStream = false)
                        drain(untilEnd = false)
                        written += frames
                        remaining -= frames
                        onProgress(written.toDouble() / totalFrames)
                    }
                } finally {
                    original?.close()
                }
            }
            queue(ShortArray(0), written, endOfStream = true)
            drain(untilEnd = true)
            val format = outputFormat ?: throw IOException("AAC encoder produced no format")
            return EncodedAudio(format, packets)
        } finally {
            music?.close()
            runCatching { encoder.stop() }
            encoder.release()
        }
    }

    private fun createEncoder(): MediaCodec {
        val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, PcmSource.OUTPUT_SAMPLE_RATE, 2).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, BITRATE)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, CHUNK_FRAMES * 2 * 2 * 4)
        }
        return MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC).apply {
            configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            start()
        }
    }
}
