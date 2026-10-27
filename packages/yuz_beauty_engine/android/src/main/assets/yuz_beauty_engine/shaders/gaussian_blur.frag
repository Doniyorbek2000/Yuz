#version 300 es
// One direction of a separable 9-tap Gaussian (sigma ~= 2 texels). Used to
// feather the face mask so the beauty effect has no visible seams.
precision mediump float;

uniform sampler2D uInput;
uniform vec2 uTexelStep;

in vec2 vTexCoord;
out vec4 fragColor;

void main() {
    // Linear-sampling optimized weights for a 9-tap kernel.
    const float w0 = 0.2270270270;
    const float w1 = 0.3162162162;
    const float w2 = 0.0702702703;
    const float o1 = 1.3846153846;
    const float o2 = 3.2307692308;

    vec4 sum = texture(uInput, vTexCoord) * w0;
    sum += texture(uInput, vTexCoord + uTexelStep * o1) * w1;
    sum += texture(uInput, vTexCoord - uTexelStep * o1) * w1;
    sum += texture(uInput, vTexCoord + uTexelStep * o2) * w2;
    sum += texture(uInput, vTexCoord - uTexelStep * o2) * w2;
    fragColor = sum;
}
