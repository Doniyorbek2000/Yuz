import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../projects/application/photo_project_controller.dart';

/// Plays a finished recording in a loop and saves it to the gallery.
class VideoResultScreen extends ConsumerStatefulWidget {
  const VideoResultScreen({required this.filePath, this.hasAudio = true, super.key});

  final String filePath;
  final bool hasAudio;

  @override
  ConsumerState<VideoResultScreen> createState() => _VideoResultScreenState();
}

class _VideoResultScreenState extends ConsumerState<VideoResultScreen> {
  VideoPlayerController? _player;
  bool _missing = false;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    final file = File(widget.filePath);
    if (widget.filePath.isEmpty || !await file.exists()) {
      if (mounted) setState(() => _missing = true);
      return;
    }
    final player = VideoPlayerController.file(file);
    try {
      await player.initialize();
      await player.setLooping(true);
      await player.play();
    } on Exception catch (error) {
      debugPrint('Video playback failed: $error');
      await player.dispose();
      if (mounted) setState(() => _missing = true);
      return;
    }
    if (!mounted) {
      await player.dispose();
      return;
    }
    setState(() => _player = player);
  }

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final saved = await ref.read(gallerySaverProvider).saveVideo(widget.filePath);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = saved;
    });
    messenger.showSnackBar(SnackBar(content: Text(saved ? l10n.videoSavedToGallery : l10n.videoSaveFailed)));
  }

  void _togglePlayback() {
    final player = _player;
    if (player == null) return;
    setState(() => player.value.isPlaying ? player.pause() : player.play());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final player = _player;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(l10n.videoResultTitle)),
      body: _missing
          ? Center(child: Text(l10n.videoNotFound))
          : Column(
              children: [
                Expanded(
                  child: player == null
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : GestureDetector(
                          key: const ValueKey('video-surface'),
                          onTap: _togglePlayback,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: AspectRatio(aspectRatio: player.value.aspectRatio, child: VideoPlayer(player)),
                              ),
                              ValueListenableBuilder<VideoPlayerValue>(
                                valueListenable: player,
                                builder: (context, value, _) => value.isPlaying
                                    ? const SizedBox.shrink()
                                    : Semantics(
                                        button: true,
                                        label: l10n.videoPlay,
                                        child: const DecoratedBox(
                                          decoration: BoxDecoration(color: AppColors.scrim, shape: BoxShape.circle),
                                          child: Padding(
                                            padding: EdgeInsets.all(AppSpacing.sm),
                                            child: Icon(Icons.play_arrow_rounded, size: 40),
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                ),
                if (player != null) VideoProgressIndicator(player, allowScrubbing: true),
                if (!widget.hasAudio)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.volume_off_rounded, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(l10n.videoSilent, style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('video-save'),
                            onPressed: player == null || _saving || _saved ? null : _save,
                            icon: _saving
                                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(_saved ? Icons.check_rounded : Icons.download_rounded),
                            label: Text(_saved ? l10n.videoSavedToGallery : l10n.videoSaveToGallery),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
