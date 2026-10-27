import 'package:flutter/foundation.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

/// Effects that the engine currently implements. Extend together with the
/// native pipelines; the UI renders one 0..100 slider per entry.
enum BeautyEffect { skinSmoothing, texturePreservation, skinBrightening }

/// Immutable 0..100 values for every [BeautyEffect].
@immutable
class BeautyAdjustments {
  const BeautyAdjustments._(this._values);

  factory BeautyAdjustments(Map<BeautyEffect, int> values) => BeautyAdjustments._({
    for (final effect in BeautyEffect.values) effect: _clamp(values[effect] ?? defaults.valueOf(effect)),
  });

  static const minValue = 0;
  static const maxValue = 100;

  /// Starting point: effects off, texture preservation at the natural default.
  static const defaults = BeautyAdjustments._({
    BeautyEffect.skinSmoothing: 0,
    BeautyEffect.texturePreservation: 50,
    BeautyEffect.skinBrightening: 0,
  });

  final Map<BeautyEffect, int> _values;

  int valueOf(BeautyEffect effect) => _values[effect] ?? 0;

  BeautyAdjustments withValue(BeautyEffect effect, int value) =>
      BeautyAdjustments._({..._values, effect: _clamp(value)});

  BeautyParameters toEngineParameters() => BeautyParameters(
    skinSmoothing: valueOf(BeautyEffect.skinSmoothing) / maxValue,
    texturePreservation: valueOf(BeautyEffect.texturePreservation) / maxValue,
    skinBrightening: valueOf(BeautyEffect.skinBrightening) / maxValue,
  );

  Map<String, int> toJson() => {for (final entry in _values.entries) entry.key.name: entry.value};

  /// Unknown keys are ignored and missing keys fall back to [defaults], so
  /// stored presets survive adding or removing effects.
  factory BeautyAdjustments.fromJson(Map<String, Object?> json) {
    final values = <BeautyEffect, int>{};
    for (final effect in BeautyEffect.values) {
      final raw = json[effect.name];
      if (raw is num) values[effect] = raw.round();
    }
    return BeautyAdjustments(values);
  }

  static int _clamp(int value) => value.clamp(minValue, maxValue);

  @override
  bool operator ==(Object other) =>
      other is BeautyAdjustments && BeautyEffect.values.every((e) => other.valueOf(e) == valueOf(e));

  @override
  int get hashCode => Object.hashAll(BeautyEffect.values.map(valueOf));

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

  List<BeautyAdjustments> _pushed(BeautyAdjustments value) {
    final trimmed = history.length >= maxHistory ? history.sublist(history.length - maxHistory + 1) : history;
    return [...trimmed, value];
  }

  BeautyEditorState undo() {
    if (!canUndo) return this;
    return BeautyEditorState(current: history.last, history: history.sublist(0, history.length - 1));
  }

  BeautyEditorState reset() => commit(BeautyAdjustments.defaults);
}
