import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_mobile/app/app.dart';
import 'package:yuz_mobile/app/router.dart';
import 'package:yuz_mobile/core/storage/preferences.dart';
import 'package:yuz_mobile/features/camera/application/beauty_camera_controller.dart';
import 'package:yuz_mobile/features/camera/domain/beauty_adjustments.dart';
import 'package:yuz_mobile/features/camera/domain/color_filters.dart';
import 'package:yuz_mobile/features/camera/presentation/beauty_controls_panel.dart';
import 'package:yuz_mobile/features/catalog/feature_catalog.dart';
import 'package:yuz_mobile/features/permissions/camera_permission_service.dart';
import 'package:yuz_mobile/l10n/generated/app_localizations.dart';

import '../helpers/test_app.dart';

Future<ProviderContainer> pumpRoute(
  WidgetTester tester,
  String location, {
  Map<String, Object> preferences = const {PreferenceKeys.onboardingCompleted: true},
  CameraPermissionState permission = CameraPermissionState.granted,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = await createContainer(preferences: preferences, permission: permission);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: YuzApp(router: testRouter(location)),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('home lists every catalogued feature with its honest status', (tester) async {
    await pumpRoute(tester, '/home');
    expect(find.text('Create your look'), findsOneWidget);
    expect(find.text('Beauty camera'), findsOneWidget);
    expect(find.text('Preview'), findsWidgets);

    await tester.scrollUntilVisible(find.text('Help'), 300);
    expect(find.text('Blocked'), findsWidgets);
    expect(find.text('Ready'), findsWidgets);
  });

  testWidgets('a blocked feature opens the honest unavailable screen', (tester) async {
    await pumpRoute(tester, '/home');
    await tester.scrollUntilVisible(find.text('AI photoshoot'), 200);
    await tester.tap(find.text('AI photoshoot'));
    await tester.pumpAndSettle();
    expect(find.text('Not available yet'), findsOneWidget);
    expect(find.textContaining('generative AI model service'), findsOneWidget);
  });

  testWidgets('home does not overflow on a small phone', (tester) async {
    await pumpRoute(tester, '/home', size: const Size(320, 568));
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching language to Uzbek re-localizes the UI', (tester) async {
    final container = await pumpRoute(tester, '/settings');
    await tester.tap(find.byKey(const ValueKey('locale-uz')));
    await tester.pumpAndSettle();
    expect(find.text('Sozlamalar'), findsOneWidget);
    expect(container.read(localeProvider), const Locale('uz'));
  });

  testWidgets('switching language to Russian re-localizes the UI', (tester) async {
    await pumpRoute(tester, '/settings');
    await tester.tap(find.byKey(const ValueKey('locale-ru')));
    await tester.pumpAndSettle();
    expect(find.text('Настройки'), findsOneWidget);
  });

  testWidgets('onboarding completes and continues to the permission screen', (tester) async {
    final container = await pumpRoute(tester, '/onboarding', preferences: const {});
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(container.read(onboardingCompletedProvider), isTrue);
    expect(find.text('Camera access'), findsOneWidget);
  });

  testWidgets('permanently denied camera permission offers system settings', (tester) async {
    await pumpRoute(tester, '/permissions?next=/home', permission: CameraPermissionState.permanentlyDenied);
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.textContaining('blocked'), findsOneWidget);
  });

  testWidgets('permission screen rejects unknown continuation targets', (tester) async {
    await pumpRoute(tester, '/permissions?next=https://evil.example', permission: CameraPermissionState.granted);
    await tester.tap(find.text('Allow camera'));
    await tester.pumpAndSettle();
    expect(find.text('Create your look'), findsOneWidget);
  });

  testWidgets('every feature label is localized in all languages', (tester) async {
    for (final locale in const [Locale('en'), Locale('ru'), Locale('uz')]) {
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) {
              final labels = AppFeature.values.map((f) => f.label(AppLocalizations.of(context))).toList();
              return Text(labels.join('|'));
            },
          ),
          locale: locale,
        ),
      );
      final text = tester.widget<Text>(find.byType(Text)).data!;
      expect(text.split('|').every((label) => label.isNotEmpty), isTrue, reason: '$locale');
    }
  });

  /// Scrolls the [listIndex]-th horizontal list until [key] is built, then taps it.
  Future<void> tapInList(WidgetTester tester, String key, int listIndex) async {
    final target = find.byKey(ValueKey(key));
    await tester.dragUntilVisible(target, find.byType(ListView).at(listIndex), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> pumpStudio(WidgetTester tester, {bool faceTracking = true}) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = await createContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          Scaffold(
            body: SingleChildScrollView(
              child: BeautyStudioPanel(
                faceTrackingAvailable: faceTracking,
                look: beautyEditorProvider,
                editor: (ref) => ref.read(beautyEditorProvider.notifier),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('studio slider edits the selected skin effect and undo restores it', (tester) async {
    final container = await pumpStudio(tester);
    final slider = find.byType(Slider);
    double value() => tester.widget<Slider>(slider).value;
    expect(value(), 0);

    await tester.drag(slider, const Offset(150, 0));
    await tester.pumpAndSettle();
    final smoothing = container.read(beautyEditorProvider).current.valueOf(BeautyEffect.skinSmoothing);
    expect(smoothing, greaterThan(0));
    expect(value(), smoothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(value(), 0);
    expect(container.read(beautyEditorProvider).canUndo, isFalse);
  });

  testWidgets('selecting another effect retargets the slider', (tester) async {
    final container = await pumpStudio(tester);
    await tapInList(tester, 'effect-glow', 1);
    await tester.drag(find.byType(Slider), const Offset(100, 0));
    await tester.pumpAndSettle();
    final look = container.read(beautyEditorProvider).current;
    expect(look.valueOf(BeautyEffect.glow), greaterThan(0));
    expect(look.valueOf(BeautyEffect.skinSmoothing), 0);
  });

  testWidgets('every studio tab renders without overflow', (tester) async {
    await pumpStudio(tester);
    for (final tab in StudioTab.values) {
      await tapInList(tester, 'studio-tab-${tab.name}', 0);
      expect(tester.takeException(), isNull, reason: tab.name);
    }
  });

  testWidgets('makeup tab offers shades and applies the chosen colour', (tester) async {
    final container = await pumpStudio(tester);
    await tapInList(tester, 'studio-tab-makeup', 0);
    await tapInList(tester, 'shade-lipstick-2', 2);
    expect(container.read(beautyEditorProvider).current.colorOf(MakeupItem.lipstick), MakeupItem.lipstick.palette[2]);
  });

  testWidgets('face effects are disabled with an explanation without face tracking', (tester) async {
    await pumpStudio(tester, faceTracking: false);
    await tapInList(tester, 'studio-tab-reshape', 0);
    expect(find.textContaining('Needs face tracking'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
  });

  testWidgets('choosing a filter stores it and shows the intensity slider', (tester) async {
    final container = await pumpStudio(tester);
    await tapInList(tester, 'studio-tab-filters', 0);
    expect(find.byKey(const ValueKey('slider-filterIntensity')), findsNothing);
    expect(find.byKey(const ValueKey('slider-sharpen')), findsOneWidget);
    await tapInList(tester, 'filter-cinematic', 1);
    expect(container.read(beautyEditorProvider).current.filter, FilterId.cinematic);
    expect(find.byKey(const ValueKey('slider-filterIntensity')), findsOneWidget);
  });

  testWidgets('selecting a built-in look applies all of its values', (tester) async {
    final container = await pumpStudio(tester);
    await tapInList(tester, 'studio-tab-looks', 0);
    await tester.dragUntilVisible(find.text('Evening'), find.byType(ListView).at(1), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evening'));
    await tester.pumpAndSettle();
    final look = container.read(beautyEditorProvider).current;
    expect(look.valueOf(BeautyEffect.lipstick), 70);
    expect(look.filter, FilterId.portrait);
  });
}
