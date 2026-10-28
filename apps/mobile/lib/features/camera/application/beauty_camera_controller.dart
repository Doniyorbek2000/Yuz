import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

import '../../permissions/camera_permission_service.dart';
import '../data/beauty_preset_repository.dart';
import '../data/filter_lut_repository.dart';
import '../domain/beauty_adjustments.dart';
import '../domain/beauty_preset.dart';
import '../domain/color_filters.dart';
import 'look_editor.dart';

final beautyEngineProvider = Provider<BeautyEngine>((ref) {
  final engine = BeautyEngine();
  ref.onDispose(engine.close);
  return engine;
});

/// Returns the absolute path for a new capture.
typedef CapturePathBuilder = Future<String> Function();

final capturePathBuilderProvider = Provider<CapturePathBuilder>((ref) {
  return () async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/captures');
    await directory.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
    return '${directory.path}/YUZ_$stamp.jpg';
  };
});

/// Returns the absolute path for a new video recording.
final videoPathBuilderProvider = Provider<CapturePathBuilder>((ref) {
  return () async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/captures');
    await directory.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
    return '${directory.path}/YUZ_$stamp.mp4';
  };
});

enum CameraPhase { idle, initializing, ready, error }

enum CaptureMode { photo, video }

@immutable
class CameraViewState {
  const CameraViewState({
    this.phase = CameraPhase.idle,
    this.lens = CameraLens.front,
    this.descriptor,
    this.capabilities,
    this.errorCode,
    this.faceStatus,
    this.performance,
    this.flashMode = FlashMode.off,
    this.timerSeconds = 0,
    this.countdown,
    this.zoomRatio = 1,
    this.exposureBias = 0,
    this.isCapturing = false,
    this.lastCapture,
    this.transientError,
    this.mode = CaptureMode.photo,
    this.isRecording = false,
    this.isFinishingRecording = false,
    this.recordingSeconds = 0,
    this.recordingHasAudio,
    this.lastRecording,
    this.screenFlash = false,
  });

  final CameraPhase phase;
  final CameraLens lens;
  final PreviewDescriptor? descriptor;
  final CameraCapabilities? capabilities;
  final EngineErrorCode? errorCode;
  final FaceTrackingStatus? faceStatus;
  final PerformanceSample? performance;
  final FlashMode flashMode;
  final int timerSeconds;
  final int? countdown;
  final double zoomRatio;
  final double exposureBias;
  final bool isCapturing;
  final PhotoCaptureResult? lastCapture;

  /// Non-fatal engine notifications (e.g. thermal throttling) for a snackbar.
  final EngineErrorCode? transientError;

  final CaptureMode mode;
  final bool isRecording;

  /// stopRecording() is finishing the file.
  final bool isFinishingRecording;
  final int recordingSeconds;

  /// Whether the running recording captures sound (null when not recording).
  final bool? recordingHasAudio;
  final VideoRecordingResult? lastRecording;

  /// The screen is lit white as the front-camera flash.
  final bool screenFlash;

  /// Flash modes for the current lens: the front camera uses the screen
  /// (off/on); a back camera without a flash unit has none.
  List<FlashMode> get availableFlashModes {
    if (lens == CameraLens.front) return const [FlashMode.off, FlashMode.on];
    return (capabilities?.hasFlash ?? false)
        ? const [FlashMode.off, FlashMode.auto, FlashMode.on, FlashMode.torch]
        : const [FlashMode.off];
  }

  bool get isReady => phase == CameraPhase.ready && descriptor != null;

  /// Lens, mode and settings changes are blocked while a recording runs.
  bool get isBusy => isCapturing || isRecording || isFinishingRecording || countdown != null;

