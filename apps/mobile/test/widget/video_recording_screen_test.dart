import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_mobile/app/app.dart';
import 'package:yuz_mobile/app/router.dart';
import 'package:yuz_mobile/core/storage/preferences.dart';
import 'package:yuz_mobile/features/video/presentation/video_result_screen.dart';

import '../helpers/fake_video_player.dart';
import '../helpers/test_app.dart';

Future<(ProviderContainer, FakeEngineHost, FakeGallerySaver)> _pump(WidgetTester tester, String location) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final host = FakeEngineHost();
  final gallery = FakeGallerySaver();
  final container = await createContainer(
    host: host,
    gallerySaver: gallery,
    preferences: const {PreferenceKeys.onboardingCompleted: true},
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: YuzApp(router: testRouter(location)),
    ),
  );
  // Spinners (camera start, video loading) never settle; pump a few frames.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return (container, host, gallery);
}

void main() {
  late FakeVideoPlayerPlatform player;

  setUp(() => player = FakeVideoPlayerPlatform.install());

  testWidgets('video mode records, shows the timer and opens the result', (tester) async {
    final (_, host, _) = await _pump(tester, '/camera');

    await tester.tap(find.byKey(const ValueKey('mode-video')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('shutter')));
    await tester.pump();

    expect(host.recordings, hasLength(1));
    expect(find.byKey(const ValueKey('recording-indicator')), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:02'), findsOneWidget);

    // Lens switch and back are disabled while recording.
    final switchButton = tester.widget<IconButton>(
      find.ancestor(of: find.byIcon(Icons.cameraswitch_outlined), matching: find.byType(IconButton)),
    );
    expect(switchButton.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('shutter')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(host.calls, contains('stopRecording'));
    expect(find.byType(VideoResultScreen), findsOneWidget);
  });

  testWidgets('photo mode is unaffected by the video controls', (tester) async {
    final (_, host, _) = await _pump(tester, '/camera');
    await tester.tap(find.byKey(const ValueKey('shutter')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(host.calls.any((c) => c.startsWith('capture:')), isTrue);
    expect(host.recordings, isEmpty);
  });

  testWidgets('result screen plays the recording in a loop and saves it', (tester) async {
    final directory = (await tester.runAsync(() => Directory.systemTemp.createTemp('yuz_video')))!;
    addTearDown(() => tester.runAsync(() => directory.delete(recursive: true)));
    final file = File('${directory.path}/clip.mp4');
    await tester.runAsync(() => file.writeAsBytes(List<int>.filled(32, 0)));

    final (_, _, gallery) = await _pump(tester, '/video?path=${Uri.encodeComponent(file.path)}&audio=0');
    await settleIo(tester);

    expect(player.calls, containsAll(<String>['looping:true', 'play']));
    expect(find.text('Recorded without sound'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('video-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(gallery.saved.single, file.path);
    expect(find.text('Saved to your gallery'), findsWidgets);
  });

  testWidgets('a missing recording shows a clear message', (tester) async {
    await _pump(tester, '/video?path=${Uri.encodeComponent('/nope/missing.mp4')}');
    await settleIo(tester);
    expect(find.text('This video is no longer available.'), findsOneWidget);
  });
}
