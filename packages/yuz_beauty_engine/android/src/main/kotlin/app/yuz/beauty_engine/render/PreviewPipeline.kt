package app.yuz.beauty_engine.render

import android.graphics.SurfaceTexture
import android.opengl.EGLSurface
import android.util.Log
import android.view.Surface
import app.yuz.beauty_engine.face.TrackedFace
import app.yuz.beauty_engine.gl.EglCore
import app.yuz.beauty_engine.gl.GlUtil
import app.yuz.beauty_engine.gl.ShaderLibrary
import app.yuz.beauty_engine.perf.PerformanceTracker
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

class CapturedFrame(val rgbaBottomUp: ByteBuffer, val width: Int, val height: Int)

/**
 * Camera SurfaceTexture → BeautyRenderer → Flutter SurfaceProducer surface.
 *
 * All members except the @Volatile configuration fields are confined to
 * the GL thread.
 */
class PreviewPipeline(
    private val glThread: GlThread,
    private val shaders: ShaderLibrary,
    private val performance: PerformanceTracker,
) {
    private var egl: EglCore? = null
    private var offscreenSurface: EGLSurface? = null
    private var windowSurface: EGLSurface? = null
    private var renderer: BeautyRenderer? = null
    private var cameraTextureId = 0
    private val surfaceTextureMatrix = FloatArray(16)
    private val renderPending = AtomicBoolean(false)

    var surfaceTexture: SurfaceTexture? = null
        private set

    @Volatile
    var settings = BeautySettings()

    /** Returns stabilized faces, or null when face tracking is unavailable. */
    @Volatile
    var faceProvider: () -> List<TrackedFace>? = { null }

    @Volatile
    private var rotationDegrees = 0

    @Volatile
    private var mirrorHorizontally = false

    suspend fun start() = glThread.run {
        val core = EglCore()
        egl = core
        val offscreen = core.createOffscreenSurface(1, 1)
        offscreenSurface = offscreen
        core.makeCurrent(offscreen)
        renderer = BeautyRenderer(shaders)
    }

    /**
     * Creates a fresh camera SurfaceTexture for a new CameraX SurfaceRequest
     * (one per binding, so a lens switch never reconnects a producer to a
     * SurfaceTexture the previous camera still holds).
     */
    suspend fun createCameraSurface(bufferWidth: Int, bufferHeight: Int): Surface = glThread.run {
        makeAnySurfaceCurrent()
        releaseCameraTexture()
        cameraTextureId = GlUtil.createExternalTexture()
        val texture = SurfaceTexture(cameraTextureId).apply {
            setDefaultBufferSize(bufferWidth, bufferHeight)
            setOnFrameAvailableListener({ onFrameAvailable() }, glThread.handler)
        }
        surfaceTexture = texture
        Surface(texture)
    }

    /**
     * Applies orientation for the current binding. Returns the upright output
     * size that the Flutter texture must use.
     */
    suspend fun configure(bufferWidth: Int, bufferHeight: Int, rotation: Int, mirror: Boolean): Pair<Int, Int> =
        glThread.run {
            rotationDegrees = rotation
            mirrorHorizontally = mirror
            val (width, height) = CameraTextureTransform.uprightSize(bufferWidth, bufferHeight, rotation)
            makeAnySurfaceCurrent()
            renderer?.resize(width, height)
            width to height
        }

    fun attachOutput(surface: Surface) = glThread.post {
        val core = egl ?: return@post
        releaseWindowSurface()
        windowSurface = runCatching { core.createWindowSurface(surface) }
            .onFailure { Log.e(TAG, "Cannot create window surface", it) }
            .getOrNull()
    }

    /** Synchronous: Flutter requires the surface to be released before returning. */
    fun detachOutput() {
        if (!glThread.runBlocking(SURFACE_RELEASE_TIMEOUT_MILLIS) { releaseWindowSurface() }) {
            Log.w(TAG, "Timed out releasing the output surface")
        }
    }

    /** Uploads (or clears) the colour LUT on the GL thread. */
    fun setLut(rgba: ByteArray?) = glThread.post {
        val core = egl ?: return@post
        core.makeCurrent(windowSurface ?: offscreenSurface ?: return@post)
        runCatching { renderer?.setLut(rgba) }.onFailure { Log.e(TAG, "LUT upload failed", it) }
    }

    suspend fun capture(): CapturedFrame = glThread.run {
        val activeRenderer = checkNotNull(renderer) { "pipeline not started" }
        check(activeRenderer.width > 0) { "no camera frame rendered yet" }
        makeAnySurfaceCurrent()
        CapturedFrame(activeRenderer.renderToPixels(settings), activeRenderer.width, activeRenderer.height)
    }

    suspend fun release() = glThread.run {
        makeAnySurfaceCurrent()
        renderer?.release()
        renderer = null
        releaseCameraTexture()
        releaseWindowSurface()
        offscreenSurface?.let { egl?.releaseSurface(it) }
        offscreenSurface = null
        egl?.release()
        egl = null
    }

    private fun onFrameAvailable() {
        performance.onCameraFrame()
        if (!renderPending.compareAndSet(false, true)) {
            performance.onFrameDropped()
            return
        }
        glThread.post {
            renderPending.set(false)
            drawFrame()
        }
    }

    private fun drawFrame() {
        val core = egl ?: return
        val texture = surfaceTexture ?: return
        val activeRenderer = renderer ?: return
        val startNanos = System.nanoTime()
        val window = windowSurface
        try {
            core.makeCurrent(window ?: offscreenSurface!!)
            texture.updateTexImage()
            if (window == null || activeRenderer.width == 0) return
            texture.getTransformMatrix(surfaceTextureMatrix)
            val uvMatrix = CameraTextureTransform.multiply(
                surfaceTextureMatrix,
                CameraTextureTransform.displayToBuffer(rotationDegrees, mirrorHorizontally),
            )
            val currentSettings = settings
            activeRenderer.process(cameraTextureId, uvMatrix, currentSettings, faceProvider())
            activeRenderer.composite(currentSettings, 0, activeRenderer.width, activeRenderer.height)
            core.setPresentationTime(window, texture.timestamp)
            if (!core.swapBuffers(window)) {
                Log.w(TAG, "eglSwapBuffers failed; dropping output surface until Flutter provides a new one")
                releaseWindowSurface()
                return
            }
            performance.onFrameRendered(System.nanoTime() - startNanos)
        } catch (error: RuntimeException) {
            performance.onFrameDropped()
            Log.e(TAG, "Frame render failed", error)
        }
    }

    private fun makeAnySurfaceCurrent() {
        val core = egl ?: return
        core.makeCurrent(windowSurface ?: offscreenSurface ?: return)
    }

    private fun releaseCameraTexture() {
        surfaceTexture?.setOnFrameAvailableListener(null)
        surfaceTexture?.release()
        surfaceTexture = null
        if (cameraTextureId != 0) GlUtil.deleteTexture(cameraTextureId)
        cameraTextureId = 0
    }

    private fun releaseWindowSurface() {
        val surface = windowSurface ?: return
        windowSurface = null
        egl?.releaseSurface(surface)
        offscreenSurface?.let { egl?.makeCurrent(it) }
    }

    private companion object {
        const val TAG = "YuzPreviewPipeline"
        const val SURFACE_RELEASE_TIMEOUT_MILLIS = 1_000L
    }
}
