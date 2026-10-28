import 'generated/beauty_engine_api.g.dart';

/// Default makeup colours (0xAARRGGBB), identical to MakeupColors.kt/.swift.
abstract final class DefaultMakeupColors {
  static const lipstick = 0xFFB4404F;
  static const blush = 0xFFE8838A;
  static const eyebrow = 0xFF4A3426;
  static const eyeshadow = 0xFF9A6B5C;
  static const eyeliner = 0xFF1C1614;
}

/// Parameters with every effect off (texture preservation at its natural
/// default and makeup intensity at 100%), the engine's identity.
BeautyParameters neutralBeautyParameters() => BeautyParameters(
  skinSmoothing: 0,
  texturePreservation: 0.5,
  skinBrightening: 0,
  skinTone: 0,
  blemishReduction: 0,
  shineReduction: 0,
  glow: 0,
  eyeBrightening: 0,
  teethWhitening: 0,
  darkCircles: 0,
  faceSlim: 0,
  jawline: 0,
  chin: 0,
  eyeEnlarge: 0,
  noseSlim: 0,
  lips: 0,
  forehead: 0,
  lipstick: 0,
  blush: 0,
  eyebrows: 0,
  eyeshadow: 0,
  eyeliner: 0,
  makeupIntensity: 1,
  lipstickColor: DefaultMakeupColors.lipstick,
  blushColor: DefaultMakeupColors.blush,
  eyebrowColor: DefaultMakeupColors.eyebrow,
  eyeshadowColor: DefaultMakeupColors.eyeshadow,
  eyelinerColor: DefaultMakeupColors.eyeliner,
  filterIntensity: 0,
);
