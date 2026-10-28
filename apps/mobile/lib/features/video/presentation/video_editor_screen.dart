import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../camera/application/beauty_camera_controller.dart' show beautyEngineProvider;
import '../../camera/presentation/beauty_controls_panel.dart';
import '../../camera/presentation/engine_error_text.dart';
import '../../editing/stickers.dart';
import '../application/video_editor_controller.dart';
import '../data/video_project_repository.dart';
import '../domain/video_project.dart';
import 'overlay_painter.dart';

/// Picks a video file; overridable in tests.
typedef MediaPicker = Future<String?> Function();

final videoPickerProvider = Provider<MediaPicker>((ref) {
  return () async => (await ImagePicker().pickVideo(source: ImageSource.gallery))?.path;
});

final musicPickerProvider = Provider<MediaPicker>((ref) {
  return () async => (await FilePicker.pickFile(type: FileType.audio))?.path;
});

enum _Tool { trim, speed, look, text, stickers, music }

const _textColors = <int>[0xFFFFFFFF, 0xFF0B0B0F, 0xFFE8A598, 0xFFF2C46D, 0xFF7FD1A8, 0xFF7FB8F0, 0xFFF07B7B];

String _formatMillis(int millis) {
  final seconds = millis / 1000;
  final minutes = seconds ~/ 60;
  final rest = seconds - minutes * 60;
  return '${minutes.toString().padLeft(2, '0')}:${rest.toStringAsFixed(1).padLeft(4, '0')}';
}

class VideoEditorScreen extends ConsumerStatefulWidget {
  const VideoEditorScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  _Tool _tool = _Tool.trim;

  /// Output-timeline position of the preview (drives overlay visibility).
  final _positionMillis = ValueNotifier<int>(0);

  NotifierProvider<VideoEditorController, VideoEditorState> get _provider =>
      videoEditorControllerProvider(widget.projectId);

  VideoEditorController get _controller => ref.read(_provider.notifier);

