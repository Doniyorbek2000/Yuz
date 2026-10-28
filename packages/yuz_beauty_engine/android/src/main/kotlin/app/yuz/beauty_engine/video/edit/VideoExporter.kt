package app.yuz.beauty_engine.video.edit

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.SurfaceTexture
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.opengl.EGLSurface
import android.opengl.GLES30
import android.opengl.GLUtils
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import app.yuz.beauty_engine.face.FaceSelectionPolicy
import app.yuz.beauty_engine.face.FaceTracker
import app.yuz.beauty_engine.face.OfflineLandmarker
import app.yuz.beauty_engine.face.TrackedFace
import app.yuz.beauty_engine.gl.EglCore
import app.yuz.beauty_engine.gl.FullScreenQuad
import app.yuz.beauty_engine.gl.GlProgram
import app.yuz.beauty_engine.gl.GlUtil
import app.yuz.beauty_engine.gl.ShaderLibrary
import app.yuz.beauty_engine.render.BeautyRenderer
import app.yuz.beauty_engine.render.BeautySettings
import app.yuz.beauty_engine.render.CameraTextureTransform
import app.yuz.beauty_engine.video.VideoEncoderSpec
import com.google.mediapipe.tasks.vision.core.RunningMode
import java.io.File
import java.io.IOException
import java.nio.ByteBuffer
import java.util.concurrent.CancellationException
import java.util.concurrent.atomic.AtomicBoolean

class ExportClip(val path: String, val startUs: Long, val endUs: Long, val speed: Double)

class ExportRequest(
    val clips: List<ExportClip>,
    val outputPath: String,
    val settings: BeautySettings,
    val lut: ByteArray?,
    val overlays: List<OverlayWindow>,
    val musicPath: String?,
    val musicVolume: Float,
    val originalVolume: Float,
    val maxLongEdge: Int,
    val applyBeauty: Boolean,
)

class ExportResult(val file: File, val durationMillis: Long, val width: Int, val height: Int, val hasAudio: Boolean)

/**
 * Offline video editor renderer: decodes each trimmed clip to a
 * SurfaceTexture, runs the same GPU beauty pipeline as the camera (with
 * VIDEO-mode face tracking), letterboxes it into the output frame, draws
 * text/sticker overlays and encodes H.264; the soundtrack is rendered first
 * by [AudioRenderer] and interleaved while muxing.
 *
 * [export] is blocking and owns an EGL context on the calling thread for
 * its whole duration; run it on a dedicated worker thread.
 */
class VideoExporter(private val context: Context) {
    fun export(request: ExportRequest, cancelled: AtomicBoolean, onProgress: (Double) -> Unit): ExportResult {
        require(request.clips.isNotEmpty()) { "no clips" }
        val probes = request.clips.map { VideoProbe.probe(it.path) }
        val inputs = request.clips.zip(probes) { clip, probe ->
            ClipInput(clip.path, probe.durationUs, clip.startUs, clip.endUs, clip.speed, probe.uprightWidth, probe.uprightHeight, probe.hasAudio)
        }
        val plan = VideoEditPlanner.plan(inputs, request.maxLongEdge.coerceIn(256, MAX_LONG_EDGE))
        val audio = AudioRenderer.render(plan, request.musicPath, request.musicVolume, request.originalVolume, cancelled) {
            onProgress(it * AUDIO_SHARE)
        }
        val output = File(request.outputPath)
        output.parentFile?.mkdirs()
        val temp = File(output.parentFile, ".${output.name}.part")
        temp.delete()
        try {
            val (width, height) = VideoSession(request, plan, probes, audio, temp, cancelled) { fraction ->
                onProgress(AUDIO_SHARE + fraction * (1 - AUDIO_SHARE))
            }.run()
            if (output.exists()) output.delete()
            if (!temp.renameTo(output)) throw IOException("Could not move the export to ${output.path}")
            onProgress(1.0)
            return ExportResult(output, plan.durationUs / 1_000, width, height, audio != null)
        } catch (error: Throwable) {
            temp.delete()
            throw error
        }
    }

