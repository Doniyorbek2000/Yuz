package app.yuz.beauty_engine.still

import android.content.Context
import android.graphics.Bitmap
import android.opengl.EGLSurface
import android.opengl.GLES30
import android.opengl.GLUtils
import android.util.Log
import app.yuz.beauty_engine.face.DetectedFace
import app.yuz.beauty_engine.face.FaceLandmarkDetector
import app.yuz.beauty_engine.face.FaceMaskGeometry
import app.yuz.beauty_engine.face.FaceSelectionPolicy
import app.yuz.beauty_engine.face.FaceTracker
import app.yuz.beauty_engine.face.NormalizedPoint
import app.yuz.beauty_engine.face.TrackedFace
import app.yuz.beauty_engine.gl.EglCore
import app.yuz.beauty_engine.gl.GlUtil
import app.yuz.beauty_engine.gl.ShaderLibrary
import app.yuz.beauty_engine.render.BeautyRenderer
import app.yuz.beauty_engine.render.BeautySettings
import app.yuz.beauty_engine.render.GlThread
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * Applies the camera's GPU beauty pipeline to photos. Owns its own EGL
 * context, renderer and IMAGE-mode face landmarker, independent of the
 * camera session. Jobs are serialized.
 */
class StillImageProcessor(private val context: Context) {
    class Output(
        val width: Int,
        val height: Int,
        val sourceWidth: Int,
        val sourceHeight: Int,
        val faceCount: Int,
        val faceTrackingAvailable: Boolean,
    )

    private val mutex = Mutex()
    private var glThread: GlThread? = null
    private var egl: EglCore? = null
    private var surface: EGLSurface? = null
    private var renderer: BeautyRenderer? = null
    private var maxTextureSize = 4096
    private var landmarker: FaceLandmarker? = null
    private var landmarkerUnavailable = false

    suspend fun process(
        inputPath: String,
        outputPath: String,
        maxLongEdge: Int,
        settings: BeautySettings,
        lut: ByteArray?,
        jpegQuality: Int,
        maxFaces: Int,
    ): Output = mutex.withLock {
        val thread = ensureGlThread()
        val gpuLimit = thread.run { ensureGl(); maxTextureSize }
        val decoded = withContext(Dispatchers.IO) { StillImageDecoder.decode(inputPath, maxLongEdge, gpuLimit) }
        try {
            val bitmap = decoded.bitmap
            val faces: List<TrackedFace>? = withContext(Dispatchers.Default) { detectFaces(bitmap, maxFaces) }
            val pixels = thread.run {
                val active = checkNotNull(renderer)
                val texture = uploadTexture(bitmap)
                try {
                    active.resize(bitmap.width, bitmap.height)
                    active.setLut(lut)
                    active.processStill(texture, settings, faces)
                    active.renderToPixels(settings)
                } finally {
                    GlUtil.deleteTexture(texture)
                }
            }
            withContext(Dispatchers.IO) {
                JpegWriter.write(pixels, bitmap.width, bitmap.height, File(outputPath), jpegQuality)
            }
            Output(
                width = bitmap.width,
                height = bitmap.height,
                sourceWidth = decoded.sourceWidth,
                sourceHeight = decoded.sourceHeight,
                faceCount = faces?.size ?: 0,
                faceTrackingAvailable = faces != null,
            )
        } finally {
            decoded.bitmap.recycle()
        }
    }

    suspend fun close() = mutex.withLock {
        val thread = glThread ?: return@withLock
        runCatching {
            thread.run {
                renderer?.release()
                renderer = null
                surface?.let { egl?.releaseSurface(it) }
                surface = null
                egl?.release()
                egl = null
            }
        }.onFailure { Log.w(TAG, "GL release failed", it) }
        thread.quit()
        glThread = null
        landmarker?.close()
        landmarker = null
    }

    private fun ensureGlThread(): GlThread = glThread ?: GlThread("YuzStillGL").also { glThread = it }

    /** GL thread only. */
    private fun ensureGl() {
        if (renderer != null) {
            egl?.makeCurrent(surface!!)
            return
        }
        val core = EglCore()
        val offscreen = core.createOffscreenSurface(1, 1)
        core.makeCurrent(offscreen)
        egl = core
        surface = offscreen
        val limit = IntArray(1)
        GLES30.glGetIntegerv(GLES30.GL_MAX_TEXTURE_SIZE, limit, 0)
        maxTextureSize = minOf(limit[0].takeIf { it > 0 } ?: 4096, MAX_OUTPUT_EDGE)
        renderer = BeautyRenderer(ShaderLibrary(context.assets))
    }

    private fun uploadTexture(bitmap: Bitmap): Int {
        val ids = IntArray(1)
        GLES30.glGenTextures(1, ids, 0)
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, ids[0])
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)
        GLUtils.texImage2D(GLES30.GL_TEXTURE_2D, 0, bitmap, 0)
        GlUtil.checkError("upload still image")
        return ids[0]
    }

    /** null when the face model is unavailable (colour-only processing). */
    private fun detectFaces(bitmap: Bitmap, maxFaces: Int): List<TrackedFace>? {
        val detector = obtainLandmarker() ?: return null
        val result = runCatching { detector.detect(BitmapImageBuilder(bitmap).build()) }
            .onFailure { Log.w(TAG, "Face detection failed", it) }
            .getOrNull() ?: return emptyList()
        val faces = result.faceLandmarks().mapNotNull { landmarks ->
            if (landmarks.size < FaceMaskGeometry.MESH_LANDMARK_COUNT) return@mapNotNull null
            DetectedFace(landmarks.map { NormalizedPoint(it.x(), it.y()) })
        }
        val tracker = FaceTracker(maxFaces.coerceIn(1, MAX_FACES), FaceSelectionPolicy.ALL_FACES)
        return tracker.update(faces, System.nanoTime()).beautifiedFaces
    }

    private fun obtainLandmarker(): FaceLandmarker? {
        landmarker?.let { return it }
        if (landmarkerUnavailable) return null
        val modelAvailable = runCatching { context.assets.open(FaceLandmarkDetector.MODEL_ASSET).close() }.isSuccess
        if (modelAvailable) {
            for (delegate in listOf(Delegate.GPU, Delegate.CPU)) {
                val created = runCatching {
                    FaceLandmarker.createFromOptions(
                        context,
                        FaceLandmarker.FaceLandmarkerOptions.builder()
                            .setBaseOptions(
                                BaseOptions.builder()
                                    .setModelAssetPath(FaceLandmarkDetector.MODEL_ASSET)
                                    .setDelegate(delegate)
                                    .build(),
                            )
                            .setRunningMode(RunningMode.IMAGE)
                            .setNumFaces(MAX_FACES)
                            .setMinFaceDetectionConfidence(0.5f)
                            .setMinFacePresenceConfidence(0.5f)
                            .build(),
                    )
                }.onFailure { Log.w(TAG, "IMAGE landmarker unavailable on $delegate", it) }.getOrNull()
                if (created != null) {
                    landmarker = created
                    return created
                }
            }
        }
        landmarkerUnavailable = true
        return null
    }

    private companion object {
        const val TAG = "YuzStillProcessor"
        const val MAX_FACES = 4
        const val MAX_OUTPUT_EDGE = 8192
    }
}
