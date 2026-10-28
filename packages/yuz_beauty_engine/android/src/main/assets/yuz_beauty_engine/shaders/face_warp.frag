#version 300 es
// Landmark-driven face reshape. Each warp is a smooth local deformation with
// a (1 - d^2)^2 falloff inside its radius:
//
//   kind 0 (bulge):     sample at c + (p - c) * (1 - s * w)   -> magnifies around c
//   kind 1 (translate): sample at p - v * w                   -> moves content by v
//
// Distances are measured in aspect-corrected space (x scaled by width/height)
// so circular warps stay circular on non-square frames. Warps are applied in
// sequence to the sampling coordinate.
precision highp float;

const int kMaxWarps = 16;

uniform sampler2D uInput;
// (center.x, center.y, radius, kind)
uniform vec4 uWarpA[kMaxWarps];
// (offset.x, offset.y, strength, unused)
uniform vec4 uWarpB[kMaxWarps];
uniform float uWarpCount;
uniform float uAspect;

in vec2 vTexCoord;
out vec4 fragColor;

void main() {
    vec2 p = vTexCoord;
    for (int i = 0; i < kMaxWarps; ++i) {
        if (float(i) >= uWarpCount) break;
        vec4 a = uWarpA[i];
        vec4 b = uWarpB[i];
        vec2 delta = p - a.xy;
        delta.x *= uAspect;
        float distance01 = length(delta) / a.z;
        if (distance01 >= 1.0) continue;
        float weight = 1.0 - distance01 * distance01;
        weight *= weight;
        if (a.w < 0.5) {
            p = a.xy + (p - a.xy) * (1.0 - b.z * weight);
        } else {
            p = p - b.xy * weight;
        }
    }
    fragColor = texture(uInput, p);
}
