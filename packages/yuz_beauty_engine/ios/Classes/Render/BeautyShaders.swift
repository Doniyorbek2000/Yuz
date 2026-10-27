// Metal compute kernels. The maths is a line-by-line port of the GLSL ES 3.00
// shaders in android/src/main/assets/yuz_beauty_engine/shaders (verified
// headlessly by tools/shader-tests); constants must stay identical.
//
// Compiled at runtime with MTLDevice.makeLibrary(source:) so the pod does not
// depend on how CocoaPods packages .metal files into a metallib.
enum BeautyShaders {
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

    constant int kOvalPoints = 36;
    constant int kEyePoints = 16;
    constant int kBrowPoints = 10;
    constant int kLipPoints = 20;
    constant int kPointsPerFace = 108;

    struct BlurParams {
      float2 texelStep;
      float rangeSigma;
      float padding;
    };

    struct MaskParams {
      uint faceCount;
      uint padding;
    };

    struct CompositeParams {
      float skinSmoothing;
      float texturePreservation;
      float skinBrightening;
      float faceMaskEnabled;
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
        float3 forwardDelta = forward - center.rgb;
        float3 backwardDelta = backward - center.rgb;
        float forwardWeight = spatialWeight * exp(-dot(forwardDelta, forwardDelta) * rangeDenominator);
        float backwardWeight = spatialWeight * exp(-dot(backwardDelta, backwardDelta) * rangeDenominator);
        weightedSum += forward * forwardWeight + backward * backwardWeight;
        weightSum += forwardWeight + backwardWeight;
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

    static bool insidePolygon(constant float2 *points, int count, float2 p) {
      bool inside = false;
      int j = count - 1;
      for (int i = 0; i < count; ++i) {
        float2 a = points[i];
        float2 b = points[j];
        if (((a.y > p.y) != (b.y > p.y)) && (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x)) {
          inside = !inside;
        }
        j = i;
      }
      return inside;
    }

    kernel void faceMask(texture2d<float, access::write> output [[texture(0)]],
                         constant float2 *points [[buffer(0)]],
                         constant MaskParams &params [[buffer(1)]],
                         uint2 gid [[thread_position_in_grid]]) {
      if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
      float2 p = uvFor(gid, output.get_width(), output.get_height());
      float value = 0.0;
      for (uint face = 0; face < params.faceCount; ++face) {
        constant float2 *base = points + face * kPointsPerFace;
        constant float2 *oval = base;
        constant float2 *leftEye = oval + kOvalPoints;
        constant float2 *rightEye = leftEye + kEyePoints;
        constant float2 *leftBrow = rightEye + kEyePoints;
        constant float2 *rightBrow = leftBrow + kBrowPoints;
        constant float2 *lips = rightBrow + kBrowPoints;
        bool excluded = insidePolygon(leftEye, kEyePoints, p) || insidePolygon(rightEye, kEyePoints, p)
          || insidePolygon(leftBrow, kBrowPoints, p) || insidePolygon(rightBrow, kBrowPoints, p)
          || insidePolygon(lips, kLipPoints, p);
        if (insidePolygon(oval, kOvalPoints, p) && !excluded) value = 1.0;
      }
      output.write(float4(value, value, value, 1.0), gid);
    }

    static float skinLikelihood(float3 rgb) {
      float y = dot(rgb, kLuma);
      float cb = 0.5 + dot(rgb, float3(-0.168736, -0.331264, 0.5));
      float cr = 0.5 + dot(rgb, float3(0.5, -0.418688, -0.081312));
      float cbWeight = smoothstep(0.26, 0.30, cb) * (1.0 - smoothstep(0.50, 0.54, cb));
      float crWeight = smoothstep(0.50, 0.53, cr) * (1.0 - smoothstep(0.68, 0.72, cr));
      float lumaWeight = smoothstep(0.06, 0.16, y);
      return cbWeight * crWeight * lumaWeight;
    }

    kernel void beautyComposite(texture2d<float, access::sample> original [[texture(0)]],
                                texture2d<float, access::sample> smoothed [[texture(1)]],
                                texture2d<float, access::sample> faceMaskTexture [[texture(2)]],
                                texture2d<float, access::write> output [[texture(3)]],
                                constant CompositeParams &params [[buffer(0)]],
                                uint2 gid [[thread_position_in_grid]]) {
      if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
      float2 uv = uvFor(gid, output.get_width(), output.get_height());
      float4 source = original.sample(linearClamp, uv);
      float3 smoothColor = smoothed.sample(linearClamp, uv).rgb;
      float faceValue = mix(1.0, faceMaskTexture.sample(linearClamp, uv).r, params.faceMaskEnabled);
      float mask = faceValue * skinLikelihood(smoothColor);

      float3 detail = source.rgb - smoothColor;
      float detailMagnitude = abs(dot(detail, kLuma));
      float fineWeight = 1.0 - smoothstep(kFineDetailLow, kFineDetailHigh, detailMagnitude);
      float3 retexturized = smoothColor + detail * fineWeight * params.texturePreservation;
      float3 result = mix(source.rgb, retexturized, params.skinSmoothing * kMaxSmoothingMix * mask);

      float3 lifted = pow(clamp(result, 0.0, 1.0), float3(1.0 / (1.0 + kMaxBrighteningGamma * params.skinBrightening)));
      result = mix(result, lifted, mask);
      output.write(float4(clamp(result, 0.0, 1.0), source.a), gid);
    }
    """
}
