import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

import '../data/beauty_preset_repository.dart';
import '../domain/beauty_adjustments.dart';
import '../domain/beauty_preset.dart';

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

enum CameraPhase { idle, initializing, ready, error }

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

  bool get isReady => phase == CameraPhase.ready && descriptor != null;

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
  );
}

/// Orchestrates the native engine for the camera screen: lifecycle, lens,
/// flash, zoom, exposure, timer and capture.
class BeautyCameraController extends Notifier<CameraViewState> {
  static const timerOptions = [0, 3, 10];

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
      await _engine.setBeautyParameters(ref.read(beautyEditorProvider).current.toEngineParameters());
      if (state.flashMode != FlashMode.off) await _engine.setFlashMode(state.flashMode);
    } on BeautyEngineException catch (error) {
      if (ref.mounted) state = state.copyWith(phase: CameraPhase.error, errorCode: error.code);
    }
  }

  Future<void> onAppPaused() async {
    if (!state.isReady || _paused) return;
    _paused = true;
    _cancelCountdown();
    await _engine.pause();
  }

  Future<void> onAppResumed() async {
    if (!_paused) return;
    _paused = false;
    if (state.isReady) await _engine.resume();
  }

  Future<void> switchLens() async {
    if (!state.isReady || state.isCapturing) return;
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
    } on BeautyEngineException catch (error) {
      state = state.copyWith(transientError: error.code);
    }
  }

  Future<void> cycleFlashMode() async {
    final hasFlash = state.capabilities?.hasFlash ?? false;
    if (!hasFlash) return;
    const order = [FlashMode.off, FlashMode.auto, FlashMode.on, FlashMode.torch];
    final next = order[(order.indexOf(state.flashMode) + 1) % order.length];
    state = state.copyWith(flashMode: next);
    await _engine.setFlashMode(next);
  }

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
    if (!state.isReady || state.isCapturing || state.countdown != null) return null;
    if (state.timerSeconds > 0) {
      final completed = await _runCountdown(state.timerSeconds);
      if (!completed) return null;
    }
    state = state.copyWith(isCapturing: true);
    try {
      final path = await ref.read(capturePathBuilderProvider)();
      final result = await _engine.capturePhoto(path);
      state = state.copyWith(isCapturing: false, lastCapture: result);
      return result;
    } on BeautyEngineException catch (error) {
      state = state.copyWith(isCapturing: false, transientError: error.code);
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
class BeautyEditorNotifier extends Notifier<BeautyEditorState> {
  BeautyPresetRepository get _repository => ref.read(beautyPresetRepositoryProvider);

  @override
  BeautyEditorState build() =>
      BeautyEditorState(current: ref.watch(beautyPresetRepositoryProvider).loadLastAdjustments());

  /// Call when a slider drag starts so the whole drag is one undo step.
  void beginEdit() => state = state.checkpoint();

  void updateLive(BeautyEffect effect, int value) {
    final next = state.current.withValue(effect, value);
    if (next == state.current) return;
    state = state.preview(next);
    _push();
  }

  Future<void> endEdit() {
    state = state.finalizeEdit();
    return _repository.saveLastAdjustments(state.current);
  }

  void applyPreset(BeautyPreset preset) {
    state = state.commit(preset.adjustments);
    _push();
    unawaited(_repository.saveLastAdjustments(state.current));
  }

  void undo() {
    state = state.undo();
    _push();
    unawaited(_repository.saveLastAdjustments(state.current));
  }

  void reset() {
    state = state.reset();
    _push();
    unawaited(_repository.saveLastAdjustments(state.current));
  }

  void _push() {
    final camera = ref.read(beautyCameraControllerProvider);
    if (!camera.isReady) return;
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
