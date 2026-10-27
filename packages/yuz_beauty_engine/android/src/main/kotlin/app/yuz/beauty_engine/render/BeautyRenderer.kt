package app.yuz.beauty_engine.render

import android.opengl.GLES11Ext
import android.opengl.GLES30
import app.yuz.beauty_engine.face.FaceMaskGeometry
import app.yuz.beauty_engine.face.TrackedFace
import app.yuz.beauty_engine.gl.FullScreenQuad
import app.yuz.beauty_engine.gl.GlProgram
import app.yuz.beauty_engine.gl.GlRenderTarget
import app.yuz.beauty_engine.gl.ShaderLibrary
import java.nio.ByteBuffer

/** Normalized 0..1 beauty controls, immutable so it can be swapped atomically. */
data class BeautySettings(
    val skinSmoothing: Float = 0f,
    val texturePreservation: Float = 0.5f,
    val skinBrightening: Float = 0f,
) {
    val isIdentity: Boolean get() = skinSmoothing <= 0f && skinBrightening <= 0f
}

/**
 * GPU beauty pipeline (GL thread only):
 *
 *   OES camera ──► original (full) ──► smoothH/smoothed (½, cross-bilateral)
 *                                  ──► face mask (¼, polygons + Gaussian feather)
 *   composite(original, smoothed, mask) ──► window surface | capture target
 *
 * The pass order and constants are mirrored by tools/shader-tests so the
 * shipped shaders are verified headlessly in CI.
 */
class BeautyRenderer(shaders: ShaderLibrary) {
    private val vertex = shaders.load("fullscreen.vert")
    private val cameraProgram = GlProgram(vertex, shaders.load("camera_oes.frag"), "camera_oes")
    private val blurProgram = GlProgram(vertex, shaders.load("edge_preserving_blur.frag"), "edge_preserving_blur")
    private val gaussianProgram = GlProgram(vertex, shaders.load("gaussian_blur.frag"), "gaussian_blur")
    private val maskProgram = GlProgram(vertex, shaders.load("face_mask.frag"), "face_mask")
    private val compositeProgram = GlProgram(vertex, shaders.load("beauty_composite.frag"), "beauty_composite")
    private val quad = FullScreenQuad()

    private var original: GlRenderTarget? = null
    private var smoothHorizontal: GlRenderTarget? = null
    private var smoothed: GlRenderTarget? = null
    private var maskRaw: GlRenderTarget? = null
    private var maskHorizontal: GlRenderTarget? = null
    private var mask: GlRenderTarget? = null

    var width = 0
        private set
    var height = 0
        private set

    private var faceMaskEnabled = false

    fun resize(newWidth: Int, newHeight: Int) {
        if (newWidth == width && newHeight == height) return
        releaseTargets()
        width = newWidth
        height = newHeight
        val halfWidth = maxOf(1, newWidth / 2)
        val halfHeight = maxOf(1, newHeight / 2)
        val quarterWidth = maxOf(1, newWidth / 4)
        val quarterHeight = maxOf(1, newHeight / 4)
        original = GlRenderTarget(newWidth, newHeight)
        smoothHorizontal = GlRenderTarget(halfWidth, halfHeight)
        smoothed = GlRenderTarget(halfWidth, halfHeight)
        maskRaw = GlRenderTarget(quarterWidth, quarterHeight)
        maskHorizontal = GlRenderTarget(quarterWidth, quarterHeight)
        mask = GlRenderTarget(quarterWidth, quarterHeight)
    }

    /**
     * Runs every pass except the final composite. [faces] null means face
     * tracking is unavailable (colour-only skin detection); an empty list
     * means tracking works but no face is visible (effects disabled).
     */
    fun process(cameraTextureId: Int, uvMatrix: FloatArray, settings: BeautySettings, faces: List<TrackedFace>?) {
        val originalTarget = checkNotNull(original) { "resize() must be called before process()" }

        originalTarget.bind()
        cameraProgram.use()
        cameraProgram.setMatrix("uTexMatrix", uvMatrix)
        cameraProgram.bindTexture("uCameraTexture", 0, GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTextureId)
        quad.draw()

        if (settings.isIdentity) return

        separableBlur(blurProgram, originalTarget, smoothHorizontal!!, smoothed!!, rangeSigma = RANGE_SIGMA)
        renderFaceMask(faces)
    }

