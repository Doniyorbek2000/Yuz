import 'package:flutter/foundation.dart';

import 'beauty_adjustments.dart';

enum BuiltInPreset { natural, soft, glow }

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
      }),
    ),
    BeautyPreset(
      id: 'builtin.soft',
      builtIn: BuiltInPreset.soft,
      adjustments: BeautyAdjustments({
        BeautyEffect.skinSmoothing: 65,
        BeautyEffect.texturePreservation: 45,
        BeautyEffect.skinBrightening: 20,
      }),
    ),
    BeautyPreset(
      id: 'builtin.glow',
      builtIn: BuiltInPreset.glow,
      adjustments: BeautyAdjustments({
        BeautyEffect.skinSmoothing: 50,
        BeautyEffect.texturePreservation: 55,
        BeautyEffect.skinBrightening: 45,
      }),
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
