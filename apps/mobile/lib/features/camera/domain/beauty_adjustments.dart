import 'package:flutter/foundation.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

import 'color_filters.dart';

enum BeautyCategory { skin, face, reshape, makeup }

/// Every 0..100 control. The engine implements each one natively on GPU.
enum BeautyEffect {
  skinSmoothing(BeautyCategory.skin),
  texturePreservation(BeautyCategory.skin, defaultValue: 50),
  skinBrightening(BeautyCategory.skin),
  skinTone(BeautyCategory.skin),
  blemishReduction(BeautyCategory.skin),
  shineReduction(BeautyCategory.skin),
  glow(BeautyCategory.skin),
  eyeBrightening(BeautyCategory.face, requiresFace: true),
  teethWhitening(BeautyCategory.face, requiresFace: true),
  darkCircles(BeautyCategory.face, requiresFace: true),
  faceSlim(BeautyCategory.reshape, requiresFace: true),
  jawline(BeautyCategory.reshape, requiresFace: true),
  chin(BeautyCategory.reshape, requiresFace: true),
  eyeEnlarge(BeautyCategory.reshape, requiresFace: true),
  noseSlim(BeautyCategory.reshape, requiresFace: true),
  lips(BeautyCategory.reshape, requiresFace: true),
  forehead(BeautyCategory.reshape, requiresFace: true),
  lipstick(BeautyCategory.makeup, requiresFace: true, makeupItem: MakeupItem.lipstick),
  blush(BeautyCategory.makeup, requiresFace: true, makeupItem: MakeupItem.blush),
  eyebrows(BeautyCategory.makeup, requiresFace: true, makeupItem: MakeupItem.eyebrows),
  eyeshadow(BeautyCategory.makeup, requiresFace: true, makeupItem: MakeupItem.eyeshadow),
  eyeliner(BeautyCategory.makeup, requiresFace: true, makeupItem: MakeupItem.eyeliner),
  makeupIntensity(BeautyCategory.makeup, defaultValue: 100, requiresFace: true),

  /// Strength of the selected colour filter.
  filterIntensity(null, defaultValue: 80);

  const BeautyEffect(this.category, {this.defaultValue = 0, this.requiresFace = false, this.makeupItem});

  /// null for controls that live outside the beauty categories (filter).
  final BeautyCategory? category;
  final int defaultValue;

  /// Needs MediaPipe landmarks; unavailable in colour-only mode.
  final bool requiresFace;
  final MakeupItem? makeupItem;

  static List<BeautyEffect> inCategory(BeautyCategory category) =>
      values.where((effect) => effect.category == category).toList(growable: false);
}

enum MakeupItem {
  lipstick([0xFFB4404F, 0xFFD0606E, 0xFF9E2B3A, 0xFFC97B6E, 0xFF8A3B52, 0xFFE07A6A]),
  blush([0xFFE8838A, 0xFFF0A08C, 0xFFD9707F, 0xFFE9A0B0]),
  eyebrows([0xFF4A3426, 0xFF2E221C, 0xFF6B4A35, 0xFF1C1A19]),
  eyeshadow([0xFF9A6B5C, 0xFFB48A76, 0xFF7D5A78, 0xFF5E6B7D, 0xFFC4956A]),
  eyeliner([0xFF1C1614, 0xFF3B2A20, 0xFF1F2A44]);

  const MakeupItem(this.palette);

  /// Curated 0xAARRGGBB shades; the first one is the default.
  final List<int> palette;

  int get defaultColor => palette.first;
}

/// The complete look: every 0..100 control, the colour filter and makeup
/// shades. Immutable; used for live state, undo history and presets.
@immutable
class BeautyAdjustments {
  const BeautyAdjustments._(this._values, this.filter, this._colors);

  factory BeautyAdjustments(
    Map<BeautyEffect, int> values, {
    FilterId filter = FilterId.none,
    Map<MakeupItem, int> colors = const {},
  }) => BeautyAdjustments._(
    {for (final effect in BeautyEffect.values) effect: _clamp(values[effect] ?? effect.defaultValue)},
    filter,
    {for (final item in MakeupItem.values) item: colors[item] ?? item.defaultColor},
  );

  static const minValue = 0;
  static const maxValue = 100;

  static final BeautyAdjustments defaults = BeautyAdjustments(const {});

  final Map<BeautyEffect, int> _values;
  final FilterId filter;
  final Map<MakeupItem, int> _colors;

  int valueOf(BeautyEffect effect) => _values[effect] ?? effect.defaultValue;

  int colorOf(MakeupItem item) => _colors[item] ?? item.defaultColor;

  BeautyAdjustments withValue(BeautyEffect effect, int value) =>
      BeautyAdjustments._({..._values, effect: _clamp(value)}, filter, _colors);

  BeautyAdjustments withFilter(FilterId next) => BeautyAdjustments._(_values, next, _colors);

  BeautyAdjustments withColor(MakeupItem item, int color) =>
      BeautyAdjustments._(_values, filter, {..._colors, item: color});

  /// True when any face-dependent effect (reshape, makeup, eye/teeth) is on.
  bool get usesFaceEffects => BeautyEffect.values.any(
    (effect) => effect.requiresFace && effect != BeautyEffect.makeupIntensity && valueOf(effect) > 0,
  );

