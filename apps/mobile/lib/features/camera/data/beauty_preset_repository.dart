import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import '../domain/beauty_adjustments.dart';
import '../domain/beauty_preset.dart';

/// Local persistence of user presets and the last-used adjustments.
/// Corrupt entries are skipped rather than crashing the camera.
class BeautyPresetRepository {
  BeautyPresetRepository(this._preferences, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const maxUserPresets = 30;

  final SharedPreferences _preferences;
  final DateTime Function() _clock;

  List<BeautyPreset> loadUserPresets() {
    final raw = _preferences.getString(PreferenceKeys.beautyPresets);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map(BeautyPreset.tryFromJson).whereType<BeautyPreset>().toList(growable: false);
    } on FormatException catch (error) {
      debugPrint('Discarding corrupt presets: $error');
      return const [];
    }
  }

  Future<BeautyPreset> saveUserPreset(String name, BeautyAdjustments adjustments) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'must not be empty');
    final preset = BeautyPreset(
      id: 'user.${_clock().microsecondsSinceEpoch}',
      name: trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed,
      adjustments: adjustments,
    );
    final presets = [...loadUserPresets(), preset];
    final bounded = presets.length > maxUserPresets ? presets.sublist(presets.length - maxUserPresets) : presets;
    await _write(bounded);
    return preset;
  }

  Future<void> deleteUserPreset(String id) async {
    await _write(loadUserPresets().where((preset) => preset.id != id).toList());
  }

  BeautyAdjustments loadLastAdjustments() {
    final raw = _preferences.getString(PreferenceKeys.lastBeautyAdjustments);
    if (raw == null) return BeautyAdjustments.defaults;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? BeautyAdjustments.fromJson(decoded) : BeautyAdjustments.defaults;
    } on FormatException {
      return BeautyAdjustments.defaults;
    }
  }

  Future<void> saveLastAdjustments(BeautyAdjustments adjustments) =>
      _preferences.setString(PreferenceKeys.lastBeautyAdjustments, jsonEncode(adjustments.toJson()));

  Future<void> _write(List<BeautyPreset> presets) => _preferences.setString(
    PreferenceKeys.beautyPresets,
    jsonEncode(presets.map((preset) => preset.toJson()).toList()),
  );
}

final beautyPresetRepositoryProvider = Provider<BeautyPresetRepository>(
  (ref) => BeautyPresetRepository(ref.watch(sharedPreferencesProvider)),
);
