import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() with the loaded instance (and in tests with a mock).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('sharedPreferencesProvider must be overridden'),
);

abstract final class PreferenceKeys {
  static const onboardingCompleted = 'onboarding.completed';
  static const localeCode = 'settings.locale';
  static const performanceOverlay = 'settings.performanceOverlay';
  static const beautyPresets = 'beauty.presets.v1';
  static const lastBeautyAdjustments = 'beauty.last.v1';
}

class OnboardingCompletedNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(PreferenceKeys.onboardingCompleted) ?? false;

  Future<void> set(bool completed) async {
    await ref.read(sharedPreferencesProvider).setBool(PreferenceKeys.onboardingCompleted, completed);
    state = completed;
  }
}

final onboardingCompletedProvider = NotifierProvider<OnboardingCompletedNotifier, bool>(
  OnboardingCompletedNotifier.new,
);

/// null = follow the system locale.
class LocaleNotifier extends Notifier<Locale?> {
  static const supportedCodes = ['uz', 'ru', 'en'];

  @override
  Locale? build() {
    final code = ref.watch(sharedPreferencesProvider).getString(PreferenceKeys.localeCode);
    return code != null && supportedCodes.contains(code) ? Locale(code) : null;
  }

  Future<void> select(String? code) async {
    final preferences = ref.read(sharedPreferencesProvider);
    if (code == null) {
      await preferences.remove(PreferenceKeys.localeCode);
      state = null;
    } else {
      if (!supportedCodes.contains(code)) throw ArgumentError.value(code, 'code', 'unsupported locale');
      await preferences.setString(PreferenceKeys.localeCode, code);
      state = Locale(code);
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

class PerformanceOverlayNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(PreferenceKeys.performanceOverlay) ?? false;

  Future<void> set(bool enabled) async {
    await ref.read(sharedPreferencesProvider).setBool(PreferenceKeys.performanceOverlay, enabled);
    state = enabled;
  }
}

final performanceOverlayProvider = NotifierProvider<PerformanceOverlayNotifier, bool>(PerformanceOverlayNotifier.new);
