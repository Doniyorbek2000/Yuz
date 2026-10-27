import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_mobile/core/storage/preferences.dart';
import 'package:yuz_mobile/features/camera/data/beauty_preset_repository.dart';
import 'package:yuz_mobile/features/camera/domain/beauty_adjustments.dart';

import '../helpers/test_app.dart';

void main() {
  test('saves, lists and deletes user presets', () async {
    var tick = 0;
    final repository = BeautyPresetRepository(
      await mockPreferences(),
      clock: () => DateTime.fromMicrosecondsSinceEpoch(++tick),
    );
    final first = await repository.saveUserPreset('  Evening  ', BeautyAdjustments({BeautyEffect.skinSmoothing: 60}));
    await repository.saveUserPreset('Day', BeautyAdjustments.defaults);

    final presets = repository.loadUserPresets();
    expect(presets.map((p) => p.name), ['Evening', 'Day']);
    expect(presets.first.adjustments.valueOf(BeautyEffect.skinSmoothing), 60);

    await repository.deleteUserPreset(first.id);
    expect(repository.loadUserPresets().map((p) => p.name), ['Day']);
  });

  test('rejects empty names', () async {
    final repository = BeautyPresetRepository(await mockPreferences());
    expect(() => repository.saveUserPreset('   ', BeautyAdjustments.defaults), throwsArgumentError);
  });

  test('keeps at most maxUserPresets', () async {
    var tick = 0;
    final repository = BeautyPresetRepository(
      await mockPreferences(),
      clock: () => DateTime.fromMicrosecondsSinceEpoch(++tick),
    );
    for (var i = 0; i < BeautyPresetRepository.maxUserPresets + 5; i++) {
      await repository.saveUserPreset('p$i', BeautyAdjustments.defaults);
    }
    final presets = repository.loadUserPresets();
    expect(presets.length, BeautyPresetRepository.maxUserPresets);
    expect(presets.first.name, 'p5');
  });

  test('corrupt storage yields empty presets and default adjustments', () async {
    final repository = BeautyPresetRepository(
      await mockPreferences({PreferenceKeys.beautyPresets: '{not json', PreferenceKeys.lastBeautyAdjustments: '[1,2]'}),
    );
    expect(repository.loadUserPresets(), isEmpty);
    expect(repository.loadLastAdjustments(), BeautyAdjustments.defaults);
  });

  test('persists the last adjustments', () async {
    final preferences = await mockPreferences();
    final adjustments = BeautyAdjustments({BeautyEffect.skinBrightening: 33});
    await BeautyPresetRepository(preferences).saveLastAdjustments(adjustments);
    expect(BeautyPresetRepository(preferences).loadLastAdjustments(), adjustments);
  });
}