  CameraViewState copyWith({
    CameraPhase? phase,
    CameraLens? lens,
    PreviewDescriptor? descriptor,
    CameraCapabilities? capabilities,
    EngineErrorCode? errorCode,
    bool clearError = false,
    FaceTrackingStatus? faceStatus,
    PerformanceSample? performance,
    FlashMode? flashMode,
    int? timerSeconds,
    int? countdown,
    bool clearCountdown = false,
    double? zoomRatio,
    double? exposureBias,
    bool? isCapturing,
    PhotoCaptureResult? lastCapture,
    EngineErrorCode? transientError,
    bool clearTransientError = false,
    CaptureMode? mode,
    bool? isRecording,
    bool? isFinishingRecording,
    int? recordingSeconds,
    bool? recordingHasAudio,
    bool clearRecordingHasAudio = false,
    VideoRecordingResult? lastRecording,
    bool? screenFlash,
  }) => CameraViewState(
    phase: phase ?? this.phase,
    lens: lens ?? this.lens,
    descriptor: descriptor ?? this.descriptor,
    capabilities: capabilities ?? this.capabilities,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    faceStatus: faceStatus ?? this.faceStatus,
    performance: performance ?? this.performance,
    flashMode: flashMode ?? this.flashMode,
    timerSeconds: timerSeconds ?? this.timerSeconds,
    countdown: clearCountdown ? null : (countdown ?? this.countdown),
    zoomRatio: zoomRatio ?? this.zoomRatio,
    exposureBias: exposureBias ?? this.exposureBias,
    isCapturing: isCapturing ?? this.isCapturing,
    lastCapture: lastCapture ?? this.lastCapture,
    transientError: clearTransientError ? null : (transientError ?? this.transientError),
    mode: mode ?? this.mode,
    isRecording: isRecording ?? this.isRecording,
    isFinishingRecording: isFinishingRecording ?? this.isFinishingRecording,
    recordingSeconds: recordingSeconds ?? this.recordingSeconds,
    recordingHasAudio: clearRecordingHasAudio ? null : (recordingHasAudio ?? this.recordingHasAudio),
    lastRecording: lastRecording ?? this.lastRecording,
    screenFlash: screenFlash ?? this.screenFlash,
  );
}

/// Orchestrates the native engine for the camera screen: lifecycle, lens,
/// flash, zoom, exposure, timer and capture.
class BeautyCameraController extends Notifier<CameraViewState> {
  static const timerOptions = [0, 3, 10];

  /// Recordings stop automatically after this long (keeps files shareable).
  static const maxRecordingSeconds = 180;
  Timer? _recordingTimer;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _countdownTimer;
  Completer<void>? _countdownCompleter;
  bool _paused = false;

  BeautyEngine get _engine => ref.read(beautyEngineProvider);

  @override
  CameraViewState build() {
    final engine = ref.watch(beautyEngineProvider);
    _subscriptions
      ..add(engine.faceStatus.listen((status) => state = state.copyWith(faceStatus: status)))
      ..add(engine.performance.listen((sample) => state = state.copyWith(performance: sample)))
      ..add(engine.errors.listen(_onEngineError));
    ref.onDispose(() {
      for (final subscription in _subscriptions) {
        unawaited(subscription.cancel());
      }
      _subscriptions.clear();
      _countdownTimer?.cancel();
      _countdownTimer = null;
      _recordingTimer?.cancel();
      _recordingTimer = null;
      final pending = _countdownCompleter;
      if (pending != null && !pending.isCompleted) pending.complete();
      // Leaving the camera releases the native camera, GPU and detector.
      unawaited(engine.disposeSession().catchError((Object error) => debugPrint('disposeSession failed: $error')));
    });
    return const CameraViewState();
  }

