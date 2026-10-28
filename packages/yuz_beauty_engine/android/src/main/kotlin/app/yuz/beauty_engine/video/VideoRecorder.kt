package app.yuz.beauty_engine.video

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.util.Log
import android.view.Surface
import java.io.File
import java.io.IOException
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicReference
import kotlin.concurrent.thread

class RecordingResult(val file: File, val durationMillis: Long, val width: Int, val height: Int, val hasAudio: Boolean)

class RecordingException(message: String, cause: Throwable? = null) : IOException(message, cause)

/**
 * H.264 + AAC MP4 recorder. Video frames are rendered by the GL pipeline into
 * [inputSurface] (with presentation times from [timeline]); audio is read
 * from the microphone on its own thread. The file is written to a temporary
 * path and renamed only when it is complete and playable.
 */
class VideoRecorder private constructor(
    private val output: File,
    val spec: VideoEncoderSpec,
    startNanos: Long,
    private val audioRecord: AudioRecord?,
) {
    val timeline = RecordingTimeline(startNanos)

    private val temp = File(output.parentFile, ".${output.name}.part")
    private val muxer = MuxerGate(MediaMuxer(temp.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4), expectedTracks = if (audioRecord != null) 2 else 1)
    private val videoCodec: MediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
    private var audioCodec: MediaCodec? = null
    private val failure = AtomicReference<Throwable?>(null)

    @Volatile
    private var stopRequested = false

    @Volatile
    private var aborted = false

    @Volatile
    private var audioWritten = false

    val inputSurface: Surface
    private val videoThread: Thread
    private var audioThread: Thread? = null

    init {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, spec.width, spec.height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, spec.bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, spec.frameRate)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        try {
            videoCodec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            inputSurface = videoCodec.createInputSurface()
            videoCodec.start()
        } catch (error: RuntimeException) {
            videoCodec.release()
            muxer.release()
            audioRecord?.release()
            temp.delete()
            throw RecordingException("Video encoder could not be configured for ${spec.width}x${spec.height}", error)
        }
        videoThread = thread(name = "YuzVideoEncoder") { guard { drain(videoCodec, Track.VIDEO) } }
        if (audioRecord != null) audioThread = thread(name = "YuzAudioEncoder") { guard { recordAudio(audioRecord) } }
    }

    /**
     * Finishes the file. The caller must already have stopped rendering into
     * [inputSurface] and released its EGL surface.
     */
    fun stop(): RecordingResult {
        stopRequested = true
        runCatching { videoCodec.signalEndOfInputStream() }.onFailure { failure.compareAndSet(null, it) }
        audioThread?.join(JOIN_TIMEOUT_MILLIS)
        videoThread.join(JOIN_TIMEOUT_MILLIS)
        if (videoThread.isAlive || audioThread?.isAlive == true) {
            aborted = true
            videoThread.join(JOIN_TIMEOUT_MILLIS)
            audioThread?.join(JOIN_TIMEOUT_MILLIS)
        }
        releaseCodecs()
        val muxed = runCatching { muxer.finish() }
        val error = failure.get() ?: muxed.exceptionOrNull()
        if (error != null || muxed.getOrNull() != true || timeline.durationUs <= 0) {
            temp.delete()
            if (error is RecordingException) throw error
            throw RecordingException(if (error == null) "Recording is too short" else "Recording failed: ${error.message}", error)
        }
        if (output.exists()) output.delete()
        if (!temp.renameTo(output)) {
            temp.delete()
            throw RecordingException("Could not move the recording to ${output.path}")
        }
        return RecordingResult(output, timeline.durationUs / 1_000, spec.width, spec.height, audioWritten)
    }

    /** Discards the recording (e.g. the session is being torn down after an error). */
    fun cancel() {
        stopRequested = true
        aborted = true
        runCatching { videoCodec.signalEndOfInputStream() }
        audioThread?.join(JOIN_TIMEOUT_MILLIS)
        videoThread.join(JOIN_TIMEOUT_MILLIS)
        releaseCodecs()
        runCatching { muxer.finish() }
        temp.delete()
    }

    private fun releaseCodecs() {
        runCatching { videoCodec.stop() }
        videoCodec.release()
        inputSurface.release()
        audioCodec?.let { codec ->
            runCatching { codec.stop() }
            codec.release()
        }
        audioCodec = null
        audioRecord?.let { record ->
            runCatching { record.stop() }
            record.release()
        }
    }

    private inline fun guard(block: () -> Unit) {
        try {
            block()
        } catch (error: Throwable) {
            Log.e(TAG, "Encoder thread failed", error)
            failure.compareAndSet(null, error)
        }
    }

    /** Moves encoded output into the muxer; blocks until end of stream (or abort). */
    private fun drain(codec: MediaCodec, track: Track, untilEndOfStream: Boolean = true) {
        val info = MediaCodec.BufferInfo()
        while (true) {
            val index = codec.dequeueOutputBuffer(info, if (untilEndOfStream) DEQUEUE_TIMEOUT_US else 0)
            when {
                index == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!untilEndOfStream || aborted) return
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> muxer.addTrack(track, codec.outputFormat)
                index >= 0 -> {
                    val buffer = checkNotNull(codec.getOutputBuffer(index))
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                    if (info.size > 0) {
                        if (muxer.write(track, buffer, info) && track == Track.AUDIO) audioWritten = true
                    }
                    codec.releaseOutputBuffer(index, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                }
            }
        }
    }

    private fun recordAudio(record: AudioRecord) {
        val codec = try {
            MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC).apply {
                val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, SAMPLE_RATE, 1).apply {
                    setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                    setInteger(MediaFormat.KEY_BIT_RATE, AUDIO_BITRATE)
                    setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, CHUNK_BYTES)
                }
                configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                start()
            }
        } catch (error: Exception) {
            Log.w(TAG, "AAC encoder unavailable; recording without sound", error)
            muxer.dropTrack()
            return
        }
        audioCodec = codec
        val clock = AudioSampleClock(SAMPLE_RATE)
        val pcm = ByteArray(CHUNK_BYTES)
        try {
            record.startRecording()
        } catch (error: IllegalStateException) {
            Log.w(TAG, "Microphone unavailable; recording without sound", error)
            muxer.dropTrack()
            return
        }
        var lastPtsUs = 0L
        while (!stopRequested) {
            val read = record.read(pcm, 0, pcm.size)
            if (read == AudioRecord.ERROR_DEAD_OBJECT) {
                Log.w(TAG, "Microphone was taken by another app; continuing without sound")
                break
            }
            if (read <= 0) continue
            val ptsUs = timeline.audioPresentationUs(clock.chunkStartNanos(read / BYTES_PER_FRAME, System.nanoTime()))
                ?: continue
            if (!queuePcm(codec, pcm, read, ptsUs, endOfStream = false)) break
            lastPtsUs = ptsUs
            drain(codec, Track.AUDIO, untilEndOfStream = false)
        }
        queuePcm(codec, pcm, 0, lastPtsUs + 1, endOfStream = true)
        drain(codec, Track.AUDIO)
        // No sound was ever encoded (e.g. a silent failure of the microphone):
        // the file must still be finished with the video track alone.
        muxer.dropTrackIfMissing(Track.AUDIO)
    }

    /** Returns false when the encoder accepted nothing within the timeout while aborting. */
    private fun queuePcm(codec: MediaCodec, pcm: ByteArray, length: Int, ptsUs: Long, endOfStream: Boolean): Boolean {
        var offset = 0
        do {
            val index = codec.dequeueInputBuffer(DEQUEUE_TIMEOUT_US)
            if (index < 0) {
                if (aborted) return false
                drain(codec, Track.AUDIO, untilEndOfStream = false)
                continue
            }
            val buffer = checkNotNull(codec.getInputBuffer(index))
            buffer.clear()
            val count = minOf(length - offset, buffer.capacity())
            buffer.put(pcm, offset, count)
            val chunkPts = ptsUs + (offset / BYTES_PER_FRAME) * 1_000_000L / SAMPLE_RATE
            offset += count
            val last = offset >= length
            codec.queueInputBuffer(index, 0, count, chunkPts, if (endOfStream && last) MediaCodec.BUFFER_FLAG_END_OF_STREAM else 0)
        } while (offset < length)
        return true
    }

    private enum class Track { VIDEO, AUDIO }

    /**
     * MediaMuxer may only start once every track is added; samples that
     * arrive earlier (usually a few audio packets) are buffered.
     */
    private class MuxerGate(private val muxer: MediaMuxer, expectedTracks: Int) {
        private var expected = expectedTracks
        private val indices = HashMap<Track, Int>()
        private val pending = ArrayList<Triple<Track, ByteBuffer, MediaCodec.BufferInfo>>()
        private var pendingBytes = 0
        private var started = false
        private var released = false

        @Synchronized
        fun addTrack(track: Track, format: MediaFormat) {
            // A track that shows up after the muxer started (it was given up
            // on) is ignored rather than failing the recording.
            if (started || released) return
            indices[track] = muxer.addTrack(format)
            startIfReady()
        }

        /** The audio track will never arrive. */
        @Synchronized
        fun dropTrack() {
            expected--
            startIfReady()
        }

        @Synchronized
        fun dropTrackIfMissing(track: Track) {
            if (!started && track !in indices) dropTrack()
        }

        @Synchronized
        /** Returns whether the sample was written or queued. */
        fun write(track: Track, buffer: ByteBuffer, info: MediaCodec.BufferInfo): Boolean {
            if (released) return false
            if (started) {
                val index = indices[track] ?: return false
                muxer.writeSampleData(index, buffer, info)
                return true
            }
            if (pendingBytes + info.size > MAX_PENDING_BYTES) {
                // The other track is far behind: never lose video, give up on it instead.
                expected = indices.size
                startIfReady()
                val index = indices[track] ?: return false
                muxer.writeSampleData(index, buffer, info)
                return true
            }
            val copy = ByteBuffer.allocate(info.size)
            buffer.position(info.offset)
            buffer.limit(info.offset + info.size)
            copy.put(buffer).flip()
            val copiedInfo = MediaCodec.BufferInfo().apply { set(0, info.size, info.presentationTimeUs, info.flags) }
            pending += Triple(track, copy, copiedInfo)
            pendingBytes += info.size
            return true
        }

        /** Returns true when a playable file was written. */
        @Synchronized
        fun finish(): Boolean {
            if (released) return false
            released = true
            val wasStarted = started
            try {
                if (wasStarted) muxer.stop()
            } finally {
                muxer.release()
            }
            return wasStarted
        }

        @Synchronized
        fun release() {
            if (released) return
            released = true
            muxer.release()
        }

        private fun startIfReady() {
            if (started || indices.size < expected || indices.isEmpty()) return
            muxer.start()
            started = true
            for ((track, buffer, info) in pending) {
                indices[track]?.let { muxer.writeSampleData(it, buffer, info) }
            }
            pending.clear()
            pendingBytes = 0
        }
    }

    companion object {
        private const val TAG = "YuzVideoRecorder"
        const val SAMPLE_RATE = 44_100
        private const val AUDIO_BITRATE = 128_000
        private const val BYTES_PER_FRAME = 2
        private const val CHUNK_BYTES = 4_096
        private const val DEQUEUE_TIMEOUT_US = 10_000L
        private const val JOIN_TIMEOUT_MILLIS = 3_000L
        private const val MAX_PENDING_BYTES = 8 * 1024 * 1024

        /**
         * Starts encoders and (when [withAudio] and the microphone can be
         * opened) audio capture. The caller must hold RECORD_AUDIO for audio.
         */
        @SuppressLint("MissingPermission")
        fun start(output: File, frameWidth: Int, frameHeight: Int, bitrate: Int, withAudio: Boolean): VideoRecorder {
            output.parentFile?.mkdirs()
            val spec = VideoEncoderSpec.forOutput(frameWidth, frameHeight, bitrate, ::encoderSupportsSize)
            val record = if (withAudio) openMicrophone() else null
            return VideoRecorder(output, spec, System.nanoTime(), record)
        }

        private fun encoderSupportsSize(width: Int, height: Int): Boolean = runCatching {
            MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.any { info ->
                info.isEncoder &&
                    info.supportedTypes.any { it.equals(MediaFormat.MIMETYPE_VIDEO_AVC, ignoreCase = true) } &&
                    info.getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AVC).videoCapabilities?.isSizeSupported(width, height) == true
            }
        }.getOrDefault(false)

        @SuppressLint("MissingPermission")
        private fun openMicrophone(): AudioRecord? {
            val minBuffer = AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
            if (minBuffer <= 0) return null
            return try {
                val record = AudioRecord(
                    MediaRecorder.AudioSource.CAMCORDER,
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    maxOf(minBuffer * 2, CHUNK_BYTES * 4),
                )
                if (record.state == AudioRecord.STATE_INITIALIZED) {
                    record
                } else {
                    record.release()
                    null
                }
            } catch (error: RuntimeException) {
                Log.w(TAG, "Microphone could not be opened", error)
                null
            }
        }
    }
}
