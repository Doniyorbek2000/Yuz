import 'dart:async';

import 'package:flutter/services.dart';

import 'color_lut.dart';
import 'generated/beauty_engine_api.g.dart';

/// Typed error raised by the native engine.
class BeautyEngineException implements Exception {
  const BeautyEngineException(this.code, this.message);

  final EngineErrorCode code;
  final String message;

  static const Map<String, EngineErrorCode> _codes = {
    'PERMISSION_DENIED': EngineErrorCode.permissionDenied,
    'CAMERA_UNAVAILABLE': EngineErrorCode.cameraUnavailable,
    'CAMERA_IN_USE': EngineErrorCode.cameraInUse,
    'CAMERA_DISCONNECTED': EngineErrorCode.cameraDisconnected,
    'GPU_INITIALIZATION_FAILED': EngineErrorCode.gpuInitializationFailed,
    'FACE_MODEL_UNAVAILABLE': EngineErrorCode.faceModelUnavailable,
    'CAPTURE_FAILED': EngineErrorCode.captureFailed,
    'THERMAL_THROTTLING': EngineErrorCode.thermalThrottling,
    'RECORDING_FAILED': EngineErrorCode.recordingFailed,
    'EXPORT_CANCELLED': EngineErrorCode.exportCancelled,
  };

  factory BeautyEngineException.fromPlatform(PlatformException error) =>
      BeautyEngineException(
        _codes[error.code] ?? EngineErrorCode.unknown,
        error.message ?? error.code,
      );

  @override
  String toString() => 'BeautyEngineException(${code.name}): $message';
}

/// Progress (0..1) of one [BeautyEngine.exportVideo] job.
class VideoExportProgress {
  const VideoExportProgress(this.jobId, this.progress);

  final String jobId;
  final double progress;
}

/// Dart facade over the Pigeon-generated host API.
///
/// - Maps platform errors to [BeautyEngineException].
/// - Exposes native telemetry as broadcast streams.
/// - Coalesces beauty-parameter updates: while one update is in flight only
///   the most recent value is kept, so slider drags never queue up calls.
class BeautyEngine implements BeautyEngineEventsApi {
  BeautyEngine({
    BeautyEngineHostApi? hostApi,
    bool registerEventHandlers = true,
  }) : _host = hostApi ?? BeautyEngineHostApi() {
    if (registerEventHandlers) BeautyEngineEventsApi.setUp(this);
  }

  final BeautyEngineHostApi _host;
  final _faceStatus = StreamController<FaceTrackingStatus>.broadcast();
  final _performance = StreamController<PerformanceSample>.broadcast();
  final _errors = StreamController<EngineError>.broadcast();
  final _exportProgress = StreamController<VideoExportProgress>.broadcast();

  BeautyParameters? _pendingParameters;
  bool _parametersInFlight = false;
  bool _disposed = false;

  Stream<FaceTrackingStatus> get faceStatus => _faceStatus.stream;

  Stream<PerformanceSample> get performance => _performance.stream;

  Stream<EngineError> get errors => _errors.stream;

  /// Progress of every running [exportVideo] call.
  Stream<VideoExportProgress> get exportProgress => _exportProgress.stream;

  Future<PreviewDescriptor> initialize(EngineConfig config) =>
      _guard(() => _host.initialize(config));

  Future<PreviewDescriptor> switchLens(CameraLens lens) =>
      _guard(() => _host.switchLens(lens));

  Future<CameraCapabilities> capabilities() => _guard(_host.getCapabilities);

  Future<void> setBeautyParameters(BeautyParameters parameters) async {
    _pendingParameters = parameters;
    if (_parametersInFlight) return;
    _parametersInFlight = true;
    try {
      while (_pendingParameters != null && !_disposed) {
        final next = _pendingParameters!;
        _pendingParameters = null;
        await _guard(() => _host.setBeautyParameters(next));
      }
    } finally {
      _parametersInFlight = false;
    }
  }

  /// Sets a 512x512 RGBA colour LUT (see [ColorLut]) or clears it with null.
  Future<void> setColorLut(Uint8List? rgba512) {
    if (rgba512 != null && rgba512.length != ColorLut.byteLength) {
      throw ArgumentError.value(
        rgba512.length,
        'rgba512',
        'must be ${ColorLut.byteLength} bytes',
      );
    }
    return _guard(() => _host.setColorLut(rgba512));
  }

  /// Runs the beauty pipeline on a photo file (independent of the camera).
  /// [maxLongEdge] 0 renders at the original size (GPU-capped).
  Future<ImageProcessingResult> processImage({
    required String inputPath,
    required String outputPath,
    required BeautyParameters parameters,
    int maxLongEdge = 0,
    Uint8List? lutRgba,
    int jpegQuality = 95,
    int maxFaces = 4,
  }) {
    if (lutRgba != null && lutRgba.length != ColorLut.byteLength) {
      throw ArgumentError.value(
        lutRgba.length,
        'lutRgba',
        'must be ${ColorLut.byteLength} bytes',
      );
    }
    if (maxLongEdge < 0) {
      throw ArgumentError.value(maxLongEdge, 'maxLongEdge', 'must be >= 0');
    }
    return _guard(
      () => _host.processImage(
        ImageProcessingRequest(
          inputPath: inputPath,
          outputPath: outputPath,
          maxLongEdge: maxLongEdge,
          parameters: parameters,
          lutRgba: lutRgba,
          jpegQuality: jpegQuality.clamp(1, 100),
          maxFaces: maxFaces.clamp(1, 4),
        ),
      ),
    );
  }

