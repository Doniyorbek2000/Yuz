import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

import '../../camera/application/beauty_camera_controller.dart' show beautyEngineProvider;
import '../../projects/application/photo_project_controller.dart';
import '../domain/template_layout.dart';
import '../presentation/template_painter.dart';

/// Working directory for normalized slot photos and exports; overridable in tests.
final templateDirectoryProvider = Provider<Future<Directory> Function()>((ref) {
  return () async => Directory('${(await getApplicationDocumentsDirectory()).path}/templates');
});

@immutable
class TemplateEditorState {
  const TemplateEditorState({
    required this.layout,
    this.style = const TemplateStyle(),
    this.images = const {},
    this.transforms = const {},
    this.selectedSlot,
    this.loadingSlot,
    this.saving = false,
    this.error,
  });

  final TemplateLayout layout;
  final TemplateStyle style;
  final Map<int, ui.Image> images;
  final Map<int, SlotTransform> transforms;
  final int? selectedSlot;

  /// Slot whose photo is being prepared.
  final int? loadingSlot;
  final bool saving;
  final EngineErrorCode? error;

  bool get isComplete => List.generate(layout.slots.length, (i) => images.containsKey(i)).every((filled) => filled);

  TemplateEditorState copyWith({
    TemplateLayout? layout,
    TemplateStyle? style,
    Map<int, ui.Image>? images,
    Map<int, SlotTransform>? transforms,
    int? selectedSlot,
    bool clearSelectedSlot = false,
    int? loadingSlot,
    bool clearLoadingSlot = false,
    bool? saving,
    EngineErrorCode? error,
    bool clearError = false,
  }) => TemplateEditorState(
    layout: layout ?? this.layout,
    style: style ?? this.style,
    images: images ?? this.images,
    transforms: transforms ?? this.transforms,
    selectedSlot: clearSelectedSlot ? null : (selectedSlot ?? this.selectedSlot),
    loadingSlot: clearLoadingSlot ? null : (loadingSlot ?? this.loadingSlot),
    saving: saving ?? this.saving,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Builds one collage: layout, style, a photo per slot with pan/zoom, export.
class TemplateEditorController extends Notifier<TemplateEditorState> {
  static const slotLongEdge = 2048;

  int _requests = 0;

  /// Decoded images this controller owns (Riverpod forbids reading `state` in onDispose).
  final Set<ui.Image> _owned = {};

  @override
  TemplateEditorState build() {
    ref.onDispose(() {
      for (final image in _owned) {
        image.dispose();
      }
      _owned.clear();
    });
    return TemplateEditorState(layout: kTemplateLayouts.first);
  }

  void _release(ui.Image? image) {
    if (image != null && _owned.remove(image)) image.dispose();
  }

  /// Keeps photos of slots that still exist in the new layout.
  void selectLayout(TemplateLayout layout) {
    final kept = <int, ui.Image>{};
    for (final MapEntry(:key, :value) in state.images.entries) {
      if (key < layout.slots.length) {
        kept[key] = value;
      } else {
        _release(value);
      }
    }
    state = state.copyWith(
      layout: layout,
      images: kept,
      transforms: {
        for (final entry in state.transforms.entries)
          if (entry.key < layout.slots.length) entry.key: entry.value,
      },
      clearSelectedSlot: true,
    );
  }

  void selectSlot(int? slot) =>
      state = slot == null ? state.copyWith(clearSelectedSlot: true) : state.copyWith(selectedSlot: slot);

  /// Normalizes [path] (EXIF orientation, HEIC, size) natively and puts it in [slot].
  Future<bool> setPhoto(int slot, String path) async {
    if (slot < 0 || slot >= state.layout.slots.length) return false;
    final request = ++_requests;
    state = state.copyWith(loadingSlot: slot, selectedSlot: slot);
    try {
      final directory = await ref.read(templateDirectoryProvider)();
      await directory.create(recursive: true);
      final output = File('${directory.path}/slot_${slot}_$request.jpg');
      await ref
          .read(beautyEngineProvider)
          .processImage(
            inputPath: path,
            outputPath: output.path,
            parameters: neutralBeautyParameters(),
            maxLongEdge: slotLongEdge,
            jpegQuality: 92,
          );
      final image = await decodeSlotImage(output, maxEdge: slotLongEdge);
      if (!ref.mounted) {
        image.dispose();
        return false;
      }
      _owned.add(image);
      final previous = state.images[slot];
      state = state.copyWith(
        images: {...state.images, slot: image},
        transforms: {...state.transforms, slot: const SlotTransform()},
        clearLoadingSlot: true,
      );
      _release(previous);
      unawaited(output.delete().then((_) {}, onError: (Object _) {}));
      return true;
    } on BeautyEngineException catch (error) {
      if (ref.mounted) state = state.copyWith(error: error.code, clearLoadingSlot: true);
      return false;
    } on Exception catch (error) {
      debugPrint('Slot photo failed: $error');
      if (ref.mounted) state = state.copyWith(error: EngineErrorCode.captureFailed, clearLoadingSlot: true);
      return false;
    }
  }

  void updateTransform(int slot, SlotTransform transform) {
    if (!state.images.containsKey(slot)) return;
    state = state.copyWith(transforms: {...state.transforms, slot: transform});
  }

  /// Applies [change] to the current style (never to a stale copy from a build).
  void editStyle(TemplateStyle Function(TemplateStyle style) change) =>
      state = state.copyWith(style: change(state.style));

  void acknowledgeError() => state = state.copyWith(clearError: true);

  /// Renders at 1920 px long edge, stores it and saves it to the gallery.
  Future<(File, bool)?> save() async {
    if (state.saving || state.images.isEmpty) return null;
    state = state.copyWith(saving: true);
    try {
      final directory = await ref.read(templateDirectoryProvider)();
      final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
      final file = await renderTemplatePng(
        layout: state.layout,
        style: state.style,
        images: state.images,
        transforms: state.transforms,
        target: File('${directory.path}/exports/YUZ_$stamp.png'),
      );
      final savedToGallery = await ref.read(gallerySaverProvider).saveImage(file.path);
      return (file, savedToGallery);
    } on FileSystemException catch (error) {
      debugPrint('Collage export failed: $error');
      if (ref.mounted) state = state.copyWith(error: EngineErrorCode.captureFailed);
      return null;
    } finally {
      if (ref.mounted) state = state.copyWith(saving: false);
    }
  }
}

final templateEditorControllerProvider = NotifierProvider.autoDispose<TemplateEditorController, TemplateEditorState>(
  TemplateEditorController.new,
);
