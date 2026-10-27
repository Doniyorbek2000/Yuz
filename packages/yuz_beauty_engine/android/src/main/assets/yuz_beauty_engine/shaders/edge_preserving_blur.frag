#version 300 es
// One direction of a separable cross-bilateral blur. Run horizontally, then
// vertically. Spatial weights fall off with distance, range weights with
// colour distance to the centre pixel, so skin is flattened while contours
// (jaw, nose, hairline) keep their edges.
precision highp float;

const int kRadius = 7;
const float kSpatialSigma = 4.0;

uniform sampler2D uInput;
// Direction * texel size, e.g. (1/width, 0) for the horizontal pass.
uniform vec2 uTexelStep;
// Colour-distance sigma in normalized RGB units (typically 0.06 .. 0.14).
uniform float uRangeSigma;

in vec2 vTexCoord;
out vec4 fragColor;

void main() {
    vec4 center = texture(uInput, vTexCoord);
    float rangeDenominator = 1.0 / (2.0 * uRangeSigma * uRangeSigma);
    float spatialDenominator = 1.0 / (2.0 * kSpatialSigma * kSpatialSigma);

    vec3 weightedSum = center.rgb;
    float weightSum = 1.0;

    for (int i = 1; i <= kRadius; ++i) {
        float offset = float(i);
        float spatialWeight = exp(-offset * offset * spatialDenominator);

        vec3 forward = texture(uInput, vTexCoord + uTexelStep * offset).rgb;
        vec3 backward = texture(uInput, vTexCoord - uTexelStep * offset).rgb;

        vec3 forwardDelta = forward - center.rgb;
        vec3 backwardDelta = backward - center.rgb;
        float forwardWeight = spatialWeight * exp(-dot(forwardDelta, forwardDelta) * rangeDenominator);
        float backwardWeight = spatialWeight * exp(-dot(backwardDelta, backwardDelta) * rangeDenominator);

        weightedSum += forward * forwardWeight + backward * backwardWeight;
        weightSum += forwardWeight + backwardWeight;
    }

    fragColor = vec4(weightedSum / weightSum, center.a);
}