    /** Everything that lives on the export thread for one job. */
    private inner class VideoSession(
        private val request: ExportRequest,
        private val plan: EditPlan,
        private val probes: List<ProbedVideo>,
        private val audio: EncodedAudio?,
        private val temp: File,
        private val cancelled: AtomicBoolean,
        private val onProgress: (Double) -> Unit,
    ) {
        private val spec = VideoEncoderSpec.forOutput(plan.width, plan.height, 0, ::encoderSupportsSize)
        private val settings = if (request.applyBeauty) request.settings else request.settings.colorOnly()
        private val muxer = MediaMuxer(temp.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        private var muxerStarted = false
        private var videoTrack = -1
        private var audioTrack = -1
        private var nextAudioPacket = 0
        private val encoderInfo = MediaCodec.BufferInfo()
        private var lastOutputUs = -1L
        private var lastEncodedUs = 0L
        private var landmarker: OfflineLandmarker? = null
        private val tracker = FaceTracker(OfflineLandmarker.MAX_FACES, FaceSelectionPolicy.ALL_FACES)
        private var detectionBitmap: Bitmap? = null
        private val frameThread = HandlerThread("YuzExportFrames").apply { start() }
        private val frameLock = Object()
        private var frameAvailable = false

        fun run(): Pair<Int, Int> {
            val egl = EglCore()
            var encoderSurface: EGLSurface? = null
            var encoder: MediaCodec? = null
            var inputSurface: Surface? = null
            var renderer: BeautyRenderer? = null
            var overlayProgram: GlProgram? = null
            var quad: FullScreenQuad? = null
            val overlayTextures = HashMap<String, Int>()
            var oesTexture = 0
            var surfaceTexture: SurfaceTexture? = null
            try {
                encoder = createEncoder()
                inputSurface = encoder.createInputSurface()
                encoder.start()
                encoderSurface = egl.createWindowSurface(inputSurface)
                egl.makeCurrent(encoderSurface)

                val shaders = ShaderLibrary(context.assets)
                val activeRenderer = BeautyRenderer(shaders).also { renderer = it }
                activeRenderer.setLut(request.lut)
                val overlay = GlProgram(shaders.load("fullscreen.vert"), shaders.load("overlay_2d.frag"), "overlay_2d")
                overlayProgram = overlay
                val overlayQuad = FullScreenQuad().also { quad = it }
                for (window in request.overlays) {
                    if (window.path !in overlayTextures) overlayTextures[window.path] = uploadOverlay(window.path)
                }
                if (settings.usesFaces) {
                    landmarker = OfflineLandmarker.create(context, RunningMode.VIDEO)
                }

                oesTexture = GlUtil.createExternalTexture()
                val texture = SurfaceTexture(oesTexture)
                surfaceTexture = texture
                texture.setOnFrameAvailableListener({
                    synchronized(frameLock) {
                        frameAvailable = true
                        frameLock.notifyAll()
                    }
                }, Handler(frameThread.looper))
                val decoderSurface = Surface(texture)
                try {
                    plan.segments.forEachIndexed { index, segment ->
                        decodeSegment(segment, probes[index], decoderSurface, texture, oesTexture, activeRenderer, overlay, overlayQuad, overlayTextures, egl, encoderSurface, encoder)
                    }
                } finally {
                    decoderSurface.release()
                }
                encoder.signalEndOfInputStream()
                drainEncoder(encoder, endOfStream = true)
                writeAudioUpTo(Long.MAX_VALUE)
                if (!muxerStarted) throw IOException("No video frames were encoded")
                muxer.stop()
                return spec.width to spec.height
            } finally {
                landmarker?.close()
                detectionBitmap?.recycle()
                surfaceTexture?.setOnFrameAvailableListener(null)
                surfaceTexture?.release()
                if (oesTexture != 0) GlUtil.deleteTexture(oesTexture)
                overlayTextures.values.forEach { GlUtil.deleteTexture(it) }
                overlayProgram?.release()
                quad?.release()
                renderer?.release()
                encoderSurface?.let { egl.releaseSurface(it) }
                egl.release()
                encoder?.let { codec ->
                    runCatching { codec.stop() }
                    codec.release()
                }
                inputSurface?.release()
                runCatching { muxer.release() }
                frameThread.quitSafely()
            }
        }

        private fun decodeSegment(
            segment: PlannedSegment,
            probe: ProbedVideo,
            decoderSurface: Surface,
            texture: SurfaceTexture,
            oesTexture: Int,
            renderer: BeautyRenderer,
            overlay: GlProgram,
            overlayQuad: FullScreenQuad,
            overlayTextures: Map<String, Int>,
            egl: EglCore,
            encoderSurface: EGLSurface,
            encoder: MediaCodec,
        ) {
            val viewport = Letterbox.fit(probe.uprightWidth, probe.uprightHeight, spec.width, spec.height)
            renderer.resize(viewport.width, viewport.height)
            val extractor = MediaExtractor()
            var decoder: MediaCodec? = null
            try {
                extractor.setDataSource(segment.clip.path)
                val track = (0 until extractor.trackCount).first { index ->
                    extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true
                }
                extractor.selectTrack(track)
                extractor.seekTo(segment.startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
                val format = extractor.getTrackFormat(track)
                val codec = MediaCodec.createDecoderByType(checkNotNull(format.getString(MediaFormat.KEY_MIME)))
                decoder = codec
                codec.configure(format, decoderSurface, null, 0)
                codec.start()
                val displayToBuffer = CameraTextureTransform.displayToBuffer(probe.rotationDegrees, false)
                val stMatrix = FloatArray(16)
                val info = MediaCodec.BufferInfo()
                var inputDone = false
                var outputDone = false
                while (!outputDone) {
                    if (cancelled.get()) throw CancellationException("export cancelled")
                    if (!inputDone) {
                        val index = codec.dequeueInputBuffer(TIMEOUT_US)
                        if (index >= 0) {
                            val buffer = checkNotNull(codec.getInputBuffer(index))
                            val size = extractor.readSampleData(buffer, 0)
                            val time = extractor.sampleTime
                            // Keep feeding a little past the end: B-frames reorder.
                            if (size < 0 || time > segment.endUs + REORDER_MARGIN_US) {
                                codec.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                inputDone = true
                            } else {
                                codec.queueInputBuffer(index, 0, size, time, 0)
                                extractor.advance()
                            }
                        }
                    }
                    val index = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                    if (index >= 0) {
                        val endOfStream = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        val pts = info.presentationTimeUs
                        val inRange = info.size != 0 && pts >= segment.startUs && pts < segment.endUs
                        val outputUs = segment.outputTimeUs(pts)
                        // Cap at ~60 fps for sped-up clips; never go back in time.
                        val render = inRange && outputUs > lastOutputUs && (lastOutputUs < 0 || outputUs - lastOutputUs >= MIN_FRAME_SPACING_US)
                        codec.releaseOutputBuffer(index, render)
                        if (render) {
                            awaitFrame()
                            egl.makeCurrent(encoderSurface)
                            texture.updateTexImage()
                            texture.getTransformMatrix(stMatrix)
                            drawFrame(renderer, overlay, overlayQuad, overlayTextures, oesTexture, CameraTextureTransform.multiply(stMatrix, displayToBuffer), viewport, outputUs)
                            egl.setPresentationTime(encoderSurface, outputUs * 1_000)
                            if (!egl.swapBuffers(encoderSurface)) throw IOException("Encoder surface was lost")
                            lastOutputUs = outputUs
                            onProgress((outputUs.toDouble() / plan.durationUs).coerceIn(0.0, 1.0))
                        }
                        if (endOfStream || pts >= segment.endUs) outputDone = true
                    }
                    drainEncoder(encoder, endOfStream = false)
                }
            } catch (error: NoSuchElementException) {
                throw IOException("No video track in ${segment.clip.path}", error)
            } finally {
                decoder?.let { codec ->
                    runCatching { codec.stop() }
                    codec.release()
                }
                extractor.release()
            }
        }

        private fun drawFrame(
            renderer: BeautyRenderer,
            overlay: GlProgram,
            overlayQuad: FullScreenQuad,
            overlayTextures: Map<String, Int>,
            oesTexture: Int,
            uvMatrix: FloatArray,
            viewport: Viewport,
            outputUs: Long,
        ) {
            renderer.uploadExternal(oesTexture, uvMatrix)
            val faces: List<TrackedFace>? = if (settings.usesFaces) detectFaces(renderer, outputUs) else emptyList()
            renderer.runEffects(settings, faces)

            GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0)
            GLES30.glViewport(0, 0, spec.width, spec.height)
            GLES30.glClearColor(0f, 0f, 0f, 1f)
            GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)
            renderer.composite(settings, 0, viewport.width, viewport.height, viewport.x, viewport.y)

            val visible = request.overlays.filter { it.isVisibleAt(outputUs) }
            if (visible.isEmpty()) return
            GLES30.glViewport(0, 0, spec.width, spec.height)
            GLES30.glEnable(GLES30.GL_BLEND)
            GLES30.glBlendFunc(GLES30.GL_ONE, GLES30.GL_ONE_MINUS_SRC_ALPHA)
            overlay.use()
            overlay.setMatrix("uTexMatrix", BeautyRenderer.FLIP_VERTICAL)
            for (window in visible) {
                overlay.bindTexture("uInput", 0, GLES30.GL_TEXTURE_2D, checkNotNull(overlayTextures[window.path]))
                overlayQuad.draw()
            }
            GLES30.glDisable(GLES30.GL_BLEND)
        }

        /** null when the face model is unavailable (colour-only skin detection). */
        private fun detectFaces(renderer: BeautyRenderer, outputUs: Long): List<TrackedFace>? {
            // Without the model, skin effects fall back to colour-based skin detection.
            val detector = landmarker ?: return null
            val scale = minOf(1f, DETECTION_LONG_EDGE / maxOf(renderer.width, renderer.height).toFloat())
            val width = maxOf(1, (renderer.width * scale).toInt())
            val height = maxOf(1, (renderer.height * scale).toInt())
            val pixels: ByteBuffer = renderer.readOriginalScaled(width, height)
            val bitmap = detectionBitmap?.takeIf { it.width == width && it.height == height }
                ?: Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also {
                    detectionBitmap?.recycle()
                    detectionBitmap = it
                }
            bitmap.copyPixelsFromBuffer(pixels)
            val faces = detector.detect(bitmap, outputUs / 1_000)
            return tracker.update(faces, outputUs * 1_000).beautifiedFaces
        }

        private fun awaitFrame() {
            synchronized(frameLock) {
                val deadline = System.nanoTime() + FRAME_TIMEOUT_NANOS
                while (!frameAvailable) {
                    val remaining = (deadline - System.nanoTime()) / 1_000_000
                    if (remaining <= 0) throw IOException("Decoder did not deliver a frame in time")
                    frameLock.wait(remaining)
                }
                frameAvailable = false
            }
        }

        private fun createEncoder(): MediaCodec {
            val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, spec.width, spec.height).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
                setInteger(MediaFormat.KEY_BIT_RATE, spec.bitrate)
                setInteger(MediaFormat.KEY_FRAME_RATE, spec.frameRate)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            }
            val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
            try {
                codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            } catch (error: RuntimeException) {
                codec.release()
                throw IOException("Video encoder could not be configured for ${spec.width}x${spec.height}", error)
            }
            return codec
        }

        private fun drainEncoder(encoder: MediaCodec, endOfStream: Boolean) {
            while (true) {
                val index = encoder.dequeueOutputBuffer(encoderInfo, if (endOfStream) TIMEOUT_US else 0)
                when {
                    index == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        if (!endOfStream) return
                        if (cancelled.get()) throw CancellationException("export cancelled")
                    }
                    index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> startMuxer(encoder.outputFormat)
                    index >= 0 -> {
                        val buffer = checkNotNull(encoder.getOutputBuffer(index))
                        if (encoderInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) encoderInfo.size = 0
                        if (encoderInfo.size > 0) {
                            check(muxerStarted) { "encoder produced data before its format" }
                            buffer.position(encoderInfo.offset)
                            buffer.limit(encoderInfo.offset + encoderInfo.size)
                            muxer.writeSampleData(videoTrack, buffer, encoderInfo)
                            lastEncodedUs = encoderInfo.presentationTimeUs
                            writeAudioUpTo(lastEncodedUs + AUDIO_LEAD_US)
                        }
                        encoder.releaseOutputBuffer(index, false)
                        if (encoderInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                    }
                }
            }
        }

        private fun startMuxer(videoFormat: MediaFormat) {
            check(!muxerStarted) { "video format changed twice" }
            videoTrack = muxer.addTrack(videoFormat)
            if (audio != null) audioTrack = muxer.addTrack(audio.format)
            muxer.start()
            muxerStarted = true
        }

        /** Interleaves the pre-rendered AAC packets with the video samples. */
        private fun writeAudioUpTo(limitUs: Long) {
            val packets = audio?.packets ?: return
            if (!muxerStarted) return
            val info = MediaCodec.BufferInfo()
            while (nextAudioPacket < packets.size && packets[nextAudioPacket].presentationTimeUs <= limitUs) {
                val packet = packets[nextAudioPacket++]
                info.set(0, packet.data.size, packet.presentationTimeUs, packet.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM.inv())
                muxer.writeSampleData(audioTrack, ByteBuffer.wrap(packet.data), info)
            }
        }

        private fun uploadOverlay(path: String): Int {
            val options = BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 }
            val bitmap = BitmapFactory.decodeFile(path, options) ?: throw IOException("Overlay image unreadable: $path")
            try {
                val ids = IntArray(1)
                GLES30.glGenTextures(1, ids, 0)
                GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, ids[0])
                GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
                GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
                GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
                GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)
                // Bitmaps are premultiplied; the overlay shader blends with ONE, ONE_MINUS_SRC_ALPHA.
                GLUtils.texImage2D(GLES30.GL_TEXTURE_2D, 0, bitmap, 0)
                GlUtil.checkError("upload overlay")
                return ids[0]
            } finally {
                bitmap.recycle()
            }
        }
    }

    companion object {
        private const val TAG = "YuzVideoExporter"
        const val MAX_LONG_EDGE = 1920
        private const val AUDIO_SHARE = 0.1
        private const val TIMEOUT_US = 10_000L
        private const val REORDER_MARGIN_US = 500_000L
        private const val MIN_FRAME_SPACING_US = 16_000L
        private const val AUDIO_LEAD_US = 500_000L
        private const val FRAME_TIMEOUT_NANOS = 2_500_000_000L
        private const val DETECTION_LONG_EDGE = 480f


        private fun encoderSupportsSize(width: Int, height: Int): Boolean = runCatching {
            MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.any { info ->
                info.isEncoder &&
                    info.supportedTypes.any { it.equals(MediaFormat.MIMETYPE_VIDEO_AVC, ignoreCase = true) } &&
                    info.getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AVC).videoCapabilities?.isSizeSupported(width, height) == true
            }
        }.getOrElse {
            Log.w(TAG, "Codec capability query failed", it)
            false
        }
    }
}
