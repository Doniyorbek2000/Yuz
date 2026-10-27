import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';
import 'package:yuz_mobile/core/storage/preferences.dart';
import 'package:yuz_mobile/core/theme/app_theme.dart';
import 'package:yuz_mobile/features/camera/application/beauty_camera_controller.dart';
import 'package:yuz_mobile/features/permissions/camera_permission_service.dart';
import 'package:yuz_mobile/l10n/generated/app_localizations.dart';

/// In-memory stand-in for the native engine host API.
class FakeEngineHost implements BeautyEngineHostApi {
  FakeEngineHost({this.hasFlash = true});

  final bool hasFlash;
  final List<String> calls = [];
  final List<BeautyParameters> parameters = [];
  EngineErrorCode? initializeFailure;
  EngineErrorCode? captureFailure;
  Completer<void>? initializeGate;

  @override
  Future<PreviewDescriptor> initialize(EngineConfig config) async {
    calls.add('initialize:${config.lens.name}');
    final gate = initializeGate;
    if (gate != null) await gate.future;
    if (initializeFailure != null) {
      throw _platformError(initializeFailure!);
    }
    return _descriptor(config.lens);
  }

  @override
  Future<PreviewDescriptor> switchLens(CameraLens lens) async {
    calls.add('switchLens:${lens.name}');
    return _descriptor(lens);
  }

  @override
  Future<CameraCapabilities> getCapabilities() async => CameraCapabilities(
    hasFrontCamera: true,
    hasBackCamera: true,
    hasFlash: hasFlash,
    minZoomRatio: 1,
    maxZoomRatio: 4,
    minExposureBias: -2,
    maxExposureBias: 2,
  );

  @override
  Future<void> setBeautyParameters(BeautyParameters parameters) async => this.parameters.add(parameters);

  @override
  Future<void> setFlashMode(FlashMode mode) async => calls.add('flash:${mode.name}');

  @override
  Future<void> setZoomRatio(double ratio) async => calls.add('zoom:$ratio');

  @override
  Future<void> setExposureBias(double ev) async => calls.add('exposure:$ev');

  @override
  Future<PhotoCaptureResult> capturePhoto(String outputFilePath) async {
    calls.add('capture:$outputFilePath');
    if (captureFailure != null) throw _platformError(captureFailure!);
    return PhotoCaptureResult(filePath: outputFilePath, width: 1080, height: 1920);
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> dispose() async => calls.add('dispose');

  PreviewDescriptor _descriptor(CameraLens lens) => PreviewDescriptor(
    textureId: 1,
    width: 1080,
    height: 1920,
    lens: lens,
    isMirrored: lens == CameraLens.front,
    faceTrackingAvailable: true,
  );

  static PlatformException _platformError(EngineErrorCode code) {
    const names = {
      EngineErrorCode.permissionDenied: 'PERMISSION_DENIED',
      EngineErrorCode.cameraUnavailable: 'CAMERA_UNAVAILABLE',
      EngineErrorCode.cameraInUse: 'CAMERA_IN_USE',
      EngineErrorCode.captureFailed: 'CAPTURE_FAILED',
      EngineErrorCode.gpuInitializationFailed: 'GPU_INITIALIZATION_FAILED',
    };
    return PlatformException(code: names[code] ?? 'UNKNOWN', message: code.name);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePermissionService implements CameraPermissionService {
  FakePermissionService(this.state);

  CameraPermissionState state;
  int requests = 0;

  @override
  Future<CameraPermissionState> status() async => state;

  @override
  Future<CameraPermissionState> request() async {
    requests++;
    return state;
  }

  @override
  Future<bool> openSystemSettings() async => true;
}

Future<SharedPreferences> mockPreferences([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<ProviderContainer> createContainer({
  FakeEngineHost? host,
  Map<String, Object> preferences = const {},
  CameraPermissionState permission = CameraPermissionState.granted,
}) async {
  final prefs = await mockPreferences(preferences);
  final engineHost = host ?? FakeEngineHost();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      beautyEngineProvider.overrideWithValue(BeautyEngine(hostApi: engineHost, registerEventHandlers: false)),
      capturePathBuilderProvider.overrideWithValue(() async => '/tmp/yuz_test_capture.jpg'),
      cameraPermissionServiceProvider.overrideWithValue(FakePermissionService(permission)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Wraps [child] in the app theme and localizations.
Widget localizedApp(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: AppTheme.dark(),
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);
