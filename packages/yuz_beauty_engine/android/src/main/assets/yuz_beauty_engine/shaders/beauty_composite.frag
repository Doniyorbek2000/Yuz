#version 300 es
// Final beauty composite (one pass, full resolution).
//
// Inputs: the (optionally reshaped) frame, its edge-preserving blur, a wide
// plain Gaussian of it (low-frequency colour: blemishes and redness patches
// that the edge-preserving blur deliberately keeps), three feathered
// semantic masks (see face_mask.frag) and an optional 512x512
// colour lookup table. Every effect is a masked blend whose weight is 0
// when its control is 0, so all-zero controls are an exact identity.
//
// The iOS Metal kernel in BeautyShaders.swift implements identical maths;
// tools/shader-tests verifies this file pixel by pixel.
precision highp float;

const vec3 kLuma = vec3(0.299, 0.587, 0.114);
const float kMaxSmoothingMix = 0.92;
const float kFineDetailLow = 0.012;
const float kFineDetailHigh = 0.055;
const float kMaxBrighteningGamma = 0.30;

uniform sampler2D uOriginal;
uniform sampler2D uSmoothed;
uniform sampler2D uBaseBlur;
// Small-radius plain Gaussian (half resolution) for unsharp masking.
uniform sampler2D uDetailBlur;
uniform sampler2D uMaskA; // skin, eyes, teeth, under-eye
uniform sampler2D uMaskB; // lips, blush, brows, eyeshadow
uniform sampler2D uMaskC; // eyeliner
uniform sampler2D uLut;

// 1.0 when landmark masks are bound, 0.0 for colour-only skin detection.
uniform float uFaceMaskEnabled;

// Skin (all 0..1)
uniform float uSkinSmoothing;
uniform float uTexturePreservation;
uniform float uSkinBrightening;
uniform float uSkinTone;
uniform float uBlemishReduction;
uniform float uShineReduction;
uniform float uGlow;
// Face details
uniform float uEyeBrightening;
uniform float uTeethWhitening;
uniform float uDarkCircles;
// Makeup (intensities already multiplied by the global makeup intensity)
uniform float uLipstick;
uniform float uBlush;
uniform float uEyebrows;
uniform float uEyeshadow;
uniform float uEyeliner;
uniform vec3 uLipColor;
uniform vec3 uBlushColor;
uniform vec3 uBrowColor;
uniform vec3 uShadowColor;
uniform vec3 uLinerColor;
// Global detail
uniform float uSharpen;
// Colour filter
uniform float uLutIntensity;

in vec2 vTexCoord;
out vec4 fragColor;

vec3 toYCbCr(vec3 rgb) {
    return vec3(
        dot(rgb, kLuma),
        0.5 + dot(rgb, vec3(-0.168736, -0.331264, 0.5)),
        0.5 + dot(rgb, vec3(0.5, -0.418688, -0.081312))
    );
}

vec3 toRgb(vec3 ycc) {
    float y = ycc.x;
    float cb = ycc.y - 0.5;
    float cr = ycc.z - 0.5;
    return vec3(y + 1.402 * cr, y - 0.344136 * cb - 0.714136 * cr, y + 1.772 * cb);
}

// Soft skin classifier (BT.601 Cb 77..127 / Cr 133..173 with smooth falloff).
float skinLikelihood(vec3 rgb) {
    vec3 ycc = toYCbCr(rgb);
    float cbWeight = smoothstep(0.26, 0.30, ycc.y) * (1.0 - smoothstep(0.50, 0.54, ycc.y));
    float crWeight = smoothstep(0.50, 0.53, ycc.z) * (1.0 - smoothstep(0.68, 0.72, ycc.z));
    float lumaWeight = smoothstep(0.06, 0.16, ycc.x);
    return cbWeight * crWeight * lumaWeight;
}

vec3 gammaLift(vec3 rgb, float amount) {
    return pow(clamp(rgb, 0.0, 1.0), vec3(1.0 / (1.0 + amount)));
}

// Keeps the pixel's luminance and takes the hue/chroma of `tint`.
vec3 colorize(vec3 rgb, vec3 tint, float lumaShift) {
    vec3 base = toYCbCr(rgb);
    vec3 color = toYCbCr(tint);
    return clamp(toRgb(vec3(base.x * (1.0 + lumaShift), color.y, color.z)), 0.0, 1.0);
}

vec3 lutLookup(vec3 rgb) {
    float blue = clamp(rgb.b, 0.0, 1.0) * 63.0;
    vec2 tile1;
    tile1.y = floor(floor(blue) / 8.0);
    tile1.x = floor(blue) - tile1.y * 8.0;
    vec2 tile2;
    tile2.y = floor(ceil(blue) / 8.0);
    tile2.x = ceil(blue) - tile2.y * 8.0;
    vec2 inner = 0.5 / 512.0 + (0.125 - 1.0 / 512.0) * clamp(rgb.rg, 0.0, 1.0);
    vec3 color1 = texture(uLut, tile1 * 0.125 + inner).rgb;
    vec3 color2 = texture(uLut, tile2 * 0.125 + inner).rgb;
    return mix(color1, color2, fract(blue));
}

