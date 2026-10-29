import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/api_models.dart';
import '../../../core/api/api_providers.dart';
import '../../account/application/session_controller.dart';
import '../../projects/application/photo_project_controller.dart';
import '../../projects/data/project_repository.dart';
import '../data/photo_source.dart';

enum BackgroundMode { blur, color, remove }

enum AiStage { idle, uploading, queued, running, downloading, done, failed }

/// Solid backgrounds offered in colour mode.
const backgroundSwatches = <Color>[
  Color(0xFFF5F3F7),
  Color(0xFF1B1B22),
  Color(0xFFE8A598),
  Color(0xFF9EC9F5),
  Color(0xFFB8E0C2),
  Color(0xFFF2D58A),
];

@immutable
class AiBackgroundState {
  const AiBackgroundState({
    this.sourcePath,
    this.mode = BackgroundMode.blur,
    this.color = const Color(0xFFF5F3F7),
    this.stage = AiStage.idle,
    this.jobId,
    this.resultPath,
    this.errorCode,
    this.savedToGallery = false,
  });

  final String? sourcePath;
  final BackgroundMode mode;
  final Color color;
  final AiStage stage;
  final String? jobId;
  final String? resultPath;

  /// Localized by the screen (API, worker or client code).
  final String? errorCode;
  final bool savedToGallery;

  bool get busy =>
      stage == AiStage.uploading || stage == AiStage.queued || stage == AiStage.running || stage == AiStage.downloading;

  bool get canStart => sourcePath != null && !busy;

  AiBackgroundState copyWith({
    String? sourcePath,
    BackgroundMode? mode,
    Color? color,
    AiStage? stage,
    String? jobId,
    bool clearJob = false,
    String? resultPath,
    bool clearResult = false,
    String? errorCode,
    bool clearError = false,
    bool? savedToGallery,
  }) => AiBackgroundState(
    sourcePath: sourcePath ?? this.sourcePath,
    mode: mode ?? this.mode,
    color: color ?? this.color,
    stage: stage ?? this.stage,
    jobId: clearJob ? null : (jobId ?? this.jobId),
    resultPath: clearResult ? null : (resultPath ?? this.resultPath),
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    savedToGallery: savedToGallery ?? this.savedToGallery,
  );
}