  Future<void> start() async {
    if (state.phase == CameraPhase.initializing) return;
    state = state.copyWith(phase: CameraPhase.initializing, clearError: true);
    final engine = _engine;
    try {
      final descriptor = await engine.initialize(
        EngineConfig(
          lens: state.lens,
          aspectRatio: CaptureAspectRatio.ratio16x9,
          quality: PreviewQuality.high1080,
          enableFaceTracking: true,
          maxFaces: 1,
          multiFacePolicy: MultiFacePolicy.primaryFace,
        ),
      );
      if (!ref.mounted) {
        // The screen left while the camera was opening: release it again.
        await engine.disposeSession();
        return;
      }
      final capabilities = await engine.capabilities();
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: CameraPhase.ready,
        descriptor: descriptor,
        capabilities: capabilities,
        lens: descriptor.lens,
        zoomRatio: capabilities.minZoomRatio,
        exposureBias: 0,
      );
      final look = ref.read(beautyEditorProvider).current;
      await engine.setBeautyParameters(look.toEngineParameters());
      await applyFilterLut(look.filter);
      if (!state.availableFlashModes.contains(state.flashMode)) state = state.copyWith(flashMode: FlashMode.off);
      if (_nativeFlash(state.flashMode) != FlashMode.off) await engine.setFlashMode(_nativeFlash(state.flashMode));
    } on BeautyEngineException catch (error) {
      if (ref.mounted) state = state.copyWith(phase: CameraPhase.error, errorCode: error.code);
    }
  }

  int _lutRequest = 0;

  /// Uploads the LUT for [filter] (generated off the UI thread). Only the
  /// most recent request is applied when filters are switched quickly.
  Future<void> applyFilterLut(FilterId filter) async {
    final request = ++_lutRequest;
    final engine = _engine;
    final Uint8List? lut;
    try {
      lut = await ref.read(filterLutRepositoryProvider).lutFor(filter);
    } on Exception catch (error) {
      debugPrint('LUT generation failed: $error');
      return;
    }
    if (!ref.mounted || request != _lutRequest || !state.isReady) return;
    try {
      await engine.setColorLut(lut);
    } on BeautyEngineException catch (error) {
      state = state.copyWith(transientError: error.code);
    }
  }

  Future<void> onAppPaused() async {
    if (!state.isReady || _paused) return;
    _paused = true;
    _cancelCountdown();
    // Finish (not discard) a running recording before the camera stops.
    if (state.isRecording) await stopRecording();
    await _engine.pause();
  }

  Future<void> onAppResumed() async {
    if (!_paused) return;
    _paused = false;
    if (state.isReady) await _engine.resume();
  }

  Future<void> switchLens() async {
    if (!state.isReady || state.isBusy) return;
    final next = state.lens == CameraLens.front ? CameraLens.back : CameraLens.front;
    try {
      final descriptor = await _engine.switchLens(next);
      final capabilities = await _engine.capabilities();
      state = state.copyWith(
        descriptor: descriptor,
        lens: descriptor.lens,
        capabilities: capabilities,
        zoomRatio: capabilities.minZoomRatio,
        exposureBias: 0,
      );
      if (!state.availableFlashModes.contains(state.flashMode)) state = state.copyWith(flashMode: FlashMode.off);
      await _engine.setFlashMode(_nativeFlash(state.flashMode));
    } on BeautyEngineException catch (error) {
      state = state.copyWith(transientError: error.code);
    }
  }

  Future<void> cycleFlashMode() async {
    final order = state.availableFlashModes;
    if (order.length < 2 || state.isBusy) return;
    final index = order.indexOf(state.flashMode);
    final next = order[(index < 0 ? 0 : index + 1) % order.length];
    state = state.copyWith(flashMode: next);
    await _engine.setFlashMode(_nativeFlash(next));
  }

  /// The front camera's flash is the screen (driven here), never the native flash.
  FlashMode _nativeFlash(FlashMode mode) => state.lens == CameraLens.front ? FlashMode.off : mode;

  static const _screenFlashSettle = Duration(milliseconds: 400);

  void cycleTimer() {
    final index = timerOptions.indexOf(state.timerSeconds);
    state = state.copyWith(timerSeconds: timerOptions[(index + 1) % timerOptions.length]);
  }

  Future<void> setZoomRatio(double ratio) async {
    final capabilities = state.capabilities;
    if (capabilities == null) return;
    final clamped = ratio.clamp(capabilities.minZoomRatio, capabilities.maxZoomRatio);
    state = state.copyWith(zoomRatio: clamped);
    await _engine.setZoomRatio(clamped);
  }

  Future<void> setExposureBias(double ev) async {
    final capabilities = state.capabilities;
    if (capabilities == null) return;
    final clamped = ev.clamp(capabilities.minExposureBias, capabilities.maxExposureBias);
    state = state.copyWith(exposureBias: clamped);
    await _engine.setExposureBias(clamped);
  }

  /// Runs the countdown (if any) and captures. Returns null when cancelled
  /// or failed (failure is reported through [CameraViewState.transientError]).
  Future<PhotoCaptureResult?> capture() async {
    if (!state.isReady || state.isBusy) return null;
    if (state.timerSeconds > 0) {
      final completed = await _runCountdown(state.timerSeconds);
      if (!completed) return null;
    }
    state = state.copyWith(isCapturing: true);
    final screenFlash = state.lens == CameraLens.front && state.flashMode == FlashMode.on;
    try {
      if (screenFlash) {
        state = state.copyWith(screenFlash: true);
        await _engine.setScreenBrightness(1);
        // Let auto-exposure adapt to the lit face before the still is taken.
        await Future<void>.delayed(_screenFlashSettle);
      }
      final path = await ref.read(capturePathBuilderProvider)();
      final result = await _engine.capturePhoto(path);
      if (ref.mounted) state = state.copyWith(isCapturing: false, lastCapture: result);
      return result;
    } on BeautyEngineException catch (error) {
      if (ref.mounted) state = state.copyWith(isCapturing: false, transientError: error.code);
      return null;
    } finally {
      if (screenFlash) {
        unawaited(_engine.restoreScreenBrightness().catchError((Object e) => debugPrint('brightness: $e')));
        if (ref.mounted) state = state.copyWith(screenFlash: false);
      }
    }
  }

  void setMode(CaptureMode mode) {
    if (state.isBusy || state.mode == mode) return;
    state = state.copyWith(mode: mode);
  }

  /// Starts recording (after the countdown, if any). Sound is recorded when
  /// microphone access is granted; otherwise the video is silent.
  Future<bool> startRecording() async {
    if (!state.isReady || state.isBusy) return false;
    if (state.timerSeconds > 0) {
      final completed = await _runCountdown(state.timerSeconds);
      if (!completed || !ref.mounted) return false;
    }
    final withAudio = await ref.read(microphonePermissionServiceProvider).ensureGranted();
    if (!ref.mounted || !state.isReady || state.isBusy) return false;
    try {
      final path = await ref.read(videoPathBuilderProvider)();
      await _engine.startRecording(outputPath: path, recordAudio: withAudio);
    } on BeautyEngineException catch (error) {
      if (ref.mounted) state = state.copyWith(transientError: error.code);
      return false;
    }
    if (!ref.mounted) return false;
    state = state.copyWith(isRecording: true, recordingSeconds: 0, recordingHasAudio: withAudio);
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final seconds = state.recordingSeconds + 1;
      state = state.copyWith(recordingSeconds: seconds);
      if (seconds >= maxRecordingSeconds) unawaited(stopRecording());
    });
    return true;
  }

  /// Finishes the running recording; null when nothing was recorded.
  Future<VideoRecordingResult?> stopRecording() async {
    if (!state.isRecording || state.isFinishingRecording) return null;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    state = state.copyWith(isFinishingRecording: true);
    try {
      final result = await _engine.stopRecording();
      if (ref.mounted) {
        state = state.copyWith(
          isRecording: false,
          isFinishingRecording: false,
          lastRecording: result,
          clearRecordingHasAudio: true,
        );
      }
      return result;
    } on BeautyEngineException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          isRecording: false,
          isFinishingRecording: false,
          transientError: error.code,
          clearRecordingHasAudio: true,
        );
      }
      return null;
    }
  }

  void cancelCountdown() => _cancelCountdown();

  void acknowledgeTransientError() => state = state.copyWith(clearTransientError: true);

  Future<bool> _runCountdown(int seconds) {
    final completer = Completer<bool>();
    var remaining = seconds;
    state = state.copyWith(countdown: remaining);
    _countdownCompleter = Completer<void>();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining -= 1;
      if (remaining <= 0) {
        timer.cancel();
        _countdownTimer = null;
        state = state.copyWith(clearCountdown: true);
        if (!completer.isCompleted) completer.complete(true);
      } else {
        state = state.copyWith(countdown: remaining);
      }
    });
    _countdownCompleter!.future.then((_) {
      if (!completer.isCompleted) completer.complete(false);
    });
    return completer.future;
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    final pending = _countdownCompleter;
    _countdownCompleter = null;
    if (pending != null && !pending.isCompleted) pending.complete();
    if (state.countdown != null) state = state.copyWith(clearCountdown: true);
  }

  void _onEngineError(EngineError error) {
    switch (error.code) {
      case EngineErrorCode.cameraDisconnected:
      case EngineErrorCode.cameraInUse:
        state = state.copyWith(phase: CameraPhase.error, errorCode: error.code);
      default:
        state = state.copyWith(transientError: error.code);
    }
  }
}

