import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

import '../../camera/application/beauty_camera_controller.dart' show beautyEngineProvider;
import '../../camera/application/look_editor.dart';
import '../../camera/data/filter_lut_repository.dart';
import '../../camera/domain/beauty_adjustments.dart';
import '../../camera/domain/beauty_preset.dart';
import '../../camera/domain/color_filters.dart';
import '../data/video_project_repository.dart';
import '../domain/video_project.dart';
import '../presentation/overlay_painter.dart';

enum VideoExportPhase { idle, running, done, failed }

@immutable
class VideoExportState {
  const VideoExportState({this.phase = VideoExportPhase.idle, this.progress = 0, this.result, this.error});

  final VideoExportPhase phase;
  final double progress;
  final VideoExportResult? result;
  final EngineErrorCode? error;
}

@immutable
class VideoEditorState {
  const VideoEditorState({
    required this.look,
    this.project,
    this.loading = true,
    this.notFound = false,
    this.selectedClip = 0,
    this.selectedOverlayId,
    this.thumbnails = const {},
    this.lookPreviewPath,
    this.lookPreviewRendering = false,
    this.busy = false,
    this.export = const VideoExportState(),
    this.error,
  });

  final VideoProject? project;
  final BeautyEditorState look;
  final bool loading;
  final bool notFound;
  final int selectedClip;
  final String? selectedOverlayId;

  /// Timeline frames per clip id.
  final Map<String, List<String>> thumbnails;
  final String? lookPreviewPath;
  final bool lookPreviewRendering;

  /// A clip or music import is running.
  final bool busy;
  final VideoExportState export;

  /// Last non-fatal failure (import, preview) for a snackbar.
  final EngineErrorCode? error;

  VideoClip? get clip {
    final clips = project?.clips;
    if (clips == null || clips.isEmpty) return null;
    return clips[selectedClip.clamp(0, clips.length - 1)];
  }

  VideoOverlayItem? get selectedOverlay => project?.overlays.where((o) => o.id == selectedOverlayId).firstOrNull;

  VideoEditorState copyWith({
    VideoProject? project,
    BeautyEditorState? look,
    bool? loading,
    bool? notFound,
    int? selectedClip,
    String? selectedOverlayId,
    bool clearSelectedOverlay = false,
    Map<String, List<String>>? thumbnails,
    String? lookPreviewPath,
    bool? lookPreviewRendering,
    bool? busy,
    VideoExportState? export,
    EngineErrorCode? error,
    bool clearError = false,
  }) => VideoEditorState(
    project: project ?? this.project,
    look: look ?? this.look,
    loading: loading ?? this.loading,
    notFound: notFound ?? this.notFound,
    selectedClip: selectedClip ?? this.selectedClip,
    selectedOverlayId: clearSelectedOverlay ? null : (selectedOverlayId ?? this.selectedOverlayId),
    thumbnails: thumbnails ?? this.thumbnails,
    lookPreviewPath: lookPreviewPath ?? this.lookPreviewPath,
    lookPreviewRendering: lookPreviewRendering ?? this.lookPreviewRendering,
    busy: busy ?? this.busy,
    export: export ?? this.export,
    error: clearError ? null : (error ?? this.error),
  );
}

/// One open video project: clips, trims, speed, look (shared studio UI via
/// [LookEditor]), overlays, sound and export.
class VideoEditorController extends Notifier<VideoEditorState> implements LookEditor {
  VideoEditorController(this.projectId);

  final String projectId;

  static const thumbnailCount = 8;
  static const _lookPreviewEdge = 1080;

  Timer? _saveTimer;
  VideoProject? _unsaved;
  int _overlayCounter = 0;
  bool _previewRunning = false;
  bool _previewDirty = false;
  int _previewVersion = 0;
  String? _exportJob;
  StreamSubscription<VideoExportProgress>? _progressSubscription;

  VideoProjectRepository get _repository => ref.read(videoProjectRepositoryProvider);

  BeautyEngine get _engine => ref.read(beautyEngineProvider);

