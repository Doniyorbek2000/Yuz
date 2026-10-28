import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

import '../../camera/application/beauty_camera_controller.dart' show beautyEngineProvider;
import '../../camera/application/look_editor.dart';
import '../../camera/data/filter_lut_repository.dart';
import '../../camera/domain/beauty_adjustments.dart';
import '../../camera/domain/beauty_preset.dart';
import '../../camera/domain/color_filters.dart';
import '../data/project_repository.dart';
import '../domain/photo_project.dart';

/// Long edge of the interactive beauty preview (the export uses the original size).
const kPhotoPreviewLongEdge = 1600;

@immutable
class PhotoProjectState {
  const PhotoProjectState({
    required this.look,
    this.project,
    this.previewPath,
    this.loading = true,
    this.notFound = false,
    this.rendering = false,
    this.renderError,
    this.faceTrackingAvailable,
    this.faceCount = 0,
  });

  final PhotoProject? project;
  final BeautyEditorState look;
  final String? previewPath;
  final bool loading;
  final bool notFound;
  final bool rendering;
  final EngineErrorCode? renderError;
  final bool? faceTrackingAvailable;
  final int faceCount;

  PhotoProjectState copyWith({
    PhotoProject? project,
    BeautyEditorState? look,
    String? previewPath,
    bool? loading,
    bool? notFound,
    bool? rendering,
    EngineErrorCode? renderError,
    bool clearRenderError = false,
    bool? faceTrackingAvailable,
    int? faceCount,
  }) => PhotoProjectState(
    project: project ?? this.project,
    look: look ?? this.look,
    previewPath: previewPath ?? this.previewPath,
    loading: loading ?? this.loading,
    notFound: notFound ?? this.notFound,
    rendering: rendering ?? this.rendering,
    renderError: clearRenderError ? null : (renderError ?? this.renderError),
    faceTrackingAvailable: faceTrackingAvailable ?? this.faceTrackingAvailable,
    faceCount: faceCount ?? this.faceCount,
  );
}

/// Saves exports to the system photo library.
abstract interface class GallerySaver {
  /// Returns false when access was denied or saving failed.
  Future<bool> saveImage(String path);
}

class GalGallerySaver implements GallerySaver {
  const GalGallerySaver();

  @override
  Future<bool> saveImage(String path) async {
    try {
      if (!await Gal.hasAccess(toAlbum: true) && !await Gal.requestAccess(toAlbum: true)) return false;
      await Gal.putImage(path, album: 'Yuz');
      return true;
    } on GalException catch (error) {
      debugPrint('Gallery save failed: ${error.type}');
      return false;
    }
  }
}

final gallerySaverProvider = Provider<GallerySaver>((ref) => const GalGallerySaver());

/// One open photo project: look editing (shared studio UI via [LookEditor]),
/// coalesced preview rendering, full-resolution rendering and exports.
class PhotoProjectController extends Notifier<PhotoProjectState> implements LookEditor {
  PhotoProjectController(this.projectId);

  final String projectId;

  bool _renderRunning = false;
  bool _renderDirty = false;
  int _previewVersion = 0;
  Timer? _saveTimer;

  /// Project waiting for the debounced save; flushed on dispose (where
  /// Riverpod forbids reading `state` or `ref`).
  PhotoProject? _unsaved;

  ProjectRepository get _repository => ref.read(projectRepositoryProvider);

  @override
  PhotoProjectState build() {
    final repository = _repository;
    ref.onDispose(() {
      _saveTimer?.cancel();
      final unsaved = _unsaved;
      if (unsaved != null) unawaited(repository.save(unsaved));
    });
    Future.microtask(_load);
    return PhotoProjectState(look: BeautyEditorState(current: BeautyAdjustments.defaults));
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
    _scheduleRender();
  }

  // region LookEditor

  @override
  void beginEdit() => state = state.copyWith(look: state.look.checkpoint());

  @override
  void updateLive(BeautyEffect effect, int value) {
    final next = state.look.current.withValue(effect, value);
    if (next == state.look.current) return;
    state = state.copyWith(look: state.look.preview(next));
    _scheduleRender();
  }

  @override
  Future<void> endEdit() async {
    state = state.copyWith(look: state.look.finalizeEdit());
    _schedulePersist();
  }

  @override
  void applyPreset(BeautyPreset preset) => _commit(preset.adjustments);

  @override
  void selectFilter(FilterId filter) => _commit(state.look.current.withFilter(filter));

  @override
  void selectColor(MakeupItem item, int color) => _commit(state.look.current.withColor(item, color));

  @override
  void undo() => _afterDiscreteChange(state.look.undo());

