import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';
import 'package:yuz_mobile/core/storage/preferences.dart';
import 'package:yuz_mobile/core/theme/app_theme.dart';
import 'package:yuz_mobile/features/camera/application/beauty_camera_controller.dart';
import 'package:yuz_mobile/features/camera/data/filter_lut_repository.dart';
import 'package:yuz_mobile/features/permissions/camera_permission_service.dart';
import 'package:yuz_mobile/features/projects/application/photo_project_controller.dart';
import 'package:yuz_mobile/features/projects/data/project_repository.dart';
import 'package:yuz_mobile/features/video/data/video_project_repository.dart';
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

  /// Every LUT upload (null = filter cleared).
  final List<Uint8List?> luts = [];

  @override
  Future<void> setColorLut(Uint8List? rgba512) async => luts.add(rgba512);

  @override
  Future<void> setFlashMode(FlashMode mode) async => calls.add('flash:${mode.name}');

  @override
  Future<void> setZoomRatio(double ratio) async => calls.add('zoom:$ratio');

  @override
  Future<void> setExposureBias(double ev) async => calls.add('exposure:$ev');

  @override
  Future<void> setScreenBrightness(double brightness) async => calls.add('brightness:$brightness');

  @override
  Future<PhotoCaptureResult> capturePhoto(String outputFilePath) async {
    calls.add('capture:$outputFilePath');
    if (captureFailure != null) throw _platformError(captureFailure!);
    return PhotoCaptureResult(filePath: outputFilePath, width: 1080, height: 1920);
  }

  final List<VideoRecordingOptions> recordings = [];
  bool recordingActive = false;
  EngineErrorCode? recordingFailure;

  @override
  Future<void> startRecording(VideoRecordingOptions options) async {
    if (recordingFailure != null) throw _platformError(recordingFailure!);
    if (recordingActive) throw _platformError(EngineErrorCode.recordingFailed);
    calls.add('startRecording');
    recordings.add(options);
    recordingActive = true;
  }

  @override
  Future<VideoRecordingResult> stopRecording() async {
    if (!recordingActive) throw _platformError(EngineErrorCode.recordingFailed);
    calls.add('stopRecording');
    recordingActive = false;
    final options = recordings.last;
    return VideoRecordingResult(
      filePath: options.outputFilePath,
      durationMillis: 4200,
      width: 1080,
      height: 1920,
      hasAudio: options.recordAudio,
    );
  }

  /// Probe results by path; unknown paths get a 10 s 1080x1920 clip with sound.
  final Map<String, VideoMetadata> videoMetadata = {};
  EngineErrorCode? probeFailure;
  final List<VideoExportRequest> exports = [];
  final List<String> cancelledExports = [];

  /// When set, exportVideo waits for it (to test progress and cancel).
  Completer<void>? exportGate;
  EngineErrorCode? exportFailure;

  /// Lets a test feed progress events into the engine facade.
  void Function(String jobId, double progress)? onExportProgress;

  @override
  Future<VideoMetadata> probeVideo(String path) async {
    if (probeFailure != null) throw _platformError(probeFailure!);
    return videoMetadata[path] ??
        VideoMetadata(durationMillis: 10000, width: 1080, height: 1920, rotationDegrees: 0, hasAudio: true);
  }

  @override
  Future<List<String>> videoThumbnails(String path, int count, int maxEdge, String outputDirectory) async {
    await Directory(outputDirectory).create(recursive: true);
    return [for (var i = 0; i < count; i++) (await File('$outputDirectory/thumb_$i.jpg').writeAsBytes(kTinyPng)).path];
  }

  @override
  Future<VideoExportResult> exportVideo(VideoExportRequest request) async {
    exports.add(request);
    onExportProgress?.call(request.jobId, 0.5);
    final gate = exportGate;
    if (gate != null) await gate.future;
    if (cancelledExports.contains(request.jobId)) {
      throw PlatformException(code: 'EXPORT_CANCELLED', message: 'cancelled');
    }
    if (exportFailure != null) throw _platformError(exportFailure!);
    await File(request.outputPath).writeAsBytes(List<int>.filled(16, 1));
    return VideoExportResult(
      outputPath: request.outputPath,
      durationMillis: 4000,
      width: 1080,
      height: 1920,
      hasAudio: request.originalVolume > 0 || request.musicPath != null,
    );
  }

  @override
  Future<void> cancelVideoExport(String jobId) async => cancelledExports.add(jobId);

  /// Every still-image request, in order.
  final List<ImageProcessingRequest> imageRequests = [];
  EngineErrorCode? processImageFailure;

  /// When set, each processImage call waits for the gate before finishing.
  Completer<void>? processImageGate;

  /// Copies the input to the output (a real engine renders the look).
  @override
  Future<ImageProcessingResult> processImage(ImageProcessingRequest request) async {
    imageRequests.add(request);
    final gate = processImageGate;
    if (gate != null) await gate.future;
    if (processImageFailure != null) throw _platformError(processImageFailure!);
    await File(request.inputPath).copy(request.outputPath);
    const sourceWidth = 3000;
    const sourceHeight = 4000;
    final scale = request.maxLongEdge <= 0 ? 1.0 : (request.maxLongEdge / sourceHeight).clamp(0.0, 1.0);
    return ImageProcessingResult(
      outputPath: request.outputPath,
      width: (sourceWidth * scale).round(),
      height: (sourceHeight * scale).round(),
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      faceCount: 1,
      faceTrackingAvailable: true,
    );
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
      EngineErrorCode.recordingFailed: 'RECORDING_FAILED',
    };
    return PlatformException(code: names[code] ?? 'UNKNOWN', message: code.name);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGallerySaver implements GallerySaver {
  FakeGallerySaver({this.accept = true});

  bool accept;
  final List<String> saved = [];

  @override
  Future<bool> saveImage(String path) async {
    saved.add(path);
    return accept;
  }

  @override
  Future<bool> saveVideo(String path) async {
    saved.add(path);
    return accept;
  }
}

