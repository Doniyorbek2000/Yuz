#version 300 es
// Rasterizes the skin region of ONE face into the (low resolution) face mask:
// inside the face oval, outside eyes, eyebrows and lips. Faces are
// accumulated with GL_MAX blending, then the mask is feathered with
// gaussian_blur.frag. Polygons are in normalized display UV space, already
// dilated on the CPU (see FaceMaskGeometry).
precision highp float;

const int kOvalPoints = 36;
const int kEyePoints = 16;
const int kBrowPoints = 10;
const int kLipPoints = 20;

uniform vec2 uFaceOval[kOvalPoints];
uniform vec2 uLeftEye[kEyePoints];
uniform vec2 uRightEye[kEyePoints];
uniform vec2 uLeftBrow[kBrowPoints];
uniform vec2 uRightBrow[kBrowPoints];
uniform vec2 uLips[kLipPoints];

in vec2 vTexCoord;
out vec4 fragColor;

// Even-odd crossing test, unrolled per polygon size because GLSL ES 3.00
// cannot pass uniform arrays of different lengths to one function.
#define INSIDE_POLYGON(points, count, p, result)                          \
    {                                                                     \
        bool inside = false;                                              \
        int j = count - 1;                                                \
        for (int i = 0; i < count; ++i) {                                 \
            vec2 a = points[i];                                           \
            vec2 b = points[j];                                           \
            if (((a.y > p.y) != (b.y > p.y)) &&                           \
                (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x)) {  \
                inside = !inside;                                         \
            }                                                             \
            j = i;                                                        \
        }                                                                 \
        result = inside;                                                  \
    }

void main() {
    vec2 p = vTexCoord;
    bool inOval;
    bool inLeftEye;
    bool inRightEye;
    bool inLeftBrow;
    bool inRightBrow;
    bool inLips;
    INSIDE_POLYGON(uFaceOval, kOvalPoints, p, inOval)
    INSIDE_POLYGON(uLeftEye, kEyePoints, p, inLeftEye)
    INSIDE_POLYGON(uRightEye, kEyePoints, p, inRightEye)
    INSIDE_POLYGON(uLeftBrow, kBrowPoints, p, inLeftBrow)
    INSIDE_POLYGON(uRightBrow, kBrowPoints, p, inRightBrow)
    INSIDE_POLYGON(uLips, kLipPoints, p, inLips)

    bool excluded = inLeftEye || inRightEye || inLeftBrow || inRightBrow || inLips;
    float skin = (inOval && !excluded) ? 1.0 : 0.0;
    fragColor = vec4(skin, skin, skin, 1.0);
}