  @override
  VideoEditorState build() {
    final repository = _repository;
    final engine = _engine;
    ref.onDispose(() {
      _saveTimer?.cancel();
      final unsaved = _unsaved;
      if (unsaved != null) {
        unawaited(
          repository
              .save(unsaved)
              .then<void>((_) {}, onError: (Object error) => debugPrint('Final save failed: $error')),
        );
      }
      unawaited(_progressSubscription?.cancel());
      final job = _exportJob;
      if (job != null) unawaited(engine.cancelVideoExport(job).catchError((Object _) {}));
    });
    Future.microtask(_load);
    return VideoEditorState(look: BeautyEditorState(current: BeautyAdjustments.defaults));
  }

  Future<void> _load() async {
    final project = await _repository.load(projectId);
    if (!ref.mounted) return;
    if (project == null) {
      state = state.copyWith(loading: false, notFound: true);
      return;
    }
    state = state.copyWith(
      project: project,
      look: BeautyEditorState(current: project.look),
      loading: false,
    );
    for (final clip in project.clips) {
      unawaited(_loadThumbnails(clip));
    }
    _scheduleLookPreview();
  }

  // region Clips

  void selectClip(int index) {
    final project = state.project;
    if (project == null || index < 0 || index >= project.clips.length) return;
    state = state.copyWith(selectedClip: index);
    _scheduleLookPreview();
  }

