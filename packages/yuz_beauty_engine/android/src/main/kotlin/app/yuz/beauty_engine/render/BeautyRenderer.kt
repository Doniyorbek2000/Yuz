package app.yuz.beauty_engine.render

import android.opengl.GLES11Ext
import android.opengl.GLES30
import app.yuz.beauty_engine.face.FaceMaskGeometry
import app.yuz.beauty_engine.face.FaceWarp
import app.yuz.beauty_engine.face.FaceWarpBuilder
import app.yuz.beauty_engine.face.TrackedFace
import app.yuz.beauty_engine.gl.FullScreenQuad
import app.yuz.beauty_engine.gl.GlLutTexture
import app.yuz.beauty_engine.gl.GlMultiTarget
import app.yuz.beauty_engine.gl.GlProgram
import app.yuz.beauty_engine.gl.GlRenderTarget
import app.yuz.beauty_engine.gl.GlTextureTarget
import app.yuz.beauty_engine.gl.ShaderLibrary
import java.nio.ByteBuffer

/**
 * GPU beauty pipeline (GL thread only):
 *
 *   OES camera ─► original (full) ─► [warp: reshape] ─► source
 *   source ─► smoothH/smoothed (½, cross-bilateral)
 *   source ─► baseBlur (¼, wide Gaussian: blemishes, tone)
 *   landmarks ─► maskA/B/C (¼, MRT polygons, Gaussian feather)
 *   composite(source, smoothed, baseBlur, masks, LUT) ─► window surface | capture target
 *
 * Pass order and constants are mirrored by tools/shader-tests, which runs
 * these exact shader files headlessly in CI.
 */
class BeautyRenderer(shaders: ShaderLibrary) {
    private val vertex = shaders.load("fullscreen.vert")
    private val cameraProgram = GlProgram(vertex, shaders.load("camera_oes.frag"), "camera_oes")
    private val warpProgram = GlProgram(vertex, shaders.load("face_warp.frag"), "face_warp")
    private val blurProgram = GlProgram(vertex, shaders.load("edge_preserving_blur.frag"), "edge_preserving_blur")
    private val gaussianProgram = GlProgram(vertex, shaders.load("gaussian_blur.frag"), "gaussian_blur")
    private val maskProgram = GlProgram(vertex, shaders.load("face_mask.frag"), "face_mask")
    private val compositeProgram = GlProgram(vertex, shaders.load("beauty_composite.frag"), "beauty_composite")
    private val quad = FullScreenQuad()
    private val lut = GlLutTexture()
    private var lutLoaded = false

    private var original: GlRenderTarget? = null
    private var warped: GlRenderTarget? = null
    private var smoothHorizontal: GlRenderTarget? = null
    private var smoothed: GlRenderTarget? = null
    private var baseTemp: GlRenderTarget? = null
    private var baseBlur: GlRenderTarget? = null
    private var masks: GlMultiTarget? = null
    private var maskTargets: List<GlTextureTarget> = emptyList()
    private var maskTemp: GlRenderTarget? = null

    var width = 0
        private set
    var height = 0
        private set

