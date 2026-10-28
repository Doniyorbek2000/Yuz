import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';
import 'package:yuz_mobile/features/camera/application/beauty_camera_controller.dart';
import 'package:yuz_mobile/features/camera/domain/beauty_adjustments.dart';
import 'package:yuz_mobile/features/camera/domain/beauty_preset.dart';

import '../helpers/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('start initializes the engine and applies the current look', () async {
    final host = FakeEngineHost();
    final container = await createContainer(host: host);
    final subscription = container.listen(beautyCameraControllerProvider, (_, _) {});
    addTearDown(subscription.close);

    await container.read(beautyCameraControllerProvider.notifier).start();

    final state = container.read(beautyCameraControllerProvider);
    expect(state.phase, CameraPhase.ready);
    expect(state.descriptor?.textureId, 1);
    expect(state.capabilities?.maxZoomRatio, 4);
    expect(host.calls.first, 'initialize:front');
    expect(host.parameters, isNotEmpty);
  });

  test('initialization failure is surfaced as an error phase with its code', () async {
    final host = FakeEngineHost()..initializeFailure = EngineErrorCode.cameraInUse;
    final container = await createContainer(host: host);
    final subscription = container.listen(beautyCameraControllerProvider, (_, _) {});
    addTearDown(subscription.close);

    await container.read(beautyCameraControllerProvider.notifier).start();

    final state = container.read(beautyCameraControllerProvider);
    expect(state.phase, CameraPhase.error);
    expect(state.errorCode, EngineErrorCode.cameraInUse);
  });

  test('leaving the camera releases the native session', () async {
    final host = FakeEngineHost();
    final container = await createContainer(host: host);
    final subscription = container.listen(beautyCameraControllerProvider, (_, _) {});
    await container.read(beautyCameraControllerProvider.notifier).start();

    subscription.close();
    await container.pump();
    await Future<void>.delayed(Duration.zero);

    expect(host.calls.last, 'dispose');
  });

  test('session opened after the screen left is released again', () async {
    final host = FakeEngineHost()..initializeGate = Completer<void>();
    final container = await createContainer(host: host);
    final subscription = container.listen(beautyCameraControllerProvider, (_, _) {});
    final starting = container.read(beautyCameraControllerProvider.notifier).start();

    subscription.close();
    await container.pump();
    host.initializeGate!.complete();
    await starting;

    expect(host.calls.where((c) => c == 'dispose').length, greaterThanOrEqualTo(2));
  });

  test('switchLens, flash, zoom and exposure are forwarded with clamping', () async {
    final host = FakeEngineHost();
    final container = await createContainer(host: host);
    final subscription = container.listen(beautyCameraControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(beautyCameraControllerProvider.notifier);
    await controller.start();

    await controller.switchLens();
    await controller.cycleFlashMode();
    await controller.setZoomRatio(9);
    await controller.setExposureBias(-5);

    final state = container.read(beautyCameraControllerProvider);
    expect(state.lens, CameraLens.back);
    expect(state.flashMode, FlashMode.auto);
    expect(state.zoomRatio, 4);
    expect(state.exposureBias, -2);
    expect(host.calls, containsAll(['switchLens:back', 'flash:auto', 'zoom:4.0', 'exposure:-2.0']));
  });

  test('back camera flash cycling is disabled without a flash unit', () async {
    final host = FakeEngineHost(hasFlash: false);
    final container = await createContainer(host: host);
    final subscription = container.listen(beautyCameraControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(beautyCameraControllerProvider.notifier);
    await controller.start();
    await controller.switchLens();
    await controller.cycleFlashMode();
    expect(container.read(beautyCameraControllerProvider).flashMode, FlashMode.off);
  });

  test('front camera offers a screen flash and never fires the native flash', () async {
    final host = FakeEngineHost(hasFlash: false);
    final container = await createContainer(host: host);
    final subscription = container.listen(beautyCameraControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(beautyCameraControllerProvider.notifier);
    await controller.start();

    expect(container.read(beautyCameraControllerProvider).availableFlashModes, [FlashMode.off, FlashMode.on]);
    await controller.cycleFlashMode();
    expect(container.read(beautyCameraControllerProvider).flashMode, FlashMode.on);
    expect(host.calls.last, 'flash:off', reason: 'the screen is the front flash');

    fakeAsync((async) {
      PhotoCaptureResult? result;
      unawaited(controller.capture().then((value) => result = value));
      async.flushMicrotasks();
      expect(container.read(beautyCameraControllerProvider).screenFlash, isTrue);
      expect(host.calls, contains('brightness:1.0'));
      async.elapse(const Duration(milliseconds: 400));
      async.flushMicrotasks();
      expect(result, isNotNull);
      expect(container.read(beautyCameraControllerProvider).screenFlash, isFalse);
      expect(host.calls.last, 'brightness:-1.0');
    });

    // Switching to a back camera without a flash unit drops the screen flash.
    await controller.switchLens();
    expect(container.read(beautyCameraControllerProvider).flashMode, FlashMode.off);
  });

  test('capture without timer writes a photo', () async {
    final host = FakeEngineHost();
    final container = await createContainer(host: host);
    final subscription = container.listen(beautyCameraControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(beautyCameraControllerProvider.notifier);
    await controller.start();

    final result = await controller.capture();
    expect(result?.filePath, '/tmp/yuz_test_capture.jpg');
    expect(container.read(beautyCameraControllerProvider).isCapturing, isFalse);
  });

  test('capture failure is reported as a transient error', () async {
    final host = FakeEngineHost()..captureFailure = EngineErrorCode.captureFailed;
    final container = await createContainer(host: host);
    final subscription = container.listen(beautyCameraControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(beautyCameraControllerProvider.notifier);
    await controller.start();

    expect(await controller.capture(), isNull);
    expect(container.read(beautyCameraControllerProvider).transientError, EngineErrorCode.captureFailed);
  });

  test('timer counts down before capturing and can be cancelled', () async {
    final host = FakeEngineHost();
    final container = await createContainer(host: host);
    final subscription = container.listen(beautyCameraControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(beautyCameraControllerProvider.notifier);
    await controller.start();
    controller.cycleTimer(); // 3 s

    fakeAsync((async) {
      PhotoCaptureResult? result;
      unawaited(controller.capture().then((value) => result = value));
      async.flushMicrotasks();
      expect(container.read(beautyCameraControllerProvider).countdown, 3);
      async.elapse(const Duration(seconds: 1));
      expect(container.read(beautyCameraControllerProvider).countdown, 2);
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(container.read(beautyCameraControllerProvider).countdown, isNull);
      expect(result, isNotNull);

      PhotoCaptureResult? cancelled = PhotoCaptureResult(filePath: 'sentinel', width: 0, height: 0);
      unawaited(controller.capture().then((value) => cancelled = value));
      async.elapse(const Duration(seconds: 1));
      controller.cancelCountdown();
      async.flushMicrotasks();
      expect(cancelled, isNull);
      expect(container.read(beautyCameraControllerProvider).countdown, isNull);
    });
  });

  test('pause and resume reach the engine once each', () async {
    final host = FakeEngineHost();
    final container = await createContainer(host: host);
    final subscription = container.listen(beautyCameraControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(beautyCameraControllerProvider.notifier);
    await controller.start();

    await controller.onAppPaused();
    await controller.onAppPaused();
    await controller.onAppResumed();
    await controller.onAppResumed();
    expect(host.calls.where((c) => c == 'pause').length, 1);
    expect(host.calls.where((c) => c == 'resume').length, 1);
  });

  test('beauty edits are pushed to the running engine and persisted', () async {
    final host = FakeEngineHost();
    final container = await createContainer(host: host);
    final subscription = container.listen(beautyCameraControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(beautyCameraControllerProvider.notifier).start();
    final editor = container.read(beautyEditorProvider.notifier);
    host.parameters.clear();

    editor.beginEdit();
    editor.updateLive(BeautyEffect.skinSmoothing, 40);
    editor.updateLive(BeautyEffect.skinSmoothing, 70);
    await editor.endEdit();
    await Future<void>.delayed(Duration.zero);

    expect(host.parameters.last.skinSmoothing, 0.7);
    expect(container.read(beautyEditorProvider).history.length, 1);

    editor.applyPreset(BeautyPreset.builtIns.first);
    await Future<void>.delayed(Duration.zero);
    expect(host.parameters.last.skinSmoothing, 0.35);
  });
}
