import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cupertino_ui/cupertino_ui.dart' as cui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/photo_project_controller.dart';
import '../domain/photo_project.dart';

/// Step 2 of photo editing: crop/rotate/flip, tune, blur, draw, text, emoji
/// and stickers on top of the full-resolution beauty render. The editor
/// history is stored in the project, so reopening restores every layer.
class PhotoEditScreen extends ConsumerStatefulWidget {
  const PhotoEditScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<PhotoEditScreen> createState() => _PhotoEditScreenState();
}

class _PhotoEditScreenState extends ConsumerState<PhotoEditScreen> {
  Future<File>? _image;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = photoProjectControllerProvider(widget.projectId);
    final state = ref.watch(provider);
    final project = state.project;
    if (state.notFound) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.photoNotFound)),
      );
    }
    if (project == null) return const _EditorLoading();
    // Normally already rendered by the retouch step (then this is a cache
    // hit); also covers opening the editor route directly.
    _image ??= ref.read(provider.notifier).prepareFullResolution();
    return FutureBuilder<File>(
      future: _image,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(l10n.photoRenderFailed)),
          );
        }
        final image = snapshot.data;
        if (image == null) return const _EditorLoading();
        return _ImageEditorHost(
          key: ValueKey('photo-editor-${project.id}'),
          project: ref.read(provider).project ?? project,
          imagePath: image.path,
        );
      },
    );
  }
}

class _EditorLoading extends StatelessWidget {
  const _EditorLoading();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );
}

class _ImageEditorHost extends ConsumerStatefulWidget {
  const _ImageEditorHost({required this.project, required this.imagePath, super.key});

  /// Snapshot when the editor opened; the history is imported only once.
  final PhotoProject project;
  final String imagePath;

  @override
  ConsumerState<_ImageEditorHost> createState() => _ImageEditorHostState();
}

class _ImageEditorHostState extends ConsumerState<_ImageEditorHost> {
  final _editorKey = GlobalKey<ProImageEditorState>();
  late final PhotoProjectController _controller = ref.read(photoProjectControllerProvider(widget.project.id).notifier);
  bool _closed = false;

  Future<String?> _exportHistory() async {
    final editor = _editorKey.currentState;
    if (editor == null) return null;
    try {
      final history = await editor.exportStateHistory(
        configs: const ExportEditorConfigs(historySpan: ExportHistorySpan.all),
      );
      return await history.toJson();
    } on Object catch (error) {
      // A failed history export must never lose the rendered image.
      debugPrint('Editor history export failed: $error');
      return null;
    }
  }

  Future<void> _onComplete(Uint8List bytes) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final history = await _exportHistory();
    try {
      final (_, savedToGallery) = await _controller.saveExport(bytes, history);
      messenger.showSnackBar(SnackBar(content: Text(savedToGallery ? l10n.photoSavedToGallery : l10n.photoSavedInApp)));
    } on FileSystemException catch (error) {
      debugPrint('Export failed: $error');
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoSaveFailed)));
    }
  }

  Future<void> _onClose() async {
    if (_closed) return;
    _closed = true;
    final history = await _exportHistory();
    if (history != null) {
      try {
        await _controller.saveEditorHistory(history);
      } on FileSystemException catch (error) {
        debugPrint('Saving editor history failed: $error');
      }
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final width = widget.project.sourceWidth;
    final height = widget.project.sourceHeight;
    // Square bound of the long edge: crop/rotate may swap the orientation and
    // the export must keep the original resolution in both.
    final longEdge = (width != null && height != null ? math.max(width, height) : 4096).toDouble();
    final history = widget.project.editorHistory;

    return Localizations.override(
      context: context,
      delegates: const [mui.DefaultMaterialLocalizations.delegate, cui.DefaultCupertinoLocalizations.delegate],
      child: mui.Theme(
        data: editorTheme(),
        child: ProImageEditor.file(
          widget.imagePath,
          key: _editorKey,
          callbacks: ProImageEditorCallbacks(onImageEditingComplete: _onComplete, onCloseEditor: (_) => _onClose()),
          configs: ProImageEditorConfigs(
            theme: editorTheme(),
            i18n: editorI18n(l10n),
            mainEditor: const MainEditorConfigs(
              tools: [
                SubEditorMode.cropRotate,
                SubEditorMode.tune,
                SubEditorMode.text,
                SubEditorMode.sticker,
                SubEditorMode.emoji,
                SubEditorMode.paint,
                SubEditorMode.blur,
              ],
            ),
            stickerEditor: StickerEditorConfigs(
              builder: (setLayer, scrollController) =>
                  _StickerGrid(scrollController: scrollController, onSelected: setLayer),
            ),
            stateHistory: StateHistoryConfigs(
              initStateHistory: history == null
                  ? null
                  : ImportStateHistory.fromJson(history, configs: const ImportEditorConfigs(widgetLoader: loadSticker)),
            ),
            imageGeneration: ImageGenerationConfigs(
              outputFormat: OutputFormat.jpg,
              jpegQuality: 95,
              maxOutputSize: Size(longEdge, longEdge),
            ),
          ),
        ),
      ),
    );
  }
}

