import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';
import 'package:yuz_mobile/app/app.dart';
import 'package:yuz_mobile/app/router.dart';
import 'package:yuz_mobile/core/storage/preferences.dart';
import 'package:yuz_mobile/features/templates/application/template_editor_controller.dart';
import 'package:yuz_mobile/features/templates/domain/template_layout.dart';
import 'package:yuz_mobile/features/templates/presentation/template_editor_screen.dart';

import '../helpers/test_app.dart';

Future<(ProviderContainer, FakeEngineHost, FakeGallerySaver, Directory)> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final directory = (await tester.runAsync(() => Directory.systemTemp.createTemp('yuz_templates')))!;
  addTearDown(() => tester.runAsync(() => directory.delete(recursive: true)));
  final picked = File('${directory.path}/picked.png');
  await tester.runAsync(() => picked.writeAsBytes(kTinyPng));
  final host = FakeEngineHost();
  final gallery = FakeGallerySaver();
  final container = await createContainer(
    host: host,
    gallerySaver: gallery,
    preferences: const {PreferenceKeys.onboardingCompleted: true},
    extraOverrides: [
      templateDirectoryProvider.overrideWithValue(() async => directory),
      templatePhotoPickerProvider.overrideWithValue(() async => picked.path),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: YuzApp(router: testRouter('/templates')),
    ),
  );
  await tester.pump();
  return (container, host, gallery, directory);
}

/// Taps the centre of [slot] of the current layout.
Future<void> _tapSlot(WidgetTester tester, ProviderContainer container, int slot) async {
  final canvas = find.byKey(const ValueKey('template-canvas'));
  final box = tester.getRect(canvas);
  final state = container.read(templateEditorControllerProvider);
  final rect = slotRect(state.layout.slots[slot], box.size, state.style.spacing);
  await tester.tapAt(box.topLeft + rect.center);
}

void main() {
  testWidgets('filling slots, switching layouts and saving a collage', (tester) async {
    final (container, host, gallery, directory) = await _pump(tester);
    expect(find.byKey(const ValueKey('slot-empty-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('slot-empty-1')), findsOneWidget);

    await _tapSlot(tester, container, 0);
    await settleIo(tester, rounds: 20);
    final state = container.read(templateEditorControllerProvider);
    expect(state.images.keys, [0]);
    expect(
      host.imageRequests.single.maxLongEdge,
      TemplateEditorController.slotLongEdge,
      reason: 'photos are normalized natively (EXIF, HEIC, size)',
    );
    expect(find.byKey(const ValueKey('slot-empty-0')), findsNothing);

    // Switching to a single-photo layout keeps the first photo.
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('layout-story-frame')),
      find.byKey(const ValueKey('template-layouts')),
      const Offset(-120, 0),
    );
    await tester.tap(find.byKey(const ValueKey('layout-story-frame')));
    await tester.pump();
    expect(container.read(templateEditorControllerProvider).images.keys, [0]);
    expect(find.byKey(const ValueKey('template-caption')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('template-caption')), 'Yuz');
    await tester.tap(find.byKey(const ValueKey('background-${0xFF0B0B0F}')));
    await tester.pump();
    expect(container.read(templateEditorControllerProvider).style.caption, 'Yuz');

    await tester.tap(find.byKey(const ValueKey('template-save')));
    await settleIo(tester, rounds: 20);
    expect(gallery.saved.single, endsWith('.png'));
    expect(File(gallery.saved.single).existsSync(), isTrue);
    expect(find.text('Saved to your gallery'), findsOneWidget);
    expect(directory.existsSync(), isTrue);
  });

  testWidgets('a photo that cannot be prepared shows an error', (tester) async {
    final (container, host, _, _) = await _pump(tester);
    host.processImageFailure = EngineErrorCode.captureFailed;
    await _tapSlot(tester, container, 1);
    await settleIo(tester, rounds: 10);
    expect(container.read(templateEditorControllerProvider).images, isEmpty);
    expect(find.text('The photo could not be saved.'), findsOneWidget);
  });

  testWidgets('template editor fits a small phone', (tester) async {
    await _pump(tester, size: const Size(320, 568));
    expect(find.byType(TemplateEditorScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