  /// Imports another video at the end of the timeline.
  Future<bool> addClip(String path) async {
    final project = state.project;
    if (project == null || state.busy) return false;
    state = state.copyWith(busy: true);
    try {
      final probe = await _probe(path);
      final clip = await _repository.importClip(project, path, probe);
      if (!ref.mounted) return false;
      final current = state.project!;
      _update(current.copyWith(clips: [...current.clips, clip]), selectedClip: current.clips.length);
      unawaited(_loadThumbnails(clip));
      _scheduleLookPreview();
      return true;
    } on BeautyEngineException catch (error) {
      if (ref.mounted) state = state.copyWith(error: error.code);
      return false;
    } on FileSystemException catch (error) {
      debugPrint('Clip import failed: $error');
      if (ref.mounted) state = state.copyWith(error: EngineErrorCode.captureFailed);
      return false;
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  /// The last clip cannot be removed (delete the project instead).
  void removeClip(int index) {
    final project = state.project;
    if (project == null || project.clips.length <= 1 || index < 0 || index >= project.clips.length) return;
    final clips = [...project.clips]..removeAt(index);
    final next = project.copyWith(clips: clips, overlays: _clampOverlays(project.overlays, clips));
    _update(next, selectedClip: (state.selectedClip >= clips.length ? clips.length - 1 : state.selectedClip));
    unawaited(_repository.removeUnusedClips(next));
    _scheduleLookPreview();
  }

  void moveClip(int from, int to) {
    final project = state.project;
    if (project == null) return;
    final clips = [...project.clips];
    if (from < 0 || from >= clips.length) return;
    final target = to.clamp(0, clips.length - 1);
    final clip = clips.removeAt(from);
    clips.insert(target, clip);
    _update(project.copyWith(clips: clips), selectedClip: target);
  }

  void trimSelected(int startMillis, int endMillis) {
    final project = state.project;
    final clip = state.clip;
    if (project == null || clip == null) return;
    _replaceClip(project, clip.trimmed(startMillis, endMillis));
  }

  void setSpeed(double speed) {
    final project = state.project;
    final clip = state.clip;
    if (project == null || clip == null || !kVideoSpeeds.contains(speed)) return;
    _replaceClip(project, clip.copyWith(speed: speed));
  }

  void _replaceClip(VideoProject project, VideoClip updated) {
    final clips = [for (final c in project.clips) c.id == updated.id ? updated : c];
    _update(project.copyWith(clips: clips, overlays: _clampOverlays(project.overlays, clips)));
  }

  /// Keeps overlay windows inside the (possibly shorter) timeline.
  List<VideoOverlayItem> _clampOverlays(List<VideoOverlayItem> overlays, List<VideoClip> clips) {
    final total = clips.fold(0, (sum, c) => sum + c.outputMillis);
    return [
      for (final overlay in overlays)
        if (overlay.startMillis < total - 100)
          overlay.copyWith(endMillis: overlay.endMillis.clamp(overlay.startMillis + 100, total)),
    ];
  }

  // endregion

  // region Overlays

  VideoOverlayItem addText(String text, {required int color, required int atMillis}) =>
      _addOverlay(OverlayKind.text, text.trim(), color, atMillis);

  VideoOverlayItem addSticker(String stickerId, {required int atMillis}) =>
      _addOverlay(OverlayKind.sticker, stickerId, 0xFFFFFFFF, atMillis);

  VideoOverlayItem _addOverlay(OverlayKind kind, String value, int color, int atMillis) {
    final project = state.project!;
    final total = project.durationMillis;
    final start = atMillis.clamp(0, (total - 500).clamp(0, total));
    final item = VideoOverlayItem(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_overlayCounter++}',
      kind: kind,
      value: value.isEmpty ? '…' : value,
      startMillis: start,
      // By default visible until the end of the video.
      endMillis: total,
      color: color,
      scale: kind == OverlayKind.sticker ? 0.14 : 0.07,
    );
    _update(project.copyWith(overlays: [...project.overlays, item]), selectedOverlayId: item.id);
    return item;
  }

  void selectOverlay(String? id) =>
      state = id == null ? state.copyWith(clearSelectedOverlay: true) : state.copyWith(selectedOverlayId: id);

  /// Live change (drag, pinch); persisted with the usual debounce.
  void updateOverlay(VideoOverlayItem item) {
    final project = state.project;
    if (project == null) return;
    final total = project.durationMillis;
    final start = item.startMillis.clamp(0, (total - 100).clamp(0, total));
    final bounded = item.copyWith(startMillis: start, endMillis: item.endMillis.clamp(start + 100, total));
    _update(project.copyWith(overlays: [for (final o in project.overlays) o.id == item.id ? bounded : o]));
  }

  void removeOverlay(String id) {
    final project = state.project;
    if (project == null) return;
    _update(
      project.copyWith(overlays: project.overlays.where((o) => o.id != id).toList()),
      clearSelectedOverlay: state.selectedOverlayId == id,
    );
  }

  // endregion

  // region Sound

  Future<bool> setMusic(String path) async {
    final project = state.project;
    if (project == null || state.busy) return false;
    state = state.copyWith(busy: true);
    try {
      final name = await _repository.importMusic(project, path);
      if (!ref.mounted) return false;
      _update(state.project!.copyWith(musicFileName: name));
      return true;
    } on FileSystemException catch (error) {
      debugPrint('Music import failed: $error');
      if (ref.mounted) state = state.copyWith(error: EngineErrorCode.captureFailed);
      return false;
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  Future<void> clearMusic() async {
    final project = state.project;
    if (project == null) return;
    final music = (await _repository.filesFor(project.id)).music(project);
    _update(state.project!.copyWith(clearMusic: true));
    if (music != null && await music.exists()) await music.delete();
  }

  void setMusicVolume(double volume) => _updateIfLoaded((p) => p.copyWith(musicVolume: volume));

  void setOriginalVolume(double volume) => _updateIfLoaded((p) => p.copyWith(originalVolume: volume));

  void setApplyBeauty(bool apply) {
    _updateIfLoaded((p) => p.copyWith(applyBeauty: apply));
    _scheduleLookPreview();
  }

  // endregion

  // region LookEditor

  @override
  void beginEdit() => state = state.copyWith(look: state.look.checkpoint());

  @override
  void updateLive(BeautyEffect effect, int value) {
    final next = state.look.current.withValue(effect, value);
    if (next == state.look.current) return;
    state = state.copyWith(look: state.look.preview(next));
    _scheduleLookPreview();
  }

  @override
  Future<void> endEdit() async {
    state = state.copyWith(look: state.look.finalizeEdit());
    _updateIfLoaded((p) => p.copyWith(look: state.look.current));
  }

  @override
  void applyPreset(BeautyPreset preset) => _commitLook(state.look.commit(preset.adjustments));

  @override
  void selectFilter(FilterId filter) => _commitLook(state.look.commit(state.look.current.withFilter(filter)));

  @override
  void selectColor(MakeupItem item, int color) =>
      _commitLook(state.look.commit(state.look.current.withColor(item, color)));

  @override
  void undo() => _commitLook(state.look.undo());

  @override
  void reset() => _commitLook(state.look.reset());

  /// Re-renders after a new custom LUT was imported for the same filter id.
  Future<void> reapplyCustomLut() async => _scheduleLookPreview();

  void _commitLook(BeautyEditorState next) {
    state = state.copyWith(look: next);
    _updateIfLoaded((p) => p.copyWith(look: next.current));
    _scheduleLookPreview();
  }

  // endregion

  // region Export

  /// Renders the edit; returns null when it failed or was cancelled
  /// (see [VideoEditorState.export]).
  Future<VideoExportResult?> export() async {
    final project = state.project;
    if (project == null || state.export.phase == VideoExportPhase.running) return null;
    _flushPersist();
    final job = '${project.id}-${DateTime.now().millisecondsSinceEpoch}';
    _exportJob = job;
    state = state.copyWith(export: const VideoExportState(phase: VideoExportPhase.running));
    _progressSubscription = _engine.exportProgress.where((p) => p.jobId == job).listen((p) {
      if (ref.mounted && _exportJob == job) {
        state = state.copyWith(
          export: VideoExportState(phase: VideoExportPhase.running, progress: p.progress),
        );
      }
    });
    try {
      final files = await _repository.filesFor(project.id);
      final (width, height) = videoOutputSize(project.clips.first);
      if (await files.overlays.exists()) await files.overlays.delete(recursive: true);
      final overlays = <VideoOverlaySpec>[];
      for (final item in project.overlays) {
        final png = await renderOverlayPng(item, width, height, File('${files.overlays.path}/${item.id}.png'));
        overlays.add(VideoOverlaySpec(imagePath: png.path, startMillis: item.startMillis, endMillis: item.endMillis));
      }
      await files.exports.create(recursive: true);
      final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
      final name = 'YUZ_$stamp.mp4';
      final look = project.look;
      final music = files.music(project);
      final result = await _engine.exportVideo(
        VideoExportRequest(
          jobId: job,
          clips: [
            for (final clip in project.clips)
              VideoClipSpec(
                path: files.clip(clip).path,
                startMillis: clip.startMillis,
                endMillis: clip.endMillis,
                speed: clip.speed,
              ),
          ],
          outputPath: '${files.exports.path}/$name',
          parameters: look.toEngineParameters(),
          lutRgba: await ref.read(filterLutRepositoryProvider).lutFor(look.filter),
          applyBeauty: project.applyBeauty,
          overlays: overlays,
          musicPath: music != null && await music.exists() ? music.path : null,
          musicVolume: project.musicVolume,
          originalVolume: project.originalVolume,
          maxLongEdge: 1920,
        ),
      );
      if (!ref.mounted) return result;
      _update(state.project!.copyWith(lastExportFileName: name));
      _flushPersist();
      state = state.copyWith(
        export: VideoExportState(phase: VideoExportPhase.done, progress: 1, result: result),
      );
      return result;
    } on BeautyEngineException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          export: error.code == EngineErrorCode.exportCancelled
              ? const VideoExportState()
              : VideoExportState(phase: VideoExportPhase.failed, error: error.code),
        );
      }
      return null;
    } on FileSystemException catch (error) {
      debugPrint('Export preparation failed: $error');
      if (ref.mounted) {
        state = state.copyWith(
          export: const VideoExportState(phase: VideoExportPhase.failed, error: EngineErrorCode.recordingFailed),
        );
      }
      return null;
    } finally {
      _exportJob = null;
      await _progressSubscription?.cancel();
      _progressSubscription = null;
    }
  }

