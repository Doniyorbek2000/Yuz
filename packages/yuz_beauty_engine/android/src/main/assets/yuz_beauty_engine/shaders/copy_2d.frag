#version 300 es
// Copies a regular 2D texture (decoded still image) into the pipeline's
// "original" target. uTexMatrix flips rows: bitmaps upload top row first.
precision mediump float;

uniform sampler2D uInput;

in vec2 vTexCoord;
out vec4 fragColor;

void main() {
    fragColor = vec4(texture(uInput, vTexCoord).rgb, 1.0);
}
