import 'package:flutter/foundation.dart';

import 'beauty_adjustments.dart';
import 'color_filters.dart';

enum BuiltInPreset { natural, soft, glow, everydayMakeup, eveningMakeup }

@immutable
class BeautyPreset {
  const BeautyPreset({required this.id, required this.adjustments, this.name, this.builtIn});

  final String id;

  /// User-given name; null for built-in presets (localized via [builtIn]).
  final String? name;
  final BuiltInPreset? builtIn;
  final BeautyAdjustments adjustments;

  bool get isUserPreset => builtIn == null;

  static final List<BeautyPreset> builtIns = [
    BeautyPreset(
      id: 'builtin.natural',
      builtIn: BuiltInPreset.natural,
      adjustments: BeautyAdjustments({
        BeautyEffect.skinSmoothing: 35,
        BeautyEffect.texturePreservation: 70,
        BeautyEffect.skinBrightening: 10,
        BeautyEffect.blemishReduction: 40,
        BeautyEffect.skinTone: 20,
      }, filter: FilterId.natural),
    ),
    BeautyPreset(
      id: 'builtin.soft',
      builtIn: BuiltInPreset.soft,
      adjustments: BeautyAdjustments({
        BeautyEffect.skinSmoothing: 65,
        BeautyEffect.texturePreservation: 45,
        BeautyEffect.skinBrightening: 20,
        BeautyEffect.blemishReduction: 60,
        BeautyEffect.skinTone: 40,
        BeautyEffect.darkCircles: 40,
        BeautyEffect.shineReduction: 30,
      }, filter: FilterId.soft),
    ),
    BeautyPreset(
      id: 'builtin.glow',
      builtIn: BuiltInPreset.glow,
      adjustments: BeautyAdjustments({
        BeautyEffect.skinSmoothing: 50,
        BeautyEffect.texturePreservation: 55,
        BeautyEffect.skinBrightening: 45,
        BeautyEffect.glow: 50,
        BeautyEffect.eyeBrightening: 30,
      }, filter: FilterId.glow),
    ),
    BeautyPreset(
      id: 'builtin.everydayMakeup',
      builtIn: BuiltInPreset.everydayMakeup,
      adjustments: BeautyAdjustments(
        {
          BeautyEffect.skinSmoothing: 35,
          BeautyEffect.texturePreservation: 65,
          BeautyEffect.lipstick: 35,
          BeautyEffect.blush: 25,
          BeautyEffect.eyebrows: 30,
          BeautyEffect.eyeshadow: 20,
          BeautyEffect.eyeliner: 15,
        },
        colors: {MakeupItem.lipstick: 0xFFC97B6E, MakeupItem.blush: 0xFFF0A08C, MakeupItem.eyeshadow: 0xFFB48A76},
      ),
    ),
    BeautyPreset(
      id: 'builtin.eveningMakeup',
      builtIn: BuiltInPreset.eveningMakeup,
      adjustments: BeautyAdjustments(
        {
          BeautyEffect.skinSmoothing: 45,
          BeautyEffect.texturePreservation: 55,
          BeautyEffect.lipstick: 70,
          BeautyEffect.blush: 30,
          BeautyEffect.eyebrows: 45,
          BeautyEffect.eyeshadow: 50,
          BeautyEffect.eyeliner: 60,
        },
        colors: {MakeupItem.lipstick: 0xFF9E2B3A, MakeupItem.eyeshadow: 0xFF7D5A78, MakeupItem.eyebrows: 0xFF2E221C},
        filter: FilterId.portrait,
      ),
    ),
  ];

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'adjustments': adjustments.toJson()};

  static BeautyPreset? tryFromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final name = json['name'];
    final adjustments = json['adjustments'];
    if (id is! String || name is! String || adjustments is! Map<String, Object?>) return null;
    return BeautyPreset(id: id, name: name, adjustments: BeautyAdjustments.fromJson(adjustments));
  }
}
