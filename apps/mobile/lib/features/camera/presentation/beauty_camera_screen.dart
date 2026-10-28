import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

import '../../../core/storage/preferences.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../permissions/camera_permission_service.dart';
import '../application/beauty_camera_controller.dart';
import '../domain/color_filters.dart';
import 'beauty_controls_panel.dart';
import 'engine_error_text.dart';

class BeautyCameraScreen extends ConsumerStatefulWidget {
  const BeautyCameraScreen({super.key});

  @override
  ConsumerState<BeautyCameraScreen> createState() => _BeautyCameraScreenState();
}

enum _PanelTab { beauty, camera, hidden }

class _BeautyCameraScreenState extends ConsumerState<BeautyCameraScreen> {
  late final BeautyCameraController _controller;
  late final AppLifecycleListener _lifecycle;
  _PanelTab _tab = _PanelTab.beauty;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(beautyCameraControllerProvider.notifier);
    _lifecycle = AppLifecycleListener(
      onHide: () => unawaited(_controller.onAppPaused()),
      onShow: () => unawaited(_controller.onAppResumed()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIfPermitted());
  }

  Future<void> _startIfPermitted() async {
    final permission = await ref.read(cameraPermissionServiceProvider).status();
    if (!mounted) return;
    if (permission != CameraPermissionState.granted) {
      context.go('/permissions?next=/camera');
      return;
    }
    await _controller.start();
  }

