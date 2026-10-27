// On-device flow test (requires a real device/emulator with a camera):
//   flutter test integration_test/camera_flow_test.dart -d <device>
// It exercises the real native engine: permission → camera start → slider →
// capture → measured performance telemetry. Grant camera permission first
// (adb shell pm grant app.yuz.beauty android.permission.CAMERA).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuz_mobile/app/app.dart';
import 'package:yuz_mobile/app/router.dart';
import 'package:yuz_mobile/core/storage/preferences.dart';
import 'package:yuz_mobile/features/camera/application/beauty_camera_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('camera starts, applies beauty, captures and reports measured FPS', (tester) async {
    SharedPreferences.setMockInitialValues({PreferenceKeys.onboardingCompleted: true});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(preferences)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: YuzApp(router: testRouter('/camera')),
      ),
    );

    // Wait for the native engine to deliver the first frame (up to 10 s).
    for (var i = 0; i < 100 && !container.read(beautyCameraControllerProvider).isReady; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final state = container.read(beautyCameraControllerProvider);
    expect(state.phase, CameraPhase.ready, reason: 'engine error: ${state.errorCode}');
    expect(state.descriptor!.width, greaterThan(0));

    await tester.drag(find.byType(Slider).first, const Offset(200, 0));
    await tester.pumpAndSettle();

    // Let the performance reporter publish at least two samples.
    await tester.pump(const Duration(seconds: 3));
    final performance = container.read(beautyCameraControllerProvider).performance;
    expect(performance, isNotNull);
    // Recorded, not asserted against a target: FPS targets are validated per device class.
    debugPrint(
      'MEASURED renderedFps=${performance!.renderedFps} gpuMs=${performance.averageGpuFrameMillis} '
      'detectorMs=${performance.averageDetectorMillis} dropped=${performance.droppedFrames}',
    );

    final result = await container.read(beautyCameraControllerProvider.notifier).capture();
    expect(result, isNotNull);
    expect(File(result!.filePath).lengthSync(), greaterThan(10 * 1024));
  });
}