  @override
  void dispose() {
    _positionMillis.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ExportDialog(provider: _provider),
      ),
    );
    final result = await _controller.export();
    if (!mounted) return;
    navigator.pop();
    final failed = ref.read(_provider).export;
    if (result != null) {
      _controller.acknowledgeExport();
      await context.push('/video?path=${Uri.encodeComponent(result.outputPath)}&audio=${result.hasAudio ? 1 : 0}');
    } else if (failed.phase == VideoExportPhase.failed) {
      _controller.acknowledgeExport();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failed.error?.message(l10n) ?? l10n.videoExportFailed)));
    }
  }

  Future<void> _addClip() async {
    final path = await ref.read(videoPickerProvider)();
    if (path == null || !mounted) return;
    await _controller.addClip(path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(_provider);
    ref.listen(_provider.select((s) => s.error), (_, error) {
      if (error == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message(l10n))));
      _controller.acknowledgeError();
    });

    if (state.notFound) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.photoNotFound)),
      );
    }
    final project = state.project;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(l10n.videoEditorTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton.icon(
              key: const ValueKey('video-export'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: project == null || state.busy ? null : _export,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: Text(l10n.videoExport),
            ),
          ),
        ],
      ),
      body: project == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              children: [
                Expanded(
                  child: _tool == _Tool.look
                      ? _LookPreview(state: state)
                      : _PreviewStage(
                          projectId: widget.projectId,
                          state: state,
                          positionMillis: _positionMillis,
                          interactiveOverlays: _tool == _Tool.text || _tool == _Tool.stickers,
                        ),
                ),
                _Timeline(state: state, controller: _controller, onAdd: state.busy ? null : _addClip),
                _ToolBar(tool: _tool, onChanged: (tool) => setState(() => _tool = tool)),
                SafeArea(
                  top: false,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
                      child: switch (_tool) {
                        _Tool.trim => _TrimTool(state: state, controller: _controller),
                        _Tool.speed => _SpeedTool(state: state, controller: _controller),
                        _Tool.look => _LookTool(provider: _provider, state: state),
                        _Tool.text => _TextTool(state: state, controller: _controller, positionMillis: _positionMillis),
                        _Tool.stickers => _StickerTool(
                          state: state,
                          controller: _controller,
                          positionMillis: _positionMillis,
                        ),
                        _Tool.music => _MusicTool(state: state, controller: _controller),
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Plays the selected clip's trimmed range in a loop, letterboxed like the
/// export, with the overlays drawn (and editable) on top.
class _PreviewStage extends ConsumerStatefulWidget {
  const _PreviewStage({
    required this.projectId,
    required this.state,
    required this.positionMillis,
    required this.interactiveOverlays,
  });

  final String projectId;
  final VideoEditorState state;
  final ValueNotifier<int> positionMillis;
  final bool interactiveOverlays;

  @override
  ConsumerState<_PreviewStage> createState() => _PreviewStageState();
}

class _PreviewStageState extends ConsumerState<_PreviewStage> {
  VideoPlayerController? _player;
  String? _clipId;
  bool _failed = false;
  VideoOverlayItem? _gestureStart;
  double _gestureBaseRotation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_openSelected());
  }

  @override
  void didUpdateWidget(_PreviewStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final clip = widget.state.clip;
    if (clip?.id != _clipId) {
      unawaited(_openSelected());
    } else if (clip != null) {
      unawaited(_applyClipSettings(clip));
    }
  }

  Future<void> _openSelected() async {
    final clip = widget.state.clip;
    if (clip == null) return;
    _clipId = clip.id;
    final old = _player;
    _player = null;
    if (mounted) setState(() => _failed = false);
    await old?.dispose();
    final files = await ref.read(videoProjectRepositoryProvider).filesFor(widget.projectId);
    final player = VideoPlayerController.file(files.clip(clip));
    try {
      await player.initialize();
    } on Exception catch (error) {
      debugPrint('Preview failed: $error');
      await player.dispose();
      if (mounted && _clipId == clip.id) setState(() => _failed = true);
      return;
    }
    if (!mounted || _clipId != clip.id) {
      await player.dispose();
      return;
    }
    player.addListener(_onTick);
    setState(() => _player = player);
    await _applyClipSettings(clip, seek: true);
    await player.play();
  }

  Future<void> _applyClipSettings(VideoClip clip, {bool seek = false}) async {
    final player = _player;
    if (player == null) return;
    final project = widget.state.project!;
    await player.setPlaybackSpeed(clip.speed);
    await player.setVolume(clip.keepsSound ? project.originalVolume : 0);
    final position = player.value.position.inMilliseconds;
    if (seek || position < clip.startMillis || position > clip.endMillis) {
      await player.seekTo(Duration(milliseconds: clip.startMillis));
    }
  }

  void _onTick() {
    final player = _player;
    final clip = widget.state.clip;
    final project = widget.state.project;
    if (player == null || clip == null || project == null) return;
    final position = player.value.position.inMilliseconds;
    if (position >= clip.endMillis) {
      unawaited(player.seekTo(Duration(milliseconds: clip.startMillis)));
      return;
    }
    final index = widget.state.selectedClip.clamp(0, project.clips.length - 1);
    widget.positionMillis.value =
        project.clipStartMillis(index) +
        ((position - clip.startMillis).clamp(0, clip.trimmedMillis) / clip.speed).round();
  }

  @override
  void dispose() {
    _player?.removeListener(_onTick);
    unawaited(_player?.dispose());
    super.dispose();
  }

  VideoEditorController get _controller => ref.read(videoEditorControllerProvider(widget.projectId).notifier);

  void _onTapUp(TapUpDetails details, Size size) {
    final overlays = widget.state.project!.overlays.reversed;
    final position = widget.positionMillis.value;
    for (final item in overlays) {
      if ((item.isVisibleAt(position) || item.id == widget.state.selectedOverlayId) &&
          overlayContains(item, size, details.localPosition)) {
        _controller.selectOverlay(item.id);
        return;
      }
    }
    _controller.selectOverlay(null);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStart = widget.state.selectedOverlay;
    _gestureBaseRotation = _gestureStart?.rotation ?? 0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size size) {
    final start = _gestureStart;
    final current = widget.state.selectedOverlay;
    if (start == null || current == null) return;
    _controller.updateOverlay(
      current.copyWith(
        x: current.x + details.focalPointDelta.dx / size.width,
        y: current.y + details.focalPointDelta.dy / size.height,
        scale: start.scale * details.scale,
        rotation: _gestureBaseRotation + details.rotation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final project = widget.state.project!;
    final clip = widget.state.clip!;
    final (outputWidth, outputHeight) = videoOutputSize(project.clips.first);
    final player = _player;
    return Center(
      child: AspectRatio(
        aspectRatio: outputWidth / outputHeight,
        child: ColoredBox(
          color: Colors.black,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: _failed
                        ? Text(l10n.videoNotFound)
                        : player == null
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : AspectRatio(aspectRatio: clip.width / clip.height, child: VideoPlayer(player)),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: widget.positionMillis,
                    builder: (context, millis, _) => CustomPaint(
                      key: const ValueKey('overlay-layer'),
                      painter: OverlayLayerPainter(
                        overlays: project.overlays,
                        millis: millis,
                        selectedId: widget.interactiveOverlays ? widget.state.selectedOverlayId : null,
                      ),
                    ),
                  ),
                  if (widget.interactiveOverlays)
                    GestureDetector(
                      key: const ValueKey('overlay-gestures'),
                      behavior: HitTestBehavior.translucent,
                      onTapUp: (details) => _onTapUp(details, size),
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: (details) => _onScaleUpdate(details, size),
                    )
                  else
                    GestureDetector(
                      key: const ValueKey('video-preview'),
                      behavior: HitTestBehavior.translucent,
                      onTap: player == null
                          ? null
                          : () => setState(() => player.value.isPlaying ? player.pause() : player.play()),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LookPreview extends StatelessWidget {
  const _LookPreview({required this.state});

  final VideoEditorState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final path = state.lookPreviewPath;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (path == null)
          const Center(child: CircularProgressIndicator(strokeWidth: 2))
        else
          InteractiveViewer(
            maxScale: 4,
            child: Image.file(
              File(path),
              key: ValueKey(path),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, size: 48),
            ),
          ),
        Positioned(
          left: AppSpacing.md,
          top: AppSpacing.md,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
            decoration: const BoxDecoration(color: AppColors.scrim, borderRadius: BorderRadius.all(AppRadii.pill)),
            child: Text(l10n.videoLookPreview, style: Theme.of(context).textTheme.labelSmall),
          ),
        ),
        if (state.lookPreviewRendering)
          const Positioned(
            right: AppSpacing.md,
            top: AppSpacing.md,
            child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.state, required this.controller, required this.onAdd});

  final VideoEditorState state;
  final VideoEditorController controller;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final project = state.project!;
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              key: const ValueKey('clip-timeline'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              itemCount: project.clips.length,
              onReorderItem: controller.moveClip,
              itemBuilder: (context, index) {
                final clip = project.clips[index];
                return _ClipTile(
                  key: ValueKey('clip-${clip.id}'),
                  clip: clip,
                  thumbnails: state.thumbnails[clip.id] ?? const [],
                  selected: index == state.selectedClip,
                  onTap: () => controller.selectClip(index),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: IconButton.filledTonal(
              key: const ValueKey('add-clip'),
              tooltip: l10n.videoAddClip,
              onPressed: onAdd,
              icon: state.busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({
    required this.clip,
    required this.thumbnails,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final VideoClip clip;
  final List<String> thumbnails;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Width follows the clip's output length (bounded so tiles stay usable).
    final width = (clip.outputMillis / 1000 * 24).clamp(72.0, 220.0);
    final visible = thumbnails.take((width / 40).ceil()).toList();
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: width,
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: const BorderRadius.all(AppRadii.sm),
            border: Border.all(color: selected ? AppColors.accent : Colors.transparent, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  for (final path in visible)
                    Expanded(
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        cacheWidth: 120,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
              Positioned(
                left: 4,
                bottom: 2,
                child: Text(
                  '${_formatMillis(clip.outputMillis)}${clip.speed == 1 ? '' : ' · ${clip.speed}×'}',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(shadows: const [Shadow(blurRadius: 4, color: Colors.black)]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar({required this.tool, required this.onChanged});

  final _Tool tool;
  final ValueChanged<_Tool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <(_Tool, IconData, String)>[
      (_Tool.trim, Icons.content_cut_rounded, l10n.videoToolTrim),
      (_Tool.speed, Icons.speed_rounded, l10n.videoToolSpeed),
      (_Tool.look, Icons.face_retouching_natural, l10n.videoToolLook),
      (_Tool.text, Icons.text_fields_rounded, l10n.videoToolText),
      (_Tool.stickers, Icons.emoji_emotions_outlined, l10n.videoToolStickers),
      (_Tool.music, Icons.music_note_rounded, l10n.videoToolMusic),
    ];
    // Six fixed slots: every tool stays visible, also on 320 px phones.
    return SizedBox(
      height: 58,
      child: Row(
        key: const ValueKey('tool-bar'),
        children: [
          for (final (value, icon, label) in items)
            Expanded(
              child: Semantics(
                button: true,
                selected: tool == value,
                label: label,
                child: InkWell(
                  key: ValueKey('tool-${value.name}'),
                  onTap: () => onChanged(value),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 22, color: tool == value ? AppColors.accent : AppColors.textSecondary),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: tool == value ? AppColors.accent : AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrimTool extends StatelessWidget {
  const _TrimTool({required this.state, required this.controller});

  final VideoEditorState state;
  final VideoEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final clip = state.clip!;
    final canRemove = state.project!.clips.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(_formatMillis(clip.startMillis), style: Theme.of(context).textTheme.labelMedium),
            const Spacer(),
            Text(
              _formatMillis(clip.trimmedMillis),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.accent),
            ),
            const Spacer(),
            Text(_formatMillis(clip.endMillis), style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        RangeSlider(
          key: const ValueKey('trim-slider'),
          values: RangeValues(clip.startMillis.toDouble(), clip.endMillis.toDouble()),
          max: clip.durationMillis.toDouble(),
          onChanged: (range) => controller.trimSelected(range.start.round(), range.end.round()),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey('remove-clip'),
            onPressed: canRemove ? () => controller.removeClip(state.selectedClip) : null,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(l10n.videoRemoveClip),
          ),
        ),
      ],
    );
  }
}

class _SpeedTool extends StatelessWidget {
  const _SpeedTool({required this.state, required this.controller});

  final VideoEditorState state;
  final VideoEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final clip = state.clip!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final speed in kVideoSpeeds)
              ChoiceChip(
                key: ValueKey('speed-$speed'),
                label: Text('$speed×'),
                selected: clip.speed == speed,
                onSelected: (_) => controller.setSpeed(speed),
              ),
          ],
        ),
        if (clip.hasAudio)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(l10n.videoSpeedMutes, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _LookTool extends StatelessWidget {
  const _LookTool({required this.provider, required this.state});

  final NotifierProvider<VideoEditorController, VideoEditorState> provider;
  final VideoEditorState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer(
      builder: (context, ref, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            key: const ValueKey('apply-beauty'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.videoApplyBeauty),
            subtitle: Text(l10n.videoApplyBeautyHint),
            value: state.project!.applyBeauty,
            onChanged: ref.read(provider.notifier).setApplyBeauty,
          ),
          BeautyStudioPanel(
            faceTrackingAvailable: state.project!.applyBeauty,
            look: provider.select((s) => s.look),
            editor: (ref) => ref.read(provider.notifier),
            onCustomLutImported: () => ref.read(provider.notifier).reapplyCustomLut(),
          ),
        ],
      ),
    );
  }
}

class _OverlayInspector extends StatelessWidget {
  const _OverlayInspector({required this.state, required this.controller, this.showColors = false});

  final VideoEditorState state;
  final VideoEditorController controller;
  final bool showColors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = state.selectedOverlay;
    if (item == null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(l10n.videoOverlayHint, style: Theme.of(context).textTheme.bodySmall),
      );
    }
    final total = state.project!.durationMillis.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showColors && item.kind == OverlayKind.text)
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final color in _textColors)
                GestureDetector(
                  key: ValueKey('text-color-$color'),
                  onTap: () => controller.updateOverlay(item.copyWith(color: color)),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: item.color == color ? AppColors.accent : AppColors.outline,
                        width: item.color == color ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text(l10n.videoOverlayTime, style: Theme.of(context).textTheme.labelMedium),
            const Spacer(),
            Text(
              '${_formatMillis(item.startMillis)} – ${_formatMillis(item.endMillis)}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        RangeSlider(
          key: const ValueKey('overlay-time'),
          values: RangeValues(item.startMillis.toDouble(), item.endMillis.toDouble().clamp(0, total)),
          max: total,
          onChanged: (range) =>
              controller.updateOverlay(item.copyWith(startMillis: range.start.round(), endMillis: range.end.round())),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey('overlay-delete'),
            onPressed: () => controller.removeOverlay(item.id),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(l10n.videoOverlayDelete),
          ),
        ),
      ],
    );
  }
}

class _TextTool extends StatelessWidget {
  const _TextTool({required this.state, required this.controller, required this.positionMillis});

  final VideoEditorState state;
  final VideoEditorController controller;
  final ValueNotifier<int> positionMillis;

  Future<void> _add(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => _TextDialog(title: l10n.videoTextDialogTitle, hint: l10n.videoTextHint),
    );
    if (text == null || text.trim().isEmpty) return;
    controller.addText(text, color: _textColors.first, atMillis: positionMillis.value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonalIcon(
          key: const ValueKey('add-text'),
          onPressed: () => _add(context),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.videoAddText),
        ),
        _OverlayInspector(state: state, controller: controller, showColors: true),
      ],
    );
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('text-input'),
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop<String>(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('text-confirm'),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.editorDone),
        ),
      ],
    );
  }
}

class _StickerTool extends StatelessWidget {
  const _StickerTool({required this.state, required this.controller, required this.positionMillis});

  final VideoEditorState state;
  final VideoEditorController controller;
  final ValueNotifier<int> positionMillis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final name in yuzStickers.keys)
              InkWell(
                key: ValueKey('add-sticker-$name'),
                borderRadius: const BorderRadius.all(AppRadii.sm),
                onTap: () => controller.addSticker(name, atMillis: positionMillis.value),
                child: Padding(padding: const EdgeInsets.all(6), child: stickerWidget(name, size: 32)),
              ),
          ],
        ),
        _OverlayInspector(state: state, controller: controller),
      ],
    );
  }
}