void main() {
    vec4 original = texture(uOriginal, vTexCoord);
    vec3 smoothed = texture(uSmoothed, vTexCoord).rgb;
    vec4 maskA = mix(vec4(1.0, 0.0, 0.0, 0.0), texture(uMaskA, vTexCoord), uFaceMaskEnabled);
    vec4 maskB = texture(uMaskB, vTexCoord) * uFaceMaskEnabled;
    float maskC = texture(uMaskC, vTexCoord).r * uFaceMaskEnabled;

    float skinColor = skinLikelihood(smoothed);
    float skin = maskA.r * skinColor;

    vec3 base = texture(uBaseBlur, vTexCoord).rgb;

    // --- Smoothing and texture preservation ---
    vec3 detail = original.rgb - smoothed;
    float fineWeight = 1.0 - smoothstep(kFineDetailLow, kFineDetailHigh, abs(dot(detail, kLuma)));
    vec3 retexturized = smoothed + detail * fineWeight * uTexturePreservation;
    vec3 result = mix(original.rgb, retexturized, uSkinSmoothing * kMaxSmoothingMix * skin);

    // --- Blemish removal: replace small dark spots with the local mean ---
    float spotDepth = dot(base - original.rgb, kLuma);
    float darkSpot = smoothstep(0.03, 0.08, spotDepth);
    result = mix(result, base, uBlemishReduction * darkSpot * skin);

    // --- Even skin tone: take chroma from the low-frequency frame ---
    if (uSkinTone > 0.0) {
        vec3 ycc = toYCbCr(result);
        vec3 baseYcc = toYCbCr(base);
        ycc.yz = mix(ycc.yz, baseYcc.yz, uSkinTone * 0.85 * skin);
        result = clamp(toRgb(ycc), 0.0, 1.0);
    }

    // --- Shine reduction: compress bright, low-chroma highlights on skin ---
    float luma = dot(result, kLuma);
    float highlight = smoothstep(0.70, 0.92, luma);
    result = mix(result, result * (1.0 - 0.22 * highlight), uShineReduction * skin);

    // --- Brightening ---
    result = mix(result, gammaLift(result, kMaxBrighteningGamma * uSkinBrightening), skin);

    // --- Glow: soft screen with the blurred frame ---
    vec3 bloom = smoothed * smoothed;
    result = mix(result, 1.0 - (1.0 - result) * (1.0 - bloom * 0.45), uGlow * skin);

    // --- Eyes, teeth, dark circles ---
    vec3 eyeLift = gammaLift(result, 0.45);
    eyeLift = mix(vec3(dot(eyeLift, kLuma)), eyeLift, 1.12);
    result = mix(result, clamp(eyeLift, 0.0, 1.0), uEyeBrightening * maskA.g);

    vec3 teethYcc = toYCbCr(result);
    float teethLikelihood = smoothstep(0.25, 0.45, teethYcc.x);
    vec3 whiter = clamp(toRgb(vec3(min(teethYcc.x * 1.12, 1.0), mix(teethYcc.yz, vec2(0.5), 0.75))), 0.0, 1.0);
    result = mix(result, whiter, uTeethWhitening * maskA.b * teethLikelihood);

    float underEye = maskA.a * skinColor;
    result = mix(result, gammaLift(result, 0.5), uDarkCircles * underEye);

    // --- Makeup ---
    result = mix(result, colorize(result, uLipColor, -0.05), uLipstick * 0.85 * maskB.r);
    result = mix(result, result * mix(vec3(1.0), uBlushColor, 0.55), uBlush * 0.6 * maskB.g * skinColor);
    result = mix(result, result * uBrowColor * 1.15, uEyebrows * 0.6 * maskB.b);
    result = mix(result, result * mix(vec3(1.0), uShadowColor, 0.8), uEyeshadow * 0.7 * maskB.a);
    result = mix(result, uLinerColor, uEyeliner * 0.85 * maskC);

    // --- Sharpen (unsharp mask); skin that is being smoothed is protected ---
    if (uSharpen > 0.0) {
        vec3 detailBlur = texture(uDetailBlur, vTexCoord).rgb;
        float protection = 1.0 - skin * min(1.0, uSkinSmoothing * 2.0);
        result = clamp(result + (original.rgb - detailBlur) * uSharpen * 1.5 * protection, 0.0, 1.0);
    }

    // --- Colour filter ---
    if (uLutIntensity > 0.0) {
        result = mix(result, lutLookup(result), uLutIntensity);
    }

    fragColor = vec4(clamp(result, 0.0, 1.0), original.a);
}
