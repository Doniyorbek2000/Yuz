import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';
import 'package:yuz_mobile/app/app.dart';
import 'package:yuz_mobile/app/router.dart';
import 'package:yuz_mobile/core/storage/preferences.dart';
import 'package:yuz_mobile/features/video/application/video_editor_controller.dart';
import 'package:yuz_mobile/features/video/data/video_project_repository.dart';
import 'package:yuz_mobile/features/video/presentation/video_editor_screen.dart';
import 'package:yuz_mobile/features/video/presentation/video_result_screen.dart';

import '../helpers/fake_video_player.dart';
import '../helpers/test_app.dart';

class _Harness {
  _Harness(this.container, this.host, this.root, this.projectId);

  final ProviderContainer container;
  final FakeEngineHost host;
  final Directory root;
  final String? projectId;
}

Future<_Harness> _pump(
  WidgetTester tester,
  String location, {
  bool seed = true,
  String? pickedVideo,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final root = (await tester.runAsync(() => Directory.systemTemp.createTemp('yuz_video_widget')))!;
  addTearDown(() => tester.runAsync(() => root.delete(recursive: true)));
  final host = FakeEngineHost();
  final container = await createContainer(
    host: host,
    videoProjectsRoot: root,
    preferences: const {PreferenceKeys.onboardingCompleted: true},
    extraOverrides: [videoPickerProvider.overrideWithValue(() async => pickedVideo)],
  );
  String? id;
  if (seed) {
    id = (await tester.runAsync(() async {
      final source = await File('${root.parent.path}/yuz_seed_${DateTime.now().microsecondsSinceEpoch}.mp4')
          .writeAsBytes([0]);
      final project = await container.read(videoProjectRepositoryProvider).create(source.path, (
        durationMillis: 10000,
        width: 1080,
        height: 1920,
        hasAudio: true,
      ));
      await source.delete();
      return project.id;
    }))!;
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: YuzApp(router: testRouter(location.replaceAll(':id', id ?? ''))),
    ),
  );
  await settleIo(tester, rounds: 30);
  return _Harness(container, host, root, id);
}

Future<void> _selectTool(WidgetTester tester, String tool) async {
  await tester.tap(find.byKey(ValueKey('tool-$tool')));
  await tester.pump();
}

void main() {
  setUp(FakeVideoPlayerPlatform.install);

  testWidgets('editor shows the timeline and every tool without overflow', (tester) async {
    await _pump(tester, '/video-editor/:id', size: const Size(320, 640));
    expect(find.byType(VideoEditorScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('clip-timeline')), findsOneWidget);
    for (final tool in ['trim', 'speed', 'look', 'text', 'stickers', 'music']) {
      await _selectTool(tester, tool);
      await settleIo(tester, rounds: 5);
      expect(tester.takeException(), isNull, reason: 'tool $tool');
    }
  });

  testWidgets('text overlay is added through the dialog and can be recoloured', (tester) async {
    final harness = await _pump(tester, '/video-editor/:id');
    await _selectTool(tester, 'text');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add-text')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('text-input')), 'Salom Yuz');
    await tester.tap(find.byKey(const ValueKey('text-confirm')));
    await tester.pumpAndSettle();

    final provider = videoEditorControllerProvider(harness.projectId!);
    final overlay = harness.container.read(provider).project!.overlays.single;
    expect(overlay.value, 'Salom Yuz');

    await tester.tap(find.byKey(const ValueKey('text-color-${0xFFF2C46D}')));
    await tester.pump();
    expect(harness.container.read(provider).project!.overlays.single.color, 0xFFF2C46D);

    await tester.ensureVisible(find.byKey(const ValueKey('overlay-delete')));
    await tester.tap(find.byKey(const ValueKey('overlay-delete')));
    await tester.pump();
    expect(harness.container.read(provider).project!.overlays, isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('stickers are added and speed chips change the clip', (tester) async {
    final harness = await _pump(tester, '/video-editor/:id');
    final provider = videoEditorControllerProvider(harness.projectId!);

    await _selectTool(tester, 'stickers');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add-sticker-heart')));
    await tester.pump();
    expect(harness.container.read(provider).project!.overlays.single.value, 'heart');

    await _selectTool(tester, 'speed');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('speed-2.0')));
    await tester.pump();
    expect(harness.container.read(provider).clip!.speed, 2);
    expect(find.textContaining('without their own sound'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('export shows progress and opens the result', (tester) async {
    final harness = await _pump(tester, '/video-editor/:id');
    await tester.tap(find.byKey(const ValueKey('video-export')));
    await settleIo(tester, rounds: 30);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(harness.host.exports, hasLength(1));
    expect(find.byType(VideoResultScreen), findsOneWidget);
  });

  testWidgets('a failed export explains what happened', (tester) async {
    final harness = await _pump(tester, '/video-editor/:id');
    harness.host.exportFailure = EngineErrorCode.recordingFailed;
    await tester.tap(find.byKey(const ValueKey('video-export')));
    await settleIo(tester, rounds: 30);
    expect(find.text('The video could not be recorded.'), findsOneWidget);
    expect(find.byType(VideoEditorScreen), findsOneWidget);
  });

  testWidgets('video tab lists projects and imports a new video', (tester) async {
    final picked = File('${Directory.systemTemp.path}/yuz_pick_${DateTime.now().microsecondsSinceEpoch}.mp4');
    await tester.runAsync(() => picked.writeAsBytes([0]));
    addTearDown(() => tester.runAsync(() => picked.delete()));
    final harness = await _pump(tester, '/projects?tab=videos', seed: false, pickedVideo: picked.path);

    expect(find.textContaining('record one with the camera'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('new-video-project')));
    await settleIo(tester, rounds: 40);

    expect(find.byType(VideoEditorScreen), findsOneWidget);
    final projects = (await tester.runAsync(harness.container.read(videoProjectRepositoryProvider).list))!;
    expect(projects, hasLength(1));
  });

  testWidgets('an unknown project shows a clear message', (tester) async {
    await _pump(tester, '/video-editor/1-abc', seed: false);
    expect(find.text('This project no longer exists.'), findsOneWidget);
  });
}