class _MusicTool extends ConsumerWidget {
  const _MusicTool({required this.state, required this.controller});

  final VideoEditorState state;
  final VideoEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final project = state.project!;
    final hasMusic = project.musicFileName != null;
    final anySound = project.clips.any((c) => c.keepsSound);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.library_music_outlined, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                hasMusic ? l10n.videoMusicSelected : l10n.videoMusicNone,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (hasMusic)
              IconButton(
                key: const ValueKey('music-remove'),
                tooltip: l10n.videoMusicRemove,
                onPressed: controller.clearMusic,
                icon: const Icon(Icons.close_rounded),
              ),
            FilledButton.tonal(
              key: const ValueKey('music-pick'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: state.busy
                  ? null
                  : () async {
                      final path = await ref.read(musicPickerProvider)();
                      if (path != null) await controller.setMusic(path);
                    },
              child: Text(l10n.videoMusicPick),
            ),
          ],
        ),
        if (hasMusic)
          _VolumeSlider(
            key: const ValueKey('music-volume'),
            label: l10n.videoMusicVolume,
            value: project.musicVolume,
            onChanged: controller.setMusicVolume,
          ),
        if (anySound)
          _VolumeSlider(
            key: const ValueKey('original-volume'),
            label: l10n.videoOriginalVolume,
            value: project.originalVolume,
            onChanged: controller.setOriginalVolume,
          ),
      ],
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({required this.label, required this.value, required this.onChanged, super.key});

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 104, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        Expanded(
          child: Slider(value: value, onChanged: onChanged),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

class _ExportDialog extends ConsumerWidget {
  const _ExportDialog({required this.provider});

  final NotifierProvider<VideoEditorController, VideoEditorState> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final export = ref.watch(provider.select((s) => s.export));
    final percent = (export.progress * 100).round();
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.videoExporting(percent)),
        content: LinearProgressIndicator(key: const ValueKey('export-progress'), value: export.progress),
        actions: [
          TextButton(
            key: const ValueKey('export-cancel'),
            onPressed: () => ref.read(provider.notifier).cancelExport(),
            child: Text(l10n.actionCancel),
          ),
        ],
      ),
    );
  }
}

