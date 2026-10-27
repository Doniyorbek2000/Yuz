import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/beauty_camera_controller.dart';
import '../domain/beauty_adjustments.dart';
import '../domain/beauty_preset.dart';

extension BeautyEffectLabel on BeautyEffect {
  String label(AppLocalizations l10n) => switch (this) {
    BeautyEffect.skinSmoothing => l10n.beautySkinSmoothing,
    BeautyEffect.texturePreservation => l10n.beautyTexturePreservation,
    BeautyEffect.skinBrightening => l10n.beautySkinBrightening,
  };
}

extension BuiltInPresetLabel on BuiltInPreset {
  String label(AppLocalizations l10n) => switch (this) {
    BuiltInPreset.natural => l10n.beautyPresetNatural,
    BuiltInPreset.soft => l10n.beautyPresetSoft,
    BuiltInPreset.glow => l10n.beautyPresetGlow,
  };
}

/// Sliders (0..100) for every implemented effect, presets, undo and reset.
class BeautyControlsPanel extends ConsumerWidget {
  const BeautyControlsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final editor = ref.watch(beautyEditorProvider);
    final notifier = ref.read(beautyEditorProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PresetStrip(current: editor.current),
        const SizedBox(height: AppSpacing.xs),
        for (final effect in BeautyEffect.values)
          _EffectSlider(
            key: ValueKey(effect),
            label: effect.label(l10n),
            value: editor.current.valueOf(effect),
            onChangeStart: notifier.beginEdit,
            onChanged: (value) => notifier.updateLive(effect, value),
            onChangeEnd: notifier.endEdit,
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: editor.canUndo ? notifier.undo : null,
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: Text(l10n.beautyUndo),
            ),
            TextButton.icon(
              onPressed: editor.isDefault ? null : notifier.reset,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: Text(l10n.beautyReset),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _savePreset(context, ref, editor.current),
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: Text(l10n.beautySavePreset),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _savePreset(BuildContext context, WidgetRef ref, BeautyAdjustments adjustments) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(context: context, builder: (_) => const _PresetNameDialog());
    if (name == null || name.trim().isEmpty) return;
    final preset = await ref.read(userPresetsProvider.notifier).save(name, adjustments);
    messenger.showSnackBar(SnackBar(content: Text(l10n.beautyPresetSaved(preset.name ?? name))));
  }
}

class _EffectSlider extends StatelessWidget {
  const _EffectSlider({
    required this.label,
    required this.value,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    super.key,
  });

  final String label;
  final int value;
  final VoidCallback onChangeStart;
  final ValueChanged<int> onChanged;
  final Future<void> Function() onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: textTheme.bodySmall, overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: BeautyAdjustments.minValue.toDouble(),
            max: BeautyAdjustments.maxValue.toDouble(),
            divisions: BeautyAdjustments.maxValue,
            label: '$value',
            semanticFormatterCallback: (v) => '$label ${v.round()}',
            onChangeStart: (_) => onChangeStart(),
            onChanged: (v) => onChanged(v.round()),
            onChangeEnd: (_) => onChangeEnd(),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: textTheme.labelMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ],
    );
  }
}

class _PresetStrip extends ConsumerWidget {
  const _PresetStrip({required this.current});

  final BeautyAdjustments current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final presets = [...BeautyPreset.builtIns, ...ref.watch(userPresetsProvider)];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final preset = presets[index];
          final label = preset.builtIn?.label(l10n) ?? preset.name ?? '';
          return GestureDetector(
            onLongPress: preset.isUserPreset ? () => _confirmDelete(context, ref, preset, label) : null,
            child: ChoiceChip(
              label: Text(label),
              selected: preset.adjustments == current,
              onSelected: (_) => ref.read(beautyEditorProvider.notifier).applyPreset(preset),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, BeautyPreset preset, String label) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.actionDelete)),
        ],
      ),
    );
    if (confirmed ?? false) await ref.read(userPresetsProvider.notifier).delete(preset.id);
  }
}

class _PresetNameDialog extends StatefulWidget {
  const _PresetNameDialog();

  @override
  State<_PresetNameDialog> createState() => _PresetNameDialogState();
}

class _PresetNameDialogState extends State<_PresetNameDialog> {
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
      title: Text(l10n.beautySavePreset),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        decoration: InputDecoration(hintText: l10n.beautyPresetNameHint),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        TextButton(onPressed: () => Navigator.pop(context, _controller.text), child: Text(l10n.actionSave)),
      ],
    );
  }
}