  Future<void> setFlashMode(FlashMode mode) =>
      _guard(() => _host.setFlashMode(mode));

  Future<void> setZoomRatio(double ratio) =>
      _guard(() => _host.setZoomRatio(ratio));

  Future<void> setExposureBias(double ev) =>
      _guard(() => _host.setExposureBias(ev));

  Future<PhotoCaptureResult> capturePhoto(String outputFilePath) =>
      _guard(() => _host.capturePhoto(outputFilePath));

  /// Starts recording the processed preview into [outputPath] (.mp4).
  Future<void> startRecording({
    required String outputPath,
    bool recordAudio = true,
    int videoBitrate = 0,
  }) {
    if (videoBitrate < 0) {
      throw ArgumentError.value(videoBitrate, 'videoBitrate', 'must be >= 0');
    }
    return _guard(
      () => _host.startRecording(
        VideoRecordingOptions(
          outputFilePath: outputPath,
          recordAudio: recordAudio,
          videoBitrate: videoBitrate,
        ),
      ),
    );
  }

  /// Finishes the recording and returns the playable file.
  Future<VideoRecordingResult> stopRecording() => _guard(_host.stopRecording);

  /// Overrides the screen brightness (0..1) for the front-camera screen
  /// flash; [restoreScreenBrightness] gives control back to the system.
  Future<void> setScreenBrightness(double brightness) =>
      _guard(() => _host.setScreenBrightness(brightness.clamp(0, 1)));

  Future<void> restoreScreenBrightness() =>
      _guard(() => _host.setScreenBrightness(-1));

  Future<VideoMetadata> probeVideo(String path) =>
      _guard(() => _host.probeVideo(path));

  /// [count] evenly spaced JPEG frames (long edge [maxEdge]) written into
  /// [outputDirectory], in time order.
  Future<List<String>> videoThumbnails({
    required String path,
    required String outputDirectory,
    int count = 8,
    int maxEdge = 160,
  }) {
    if (count < 1 || count > 60) {
      throw ArgumentError.value(count, 'count', 'must be 1..60');
    }
    return _guard(
      () => _host.videoThumbnails(path, count, maxEdge, outputDirectory),
    );
  }

  /// Renders an edit to [VideoExportRequest.outputPath]. Listen to
  /// [exportProgress] for progress; [cancelVideoExport] stops it with
  /// [EngineErrorCode.exportCancelled].
  Future<VideoExportResult> exportVideo(VideoExportRequest request) {
    if (request.clips.isEmpty) {
      throw ArgumentError.value(request.clips, 'clips', 'must not be empty');
    }
    final lut = request.lutRgba;
    if (lut != null && lut.length != ColorLut.byteLength) {
      throw ArgumentError.value(
        lut.length,
        'lutRgba',
        'must be ${ColorLut.byteLength} bytes',
      );
    }
    for (final clip in request.clips) {
      if (clip.speed < 0.25 || clip.speed > 4) {
        throw ArgumentError.value(clip.speed, 'speed', 'must be 0.25..4');
      }
      if (clip.endMillis <= clip.startMillis) {
        throw ArgumentError.value(
          clip.endMillis,
          'endMillis',
          'must be > startMillis',
        );
      }
    }
    return _guard(() => _host.exportVideo(request));
  }

  Future<void> cancelVideoExport(String jobId) =>
      _guard(() => _host.cancelVideoExport(jobId));

  Future<void> pause() => _guard(_host.pause);

  Future<void> resume() => _guard(_host.resume);

  /// Releases native resources. The instance can be re-initialized.
  Future<void> disposeSession() => _guard(_host.dispose);

  /// Releases native resources and closes the streams. Terminal.
  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _guard(_host.dispose);
    } finally {
      BeautyEngineEventsApi.setUp(null);
      await Future.wait([
        _faceStatus.close(),
        _performance.close(),
        _errors.close(),
        _exportProgress.close(),
      ]);
    }
  }

  @override
  void onFaceTrackingStatus(FaceTrackingStatus status) {
    if (!_faceStatus.isClosed) _faceStatus.add(status);
  }

  @override
  void onPerformanceSample(PerformanceSample sample) {
    if (!_performance.isClosed) _performance.add(sample);
  }

  @override
  void onEngineError(EngineError error) {
    if (!_errors.isClosed) _errors.add(error);
  }

  @override
  void onVideoExportProgress(String jobId, double progress) {
    if (!_exportProgress.isClosed) {
      _exportProgress.add(VideoExportProgress(jobId, progress.clamp(0, 1)));
    }
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error) {
      throw BeautyEngineException.fromPlatform(error);
    }
  }
}