    private var faceMaskEnabled = false
    private var sourceTextureId = 0

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
        warped = GlRenderTarget(newWidth, newHeight)
        smoothHorizontal = GlRenderTarget(halfWidth, halfHeight)
        smoothed = GlRenderTarget(halfWidth, halfHeight)
        baseTemp = GlRenderTarget(quarterWidth, quarterHeight)
        baseBlur = GlRenderTarget(quarterWidth, quarterHeight)
        val multi = GlMultiTarget(quarterWidth, quarterHeight, MASK_COUNT)
        masks = multi
        maskTargets = multi.textureIds.map { GlTextureTarget(it, quarterWidth, quarterHeight) }
        maskTemp = GlRenderTarget(quarterWidth, quarterHeight)
        clearMasks()
    }

    /** Uploads a 512x512 RGBA LUT, or disables the filter when null. */
    fun setLut(rgba: ByteArray?) {
        if (rgba == null) {
            lutLoaded = false
            return
        }
        lut.upload(rgba)
        lutLoaded = true
    }

    /**
     * Runs every pass except the final composite. [faces] null means face
     * tracking is unavailable (colour-only skin detection, no reshape or
     * makeup); an empty list means tracking works but nobody is visible.
     */
    fun process(cameraTextureId: Int, uvMatrix: FloatArray, settings: BeautySettings, faces: List<TrackedFace>?) {
        val originalTarget = checkNotNull(original) { "resize() must be called before process()" }

        originalTarget.bind()
        cameraProgram.use()
        cameraProgram.setMatrix("uTexMatrix", uvMatrix)
        cameraProgram.bindTexture("uCameraTexture", 0, GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTextureId)
        quad.draw()
        sourceTextureId = originalTarget.textureId

        val aspect = width.toFloat() / height.toFloat()
        if (!faces.isNullOrEmpty() && !settings.reshape.isIdentity) {
            val warps = faces.flatMap { FaceWarpBuilder.build(it.landmarks, settings.reshape, aspect) }
                .take(FaceWarpBuilder.MAX_WARPS)
            if (warps.isNotEmpty()) {
                renderWarps(originalTarget.textureId, warps, aspect)
                sourceTextureId = warped!!.textureId
            }
        }

        if (!settings.compositeActive) return

        separableBlur(blurProgram, sourceTextureId, smoothHorizontal!!, smoothed!!, rangeSigma = RANGE_SIGMA)
        var baseSource = sourceTextureId
        repeat(BASE_BLUR_ITERATIONS) {
            separableBlur(gaussianProgram, baseSource, baseTemp!!, baseBlur!!, rangeSigma = null)
            baseSource = baseBlur!!.textureId
        }
        renderFaceMasks(faces, aspect)
    }

    /** Composites into [framebufferId] (0 = window surface). */
    fun composite(settings: BeautySettings, framebufferId: Int, viewportWidth: Int, viewportHeight: Int) {
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebufferId)
        GLES30.glViewport(0, 0, viewportWidth, viewportHeight)
        val active = settings.compositeActive
        val program = compositeProgram
        program.use()
        program.setMatrix("uTexMatrix", IDENTITY)
        val maskTextures = masks!!.textureIds
        program.bindTexture("uOriginal", 0, GLES30.GL_TEXTURE_2D, sourceTextureId)
        program.bindTexture("uSmoothed", 1, GLES30.GL_TEXTURE_2D, smoothed!!.textureId)
        program.bindTexture("uBaseBlur", 2, GLES30.GL_TEXTURE_2D, baseBlur!!.textureId)
        program.bindTexture("uMaskA", 3, GLES30.GL_TEXTURE_2D, maskTextures[0])
        program.bindTexture("uMaskB", 4, GLES30.GL_TEXTURE_2D, maskTextures[1])
        program.bindTexture("uMaskC", 5, GLES30.GL_TEXTURE_2D, maskTextures[2])
        program.bindTexture("uLut", 6, GLES30.GL_TEXTURE_2D, lut.textureId)
        program.setFloat("uFaceMaskEnabled", if (faceMaskEnabled) 1f else 0f)

        fun gate(value: Float) = if (active) value else 0f
        val makeup = settings.makeupIntensity
        program.setFloat("uSkinSmoothing", gate(settings.skinSmoothing))
        program.setFloat("uTexturePreservation", settings.texturePreservation)
        program.setFloat("uSkinBrightening", gate(settings.skinBrightening))
        program.setFloat("uSkinTone", gate(settings.skinTone))
        program.setFloat("uBlemishReduction", gate(settings.blemishReduction))
        program.setFloat("uShineReduction", gate(settings.shineReduction))
        program.setFloat("uGlow", gate(settings.glow))
        program.setFloat("uEyeBrightening", gate(settings.eyeBrightening))
        program.setFloat("uTeethWhitening", gate(settings.teethWhitening))
        program.setFloat("uDarkCircles", gate(settings.darkCircles))
        program.setFloat("uLipstick", gate(settings.lipstick * makeup))
        program.setFloat("uBlush", gate(settings.blush * makeup))
        program.setFloat("uEyebrows", gate(settings.eyebrows * makeup))
        program.setFloat("uEyeshadow", gate(settings.eyeshadow * makeup))
        program.setFloat("uEyeliner", gate(settings.eyeliner * makeup))
        program.setVec3("uLipColor", MakeupColors.rgb(settings.colors.lipstick))
        program.setVec3("uBlushColor", MakeupColors.rgb(settings.colors.blush))
        program.setVec3("uBrowColor", MakeupColors.rgb(settings.colors.eyebrow))
        program.setVec3("uShadowColor", MakeupColors.rgb(settings.colors.eyeshadow))
        program.setVec3("uLinerColor", MakeupColors.rgb(settings.colors.eyeliner))
        program.setFloat("uLutIntensity", if (lutLoaded) gate(settings.filterIntensity) else 0f)
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

    private fun renderWarps(input: Int, warps: List<FaceWarp>, aspect: Float) {
        val a = FloatArray(FaceWarpBuilder.MAX_WARPS * 4)
        val b = FloatArray(FaceWarpBuilder.MAX_WARPS * 4)
        warps.forEachIndexed { i, warp ->
            // Landmark space (top-left) -> GL texture space (bottom-left).
            a[i * 4] = warp.centerX
            a[i * 4 + 1] = 1f - warp.centerY
            a[i * 4 + 2] = warp.radius
            a[i * 4 + 3] = warp.kind.shaderValue
            b[i * 4] = warp.offsetX
            b[i * 4 + 1] = -warp.offsetY
            b[i * 4 + 2] = warp.strength
        }
        warped!!.bind()
        warpProgram.use()
        warpProgram.setMatrix("uTexMatrix", IDENTITY)
        warpProgram.bindTexture("uInput", 0, GLES30.GL_TEXTURE_2D, input)
        warpProgram.setVec4Array("uWarpA", a)
        warpProgram.setVec4Array("uWarpB", b)
        warpProgram.setFloat("uWarpCount", warps.size.toFloat())
        warpProgram.setFloat("uAspect", aspect)
        quad.draw()
    }

    private fun renderFaceMasks(faces: List<TrackedFace>?, aspect: Float) {
        faceMaskEnabled = faces != null
        clearMasks()
        if (faces.isNullOrEmpty()) return

        masks!!.bind()
        maskProgram.use()
        maskProgram.setMatrix("uTexMatrix", IDENTITY)
        maskProgram.setFloat("uVerticalSign", 1f)
        GLES30.glEnable(GLES30.GL_BLEND)
        GLES30.glBlendEquation(GLES30.GL_MAX)
        for (face in faces) {
            val uniforms = FaceMaskGeometry.build(face.landmarks, aspect, flipVertical = true)
            maskProgram.setVec4Array("uPoints", uniforms.packedPoints)
            maskProgram.setVec4("uLeftEyeBox", uniforms.leftEyeBox)
            maskProgram.setVec4("uRightEyeBox", uniforms.rightEyeBox)
            maskProgram.setVec4("uMouthBox", uniforms.mouthBox)
            maskProgram.setVec4("uLeftCheek", uniforms.leftCheek)
            maskProgram.setVec4("uRightCheek", uniforms.rightCheek)
            maskProgram.setVec4("uFaceBounds", uniforms.faceBounds)
            quad.draw()
        }
        GLES30.glDisable(GLES30.GL_BLEND)
        GLES30.glBlendEquation(GLES30.GL_FUNC_ADD)

        maskTargets.forEachIndexed { index, target ->
            val iterations = if (index == EYELINER_MASK) LINER_BLUR_ITERATIONS else MASK_BLUR_ITERATIONS
            repeat(iterations) { featherInPlace(target) }
        }
    }

    private fun featherInPlace(target: GlTextureTarget) {
        val temp = maskTemp!!
        gaussianProgram.use()
        gaussianProgram.setMatrix("uTexMatrix", IDENTITY)
        temp.bind()
        gaussianProgram.bindTexture("uInput", 0, GLES30.GL_TEXTURE_2D, target.textureId)
        gaussianProgram.setVec2("uTexelStep", 1f / temp.width, 0f)
        quad.draw()
        target.bind()
        gaussianProgram.bindTexture("uInput", 0, GLES30.GL_TEXTURE_2D, temp.textureId)
        gaussianProgram.setVec2("uTexelStep", 0f, 1f / target.height)
        quad.draw()
    }

    private fun clearMasks() {
        masks?.bind() ?: return
        GLES30.glClearColor(0f, 0f, 0f, 0f)
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)
    }

    private fun separableBlur(
        program: GlProgram,
        sourceTexture: Int,
        intermediate: GlRenderTarget,
        destination: GlRenderTarget,
        rangeSigma: Float?,
    ) {
        program.use()
        program.setMatrix("uTexMatrix", IDENTITY)
        if (rangeSigma != null) program.setFloat("uRangeSigma", rangeSigma)

        intermediate.bind()
        program.bindTexture("uInput", 0, GLES30.GL_TEXTURE_2D, sourceTexture)
        program.setVec2("uTexelStep", 1f / intermediate.width, 0f)
        quad.draw()

        destination.bind()
        program.bindTexture("uInput", 0, GLES30.GL_TEXTURE_2D, intermediate.textureId)
        program.setVec2("uTexelStep", 0f, 1f / destination.height)
        quad.draw()
    }

    private fun releaseTargets() {
        maskTargets.forEach { it.release() }
        maskTargets = emptyList()
        masks?.release()
        masks = null
        listOfNotNull(original, warped, smoothHorizontal, smoothed, baseTemp, baseBlur, maskTemp).forEach { it.release() }
        original = null
        warped = null
        smoothHorizontal = null
        smoothed = null
        baseTemp = null
        baseBlur = null
        maskTemp = null
    }

    fun release() {
        releaseTargets()
        listOf(cameraProgram, warpProgram, blurProgram, gaussianProgram, maskProgram, compositeProgram).forEach { it.release() }
        lut.release()
        quad.release()
    }

    companion object {
        // Keep in sync with tools/shader-tests/beauty_pipeline.mjs and MetalBeautyRenderer.swift.
        const val RANGE_SIGMA = 0.10f
        const val MASK_BLUR_ITERATIONS = 2
        const val LINER_BLUR_ITERATIONS = 1
        const val BASE_BLUR_ITERATIONS = 2
        private const val MASK_COUNT = 3
        private const val EYELINER_MASK = 2

        val IDENTITY = floatArrayOf(
            1f, 0f, 0f, 0f,
            0f, 1f, 0f, 0f,
            0f, 0f, 1f, 0f,
            0f, 0f, 0f, 1f,
        )
    }
}
