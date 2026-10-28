import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';
import 'package:yuz_mobile/features/camera/application/beauty_camera_controller.dart';

import '../helpers/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, BeautyCameraController, FakeEngineHost)> ready({
    FakeMicrophonePermission? microphone,
  }) async {
    final host = FakeEngineHost();
    final container = await createContainer(host: host, microphone: microphone);
    final subscription = container.listen(beautyCameraControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(beautyCameraControllerProvider.notifier);
    await controller.start();
    controller.setMode(CaptureMode.video);
    return (container, controller, host);
  }

  test('recording starts with sound when the microphone is allowed', () async {
    final (container, controller, host) = await ready();

    expect(await controller.startRecording(), isTrue);

    final state = container.read(beautyCameraControllerProvider);
    expect(state.isRecording, isTrue);
    expect(state.recordingHasAudio, isTrue);
    expect(host.recordings.single.recordAudio, isTrue);
    expect(host.recordings.single.outputFilePath, endsWith('.mp4'));

    final result = await controller.stopRecording();
    expect(result?.durationMillis, 4200);
    final stopped = container.read(beautyCameraControllerProvider);
    expect(stopped.isRecording, isFalse);
    expect(stopped.lastRecording?.filePath, result?.filePath);
    expect(stopped.recordingHasAudio, isNull);
  });

  test('a denied microphone records a silent video instead of failing', () async {
    final (container, controller, host) = await ready(microphone: FakeMicrophonePermission(granted: false));

    expect(await controller.startRecording(), isTrue);
    expect(host.recordings.single.recordAudio, isFalse);
    expect(container.read(beautyCameraControllerProvider).recordingHasAudio, isFalse);
    expect((await controller.stopRecording())?.hasAudio, isFalse);
  });

  test('lens, mode and capture are blocked while recording', () async {
    final (container, controller, host) = await ready();
    await controller.startRecording();

    await controller.switchLens();
    controller.setMode(CaptureMode.photo);
    expect(await controller.capture(), isNull);
    expect(await controller.startRecording(), isFalse);

    final state = container.read(beautyCameraControllerProvider);
    expect(state.lens, CameraLens.front);
    expect(state.mode, CaptureMode.video);
    expect(host.calls.where((c) => c.startsWith('switchLens')), isEmpty);
    expect(host.recordings, hasLength(1));
  });

  test('a native start failure is reported and leaves the camera usable', () async {
    final (container, controller, host) = await ready();
    host.recordingFailure = EngineErrorCode.recordingFailed;

    expect(await controller.startRecording(), isFalse);
    final state = container.read(beautyCameraControllerProvider);
    expect(state.isRecording, isFalse);
    expect(state.transientError, EngineErrorCode.recordingFailed);

    host.recordingFailure = null;
    expect(await controller.startRecording(), isTrue);
  });

  test('stopping without a recording is a no-op', () async {
    final (_, controller, host) = await ready();
    expect(await controller.stopRecording(), isNull);
    expect(host.calls, isNot(contains('stopRecording')));
  });

  test('backgrounding the app finishes the recording before pausing the camera', () async {
    final (container, controller, host) = await ready();
    await controller.startRecording();

    await controller.onAppPaused();

    final stop = host.calls.indexOf('stopRecording');
    final pause = host.calls.indexOf('pause');
    expect(stop, greaterThanOrEqualTo(0));
    expect(pause, greaterThan(stop));
    expect(container.read(beautyCameraControllerProvider).lastRecording, isNotNull);
  });

  test('elapsed time is counted and recording stops at the maximum length', () async {
    final (container, controller, host) = await ready();
    fakeAsync((async) {
      unawaited(controller.startRecording());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));
      expect(container.read(beautyCameraControllerProvider).recordingSeconds, 5);

      async.elapse(const Duration(seconds: BeautyCameraController.maxRecordingSeconds - 5));
      async.flushMicrotasks();
      final state = container.read(beautyCameraControllerProvider);
      expect(state.isRecording, isFalse);
      expect(host.calls, contains('stopRecording'));
    });
  });

  test('the timer counts down before recording starts', () async {
    final (container, controller, host) = await ready();
    controller.cycleTimer(); // 3 s
    fakeAsync((async) {
      bool? started;
      unawaited(controller.startRecording().then((value) => started = value));
      async.flushMicrotasks();
      expect(container.read(beautyCameraControllerProvider).countdown, 3);
      expect(host.recordings, isEmpty);
      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();
      expect(started, isTrue);
      expect(host.recordings, hasLength(1));
    });
  });
}
