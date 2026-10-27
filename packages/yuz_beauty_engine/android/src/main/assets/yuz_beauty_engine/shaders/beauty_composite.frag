#version 300 es
// Final beauty composite.
//
//   mask    = faceMask * skinLikelihood(YCbCr)
//   detail  = original - smoothed            (high-pass)
//   fine    = detail where |detail| is small (pores, micro texture)
//   result  = mix(original, smoothed + fine * texturePreservation,
//                 skinSmoothing * kMaxSmoothingMix * mask)
//   result  = mix(result, gammaLift(result), skinBrightening * mask)
//
// Large-amplitude detail (blemishes, noise blobs, shine spots) is removed,
// small-amplitude detail is re-injected so skin does not turn plastic.
// The iOS Metal kernel in BeautyShaders.swift implements identical maths.
precision highp float;

const vec3 kLuma = vec3(0.299, 0.587, 0.114);
const float kMaxSmoothingMix = 0.92;
const float kFineDetailLow = 0.012;
const float kFineDetailHigh = 0.055;
const float kMaxBrighteningGamma = 0.30;

uniform sampler2D uOriginal;
uniform sampler2D uSmoothed;
uniform sampler2D uFaceMask;

uniform float uSkinSmoothing;       // 0..1
uniform float uTexturePreservation; // 0..1
uniform float uSkinBrightening;     // 0..1
// 1.0 when a landmark-based face mask is bound, 0.0 for colour-only mode.
uniform float uFaceMaskEnabled;

in vec2 vTexCoord;
out vec4 fragColor;

// Soft skin classifier in BT.601 full-range YCbCr. Bounds cover the
// Cb 77..127 / Cr 133..173 cluster with smooth falloff so the mask has no
// hard edges and works across light to deep skin tones.
float skinLikelihood(vec3 rgb) {
    float y = dot(rgb, kLuma);
    float cb = 0.5 + dot(rgb, vec3(-0.168736, -0.331264, 0.5));
    float cr = 0.5 + dot(rgb, vec3(0.5, -0.418688, -0.081312));
    float cbWeight = smoothstep(0.26, 0.30, cb) * (1.0 - smoothstep(0.50, 0.54, cb));
    float crWeight = smoothstep(0.50, 0.53, cr) * (1.0 - smoothstep(0.68, 0.72, cr));
    float lumaWeight = smoothstep(0.06, 0.16, y);
    return cbWeight * crWeight * lumaWeight;
}

void main() {
    vec4 original = texture(uOriginal, vTexCoord);
    vec3 smoothed = texture(uSmoothed, vTexCoord).rgb;
    float faceMask = mix(1.0, texture(uFaceMask, vTexCoord).r, uFaceMaskEnabled);
    float mask = faceMask * skinLikelihood(smoothed);

    vec3 detail = original.rgb - smoothed;
    float detailMagnitude = abs(dot(detail, kLuma));
    float fineWeight = 1.0 - smoothstep(kFineDetailLow, kFineDetailHigh, detailMagnitude);
    vec3 retexturized = smoothed + detail * fineWeight * uTexturePreservation;

    vec3 result = mix(original.rgb, retexturized, uSkinSmoothing * kMaxSmoothingMix * mask);

    vec3 lifted = pow(clamp(result, 0.0, 1.0), vec3(1.0 / (1.0 + kMaxBrighteningGamma * uSkinBrightening)));
    result = mix(result, lifted, mask);

    fragColor = vec4(clamp(result, 0.0, 1.0), original.a);
}