  @override
  void reset() => _afterDiscreteChange(state.look.reset());

  // endregion

  /// Re-renders after a new custom LUT was imported for the same filter id.
  Future<void> reapplyCustomLut() async => _scheduleRender();

  void _commit(BeautyAdjustments next) => _afterDiscreteChange(state.look.commit(next));

  void _afterDiscreteChange(BeautyEditorState next) {
    state = state.copyWith(look: next);
    _scheduleRender();
    _schedulePersist();
  }

  void _schedulePersist() {
    final project = state.project;
    if (project == null) return;
    _unsaved = project.copyWith(look: state.look.current);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      final unsaved = _unsaved;
      if (unsaved != null && ref.mounted) unawaited(_persist(unsaved));
    });
  }

  Future<void> _persist(PhotoProject project) async {
    _saveTimer?.cancel();
    _unsaved = null;
    final saved = await _repository.save(project);
    if (ref.mounted) state = state.copyWith(project: saved);
  }

  /// Latest-wins: while a render runs, further requests collapse into one.
  void _scheduleRender() {
    _renderDirty = true;
    if (!_renderRunning) unawaited(_renderLoop());
  }

  Future<void> _renderLoop() async {
    _renderRunning = true;
    try {
      while (_renderDirty && ref.mounted) {
        _renderDirty = false;
        final project = state.project;
        if (project == null) return;
        state = state.copyWith(rendering: true);
        final look = state.look.current;
        final files = await _repository.filesFor(project);
        final output = files.preview(++_previewVersion);
        try {
          final result = await ref
              .read(beautyEngineProvider)
              .processImage(
                inputPath: files.original.path,
                outputPath: output.path,
                parameters: look.toEngineParameters(),
                lutRgba: await ref.read(filterLutRepositoryProvider).lutFor(look.filter),
                maxLongEdge: kPhotoPreviewLongEdge,
                jpegQuality: 90,
              );
          if (!ref.mounted) return;
          state = state.copyWith(
            previewPath: result.outputPath,
            faceTrackingAvailable: result.faceTrackingAvailable,
            faceCount: result.faceCount,
            clearRenderError: true,
          );
        } on BeautyEngineException catch (error) {
          if (ref.mounted) state = state.copyWith(renderError: error.code);
        }
      }
    } finally {
      _renderRunning = false;
      if (ref.mounted) state = state.copyWith(rendering: false);
    }
  }

  /// Renders the look at the original resolution for the editor (cached per look).
  Future<File> prepareFullResolution() async {
    final project = state.project!.copyWith(look: state.look.current);
    final files = await _repository.filesFor(project);
    final lookKey = jsonEncode(project.look.toJson());
    if (project.fullRenderLookKey == lookKey && await files.beautyFull.exists()) {
      await _persist(project);
      return files.beautyFull;
    }
    final result = await ref
        .read(beautyEngineProvider)
        .processImage(
          inputPath: files.original.path,
          outputPath: files.beautyFull.path,
          parameters: project.look.toEngineParameters(),
          lutRgba: await ref.read(filterLutRepositoryProvider).lutFor(project.look.filter),
          jpegQuality: 97,
        );
    await _persist(
      project.copyWith(fullRenderLookKey: lookKey, sourceWidth: result.sourceWidth, sourceHeight: result.sourceHeight),
    );
    return files.beautyFull;
  }

  Future<void> saveEditorHistory(String historyJson) async {
    final project = state.project;
    if (project == null) return;
    await _persist(project.copyWith(editorHistory: historyJson, look: state.look.current));
  }

  /// Stores the final JPEG in the project and the system gallery.
  /// Returns the exported file and whether the gallery accepted it.
  Future<(File, bool)> saveExport(Uint8List jpeg, String? historyJson) async {
    final project = state.project!;
    final files = await _repository.filesFor(project);
    await files.exports.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
    final name = 'YUZ_$stamp.jpg';
    final file = File('${files.exports.path}/$name');
    await file.writeAsBytes(jpeg, flush: true);
    await _persist(project.copyWith(lastExportFileName: name, editorHistory: historyJson, look: state.look.current));
    final savedToGallery = await ref.read(gallerySaverProvider).saveImage(file.path);
    return (file, savedToGallery);
  }
}

final photoProjectControllerProvider = NotifierProvider.autoDispose
    .family<PhotoProjectController, PhotoProjectState, String>(PhotoProjectController.new);

/// Saved projects, newest first.
final projectsListProvider = FutureProvider.autoDispose<List<PhotoProject>>(
  (ref) => ref.watch(projectRepositoryProvider).list(),
);