    /** Composites into the currently relevant framebuffer (0 = window surface). */
    fun composite(settings: BeautySettings, framebufferId: Int, viewportWidth: Int, viewportHeight: Int) {
        val originalTarget = checkNotNull(original)
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebufferId)
        GLES30.glViewport(0, 0, viewportWidth, viewportHeight)
        compositeProgram.use()
        compositeProgram.setMatrix("uTexMatrix", IDENTITY)
        compositeProgram.bindTexture("uOriginal", 0, GLES30.GL_TEXTURE_2D, originalTarget.textureId)
        compositeProgram.bindTexture("uSmoothed", 1, GLES30.GL_TEXTURE_2D, smoothed!!.textureId)
        compositeProgram.bindTexture("uFaceMask", 2, GLES30.GL_TEXTURE_2D, mask!!.textureId)
        val identity = settings.isIdentity
        compositeProgram.setFloat("uSkinSmoothing", if (identity) 0f else settings.skinSmoothing)
        compositeProgram.setFloat("uTexturePreservation", settings.texturePreservation)
        compositeProgram.setFloat("uSkinBrightening", if (identity) 0f else settings.skinBrightening)
        compositeProgram.setFloat("uFaceMaskEnabled", if (faceMaskEnabled) 1f else 0f)
        quad.draw()
    }

    /** Renders the processed frame at full resolution and returns RGBA rows (bottom first). */
    fun renderToPixels(settings: BeautySettings): ByteBuffer {
        val target = GlRenderTarget(width, height)
        try {
            composite(settings, target.framebufferId, width, height)
            return target.readPixels()
        } finally {
            target.release()
        }
    }

    private fun renderFaceMask(faces: List<TrackedFace>?) {
        val raw = maskRaw!!
        raw.bind()
        if (faces == null) {
            faceMaskEnabled = false
            return
        }
        faceMaskEnabled = true
        GLES30.glClearColor(0f, 0f, 0f, 1f)
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)
        if (faces.isEmpty()) {
            // Tracking works but nobody is visible: the feathered mask is black.
            mask!!.bind()
            GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)
            return
        }
        maskProgram.use()
        maskProgram.setMatrix("uTexMatrix", IDENTITY)
        GLES30.glEnable(GLES30.GL_BLEND)
        GLES30.glBlendEquation(GLES30.GL_MAX)
        for (face in faces) {
            val polygons = FaceMaskGeometry.build(face.landmarks)
            maskProgram.setVec2Array("uFaceOval", polygons.faceOval)
            maskProgram.setVec2Array("uLeftEye", polygons.leftEye)
            maskProgram.setVec2Array("uRightEye", polygons.rightEye)
            maskProgram.setVec2Array("uLeftBrow", polygons.leftBrow)
            maskProgram.setVec2Array("uRightBrow", polygons.rightBrow)
            maskProgram.setVec2Array("uLips", polygons.lips)
            quad.draw()
        }
        GLES30.glDisable(GLES30.GL_BLEND)
        GLES30.glBlendEquation(GLES30.GL_FUNC_ADD)

        var source = raw
        repeat(MASK_BLUR_ITERATIONS) {
            separableBlur(gaussianProgram, source, maskHorizontal!!, mask!!, rangeSigma = null)
            source = mask!!
        }
    }

    private fun separableBlur(
        program: GlProgram,
        source: GlRenderTarget,
        intermediate: GlRenderTarget,
        destination: GlRenderTarget,
        rangeSigma: Float?,
    ) {
        program.use()
        program.setMatrix("uTexMatrix", IDENTITY)
        if (rangeSigma != null) program.setFloat("uRangeSigma", rangeSigma)

        intermediate.bind()
        program.bindTexture("uInput", 0, GLES30.GL_TEXTURE_2D, source.textureId)
        program.setVec2("uTexelStep", 1f / intermediate.width, 0f)
        quad.draw()

        destination.bind()
        program.bindTexture("uInput", 0, GLES30.GL_TEXTURE_2D, intermediate.textureId)
        program.setVec2("uTexelStep", 0f, 1f / destination.height)
        quad.draw()
    }

    private fun releaseTargets() {
        listOfNotNull(original, smoothHorizontal, smoothed, maskRaw, maskHorizontal, mask).forEach { it.release() }
        original = null
        smoothHorizontal = null
        smoothed = null
        maskRaw = null
        maskHorizontal = null
        mask = null
    }

    fun release() {
        releaseTargets()
        cameraProgram.release()
        blurProgram.release()
        gaussianProgram.release()
        maskProgram.release()
        compositeProgram.release()
        quad.release()
    }

    companion object {
        // Keep in sync with tools/shader-tests/beauty_pipeline.mjs.
        const val RANGE_SIGMA = 0.10f
        const val MASK_BLUR_ITERATIONS = 2

        val IDENTITY = floatArrayOf(
            1f, 0f, 0f, 0f,
            0f, 1f, 0f, 0f,
            0f, 0f, 1f, 0f,
            0f, 0f, 0f, 1f,
        )
    }
}