/// Polls (real time) until [condition] holds; file I/O makes fake time unusable.
Future<void> eventually(bool Function() condition, {Duration timeout = const Duration(seconds: 5)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition not met within $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// A valid 1×1 PNG, enough for Image.file and file-copy tests.
final Uint8List kTinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Lets real file I/O started inside a widget test complete, then rebuilds.
Future<void> settleIo(WidgetTester tester, {int rounds = 25}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

class FakeMicrophonePermission implements MicrophonePermissionService {
  FakeMicrophonePermission({this.granted = true});

  bool granted;
  int requests = 0;

  @override
  Future<bool> ensureGranted() async {
    requests++;
    return granted;
  }
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
  Directory? projectsRoot,
  Directory? videoProjectsRoot,
  GallerySaver? gallerySaver,
  List<Override> extraOverrides = const [],
  FakeMicrophonePermission? microphone,
}) async {
  final prefs = await mockPreferences(preferences);
  final engineHost = host ?? FakeEngineHost();
  final engine = BeautyEngine(hostApi: engineHost, registerEventHandlers: false);
  engineHost.onExportProgress ??= engine.onVideoExportProgress;
  final container = ProviderContainer(
    overrides: [
      ...extraOverrides,
      sharedPreferencesProvider.overrideWithValue(prefs),
      beautyEngineProvider.overrideWithValue(engine),
      capturePathBuilderProvider.overrideWithValue(() async => '/tmp/yuz_test_capture.jpg'),
      videoPathBuilderProvider.overrideWithValue(() async => '/tmp/yuz_test_video.mp4'),
      microphonePermissionServiceProvider.overrideWithValue(microphone ?? FakeMicrophonePermission()),
      cameraPermissionServiceProvider.overrideWithValue(FakePermissionService(permission)),
      projectRepositoryProvider.overrideWithValue(
        ProjectRepository(root: () async => projectsRoot ?? Directory('${Directory.systemTemp.path}/yuz_no_projects')),
      ),
      gallerySaverProvider.overrideWithValue(gallerySaver ?? FakeGallerySaver()),
      videoProjectRepositoryProvider.overrideWithValue(
        VideoProjectRepository(
          root: () async => videoProjectsRoot ?? Directory('${Directory.systemTemp.path}/yuz_no_video_projects'),
        ),
      ),
      filterLutRepositoryProvider.overrideWithValue(
        FilterLutRepository(
          storageDirectory: () async => Directory.systemTemp.createTemp('yuz_lut_test'),
          generator: (grade) async => Uint8List(ColorLut.byteLength),
        ),
      ),
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