  BeautyParameters toEngineParameters() {
    double unit(BeautyEffect effect) => valueOf(effect) / maxValue;
    return BeautyParameters(
      skinSmoothing: unit(BeautyEffect.skinSmoothing),
      texturePreservation: unit(BeautyEffect.texturePreservation),
      skinBrightening: unit(BeautyEffect.skinBrightening),
      skinTone: unit(BeautyEffect.skinTone),
      blemishReduction: unit(BeautyEffect.blemishReduction),
      shineReduction: unit(BeautyEffect.shineReduction),
      glow: unit(BeautyEffect.glow),
      eyeBrightening: unit(BeautyEffect.eyeBrightening),
      teethWhitening: unit(BeautyEffect.teethWhitening),
      darkCircles: unit(BeautyEffect.darkCircles),
      faceSlim: unit(BeautyEffect.faceSlim),
      jawline: unit(BeautyEffect.jawline),
      chin: unit(BeautyEffect.chin),
      eyeEnlarge: unit(BeautyEffect.eyeEnlarge),
      noseSlim: unit(BeautyEffect.noseSlim),
      lips: unit(BeautyEffect.lips),
      forehead: unit(BeautyEffect.forehead),
      lipstick: unit(BeautyEffect.lipstick),
      blush: unit(BeautyEffect.blush),
      eyebrows: unit(BeautyEffect.eyebrows),
      eyeshadow: unit(BeautyEffect.eyeshadow),
      eyeliner: unit(BeautyEffect.eyeliner),
      makeupIntensity: unit(BeautyEffect.makeupIntensity),
      lipstickColor: colorOf(MakeupItem.lipstick),
      blushColor: colorOf(MakeupItem.blush),
      eyebrowColor: colorOf(MakeupItem.eyebrows),
      eyeshadowColor: colorOf(MakeupItem.eyeshadow),
      eyelinerColor: colorOf(MakeupItem.eyeliner),
      filterIntensity: filter == FilterId.none ? 0 : unit(BeautyEffect.filterIntensity),
    );
  }

  Map<String, Object> toJson() => {
    for (final entry in _values.entries) entry.key.name: entry.value,
    'filter': filter.name,
    'colors': {for (final entry in _colors.entries) entry.key.name: entry.value},
  };

  /// Tolerant: unknown keys are ignored, missing or malformed keys fall back
  /// to defaults, so stored presets survive adding or removing controls.
  factory BeautyAdjustments.fromJson(Map<String, Object?> json) {
    final values = <BeautyEffect, int>{};
    for (final effect in BeautyEffect.values) {
      final raw = json[effect.name];
      if (raw is num) values[effect] = raw.round();
    }
    final filterName = json['filter'];
    final filter = FilterId.values.where((f) => f.name == filterName).firstOrNull ?? FilterId.none;
    final colors = <MakeupItem, int>{};
    final rawColors = json['colors'];
    if (rawColors is Map) {
      for (final item in MakeupItem.values) {
        final raw = rawColors[item.name];
        if (raw is int) colors[item] = raw;
      }
    }
    return BeautyAdjustments(values, filter: filter, colors: colors);
  }

  static int _clamp(int value) => value.clamp(minValue, maxValue);

  @override
  bool operator ==(Object other) =>
      other is BeautyAdjustments &&
      other.filter == filter &&
      BeautyEffect.values.every((e) => other.valueOf(e) == valueOf(e)) &&
      MakeupItem.values.every((i) => other.colorOf(i) == colorOf(i));

  @override
  int get hashCode => Object.hash(
    filter,
    Object.hashAll(BeautyEffect.values.map(valueOf)),
    Object.hashAll(MakeupItem.values.map(colorOf)),
  );

  @override
  String toString() => 'BeautyAdjustments(${toJson()})';
}

/// Adjustments plus a bounded undo history.
@immutable
class BeautyEditorState {
  const BeautyEditorState({required this.current, this.history = const []});

  static const maxHistory = 50;

  final BeautyAdjustments current;
  final List<BeautyAdjustments> history;

  bool get canUndo => history.isNotEmpty;

  bool get isDefault => current == BeautyAdjustments.defaults;

  /// Records [next] as a new undo step (no-op when nothing changed).
  BeautyEditorState commit(BeautyAdjustments next) {
    if (next == current) return this;
    return BeautyEditorState(current: next, history: _pushed(current));
  }

  /// Starts a continuous edit (slider drag): the current value becomes one
  /// undo step, followed by any number of [preview] updates.
  BeautyEditorState checkpoint() => BeautyEditorState(current: current, history: _pushed(current));

  /// Live update during a continuous edit; does not create undo steps.
  BeautyEditorState preview(BeautyAdjustments next) => BeautyEditorState(current: next, history: history);

  /// Ends a continuous edit, dropping its checkpoint if nothing changed.
  BeautyEditorState finalizeEdit() {
    if (history.isNotEmpty && history.last == current) {
      return BeautyEditorState(current: current, history: history.sublist(0, history.length - 1));
    }
    return this;
  }

  BeautyEditorState undo() {
    if (!canUndo) return this;
    return BeautyEditorState(current: history.last, history: history.sublist(0, history.length - 1));
  }

  BeautyEditorState reset() => commit(BeautyAdjustments.defaults);

  List<BeautyAdjustments> _pushed(BeautyAdjustments value) {
    final trimmed = history.length >= maxHistory ? history.sublist(history.length - maxHistory + 1) : history;
    return [...trimmed, value];
  }
}