  @override
  void dispose() {
    // The autoDispose controller releases the native session when this
    // screen's provider subscription goes away.
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(beautyCameraControllerProvider);
    final showPerformance = ref.watch(performanceOverlayProvider);

    ref.listen(beautyCameraControllerProvider.select((s) => s.transientError), (_, error) {
      if (error == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message(l10n))));
      _controller.acknowledgeTransientError();
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        // Leaving would discard the running recording; stop it first.
        canPop: !state.isRecording && !state.isFinishingRecording,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _PreviewLayer(state: state),
              if (state.countdown != null) _CountdownOverlay(seconds: state.countdown!),
              if (state.screenFlash)
                const IgnorePointer(
                  child: ColoredBox(key: ValueKey('screen-flash'), color: Colors.white),
                ),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(state: state, controller: _controller),
                    if (state.isRecording) _RecordingIndicator(state: state),
                    if (state.isReady && !state.isRecording) _FaceStatusChip(state: state),
                    if (showPerformance && state.performance != null) _PerformanceText(sample: state.performance!),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: state.isReady
                            ? SingleChildScrollView(
                                child: _BottomPanel(
                                  state: state,
                                  tab: _tab,
                                  onTabChanged: (tab) => setState(() => _tab = tab),
                                  controller: _controller,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewLayer extends ConsumerWidget {
  const _PreviewLayer({required this.state});

  final CameraViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    switch (state.phase) {
      case CameraPhase.ready when state.descriptor != null:
        return BeautyCameraPreview(descriptor: state.descriptor!);
      case CameraPhase.error:
        final code = state.errorCode ?? EngineErrorCode.unknown;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_outlined, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: AppSpacing.md),
                Text(code.message(l10n), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: code == EngineErrorCode.permissionDenied
                      ? () => context.go('/permissions?next=/camera')
                      : () => ref.read(beautyCameraControllerProvider.notifier).start(),
                  child: Text(l10n.actionRetry),
                ),
              ],
            ),
          ),
        );
      case CameraPhase.idle:
      case CameraPhase.initializing:
      case CameraPhase.ready:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.cameraStarting),
            ],
          ),
        );
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.controller});

  final CameraViewState state;
  final BeautyCameraController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasFlash = state.availableFlashModes.length > 1;
    final (flashIcon, flashLabel) = switch (state.flashMode) {
      FlashMode.off => (Icons.flash_off_rounded, l10n.cameraFlashOff),
      FlashMode.auto => (Icons.flash_auto_rounded, l10n.cameraFlashAuto),
      FlashMode.on => (Icons.flash_on_rounded, l10n.cameraFlashOn),
      FlashMode.torch => (Icons.highlight_rounded, l10n.cameraFlashTorch),
    };
    final timerLabel = state.timerSeconds == 0 ? l10n.cameraTimerOff : l10n.cameraTimerSeconds(state.timerSeconds);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: state.isRecording || state.isFinishingRecording
                ? null
                : () => context.canPop() ? context.pop() : context.go('/home'),
          ),
          const Spacer(),
          if (hasFlash)
            _GlassIconButton(
              icon: flashIcon,
              tooltip: flashLabel,
              onPressed: state.isBusy ? null : controller.cycleFlashMode,
            ),
          _GlassIconButton(
            icon: state.timerSeconds == 0 ? Icons.timer_off_outlined : Icons.timer_outlined,
            tooltip: timerLabel,
            badge: state.timerSeconds == 0 ? null : '${state.timerSeconds}',
            onPressed: state.isReady && !state.isBusy ? controller.cycleTimer : null,
          ),
          _GlassIconButton(
            icon: Icons.cameraswitch_outlined,
            tooltip: l10n.cameraSwitch,
            onPressed:
                state.isReady &&
                    !state.isBusy &&
                    (state.capabilities?.hasBackCamera ?? false) &&
                    (state.capabilities?.hasFrontCamera ?? false)
                ? controller.switchLens
                : null,
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.tooltip, required this.onPressed, this.badge});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      child: Material(
        color: AppColors.scrim,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: badge == null ? Icon(icon) : Badge(label: Text(badge!), child: Icon(icon)),
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _FaceStatusChip extends StatelessWidget {
  const _FaceStatusChip({required this.state});

  final CameraViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trackingAvailable = state.descriptor?.faceTrackingAvailable ?? false;
    final faces = state.faceStatus?.faceCount ?? 0;
    final text = !trackingAvailable
        ? l10n.cameraTrackingUnavailable
        : faces == 0
        ? l10n.cameraNoFace
        : l10n.cameraFacesDetected(faces);
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        decoration: const BoxDecoration(color: AppColors.scrim, borderRadius: BorderRadius.all(AppRadii.pill)),
        child: Text(text, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}

class _PerformanceText extends StatelessWidget {
  const _PerformanceText({required this.sample});

  final PerformanceSample sample;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Text(
        l10n.cameraMeasuredFps(
          sample.renderedFps.toStringAsFixed(1),
          sample.averageGpuFrameMillis.toStringAsFixed(1),
          sample.averageDetectorMillis.toStringAsFixed(1),
        ),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: AppColors.textSecondary, fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedSwitcher(
          duration: AppDurations.medium,
          child: Text(
            '$seconds',
            key: ValueKey(seconds),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w300,
              shadows: const [Shadow(blurRadius: 16, color: Colors.black54)],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.state, required this.tab, required this.onTabChanged, required this.controller});

  final CameraViewState state;
  final _PanelTab tab;
  final ValueChanged<_PanelTab> onTabChanged;
  final BeautyCameraController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xE6000000)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: AppDurations.medium,
              alignment: Alignment.bottomCenter,
              child: switch (tab) {
                _PanelTab.beauty => BeautyStudioPanel(
                  faceTrackingAvailable: state.descriptor?.faceTrackingAvailable ?? false,
                  look: beautyEditorProvider,
                  editor: (ref) => ref.read(beautyEditorProvider.notifier),
                  onCustomLutImported: () => controller.applyFilterLut(FilterId.custom),
                ),
                _PanelTab.camera => _CameraAdjustments(state: state, controller: controller),
                _PanelTab.hidden => const SizedBox(width: double.infinity),
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _ModeSelector(state: state, controller: controller),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      key: const ValueKey('toggle-camera-adjustments'),
                      tooltip: l10n.tabCamera,
                      isSelected: tab == _PanelTab.camera,
                      icon: const Icon(Icons.tune_rounded),
                      selectedIcon: const Icon(Icons.face_retouching_natural),
                      onPressed: () => onTabChanged(tab == _PanelTab.camera ? _PanelTab.beauty : _PanelTab.camera),
                    ),
                  ),
                ),
                _ShutterButton(state: state, controller: controller),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      key: const ValueKey('toggle-panel'),
                      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                      icon: Icon(tab == _PanelTab.hidden ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                      onPressed: () => onTabChanged(tab == _PanelTab.hidden ? _PanelTab.beauty : _PanelTab.hidden),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraAdjustments extends StatelessWidget {
  const _CameraAdjustments({required this.state, required this.controller});

  final CameraViewState state;
  final BeautyCameraController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final capabilities = state.capabilities;
    if (capabilities == null) return const SizedBox.shrink();
    final canZoom = capabilities.maxZoomRatio > capabilities.minZoomRatio;
    final canExpose = capabilities.maxExposureBias > capabilities.minExposureBias;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canZoom)
          _LabeledSlider(
            label: l10n.cameraZoom,
            valueText: '${state.zoomRatio.toStringAsFixed(1)}×',
            value: state.zoomRatio,
            min: capabilities.minZoomRatio,
            max: capabilities.maxZoomRatio,
            onChanged: controller.setZoomRatio,
          ),
        if (canExpose)
          _LabeledSlider(
            label: l10n.cameraExposure,
            valueText: '${state.exposureBias >= 0 ? '+' : ''}${state.exposureBias.toStringAsFixed(1)} EV',
            value: state.exposureBias,
            min: capabilities.minExposureBias,
            max: capabilities.maxExposureBias,
            onChanged: controller.setExposureBias,
          ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(width: 88, child: Text(label, style: textTheme.bodySmall)),
        Expanded(
          child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(
          width: 64,
          child: Text(valueText, textAlign: TextAlign.end, style: textTheme.labelMedium),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.state, required this.controller});

  final CameraViewState state;
  final BeautyCameraController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget option(CaptureMode mode, String label) {
      final selected = state.mode == mode;
      return Semantics(
        selected: selected,
        button: true,
        child: TextButton(
          key: ValueKey('mode-${mode.name}'),
          onPressed: state.isBusy ? null : () => controller.setMode(mode),
          style: TextButton.styleFrom(
            foregroundColor: selected ? AppColors.accent : AppColors.textSecondary,
            textStyle: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
          ),
          child: Text(label),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        option(CaptureMode.photo, l10n.cameraModePhoto),
        const SizedBox(width: AppSpacing.md),
        option(CaptureMode.video, l10n.cameraModeVideo),
      ],
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator({required this.state});

  final CameraViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seconds = state.recordingSeconds;
    final text = '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final silent = state.recordingHasAudio == false;
    return Semantics(
      liveRegion: true,
      label: '${l10n.cameraRecording} $text${silent ? ', ${l10n.cameraRecordingNoSound}' : ''}',
      child: Container(
        key: const ValueKey('recording-indicator'),
        margin: const EdgeInsets.only(top: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        decoration: const BoxDecoration(color: AppColors.scrim, borderRadius: BorderRadius.all(AppRadii.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
              child: SizedBox.square(dimension: 8),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              text,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            if (silent) ...[
              const SizedBox(width: AppSpacing.xs),
              Tooltip(
                message: l10n.cameraRecordingNoSound,
                child: const Icon(Icons.mic_off_rounded, size: 16, color: AppColors.warning),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.state, required this.controller});

  final CameraViewState state;
  final BeautyCameraController controller;

  Future<void> _onTap(BuildContext context) async {
    if (state.countdown != null) {
      controller.cancelCountdown();
      return;
    }
    if (state.mode == CaptureMode.video) {
      if (state.isRecording) {
        final result = await controller.stopRecording();
        if (result != null && context.mounted) {
          unawaited(HapticFeedback.mediumImpact());
          await context.push('/video?path=${Uri.encodeComponent(result.filePath)}&audio=${result.hasAudio ? 1 : 0}');
        }
      } else if (await controller.startRecording()) {
        unawaited(HapticFeedback.mediumImpact());
      }
      return;
    }
    final result = await controller.capture();
    if (result != null && context.mounted) {
      unawaited(HapticFeedback.lightImpact());
      await context.push('/capture?path=${Uri.encodeComponent(result.filePath)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final video = state.mode == CaptureMode.video;
    final busy = state.isCapturing || state.countdown != null || state.isFinishingRecording;
    final label = !video
        ? l10n.cameraCapture
        : state.isRecording
        ? l10n.cameraRecordStop
        : l10n.cameraRecordStart;
    final Color fill = video ? AppColors.danger : (busy ? AppColors.accent : AppColors.textPrimary);
    final recording = video && state.isRecording;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: const ValueKey('shutter'),
        onTap: state.isFinishingRecording ? null : () => _onTap(context),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textPrimary, width: 4),
          ),
          padding: EdgeInsets.all(recording ? 20 : 5),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.all(recording ? AppRadii.sm : const Radius.circular(40)),
            ),
            child: state.isCapturing || state.isFinishingRecording
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
