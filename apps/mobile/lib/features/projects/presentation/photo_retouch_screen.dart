import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../camera/presentation/beauty_controls_panel.dart';
import '../../camera/presentation/engine_error_text.dart';
import '../application/photo_project_controller.dart';
import '../data/project_repository.dart';

/// Step 1 of photo editing: the GPU beauty look on the photo (same engine
/// and studio as the camera), with press-and-hold before/after.
class PhotoRetouchScreen extends ConsumerStatefulWidget {
  const PhotoRetouchScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<PhotoRetouchScreen> createState() => _PhotoRetouchScreenState();
}

class _PhotoRetouchScreenState extends ConsumerState<PhotoRetouchScreen> {
  bool _showOriginal = false;
  bool _preparing = false;

  NotifierProvider<PhotoProjectController, PhotoProjectState> get _provider =>
      photoProjectControllerProvider(widget.projectId);

  Future<void> _openEditor() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _preparing = true);
    try {
      await ref.read(_provider.notifier).prepareFullResolution();
      if (mounted) await context.push('/photo/${widget.projectId}/edit');
    } on BeautyEngineException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.code.message(l10n))));
    } on FileSystemException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoRenderFailed)));
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(_provider);

    if (state.notFound) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.photoNotFound)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(l10n.photoRetouchTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton.icon(
              key: const ValueKey('photo-next'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: state.project == null || _preparing ? null : _openEditor,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l10n.photoNext),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _PreviewArea(state: state, showOriginal: _showOriginal),
              ),
              if (state.renderError != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Text(
                    state.renderError!.message(l10n),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning),
                  ),
                ),
              _FaceInfo(state: state),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: state.project == null
                            ? const SizedBox(height: 120)
                            : BeautyStudioPanel(
                                faceTrackingAvailable: state.faceTrackingAvailable ?? true,
                                look: _provider.select((s) => s.look),
                                editor: (ref) => ref.read(_provider.notifier),
                                onCustomLutImported: () => ref.read(_provider.notifier).reapplyCustomLut(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: AppSpacing.md,
            top: AppSpacing.md,
            child: _CompareButton(onChanged: (pressed) => setState(() => _showOriginal = pressed)),
          ),
          if (_preparing)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.scrim,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(strokeWidth: 2),
                      const SizedBox(height: AppSpacing.md),
                      Text(l10n.photoPreparing),
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

class _PreviewArea extends ConsumerWidget {
  const _PreviewArea({required this.state, required this.showOriginal});

  final PhotoProjectState state;
  final bool showOriginal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = state.project;
    if (project == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    final repository = ref.watch(projectRepositoryProvider);
    return FutureBuilder<ProjectFiles>(
      future: repository.filesFor(project),
      builder: (context, snapshot) {
        final files = snapshot.data;
        if (files == null) return const SizedBox.expand();
        final previewPath = state.previewPath;
        final File file = showOriginal || previewPath == null ? files.original : File(previewPath);
        return Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              maxScale: 6,
              child: Center(
                child: Image.file(
                  file,
                  key: ValueKey(file.path),
                  fit: BoxFit.contain,
                  // Originals can be huge; previews are already 1600 px.
                  cacheWidth: showOriginal || previewPath == null ? 1600 : null,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
            if (state.rendering)
              const Positioned(
                right: AppSpacing.md,
                top: AppSpacing.md,
                child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        );
      },
    );
  }
}

class _FaceInfo extends StatelessWidget {
  const _FaceInfo({required this.state});

  final PhotoProjectState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = state.faceTrackingAvailable;
    if (available == null) return const SizedBox.shrink();
    final text = !available
        ? l10n.cameraTrackingUnavailable
        : state.faceCount == 0
        ? l10n.cameraNoFace
        : l10n.cameraFacesDetected(state.faceCount);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _CompareButton extends StatelessWidget {
  const _CompareButton({required this.onChanged});

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: l10n.photoCompare,
      child: Semantics(
        button: true,
        label: l10n.photoCompare,
        // Raw pointer events: the original shows instantly on touch, without
        // the tap recognizer's press delay.
        child: Listener(
          key: const ValueKey('photo-compare'),
          onPointerDown: (_) => onChanged(true),
          onPointerUp: (_) => onChanged(false),
          onPointerCancel: (_) => onChanged(false),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: const BoxDecoration(color: AppColors.scrim, shape: BoxShape.circle),
            child: const Icon(Icons.compare_rounded, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
