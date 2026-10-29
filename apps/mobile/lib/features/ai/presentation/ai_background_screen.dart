import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_models.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../account/application/account_data.dart';
import '../../account/application/session_controller.dart';
import '../../account/presentation/account_widgets.dart';
import '../../catalog/feature_catalog.dart';
import '../application/ai_background_controller.dart';
import '../data/photo_source.dart';

class AiBackgroundScreen extends ConsumerWidget {
  const AiBackgroundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final Widget body = switch (session) {
      AsyncData(value: SessionUnconfigured()) => MessagePanel(
        icon: Icons.cloud_off_outlined,
        title: l10n.accountUnconfiguredTitle,
        body: l10n.accountUnconfiguredBody,
      ),
      AsyncData(value: SignedOut()) => MessagePanel(
        icon: Icons.person_outline,
        title: l10n.aiSignInRequired,
        actions: [
          FilledButton(
            key: const ValueKey('ai-sign-in'),
            onPressed: () => context.push('/account/auth'),
            child: Text(l10n.accountSignIn),
          ),
        ],
      ),
      AsyncData(value: SignedIn(:final profile)) when !profile.cloudAiConsent => MessagePanel(
        icon: Icons.cloud_outlined,
        title: l10n.aiConsentRequired,
        body: l10n.consentPointUpload,
        actions: [
          FilledButton(
            key: const ValueKey('ai-consent'),
            onPressed: () => context.push('/account/consent'),
            child: Text(l10n.aiReviewConsent),
          ),
        ],
      ),
      AsyncData(value: SignedIn(:final profile)) => _Editor(balance: profile.creditBalance),
      AsyncError() => MessagePanel(
        icon: Icons.wifi_off_outlined,
        title: l10n.accountLoadFailed,
        actions: [
          FilledButton(
            onPressed: () => ref.read(sessionControllerProvider.notifier).retry(),
            child: Text(l10n.actionRetry),
          ),
        ],
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
    return Scaffold(
      appBar: AppBar(title: Text(AppFeature.aiBackground.label(l10n))),
      body: SafeArea(child: body),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.balance});

  final int balance;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  bool _showOriginal = false;

  AiBackgroundController get _controller => ref.read(aiBackgroundControllerProvider.notifier);

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await _controller.saveToGallery();
    messenger.showSnackBar(SnackBar(content: Text(saved ? l10n.photoSavedToGallery : l10n.videoSaveFailed)));
  }

  Future<void> _openInEditor() async {
    final router = GoRouter.of(context);
    try {
      final id = await _controller.openAsProject();
      if (id != null) unawaited(router.push('/photo/$id'));
    } on FileSystemException {
      if (mounted) showErrorSnack(context, const FileSystemException());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final state = ref.watch(aiBackgroundControllerProvider);
    final price = ref.watch(aiPricingProvider).value?[AiJobType.background];
    final cost = price?.cost ?? 1;
    final enabled = price?.enabled ?? true;
    final showResult = state.resultPath != null && !_showOriginal;
    final shownPath = showResult ? state.resultPath : state.sourcePath;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(AppRadii.md),
              child: ColoredBox(
                color: AppColors.surface,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (shownPath == null)
                      MessagePanel(icon: Icons.wallpaper_outlined, title: l10n.aiPickHint, body: l10n.aiBgIntro)
                    else
                      // Checkerboard shows transparency of "remove" results.
                      DecoratedBox(
                        decoration: const BoxDecoration(color: AppColors.surfaceRaised),
                        child: Image.file(
                          File(shownPath),
                          key: ValueKey(shownPath),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, size: 48),
                        ),
                      ),
                    if (state.busy)
                      ColoredBox(
                        color: AppColors.scrim,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: AppSpacing.md),
                              Text(_stageText(l10n, state.stage), key: const ValueKey('ai-stage')),
                              if (state.stage == AiStage.queued) ...[
                                const SizedBox(height: AppSpacing.sm),
                                TextButton(
                                  key: const ValueKey('ai-cancel'),
                                  onPressed: _controller.cancel,
                                  child: Text(l10n.actionCancel),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (state.resultPath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l10n.aiViewResult)),
                ButtonSegment(value: true, label: Text(l10n.aiViewOriginal)),
              ],
              selected: {_showOriginal},
              onSelectionChanged: (selection) => setState(() => _showOriginal = selection.first),
            ),
          ),
        if (state.stage == AiStage.failed && state.errorCode != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Text(
              apiErrorText(l10n, state.errorCode),
              key: const ValueKey('ai-error'),
              style: textTheme.bodyMedium?.copyWith(color: AppColors.danger),
              textAlign: TextAlign.center,
            ),
          ),
        if (!enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Text(l10n.errorAiUnavailable, style: textTheme.bodyMedium?.copyWith(color: AppColors.warning)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          child: Wrap(
            spacing: AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: [
              for (final (mode, label) in [
                (BackgroundMode.blur, l10n.aiModeBlur),
                (BackgroundMode.color, l10n.aiModeColor),
                (BackgroundMode.remove, l10n.aiModeRemove),
              ])
                ChoiceChip(
                  key: ValueKey('ai-mode-${mode.name}'),
                  label: Text(label),
                  selected: state.mode == mode,
                  onSelected: state.busy ? null : (_) => _controller.setMode(mode),
                ),
            ],
          ),
        ),
        if (state.mode == BackgroundMode.color)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final color in backgroundSwatches)
                  Semantics(
                    button: true,
                    selected: state.color == color,
                    label: hexColor(color),
                    child: GestureDetector(
                      key: ValueKey('ai-swatch-${hexColor(color)}'),
                      onTap: state.busy ? null : () => _controller.setColor(color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: state.color == color ? AppColors.accent : AppColors.outline,
                            width: state.color == color ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.stage == AiStage.done)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('ai-save'),
                      onPressed: state.savedToGallery ? null : _save,
                      icon: const Icon(Icons.download_outlined),
                      label: Text(l10n.videoSaveToGallery),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('ai-edit'),
                      onPressed: _openInEditor,
                      icon: const Icon(Icons.tune),
                      label: Text(l10n.aiOpenEditor),
                    ),
                  ],
                )
              else
                FilledButton(
                  key: const ValueKey('ai-start'),
                  onPressed: state.canStart && enabled && widget.balance >= cost ? _controller.start : null,
                  child: Text(l10n.aiStart(cost)),
                ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      key: const ValueKey('ai-pick-gallery'),
                      onPressed: state.busy ? null : () => _controller.pick(PhotoOrigin.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(l10n.aiPickGallery),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: state.busy ? null : () => _controller.pick(PhotoOrigin.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(l10n.aiPickCamera),
                    ),
                  ),
                ],
              ),
              Text(
                '${l10n.aiBalance(widget.balance)} · ${l10n.aiPrivacyNote}',
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _stageText(AppLocalizations l10n, AiStage stage) => switch (stage) {
    AiStage.uploading => l10n.aiStageUploading,
    AiStage.queued => l10n.aiStageQueued,
    AiStage.downloading => l10n.aiStageDownloading,
    _ => l10n.aiStageRunning,
  };
}
