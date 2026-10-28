// Metal compute kernels. The maths is a line-by-line port of the GLSL ES 3.00
// shaders in android/src/main/assets/yuz_beauty_engine/shaders (verified
// headlessly by tools/shader-tests); constants must stay identical.
//
// Compiled at runtime with MTLDevice.makeLibrary(source:) so the pod does not
// depend on how CocoaPods packages .metal files into a metallib.
enum BeautyShaders {
  /// Indices into the composite `values` buffer (keep in sync with MetalBeautyRenderer).
  enum Value: Int, CaseIterable {
    case faceMaskEnabled, skinSmoothing, texturePreservation, skinBrightening, skinTone, blemishReduction
    case shineReduction, glow, eyeBrightening, teethWhitening, darkCircles
    case lipstick, blush, eyebrows, eyeshadow, eyeliner, lutIntensity
  }

  /// Indices into the composite `colors` buffer.
  enum Color: Int, CaseIterable {
    case lipstick, blush, eyebrow, eyeshadow, eyeliner
  }

  static let source = """
    #include <metal_stdlib>
    using namespace metal;

    constant float3 kLuma = float3(0.299, 0.587, 0.114);
    constant int kRadius = 7;
    constant float kSpatialSigma = 4.0;
    constant float kMaxSmoothingMix = 0.92;
    constant float kFineDetailLow = 0.012;
    constant float kFineDetailHigh = 0.055;
    constant float kMaxBrighteningGamma = 0.30;
    constant int kMaxWarps = 16;

    constant int kOvalStart = 0;
    constant int kOvalCount = 36;
    constant int kLeftEyeStart = 36;
    constant int kRightEyeStart = 52;
    constant int kEyeCount = 16;
    constant int kLeftBrowStart = 68;
    constant int kRightBrowStart = 78;
    constant int kBrowCount = 10;
    constant int kLipsStart = 88;
    constant int kLipsCount = 20;
    constant int kMouthStart = 108;
    constant int kMouthCount = 20;
    constant int kFloat4PerFace = 70;

    // Composite value indices (BeautyShaders.Value).
    constant int vFaceMask = 0;
    constant int vSmoothing = 1;
    constant int vTexture = 2;
    constant int vBrightening = 3;
    constant int vTone = 4;
    constant int vBlemish = 5;
    constant int vShine = 6;
    constant int vGlow = 7;
    constant int vEyes = 8;
    constant int vTeeth = 9;
    constant int vDarkCircles = 10;
    constant int vLipstick = 11;
    constant int vBlush = 12;
    constant int vEyebrows = 13;
    constant int vEyeshadow = 14;
    constant int vEyeliner = 15;
    constant int vLut = 16;

    struct BlurParams {
      float2 texelStep;
      float rangeSigma;
      float padding;
    };

    constexpr sampler linearClamp(coord::normalized, address::clamp_to_edge, filter::linear);

    static float2 uvFor(uint2 gid, uint width, uint height) {
      return (float2(gid) + 0.5) / float2(width, height);
    }

    kernel void edgePreservingBlur(texture2d<float, access::sample> input [[texture(0)]],
                                   texture2d<float, access::write> output [[texture(1)]],
                                   constant BlurParams &params [[buffer(0)]],
                                   uint2 gid [[thread_position_in_grid]]) {
      if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
      float2 uv = uvFor(gid, output.get_width(), output.get_height());
      float4 center = input.sample(linearClamp, uv);
      float rangeDenominator = 1.0 / (2.0 * params.rangeSigma * params.rangeSigma);
      float spatialDenominator = 1.0 / (2.0 * kSpatialSigma * kSpatialSigma);
      float3 weightedSum = center.rgb;
      float weightSum = 1.0;
      for (int i = 1; i <= kRadius; ++i) {
        float offset = float(i);
        float spatialWeight = exp(-offset * offset * spatialDenominator);
        float3 forward = input.sample(linearClamp, uv + params.texelStep * offset).rgb;
        float3 backward = input.sample(linearClamp, uv - params.texelStep * offset).rgb;
        float3 fd = forward - center.rgb;
        float3 bd = backward - center.rgb;
        float fw = spatialWeight * exp(-dot(fd, fd) * rangeDenominator);
        float bw = spatialWeight * exp(-dot(bd, bd) * rangeDenominator);
        weightedSum += forward * fw + backward * bw;
        weightSum += fw + bw;
      }
      output.write(float4(weightedSum / weightSum, center.a), gid);
    }

    kernel void gaussianBlur(texture2d<float, access::sample> input [[texture(0)]],
                             texture2d<float, access::write> output [[texture(1)]],
                             constant BlurParams &params [[buffer(0)]],
                             uint2 gid [[thread_position_in_grid]]) {
      if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
      float2 uv = uvFor(gid, output.get_width(), output.get_height());
      const float w0 = 0.2270270270;
      const float w1 = 0.3162162162;
      const float w2 = 0.0702702703;
      const float o1 = 1.3846153846;
      const float o2 = 3.2307692308;
      float4 sum = input.sample(linearClamp, uv) * w0;
      sum += input.sample(linearClamp, uv + params.texelStep * o1) * w1;
      sum += input.sample(linearClamp, uv - params.texelStep * o1) * w1;
      sum += input.sample(linearClamp, uv + params.texelStep * o2) * w2;
      sum += input.sample(linearClamp, uv - params.texelStep * o2) * w2;
      output.write(sum, gid);
    }

    kernel void faceWarp(texture2d<float, access::sample> input [[texture(0)]],
                         texture2d<float, access::write> output [[texture(1)]],
                         constant float4 *warpA [[buffer(0)]],
                         constant float4 *warpB [[buffer(1)]],
                         constant float2 &meta [[buffer(2)]],
                         uint2 gid [[thread_position_in_grid]]) {
      if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
      float2 p = uvFor(gid, output.get_width(), output.get_height());
      int count = int(meta.x);
      for (int i = 0; i < kMaxWarps && i < count; ++i) {
        float4 a = warpA[i];
        float4 b = warpB[i];
        float2 delta = p - a.xy;
        delta.x *= meta.y;
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
      output.write(input.sample(linearClamp, p), gid);
    }

    static float2 pointAt(constant float4 *points, int index) {
      float4 pair = points[index / 2];
      return (index % 2 == 0) ? pair.xy : pair.zw;
    }

    static bool insideRing(constant float4 *points, int start, int count, float2 origin, float scale,
                           float2 shift, float2 p) {
      float2 q = origin + (p - origin - shift) / scale;
      bool inside = false;
      int j = count - 1;
      for (int i = 0; i < count; ++i) {
        float2 a = pointAt(points, start + i);
        float2 b = pointAt(points, start + j);
        if (((a.y > q.y) != (b.y > q.y)) && (q.x < (b.x - a.x) * (q.y - a.y) / (b.y - a.y) + a.x)) {
          inside = !inside;
        }
        j = i;
      }
      return inside;
    }

    struct EyeRegions {
      float tight;
      float dilated;
      float underEye;
      float eyeshadow;
      float eyeliner;
    };

    static EyeRegions eyeRegion(constant float4 *points, int start, float4 box, float2 p, float verticalSign) {
      float2 up = float2(0.0, verticalSign * box.w);
      EyeRegions r;
      r.tight = insideRing(points, start, kEyeCount, box.xy, 1.0, float2(0.0), p) ? 1.0 : 0.0;
      r.dilated = insideRing(points, start, kEyeCount, box.xy, 1.45, float2(0.0), p) ? 1.0 : 0.0;
      float liner = insideRing(points, start, kEyeCount, box.xy, 1.25, float2(0.0), p) ? 1.0 : 0.0;
      float below = insideRing(points, start, kEyeCount, box.xy, 1.8, -up * 1.9, p) ? 1.0 : 0.0;
      float lid = insideRing(points, start, kEyeCount, box.xy, 1.9, up * 1.3, p) ? 1.0 : 0.0;
      float above = (p.y - box.y) * verticalSign > 0.0 ? 1.0 : 0.0;
      r.underEye = below * (1.0 - r.dilated) * (1.0 - above);
      r.eyeshadow = lid * (1.0 - liner) * above;
      r.eyeliner = liner * (1.0 - r.tight) * above;
      return r;
    }

    static float cheek(float4 ellipse, float2 p) {
      return 1.0 - smoothstep(0.0, 1.0, length((p - ellipse.xy) / ellipse.zw));
    }

    // faces: faceCount blocks of kFloat4PerFace float4 (64 packed points, then
    // leftEye, rightEye, mouth, leftCheek, rightCheek, bounds). Max-accumulated.
    kernel void faceMask(texture2d<float, access::write> outA [[texture(0)]],
                         texture2d<float, access::write> outB [[texture(1)]],
                         texture2d<float, access::write> outC [[texture(2)]],
                         constant float4 *faces [[buffer(0)]],
                         constant float2 &meta [[buffer(1)]],
                         uint2 gid [[thread_position_in_grid]]) {
      if (gid.x >= outA.get_width() || gid.y >= outA.get_height()) return;
      float2 p = uvFor(gid, outA.get_width(), outA.get_height());
      int faceCount = int(meta.x);
      float verticalSign = meta.y;
      float4 a = float4(0.0);
      float4 b = float4(0.0);
      float c = 0.0;
      for (int f = 0; f < faceCount; ++f) {
        constant float4 *points = faces + f * kFloat4PerFace;
        constant float4 *boxes = points + 64;
        float4 leftEyeBox = boxes[0];
        float4 rightEyeBox = boxes[1];
        float4 mouthBox = boxes[2];
        float4 bounds = boxes[5];
        if (p.x < bounds.x || p.y < bounds.y || p.x > bounds.z || p.y > bounds.w) continue;
        float inOval = insideRing(points, kOvalStart, kOvalCount, p, 1.0, float2(0.0), p) ? 1.0 : 0.0;
        EyeRegions left = eyeRegion(points, kLeftEyeStart, leftEyeBox, p, verticalSign);
        EyeRegions right = eyeRegion(points, kRightEyeStart, rightEyeBox, p, verticalSign);
        float brows = (insideRing(points, kLeftBrowStart, kBrowCount, p, 1.0, float2(0.0), p) ||
                       insideRing(points, kRightBrowStart, kBrowCount, p, 1.0, float2(0.0), p)) ? 1.0 : 0.0;
        float lipsOuter = insideRing(points, kLipsStart, kLipsCount, mouthBox.xy, 1.0, float2(0.0), p) ? 1.0 : 0.0;
        float lipsGuard = insideRing(points, kLipsStart, kLipsCount, mouthBox.xy, 1.12, float2(0.0), p) ? 1.0 : 0.0;
        float mouthInner = insideRing(points, kMouthStart, kMouthCount, mouthBox.xy, 1.0, float2(0.0), p) ? 1.0 : 0.0;
        float skin = inOval * (1.0 - max(left.dilated, right.dilated)) * (1.0 - brows) * (1.0 - lipsGuard);
        float blush = max(cheek(boxes[3], p), cheek(boxes[4], p)) * skin;
        a = max(a, float4(skin, max(left.tight, right.tight), mouthInner, max(left.underEye, right.underEye) * inOval));
        b = max(b, float4(lipsOuter * (1.0 - mouthInner), blush, brows,
                          max(left.eyeshadow, right.eyeshadow) * (1.0 - brows)));
        c = max(c, max(left.eyeliner, right.eyeliner));
      }
      outA.write(a, gid);
      outB.write(b, gid);
      outC.write(float4(c, 0.0, 0.0, 1.0), gid);
    }

    static float3 toYCbCr(float3 rgb) {
      return float3(dot(rgb, kLuma), 0.5 + dot(rgb, float3(-0.168736, -0.331264, 0.5)),
                    0.5 + dot(rgb, float3(0.5, -0.418688, -0.081312)));
    }

    static float3 toRgb(float3 ycc) {
      float cb = ycc.y - 0.5;
      float cr = ycc.z - 0.5;
      return float3(ycc.x + 1.402 * cr, ycc.x - 0.344136 * cb - 0.714136 * cr, ycc.x + 1.772 * cb);
    }

    static float skinLikelihood(float3 rgb) {
      float3 ycc = toYCbCr(rgb);
      float cbWeight = smoothstep(0.26, 0.30, ycc.y) * (1.0 - smoothstep(0.50, 0.54, ycc.y));
      float crWeight = smoothstep(0.50, 0.53, ycc.z) * (1.0 - smoothstep(0.68, 0.72, ycc.z));
      float lumaWeight = smoothstep(0.06, 0.16, ycc.x);
      return cbWeight * crWeight * lumaWeight;
    }

    static float3 gammaLift(float3 rgb, float amount) {
      return pow(clamp(rgb, 0.0, 1.0), float3(1.0 / (1.0 + amount)));
    }

    static float3 colorize(float3 rgb, float3 tint, float lumaShift) {
      float3 base = toYCbCr(rgb);
      float3 color = toYCbCr(tint);
      return clamp(toRgb(float3(base.x * (1.0 + lumaShift), color.y, color.z)), 0.0, 1.0);
    }

    static float3 lutLookup(texture2d<float, access::sample> lut, float3 rgb) {
      float blue = clamp(rgb.b, 0.0, 1.0) * 63.0;
      float2 tile1;
      tile1.y = floor(floor(blue) / 8.0);
      tile1.x = floor(blue) - tile1.y * 8.0;
      float2 tile2;
      tile2.y = floor(ceil(blue) / 8.0);
      tile2.x = ceil(blue) - tile2.y * 8.0;
      float2 inner = 0.5 / 512.0 + (0.125 - 1.0 / 512.0) * clamp(rgb.rg, 0.0, 1.0);
      float3 c1 = lut.sample(linearClamp, tile1 * 0.125 + inner).rgb;
      float3 c2 = lut.sample(linearClamp, tile2 * 0.125 + inner).rgb;
      return mix(c1, c2, fract(blue));
    }

    kernel void beautyComposite(texture2d<float, access::sample> original [[texture(0)]],
                                texture2d<float, access::sample> smoothedTexture [[texture(1)]],
                                texture2d<float, access::sample> baseBlurTexture [[texture(2)]],
                                texture2d<float, access::sample> maskATexture [[texture(3)]],
                                texture2d<float, access::sample> maskBTexture [[texture(4)]],
                                texture2d<float, access::sample> maskCTexture [[texture(5)]],
                                texture2d<float, access::sample> lut [[texture(6)]],
                                texture2d<float, access::write> output [[texture(7)]],
                                constant float *v [[buffer(0)]],
                                constant float4 *colors [[buffer(1)]],
                                uint2 gid [[thread_position_in_grid]]) {
      if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
      float2 uv = uvFor(gid, output.get_width(), output.get_height());
      float4 source = original.sample(linearClamp, uv);
      float3 smoothColor = smoothedTexture.sample(linearClamp, uv).rgb;
      float3 base = baseBlurTexture.sample(linearClamp, uv).rgb;
      float enabled = v[vFaceMask];
      float4 maskA = mix(float4(1.0, 0.0, 0.0, 0.0), maskATexture.sample(linearClamp, uv), enabled);
      float4 maskB = maskBTexture.sample(linearClamp, uv) * enabled;
      float maskC = maskCTexture.sample(linearClamp, uv).r * enabled;

      float skinColor = skinLikelihood(smoothColor);
      float skin = maskA.r * skinColor;

      float3 detail = source.rgb - smoothColor;
      float fineWeight = 1.0 - smoothstep(kFineDetailLow, kFineDetailHigh, abs(dot(detail, kLuma)));
      float3 retexturized = smoothColor + detail * fineWeight * v[vTexture];
      float3 result = mix(source.rgb, retexturized, v[vSmoothing] * kMaxSmoothingMix * skin);

      float spotDepth = dot(base - source.rgb, kLuma);
      float darkSpot = smoothstep(0.03, 0.08, spotDepth);
      result = mix(result, base, v[vBlemish] * darkSpot * skin);

      if (v[vTone] > 0.0) {
        float3 ycc = toYCbCr(result);
        float3 baseYcc = toYCbCr(base);
        ycc.yz = mix(ycc.yz, baseYcc.yz, v[vTone] * 0.85 * skin);
        result = clamp(toRgb(ycc), 0.0, 1.0);
      }

      float highlight = smoothstep(0.70, 0.92, dot(result, kLuma));
      result = mix(result, result * (1.0 - 0.22 * highlight), v[vShine] * skin);
      result = mix(result, gammaLift(result, kMaxBrighteningGamma * v[vBrightening]), skin);
      float3 bloom = smoothColor * smoothColor;
      result = mix(result, 1.0 - (1.0 - result) * (1.0 - bloom * 0.45), v[vGlow] * skin);

      float3 eyeLift = gammaLift(result, 0.45);
      eyeLift = mix(float3(dot(eyeLift, kLuma)), eyeLift, 1.12);
      result = mix(result, clamp(eyeLift, 0.0, 1.0), v[vEyes] * maskA.g);

      float3 teethYcc = toYCbCr(result);
      float teethLikelihood = smoothstep(0.25, 0.45, teethYcc.x);
      float3 whiter = clamp(toRgb(float3(min(teethYcc.x * 1.12, 1.0), mix(teethYcc.yz, float2(0.5), 0.75))), 0.0, 1.0);
      result = mix(result, whiter, v[vTeeth] * maskA.b * teethLikelihood);

      result = mix(result, gammaLift(result, 0.5), v[vDarkCircles] * maskA.a * skinColor);

      result = mix(result, colorize(result, colors[0].rgb, -0.05), v[vLipstick] * 0.85 * maskB.r);
      result = mix(result, result * mix(float3(1.0), colors[1].rgb, 0.55), v[vBlush] * 0.6 * maskB.g * skinColor);
      result = mix(result, result * colors[2].rgb * 1.15, v[vEyebrows] * 0.6 * maskB.b);
      result = mix(result, result * mix(float3(1.0), colors[3].rgb, 0.8), v[vEyeshadow] * 0.7 * maskB.a);
      result = mix(result, colors[4].rgb, v[vEyeliner] * 0.85 * maskC);

      if (v[vLut] > 0.0) {
        result = mix(result, lutLookup(lut, result), v[vLut]);
      }
      output.write(float4(clamp(result, 0.0, 1.0), source.a), gid);
    }
    """
}
