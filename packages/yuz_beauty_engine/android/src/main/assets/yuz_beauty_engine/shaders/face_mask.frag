#version 300 es
// Rasterizes the semantic regions of ONE face into three RGBA mask targets
// (faces are accumulated with GL_MAX blending, then feathered):
//
//   outMaskA: r = skin, g = eyes, b = teeth (inner mouth), a = under-eye
//   outMaskB: r = lips, g = blush, b = brows, a = eyeshadow
//   outMaskC: r = eyeliner
//
// Rings are raw MediaPipe contours packed two points per vec4 (see
// FaceMaskGeometry). Eye-derived regions (under-eye, eyeshadow, eyeliner)
// are produced by testing the eye ring scaled and shifted, which keeps the
// uniform budget small. uVerticalSign is +1 when "up" in the image is +v
// (OpenGL) and -1 when it is -y (Metal).
precision highp float;

const int kOvalStart = 0;
const int kOvalCount = 36;
const int kLeftEyeStart = 36;
const int kRightEyeStart = 52;
const int kEyeCount = 16;
const int kLeftBrowStart = 68;
const int kRightBrowStart = 78;
const int kBrowCount = 10;
const int kLipsStart = 88;
const int kLipsCount = 20;
const int kMouthStart = 108;
const int kMouthCount = 20;
const int kPackedPoints = 64;

uniform vec4 uPoints[kPackedPoints];
// (centroid.x, centroid.y, halfWidth, halfHeight)
uniform vec4 uLeftEyeBox;
uniform vec4 uRightEyeBox;
uniform vec4 uMouthBox;
// (center.x, center.y, radius.x, radius.y)
uniform vec4 uLeftCheek;
uniform vec4 uRightCheek;
// (minX, minY, maxX, maxY), already expanded on the CPU
uniform vec4 uFaceBounds;
uniform float uVerticalSign;

in vec2 vTexCoord;
layout(location = 0) out vec4 outMaskA;
layout(location = 1) out vec4 outMaskB;
layout(location = 2) out vec4 outMaskC;

vec2 pointAt(int index) {
    vec4 pair = uPoints[index / 2];
    return (index % 2 == 0) ? pair.xy : pair.zw;
}

// Even-odd test of p against ring[start, start+count) scaled by `scale`
// about `origin` and then translated by `shift`.
bool insideRing(int start, int count, vec2 origin, float scale, vec2 shift, vec2 p) {
    vec2 q = origin + (p - origin - shift) / scale;
    bool inside = false;
    int j = count - 1;
    for (int i = 0; i < count; ++i) {
        vec2 a = pointAt(start + i);
        vec2 b = pointAt(start + j);
        if (((a.y > q.y) != (b.y > q.y)) && (q.x < (b.x - a.x) * (q.y - a.y) / (b.y - a.y) + a.x)) {
            inside = !inside;
        }
        j = i;
    }
    return inside;
}

float aboveCenter(vec2 p, vec4 box) {
    return (p.y - box.y) * uVerticalSign > 0.0 ? 1.0 : 0.0;
}

float eyeRegion(int start, vec4 box, vec2 p, out float tight, out float dilated,
                out float underEye, out float eyeshadow, out float eyeliner) {
    vec2 up = vec2(0.0, uVerticalSign * box.w);
    tight = insideRing(start, kEyeCount, box.xy, 1.0, vec2(0.0), p) ? 1.0 : 0.0;
    dilated = insideRing(start, kEyeCount, box.xy, 1.45, vec2(0.0), p) ? 1.0 : 0.0;
    float liner = insideRing(start, kEyeCount, box.xy, 1.25, vec2(0.0), p) ? 1.0 : 0.0;
    float below = insideRing(start, kEyeCount, box.xy, 1.8, -up * 1.9, p) ? 1.0 : 0.0;
    float lid = insideRing(start, kEyeCount, box.xy, 1.9, up * 1.3, p) ? 1.0 : 0.0;
    float above = aboveCenter(p, box);
    underEye = below * (1.0 - dilated) * (1.0 - above);
    eyeshadow = lid * (1.0 - liner) * above;
    eyeliner = liner * (1.0 - tight) * above;
    return dilated;
}

float cheek(vec4 ellipse, vec2 p) {
    float d = length((p - ellipse.xy) / ellipse.zw);
    return 1.0 - smoothstep(0.0, 1.0, d);
}

void main() {
    vec2 p = vTexCoord;
    outMaskA = vec4(0.0);
    outMaskB = vec4(0.0);
    outMaskC = vec4(0.0);
    if (p.x < uFaceBounds.x || p.y < uFaceBounds.y || p.x > uFaceBounds.z || p.y > uFaceBounds.w) return;

    float inOval = insideRing(kOvalStart, kOvalCount, p, 1.0, vec2(0.0), p) ? 1.0 : 0.0;

    float leftTight, leftDilated, leftUnder, leftShadow, leftLiner;
    float rightTight, rightDilated, rightUnder, rightShadow, rightLiner;
    eyeRegion(kLeftEyeStart, uLeftEyeBox, p, leftTight, leftDilated, leftUnder, leftShadow, leftLiner);
    eyeRegion(kRightEyeStart, uRightEyeBox, p, rightTight, rightDilated, rightUnder, rightShadow, rightLiner);

    float brows = (insideRing(kLeftBrowStart, kBrowCount, p, 1.0, vec2(0.0), p) ||
                   insideRing(kRightBrowStart, kBrowCount, p, 1.0, vec2(0.0), p)) ? 1.0 : 0.0;
    float lipsOuter = insideRing(kLipsStart, kLipsCount, uMouthBox.xy, 1.0, vec2(0.0), p) ? 1.0 : 0.0;
    float lipsGuard = insideRing(kLipsStart, kLipsCount, uMouthBox.xy, 1.12, vec2(0.0), p) ? 1.0 : 0.0;
    float mouthInner = insideRing(kMouthStart, kMouthCount, uMouthBox.xy, 1.0, vec2(0.0), p) ? 1.0 : 0.0;

    float eyesGuard = max(leftDilated, rightDilated);
    float skin = inOval * (1.0 - eyesGuard) * (1.0 - brows) * (1.0 - lipsGuard);
    float eyes = max(leftTight, rightTight);
    float underEye = max(leftUnder, rightUnder) * inOval;
    float eyeshadow = max(leftShadow, rightShadow) * (1.0 - brows);
    float eyeliner = max(leftLiner, rightLiner);
    float blush = max(cheek(uLeftCheek, p), cheek(uRightCheek, p)) * skin;
    float lips = lipsOuter * (1.0 - mouthInner);

    outMaskA = vec4(skin, eyes, mouthInner, underEye);
    outMaskB = vec4(lips, blush, brows, eyeshadow);
    outMaskC = vec4(eyeliner, 0.0, 0.0, 1.0);
}