/// Creates a project from [sourcePath] (e.g. a fresh recording) and opens it.
class NewVideoProjectScreen extends ConsumerStatefulWidget {
  const NewVideoProjectScreen({required this.sourcePath, super.key});

  final String sourcePath;

  @override
  ConsumerState<NewVideoProjectScreen> createState() => _NewVideoProjectScreenState();
}

class _NewVideoProjectScreenState extends ConsumerState<NewVideoProjectScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  Future<void> _create() async {
    final project = await createVideoProject(ref, widget.sourcePath);
    if (!mounted) return;
    if (project == null) {
      setState(() => _failed = true);
      return;
    }
    context.pushReplacement('/video-editor/${project.id}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: _failed ? Text(l10n.videoImportFailed) : const CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

/// Probes and imports [sourcePath] as a new video project; null on failure.
Future<VideoProject?> createVideoProject(WidgetRef ref, String sourcePath) async {
  try {
    final metadata = await ref.read(beautyEngineProvider).probeVideo(sourcePath);
    return await ref.read(videoProjectRepositoryProvider).create(sourcePath, (
      durationMillis: metadata.durationMillis,
      width: metadata.width,
      height: metadata.height,
      hasAudio: metadata.hasAudio,
    ));
  } on BeautyEngineException catch (error) {
    debugPrint('Video import failed: ${error.message}');
    return null;
  } on FileSystemException catch (error) {
    debugPrint('Video import failed: $error');
    return null;
  }
}