String hexColor(Color color) {
  String channel(double value) => (value * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${channel(color.r)}${channel(color.g)}${channel(color.b)}'.toUpperCase();
}

/// Timing of the job polling; overridden in tests.
@immutable
class AiPollingPolicy {
  const AiPollingPolicy({this.interval = const Duration(seconds: 2), this.maxWait = const Duration(minutes: 5)});

  final Duration interval;
  final Duration maxWait;
}

final aiPollingPolicyProvider = Provider<AiPollingPolicy>((ref) => const AiPollingPolicy());

/// Cloud background replacement: upload -> queued/running -> download.
/// The server copy of the result is deleted once it is on the device.
class AiBackgroundController extends Notifier<AiBackgroundState> {
  bool _disposed = false;

  /// Bumped on reset so a stale polling loop stops writing state.
  int _generation = 0;

  @override
  AiBackgroundState build() {
    ref.onDispose(() => _disposed = true);
    return const AiBackgroundState();
  }

  Future<void> pick(PhotoOrigin origin) async {
    if (state.busy) return;
    final path = await ref.read(photoSourceProvider).pick(origin);
    if (path == null || _disposed) return;
    _generation++;
    state = AiBackgroundState(sourcePath: path, mode: state.mode, color: state.color);
  }

  void setMode(BackgroundMode mode) {
    if (!state.busy) state = state.copyWith(mode: mode, stage: AiStage.idle, clearResult: true, clearError: true);
  }

  void setColor(Color color) {
    if (!state.busy) {
      state = state.copyWith(color: color, stage: AiStage.idle, clearResult: true, clearError: true);
    }
  }

  Future<void> start() async {
    final source = state.sourcePath;
    final api = ref.read(yuzApiProvider);
    if (source == null || state.busy || api == null) return;
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;

    state = state.copyWith(stage: AiStage.uploading, clearJob: true, clearResult: true, clearError: true);
    try {
      final bytes = await File(source).readAsBytes();
      final extension = imageExtension(bytes);
      if (extension == null) throw const ApiException('unsupported_image');
      var job = await api.createAiJob(
        type: AiJobType.background,
        image: bytes,
        filename: 'photo.$extension',
        params: {'mode': state.mode.name, if (state.mode == BackgroundMode.color) 'color': hexColor(state.color)},
      );
      if (!current()) return;
      // Credits were spent: show the new balance.
      unawaited(ref.read(sessionControllerProvider.notifier).refresh());

      final policy = ref.read(aiPollingPolicyProvider);
      final deadline = DateTime.now().add(policy.maxWait);
      while (!job.status.isFinal) {
        state = state.copyWith(
          jobId: job.id,
          stage: job.status == AiJobStatus.running ? AiStage.running : AiStage.queued,
        );
        if (DateTime.now().isAfter(deadline)) throw const ApiException('processing_timeout');
        await Future<void>.delayed(policy.interval);
        if (!current()) return;
        job = await api.aiJob(job.id);
        if (!current()) return;
      }

      switch (job.status) {
        case AiJobStatus.succeeded:
          state = state.copyWith(jobId: job.id, stage: AiStage.downloading);
          final result = await api.aiJobResult(job.id);
          if (!current()) return;
          final directory = await ref.read(aiResultDirectoryProvider)();
          final file = File('${directory.path}/background_${job.id}.${imageExtension(result) ?? 'jpg'}');
          await file.writeAsBytes(result, flush: true);
          if (!current()) return;
          state = state.copyWith(stage: AiStage.done, resultPath: file.path);
          unawaited(_deleteServerCopy(job.id));
        case AiJobStatus.cancelled:
          state = state.copyWith(stage: AiStage.failed, errorCode: 'cancelled');
        case _:
          // Failed jobs are refunded by the server.
          state = state.copyWith(stage: AiStage.failed, errorCode: job.error ?? ApiException.server);
          unawaited(ref.read(sessionControllerProvider.notifier).refresh());
      }
    } on ApiException catch (error) {
      if (current()) state = state.copyWith(stage: AiStage.failed, errorCode: error.code);
    } on FileSystemException catch (error) {
      debugPrint('AI background file error: ${error.message}');
      if (current()) state = state.copyWith(stage: AiStage.failed, errorCode: 'file_error');
    }
  }

  /// Only queued jobs can be cancelled (and are refunded).
  Future<void> cancel() async {
    final jobId = state.jobId;
    final api = ref.read(yuzApiProvider);
    if (jobId == null || api == null || state.stage != AiStage.queued) return;
    try {
      await api.deleteAiJob(jobId);
      if (_disposed) return;
      _generation++;
      state = state.copyWith(stage: AiStage.idle, clearJob: true);
      unawaited(ref.read(sessionControllerProvider.notifier).refresh());
    } on ApiException catch (error) {
      // job_running: the worker already picked it up; keep polling.
      debugPrint('Cancel refused: ${error.code}');
    }
  }

  Future<bool> saveToGallery() async {
    final path = state.resultPath;
    if (path == null) return false;
    final saved = await ref.read(gallerySaverProvider).saveImage(path);
    if (saved && !_disposed) state = state.copyWith(savedToGallery: true);
    return saved;
  }

  /// Creates a photo project from the result; returns its id.
  Future<String?> openAsProject() async {
    final path = state.resultPath;
    if (path == null) return null;
    final project = await ref.read(projectRepositoryProvider).create(path);
    return project.id;
  }

  Future<void> _deleteServerCopy(String jobId) async {
    try {
      await ref.read(yuzApiProvider)?.deleteAiJob(jobId);
    } on ApiException catch (error) {
      // The server purges it after the retention period anyway.
      debugPrint('Server copy of $jobId not deleted: ${error.code}');
    }
  }
}

final aiBackgroundControllerProvider = NotifierProvider.autoDispose<AiBackgroundController, AiBackgroundState>(
  AiBackgroundController.new,
);