final beautyCameraControllerProvider = NotifierProvider.autoDispose<BeautyCameraController, CameraViewState>(
  BeautyCameraController.new,
);

/// Beauty sliders, undo and presets. Pushes every change to the engine while
/// the camera is running and remembers the last look across launches.
class BeautyEditorNotifier extends Notifier<BeautyEditorState> implements LookEditor {
  BeautyPresetRepository get _repository => ref.read(beautyPresetRepositoryProvider);

  @override
  BeautyEditorState build() =>
      BeautyEditorState(current: ref.watch(beautyPresetRepositoryProvider).loadLastAdjustments());

  /// Call when a slider drag starts so the whole drag is one undo step.
  @override
  void beginEdit() => state = state.checkpoint();

  @override
  void updateLive(BeautyEffect effect, int value) {
    final next = state.current.withValue(effect, value);
    if (next == state.current) return;
    state = state.preview(next);
    _push();
  }

  @override
  Future<void> endEdit() {
    state = state.finalizeEdit();
    return _repository.saveLastAdjustments(state.current);
  }

  @override
  void applyPreset(BeautyPreset preset) => _commit(preset.adjustments);

  @override
  void selectFilter(FilterId filter) => _commit(state.current.withFilter(filter));

  @override
  void selectColor(MakeupItem item, int color) => _commit(state.current.withColor(item, color));

