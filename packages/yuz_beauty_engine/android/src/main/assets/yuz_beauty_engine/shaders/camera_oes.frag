#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
// Copies the external camera texture into a regular RGBA texture in display
// orientation so every later pass samples a plain sampler2D.
precision mediump float;

uniform samplerExternalOES uCameraTexture;

in vec2 vTexCoord;
out vec4 fragColor;

void main() {
    fragColor = vec4(texture(uCameraTexture, vTexCoord).rgb, 1.0);
}
