#version 300 es
// Draws a premultiplied-alpha RGBA image (text and stickers rendered by
// Flutter) over the frame. Blending: ONE, ONE_MINUS_SRC_ALPHA.
precision mediump float;

uniform sampler2D uInput;

in vec2 vTexCoord;
out vec4 fragColor;

void main() {
    fragColor = texture(uInput, vTexCoord);
}