  Future<void> cancelExport() async {
    final job = _exportJob;
    if (job != null) await _engine.cancelVideoExport(job);
  }

  void acknowledgeExport() => state = state.copyWith(export: const VideoExportState());

  void acknowledgeError() => state = state.copyWith(clearError: true);

  // endregion

  Future<VideoProbeResult> _probe(String path) async {
    final metadata = await _engine.probeVideo(path);
    return (
      durationMillis: metadata.durationMillis,
      width: metadata.width,
      height: metadata.height,
      hasAudio: metadata.hasAudio,
    );
  }

  Future<void> _loadThumbnails(VideoClip clip) async {
    try {
      final files = await _repository.filesFor(projectId);
      final directory = files.thumbnailsFor(clip);
      var paths = <String>[];
      if (await directory.exists()) {
        paths = [
          for (var i = 0; i < thumbnailCount; i++)
            if (await File('${directory.path}/thumb_$i.jpg').exists()) '${directory.path}/thumb_$i.jpg',
        ];
      }
      if (paths.length < thumbnailCount) {
        paths = await _engine.videoThumbnails(
          path: files.clip(clip).path,
          outputDirectory: directory.path,
          count: thumbnailCount,
        );
      }
      if (ref.mounted) state = state.copyWith(thumbnails: {...state.thumbnails, clip.id: paths});
    } on BeautyEngineException catch (error) {
      debugPrint('Thumbnails failed for ${clip.id}: ${error.message}');
    } on FileSystemException catch (error) {
      debugPrint('Thumbnails failed for ${clip.id}: $error');
    }
  }

