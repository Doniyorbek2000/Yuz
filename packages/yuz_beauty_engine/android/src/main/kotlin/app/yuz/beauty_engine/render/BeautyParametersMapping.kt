package app.yuz.beauty_engine.render

import app.yuz.beauty_engine.face.ReshapeSettings
import app.yuz.beauty_engine.generated.BeautyParameters

private fun Double.unit(): Float = toFloat().coerceIn(0f, 1f).takeUnless { it.isNaN() } ?: 0f

/** Maps the Pigeon message to engine settings, clamping every control to 0..1. */
fun BeautyParameters.toSettings(): BeautySettings = BeautySettings(
    skinSmoothing = skinSmoothing.unit(),
    texturePreservation = texturePreservation.unit(),
    skinBrightening = skinBrightening.unit(),
    skinTone = skinTone.unit(),
    blemishReduction = blemishReduction.unit(),
    shineReduction = shineReduction.unit(),
    glow = glow.unit(),
    eyeBrightening = eyeBrightening.unit(),
    teethWhitening = teethWhitening.unit(),
    darkCircles = darkCircles.unit(),
    reshape = ReshapeSettings(
        faceSlim = faceSlim.unit(),
        jawline = jawline.unit(),
        chin = chin.unit(),
        eyeEnlarge = eyeEnlarge.unit(),
        noseSlim = noseSlim.unit(),
        lips = lips.unit(),
        forehead = forehead.unit(),
    ),
    lipstick = lipstick.unit(),
    blush = blush.unit(),
    eyebrows = eyebrows.unit(),
    eyeshadow = eyeshadow.unit(),
    eyeliner = eyeliner.unit(),
    makeupIntensity = makeupIntensity.unit(),
    colors = MakeupColors(
        lipstick = lipstickColor.toInt(),
        blush = blushColor.toInt(),
        eyebrow = eyebrowColor.toInt(),
        eyeshadow = eyeshadowColor.toInt(),
        eyeliner = eyelinerColor.toInt(),
    ),
    filterIntensity = filterIntensity.unit(),
    sharpen = sharpen.unit(),
)
