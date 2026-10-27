import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_mobile/app/app.dart';
import 'package:yuz_mobile/app/router.dart';
import 'package:yuz_mobile/core/storage/preferences.dart';
import 'package:yuz_mobile/features/camera/application/beauty_camera_controller.dart';
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
    expect(find.text('Planned'), findsWidgets);
    expect(find.text('Ready'), findsWidgets);
  });

  testWidgets('a planned feature opens the honest unavailable screen', (tester) async {
    await pumpRoute(tester, '/home');
    await tester.tap(find.text('Photo editor'));
    await tester.pumpAndSettle();
    expect(find.text('Not available yet'), findsOneWidget);
    expect(find.textContaining('phase 3'), findsOneWidget);
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

  testWidgets('beauty sliders update values and undo restores them', (tester) async {
    final container = await createContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(const Scaffold(body: BeautyControlsPanel())),
      ),
    );
    await tester.pumpAndSettle();

    final slider = find.byType(Slider).first;
    double smoothing() => tester.widget<Slider>(slider).value;
    expect(smoothing(), 0);

    await tester.drag(slider, const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(smoothing(), greaterThan(0));
    expect(container.read(beautyEditorProvider).canUndo, isTrue);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(smoothing(), 0);
    expect(container.read(beautyEditorProvider).canUndo, isFalse);
  });

  testWidgets('selecting a built-in preset applies its values', (tester) async {
    final container = await createContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(const Scaffold(body: BeautyControlsPanel())),
      ),
    );
    await tester.tap(find.text('Soft'));
    await tester.pumpAndSettle();
    expect(find.text('65'), findsOneWidget);
  });
}