  /// Latest-wins render of the selected clip's middle frame with the look.
  void _scheduleLookPreview() {
    _previewDirty = true;
    if (!_previewRunning) unawaited(_previewLoop());
  }

  Future<void> _previewLoop() async {
    _previewRunning = true;
    try {
      while (_previewDirty && ref.mounted) {
        _previewDirty = false;
        final project = state.project;
        final clip = state.clip;
        if (project == null || clip == null) return;
        state = state.copyWith(lookPreviewRendering: true);
        final files = await _repository.filesFor(project.id);
        await files.previews.create(recursive: true);
        final frameDirectory = Directory('${files.previews.path}/frame_${clip.id}');
        final frame = File('${frameDirectory.path}/thumb_0.jpg');
        try {
          if (!await frame.exists()) {
            await _engine.videoThumbnails(
              path: files.clip(clip).path,
              outputDirectory: frameDirectory.path,
              count: 1,
              maxEdge: _lookPreviewEdge,
            );
          }
          final look = state.look.current;
          final output = File('${files.previews.path}/look_${++_previewVersion % 2}.jpg');
          final parameters = project.applyBeauty ? look.toEngineParameters() : _colorOnly(look);
          final result = await _engine.processImage(
            inputPath: frame.path,
            outputPath: output.path,
            parameters: parameters,
            lutRgba: await ref.read(filterLutRepositoryProvider).lutFor(look.filter),
            maxLongEdge: _lookPreviewEdge,
            jpegQuality: 88,
          );
          if (ref.mounted) state = state.copyWith(lookPreviewPath: result.outputPath);
        } on BeautyEngineException catch (error) {
          debugPrint('Look preview failed: ${error.message}');
        }
      }
    } finally {
      _previewRunning = false;
      if (ref.mounted) state = state.copyWith(lookPreviewRendering: false);
    }
  }

  /// Only the colour look (filter + sharpen), as the exporter applies it when beauty is off.
  BeautyParameters _colorOnly(BeautyAdjustments look) {
    final full = look.toEngineParameters();
    return neutralBeautyParameters()
      ..filterIntensity = full.filterIntensity
      ..sharpen = full.sharpen;
  }

  void _updateIfLoaded(VideoProject Function(VideoProject) change) {
    final project = state.project;
    if (project != null) _update(change(project));
  }

  void _update(
    VideoProject project, {
    int? selectedClip,
    String? selectedOverlayId,
    bool clearSelectedOverlay = false,
  }) {
    state = state.copyWith(
      project: project,
      selectedClip: selectedClip,
      selectedOverlayId: selectedOverlayId,
      clearSelectedOverlay: clearSelectedOverlay,
    );
    _unsaved = project;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _flushPersist);
  }

  void _flushPersist() {
    _saveTimer?.cancel();
    final unsaved = _unsaved;
    _unsaved = null;
    if (unsaved == null || !ref.mounted) return;
    unawaited(
      _repository.save(unsaved).catchError((Object error) {
        debugPrint('Saving video project failed: $error');
        return unsaved;
      }),
    );
  }
}

final videoEditorControllerProvider = NotifierProvider.autoDispose
    .family<VideoEditorController, VideoEditorState, String>(VideoEditorController.new);

/// Saved video projects, newest first.
final videoProjectsListProvider = FutureProvider.autoDispose<List<VideoProject>>(
  (ref) => ref.watch(videoProjectRepositoryProvider).list(),
);