/// Brand palette for the editor, which is built on the material_ui package.
mui.ThemeData editorTheme() => mui.ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.black,
  colorScheme: const mui.ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.accent,
    onPrimary: AppColors.onAccent,
    secondary: AppColors.accentStrong,
    onSecondary: AppColors.onAccent,
    error: AppColors.danger,
    onError: AppColors.onAccent,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceRaised,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.outline,
  ),
);

I18n editorI18n(AppLocalizations l10n) => I18n(
  cancel: l10n.actionCancel,
  undo: l10n.editorUndo,
  redo: l10n.editorRedo,
  done: l10n.editorDone,
  remove: l10n.editorRemove,
  doneLoadingMsg: l10n.editorApplying,
  importStateHistoryMsg: l10n.editorLoading,
  layerInteraction: I18nLayerInteraction(
    remove: l10n.editorRemove,
    edit: l10n.editorEdit,
    rotateScale: l10n.editorRotateScale,
  ),
  paintEditor: I18nPaintEditor(
    bottomNavigationBarText: l10n.editorPaint,
    lineWidth: l10n.editorLineWidth,
    eraser: l10n.editorEraser,
    changeOpacity: l10n.editorOpacity,
    opacity: l10n.editorOpacity,
    color: l10n.editorColor,
    blur: l10n.editorBlur,
    undo: l10n.editorUndo,
    redo: l10n.editorRedo,
    done: l10n.editorDone,
    back: l10n.editorBack,
    cancel: l10n.actionCancel,
  ),
  textEditor: I18nTextEditor(
    inputHintText: l10n.editorTextHint,
    bottomNavigationBarText: l10n.editorText,
    back: l10n.editorBack,
    done: l10n.editorDone,
    textAlign: l10n.editorAlign,
  ),
  cropRotateEditor: I18nCropRotateEditor(
    bottomNavigationBarText: l10n.editorCrop,
    rotate: l10n.editorRotate,
    tiltRotate: l10n.editorRotate,
    flip: l10n.editorFlip,
    ratio: l10n.editorRatio,
    back: l10n.editorBack,
    done: l10n.editorDone,
    cancel: l10n.actionCancel,
    undo: l10n.editorUndo,
    redo: l10n.editorRedo,
    reset: l10n.editorReset,
  ),
  tuneEditor: I18nTuneEditor(
    bottomNavigationBarText: l10n.editorTune,
    back: l10n.editorBack,
    done: l10n.editorDone,
    brightness: l10n.editorBrightness,
    contrast: l10n.editorContrast,
    saturation: l10n.editorSaturation,
    exposure: l10n.editorExposure,
    hue: l10n.editorHue,
    temperature: l10n.editorTemperature,
    fade: l10n.editorFade,
    tint: l10n.editorTint,
    undo: l10n.editorUndo,
    redo: l10n.editorRedo,
  ),
  blurEditor: I18nBlurEditor(bottomNavigationBarText: l10n.editorBlur, back: l10n.editorBack, done: l10n.editorDone),
  emojiEditor: I18nEmojiEditor(bottomNavigationBarText: l10n.editorEmoji, search: l10n.editorSearch),
  stickerEditor: I18nStickerEditor(bottomNavigationBarText: l10n.editorStickers),
  various: I18nVarious(
    loadingDialogMsg: l10n.editorLoading,
    closeEditorWarningTitle: l10n.editorCloseTitle,
    closeEditorWarningMessage: l10n.editorCloseBody,
    closeEditorWarningConfirmBtn: l10n.editorDone,
    closeEditorWarningCancelBtn: l10n.actionCancel,
  ),
);

