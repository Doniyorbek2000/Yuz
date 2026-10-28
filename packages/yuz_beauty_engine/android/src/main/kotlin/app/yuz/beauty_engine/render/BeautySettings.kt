package app.yuz.beauty_engine.render

import app.yuz.beauty_engine.face.ReshapeSettings

/** Makeup colours as 0xAARRGGBB. Defaults are natural, everyday tones. */
data class MakeupColors(
    val lipstick: Int = 0xFFB4404F.toInt(),
    val blush: Int = 0xFFE8838A.toInt(),
    val eyebrow: Int = 0xFF4A3426.toInt(),
    val eyeshadow: Int = 0xFF9A6B5C.toInt(),
    val eyeliner: Int = 0xFF1C1614.toInt(),
) {
    companion object {
        /** 0xAARRGGBB -> linear 0..1 RGB as stored in the shader uniforms. */
        fun rgb(color: Int): FloatArray = floatArrayOf(
            ((color shr 16) and 0xFF) / 255f,
            ((color shr 8) and 0xFF) / 255f,
            (color and 0xFF) / 255f,
        )
    }
}

/** Every engine control, normalized 0..1 and immutable so it can be swapped atomically. */
data class BeautySettings(
    val skinSmoothing: Float = 0f,
    val texturePreservation: Float = 0.5f,
    val skinBrightening: Float = 0f,
    val skinTone: Float = 0f,
    val blemishReduction: Float = 0f,
    val shineReduction: Float = 0f,
    val glow: Float = 0f,
    val eyeBrightening: Float = 0f,
    val teethWhitening: Float = 0f,
    val darkCircles: Float = 0f,
    val reshape: ReshapeSettings = ReshapeSettings(),
    val lipstick: Float = 0f,
    val blush: Float = 0f,
    val eyebrows: Float = 0f,
    val eyeshadow: Float = 0f,
    val eyeliner: Float = 0f,
    val makeupIntensity: Float = 1f,
    val colors: MakeupColors = MakeupColors(),
    val filterIntensity: Float = 0f,
) {
    /** True when the composite pass changes anything (warps are separate). */
    val compositeActive: Boolean
        get() = listOf(
            skinSmoothing, skinBrightening, skinTone, blemishReduction, shineReduction, glow,
            eyeBrightening, teethWhitening, darkCircles,
        ).any { it > 0f } || makeupActive || filterIntensity > 0f

    val makeupActive: Boolean
        get() = makeupIntensity > 0f && listOf(lipstick, blush, eyebrows, eyeshadow, eyeliner).any { it > 0f }

    val isIdentity: Boolean get() = !compositeActive && reshape.isIdentity
}
