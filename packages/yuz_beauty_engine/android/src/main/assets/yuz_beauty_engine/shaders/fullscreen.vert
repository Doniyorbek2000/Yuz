#version 300 es
// Full-screen quad. uTexMatrix maps quad UVs to source UVs: it carries the
// SurfaceTexture transform, sensor rotation and front-camera mirroring for
// the camera pass, and is identity for every intermediate pass.
layout(location = 0) in vec2 aPosition;
layout(location = 1) in vec2 aTexCoord;

uniform mat4 uTexMatrix;

out vec2 vTexCoord;

void main() {
    gl_Position = vec4(aPosition, 0.0, 1.0);
    vTexCoord = (uTexMatrix * vec4(aTexCoord, 0.0, 1.0)).xy;
}