/// Yuz's own sticker set (vector icons, no third-party artwork). Each sticker
/// is exported by id so saved projects can rebuild the layer.
const _stickers = <String, (IconData, Color)>{
  'heart': (Icons.favorite_rounded, Color(0xFFF07B7B)),
  'sparkle': (Icons.auto_awesome_rounded, Color(0xFFF2C46D)),
  'star': (Icons.star_rounded, Color(0xFFF2C46D)),
  'crown': (Icons.workspace_premium_rounded, Color(0xFFE8A598)),
  'flower': (Icons.local_florist_rounded, Color(0xFFE8A598)),
  'sun': (Icons.wb_sunny_rounded, Color(0xFFF2C46D)),
  'moon': (Icons.nightlight_round, Color(0xFFA9A6B5)),
  'cloud': (Icons.cloud_rounded, Color(0xFFF5F3F7)),
  'bolt': (Icons.bolt_rounded, Color(0xFFF2C46D)),
  'bird': (Icons.flutter_dash_rounded, Color(0xFF7FB8F0)),
  'music': (Icons.music_note_rounded, Color(0xFFF5F3F7)),
  'camera': (Icons.photo_camera_rounded, Color(0xFFF5F3F7)),
  'smile': (Icons.sentiment_very_satisfied_rounded, Color(0xFFF2C46D)),
  'glam': (Icons.face_retouching_natural_rounded, Color(0xFFF07B7B)),
  'diamond': (Icons.diamond_rounded, Color(0xFF7FD1A8)),
  'fire': (Icons.local_fire_department_rounded, Color(0xFFD9826F)),
};

const _stickerIdPrefix = 'yuz-sticker:';

Widget _stickerWidget(String name) {
  final (icon, color) = _stickers[name] ?? (Icons.help_outline_rounded, AppColors.textMuted);
  return Icon(
    icon,
    size: 120,
    color: color,
    shadows: const [Shadow(blurRadius: 8, color: Color(0x66000000))],
  );
}

/// Rebuilds sticker layers when a saved editor history is imported.
@visibleForTesting
Widget loadSticker(String id, {Map<String, dynamic>? meta}) =>
    _stickerWidget(id.startsWith(_stickerIdPrefix) ? id.substring(_stickerIdPrefix.length) : id);

class _StickerGrid extends StatelessWidget {
  const _StickerGrid({required this.scrollController, required this.onSelected});

  final ScrollController scrollController;
  final void Function(WidgetLayer layer) onSelected;

  @override
  Widget build(BuildContext context) {
    final names = _stickers.keys.toList(growable: false);
    return ColoredBox(
      color: AppColors.surface,
      child: GridView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 88,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
        ),
        itemCount: names.length,
        itemBuilder: (context, index) {
          final name = names[index];
          return GestureDetector(
            key: ValueKey('sticker-$name'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(
              WidgetLayer(
                widget: _stickerWidget(name),
                exportConfigs: WidgetLayerExportConfigs(id: '$_stickerIdPrefix$name'),
              ),
            ),
            child: FittedBox(child: _stickerWidget(name)),
          );
        },
      ),
    );
  }
}