  @override
  void undo() {
    state = state.undo();
    _afterDiscreteChange();
  }

  @override
  void reset() {
    state = state.reset();
    _afterDiscreteChange();
  }

  void _commit(BeautyAdjustments next) {
    state = state.commit(next);
    _afterDiscreteChange();
  }

  void _afterDiscreteChange() {
    _push();
    unawaited(_repository.saveLastAdjustments(state.current));
  }

  FilterId? _pushedFilter;

  void _push() {
    final camera = ref.read(beautyCameraControllerProvider);
    if (!camera.isReady) return;
    final filter = state.current.filter;
    if (filter != _pushedFilter) {
      _pushedFilter = filter;
      unawaited(ref.read(beautyCameraControllerProvider.notifier).applyFilterLut(filter));
    }
    unawaited(
      ref
          .read(beautyEngineProvider)
          .setBeautyParameters(state.current.toEngineParameters())
          .catchError((Object error) => debugPrint('setBeautyParameters failed: $error')),
    );
  }
}

final beautyEditorProvider = NotifierProvider<BeautyEditorNotifier, BeautyEditorState>(BeautyEditorNotifier.new);

class UserPresetsNotifier extends Notifier<List<BeautyPreset>> {
  @override
  List<BeautyPreset> build() => ref.watch(beautyPresetRepositoryProvider).loadUserPresets();

  Future<BeautyPreset> save(String name, BeautyAdjustments adjustments) async {
    final preset = await ref.read(beautyPresetRepositoryProvider).saveUserPreset(name, adjustments);
    state = ref.read(beautyPresetRepositoryProvider).loadUserPresets();
    return preset;
  }

  Future<void> delete(String id) async {
    await ref.read(beautyPresetRepositoryProvider).deleteUserPreset(id);
    state = ref.read(beautyPresetRepositoryProvider).loadUserPresets();
  }
}

final userPresetsProvider = NotifierProvider<UserPresetsNotifier, List<BeautyPreset>>(UserPresetsNotifier.new);
