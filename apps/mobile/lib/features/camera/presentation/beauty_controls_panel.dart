import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:image_picker/image_picker.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/beauty_camera_controller.dart';
import '../application/look_editor.dart';
import '../data/filter_lut_repository.dart';
import '../domain/beauty_adjustments.dart';
import '../domain/beauty_preset.dart';
import '../domain/color_filters.dart';

/// Tabs of the beauty studio, in display order.
enum StudioTab { looks, filters, skin, face, reshape, makeup }

extension StudioTabLabel on StudioTab {
  String label(AppLocalizations l10n) => switch (this) {
    StudioTab.looks => l10n.tabLooks,
    StudioTab.filters => l10n.tabFilters,
    StudioTab.skin => l10n.tabSkin,
    StudioTab.face => l10n.tabFace,
    StudioTab.reshape => l10n.tabReshape,
    StudioTab.makeup => l10n.tabMakeup,
  };

  BeautyCategory? get category => switch (this) {
    StudioTab.skin => BeautyCategory.skin,
    StudioTab.face => BeautyCategory.face,
    StudioTab.reshape => BeautyCategory.reshape,
    StudioTab.makeup => BeautyCategory.makeup,
    StudioTab.looks || StudioTab.filters => null,
  };
}

extension BeautyEffectPresentation on BeautyEffect {
  String label(AppLocalizations l10n) => switch (this) {
    BeautyEffect.skinSmoothing => l10n.effectSkinSmoothing,
    BeautyEffect.texturePreservation => l10n.effectTexturePreservation,
    BeautyEffect.skinBrightening => l10n.effectSkinBrightening,
    BeautyEffect.skinTone => l10n.effectSkinTone,
    BeautyEffect.blemishReduction => l10n.effectBlemishReduction,
    BeautyEffect.shineReduction => l10n.effectShineReduction,
    BeautyEffect.glow => l10n.effectGlow,
    BeautyEffect.eyeBrightening => l10n.effectEyeBrightening,
    BeautyEffect.teethWhitening => l10n.effectTeethWhitening,
    BeautyEffect.darkCircles => l10n.effectDarkCircles,
    BeautyEffect.faceSlim => l10n.effectFaceSlim,
    BeautyEffect.jawline => l10n.effectJawline,
    BeautyEffect.chin => l10n.effectChin,
    BeautyEffect.eyeEnlarge => l10n.effectEyeEnlarge,
    BeautyEffect.noseSlim => l10n.effectNoseSlim,
    BeautyEffect.lips => l10n.effectLips,
    BeautyEffect.forehead => l10n.effectForehead,
    BeautyEffect.lipstick => l10n.effectLipstick,
    BeautyEffect.blush => l10n.effectBlush,
    BeautyEffect.eyebrows => l10n.effectEyebrows,
    BeautyEffect.eyeshadow => l10n.effectEyeshadow,
    BeautyEffect.eyeliner => l10n.effectEyeliner,
    BeautyEffect.makeupIntensity => l10n.effectMakeupIntensity,
    BeautyEffect.filterIntensity => l10n.effectFilterIntensity,
    BeautyEffect.sharpen => l10n.effectSharpen,
  };

  IconData get icon => switch (this) {
    BeautyEffect.skinSmoothing => Icons.blur_on_rounded,
    BeautyEffect.texturePreservation => Icons.grain_rounded,
    BeautyEffect.skinBrightening => Icons.wb_sunny_outlined,
    BeautyEffect.skinTone => Icons.palette_outlined,
    BeautyEffect.blemishReduction => Icons.healing_outlined,
    BeautyEffect.shineReduction => Icons.opacity_rounded,
    BeautyEffect.glow => Icons.auto_awesome_outlined,
    BeautyEffect.eyeBrightening => Icons.remove_red_eye_outlined,
    BeautyEffect.teethWhitening => Icons.sentiment_very_satisfied_outlined,
    BeautyEffect.darkCircles => Icons.nights_stay_outlined,
    BeautyEffect.faceSlim => Icons.face_retouching_natural,
    BeautyEffect.jawline => Icons.change_history_rounded,
    BeautyEffect.chin => Icons.keyboard_arrow_up_rounded,
    BeautyEffect.eyeEnlarge => Icons.visibility_outlined,
    BeautyEffect.noseSlim => Icons.compress_rounded,
    BeautyEffect.lips => Icons.favorite_border_rounded,
    BeautyEffect.forehead => Icons.vertical_align_top_rounded,
    BeautyEffect.lipstick => Icons.brush_outlined,
    BeautyEffect.blush => Icons.circle_outlined,
    BeautyEffect.eyebrows => Icons.horizontal_rule_rounded,
    BeautyEffect.eyeshadow => Icons.gradient_rounded,
    BeautyEffect.eyeliner => Icons.edit_outlined,
    BeautyEffect.makeupIntensity => Icons.tune_rounded,
    BeautyEffect.filterIntensity => Icons.tune_rounded,
    BeautyEffect.sharpen => Icons.details_rounded,
  };
}

extension FilterIdLabel on FilterId {
  String label(AppLocalizations l10n) => switch (this) {
    FilterId.none => l10n.filterNone,
    FilterId.natural => l10n.filterNatural,
    FilterId.soft => l10n.filterSoft,
    FilterId.glow => l10n.filterGlow,
    FilterId.portrait => l10n.filterPortrait,
    FilterId.cinematic => l10n.filterCinematic,
    FilterId.warm => l10n.filterWarm,
    FilterId.cool => l10n.filterCool,
    FilterId.vintage => l10n.filterVintage,
    FilterId.blackWhite => l10n.filterBlackWhite,
    FilterId.custom => l10n.filterCustom,
  };
}

extension BuiltInPresetLabel on BuiltInPreset {
  String label(AppLocalizations l10n) => switch (this) {
    BuiltInPreset.natural => l10n.beautyPresetNatural,
    BuiltInPreset.soft => l10n.beautyPresetSoft,
    BuiltInPreset.glow => l10n.beautyPresetGlow,
    BuiltInPreset.everydayMakeup => l10n.beautyPresetEverydayMakeup,
    BuiltInPreset.eveningMakeup => l10n.beautyPresetEveningMakeup,
  };
}

/// The beauty studio: tab row, per-tab content and the undo/reset/save row.
class BeautyStudioPanel extends ConsumerStatefulWidget {
  const BeautyStudioPanel({
    required this.faceTrackingAvailable,
    required this.look,
    required this.editor,
    this.onCustomLutImported,
    super.key,
  });

  /// When false, face-dependent effects are shown but marked as unavailable.
  final bool faceTrackingAvailable;

  /// The look being edited (camera look or a photo project's look).
  final ProviderListenable<BeautyEditorState> look;
  final LookEditor Function(WidgetRef ref) editor;

  /// Re-applies the custom LUT after a new one was imported.
  final Future<void> Function()? onCustomLutImported;

  @override
  ConsumerState<BeautyStudioPanel> createState() => _BeautyStudioPanelState();
}

class _BeautyStudioPanelState extends ConsumerState<BeautyStudioPanel> {
  StudioTab _tab = StudioTab.skin;
  final Map<BeautyCategory, BeautyEffect> _selected = {
    for (final category in BeautyCategory.values) category: BeautyEffect.inCategory(category).first,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editor = ref.watch(widget.look);
    final notifier = widget.editor(ref);
    final category = _tab.category;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: StudioTab.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, index) {
              final tab = StudioTab.values[index];
              return ChoiceChip(
                key: ValueKey('studio-tab-${tab.name}'),
                label: Text(tab.label(l10n)),
                selected: tab == _tab,
                showCheckmark: false,
                onSelected: (_) => setState(() => _tab = tab),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSize(
          duration: AppDurations.medium,
          alignment: Alignment.topCenter,
          child: switch (_tab) {
            StudioTab.looks => _LooksTab(current: editor.current, editor: notifier),
            StudioTab.filters => _FiltersTab(
              current: editor.current,
              editor: notifier,
              onCustomLutImported: widget.onCustomLutImported,
            ),
            _ => _EffectsTab(
              editor: notifier,
              key: ValueKey(category),
              category: category!,
              selected: _selected[category]!,
              adjustments: editor.current,
              faceTrackingAvailable: widget.faceTrackingAvailable,
              onSelect: (effect) => setState(() => _selected[category] = effect),
            ),
          },
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
            Flexible(
              child: TextButton.icon(
                onPressed: () => _savePreset(context, editor.current),
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: Text(l10n.beautySavePreset, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _savePreset(BuildContext context, BeautyAdjustments adjustments) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(context: context, builder: (_) => const _PresetNameDialog());
    if (name == null || name.trim().isEmpty) return;
    final preset = await ref.read(userPresetsProvider.notifier).save(name, adjustments);
    messenger.showSnackBar(SnackBar(content: Text(l10n.beautyPresetSaved(preset.name ?? name))));
  }
}

class _EffectsTab extends ConsumerWidget {
  const _EffectsTab({
    required this.editor,
    required this.category,
    required this.selected,
    required this.adjustments,
    required this.faceTrackingAvailable,
    required this.onSelect,
    super.key,
  });

  final BeautyCategory category;
  final BeautyEffect selected;
  final BeautyAdjustments adjustments;
  final bool faceTrackingAvailable;
  final ValueChanged<BeautyEffect> onSelect;
  final LookEditor editor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final effects = BeautyEffect.inCategory(category);
    final notifier = editor;
    final unavailable = selected.requiresFace && !faceTrackingAvailable;
    final item = selected.makeupItem;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: effects.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, index) {
              final effect = effects[index];
              return _EffectButton(
                key: ValueKey('effect-${effect.name}'),
                label: effect.label(l10n),
                icon: effect.icon,
                selected: effect == selected,
                active: adjustments.valueOf(effect) != effect.defaultValue,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(effect);
                },
              );
            },
          ),
        ),
        _ValueSlider(
          key: ValueKey('slider-${selected.name}'),
          label: selected.label(l10n),
          value: adjustments.valueOf(selected),
          enabled: !unavailable,
          onChangeStart: notifier.beginEdit,
          onChanged: (value) => notifier.updateLive(selected, value),
          onChangeEnd: notifier.endEdit,
        ),
        if (unavailable)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              l10n.requiresFaceTracking,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.warning),
            ),
          ),
        if (item != null && !unavailable) _ShadePicker(item: item, selected: adjustments.colorOf(item), editor: editor),
      ],
    );
  }
}

class _EffectButton extends StatelessWidget {
  const _EffectButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadii.sm),
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: AppDurations.fast,
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.accent.withValues(alpha: 0.18) : AppColors.surfaceRaised,
                      border: Border.all(color: selected ? AppColors.accent : AppColors.outline),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  if (active)
                    const Positioned(
                      right: 0,
                      top: 0,
                      child: CircleAvatar(radius: 4, backgroundColor: AppColors.accent),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueSlider extends StatelessWidget {
  const _ValueSlider({
    this.leading,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    super.key,
  });

  final String label;
  final int value;
  final bool enabled;
  final VoidCallback onChangeStart;
  final ValueChanged<int> onChanged;
  final Future<void> Function() onChangeEnd;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        if (leading != null)
          Tooltip(
            message: label,
            child: Icon(leading, size: 18, color: AppColors.textSecondary),
          ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: BeautyAdjustments.minValue.toDouble(),
            max: BeautyAdjustments.maxValue.toDouble(),
            divisions: BeautyAdjustments.maxValue,
            label: '$value',
            semanticFormatterCallback: (v) => '$label ${v.round()}',
            onChangeStart: enabled ? (_) => onChangeStart() : null,
            onChanged: enabled ? (v) => onChanged(v.round()) : null,
            onChangeEnd: enabled ? (_) => onChangeEnd() : null,
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

class _ShadePicker extends ConsumerWidget {
  const _ShadePicker({required this.item, required this.selected, required this.editor});

  final MakeupItem item;
  final int selected;
  final LookEditor editor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: item.palette.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final color = item.palette[index];
          final isSelected = color == selected;
          return Semantics(
            button: true,
            selected: isSelected,
            label: '${l10n.makeupShade} ${index + 1}',
            child: GestureDetector(
              key: ValueKey('shade-${item.name}-$index'),
              onTap: () => editor.selectColor(item, color),
              child: AnimatedContainer(
                duration: AppDurations.fast,
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Color(color),
                  shape: BoxShape.circle,
                  border: Border.all(color: isSelected ? AppColors.textPrimary : Colors.transparent, width: 2.5),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LooksTab extends ConsumerWidget {
  const _LooksTab({required this.current, required this.editor});

  final BeautyAdjustments current;
  final LookEditor editor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final presets = [...BeautyPreset.builtIns, ...ref.watch(userPresetsProvider)];
    return SizedBox(
      height: 44,
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
              onSelected: (_) => editor.applyPreset(preset),
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

class _FiltersTab extends ConsumerStatefulWidget {
  const _FiltersTab({required this.current, required this.editor, this.onCustomLutImported});

  final BeautyAdjustments current;
  final LookEditor editor;
  final Future<void> Function()? onCustomLutImported;

  @override
  ConsumerState<_FiltersTab> createState() => _FiltersTabState();
}

class _FiltersTabState extends ConsumerState<_FiltersTab> {
  bool _hasCustom = false;

  @override
  void initState() {
    super.initState();
    ref.read(filterLutRepositoryProvider).hasCustomLut().then((value) {
      if (mounted) setState(() => _hasCustom = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notifier = widget.editor;
    final filters = [FilterId.none, ...FilterId.builtIns, if (_hasCustom) FilterId.custom];
    final current = widget.current;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == filters.length) {
                return _FilterTile(
                  key: const ValueKey('filter-import'),
                  label: l10n.filterImport,
                  selected: false,
                  colors: const [AppColors.surfaceRaised, AppColors.surfaceRaised],
                  icon: Icons.add_photo_alternate_outlined,
                  onTap: _importLut,
                );
              }
              final filter = filters[index];
              return _FilterTile(
                key: ValueKey('filter-${filter.name}'),
                label: filter.label(l10n),
                selected: filter == current.filter,
                colors: _previewColors(filter),
                icon: filter == FilterId.custom ? Icons.photo_filter_outlined : null,
                onTap: () => notifier.selectFilter(filter),
              );
            },
          ),
        ),
        if (current.filter != FilterId.none)
          _ValueSlider(
            key: const ValueKey('slider-filterIntensity'),
            label: l10n.effectFilterIntensity,
            value: current.valueOf(BeautyEffect.filterIntensity),
            enabled: true,
            onChangeStart: notifier.beginEdit,
            onChanged: (value) => notifier.updateLive(BeautyEffect.filterIntensity, value),
            onChangeEnd: notifier.endEdit,
          ),
        _ValueSlider(
          key: const ValueKey('slider-sharpen'),
          label: l10n.effectSharpen,
          value: current.valueOf(BeautyEffect.sharpen),
          enabled: true,
          leading: Icons.details_rounded,
          onChangeStart: notifier.beginEdit,
          onChanged: (value) => notifier.updateLive(BeautyEffect.sharpen, value),
          onChangeEnd: notifier.endEdit,
        ),
      ],
    );
  }

  Future<void> _importLut() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, requestFullMetadata: false);
    if (picked == null) return;
    try {
      await ref.read(filterLutRepositoryProvider).importCustom(await picked.readAsBytes());
      if (!mounted) return;
      setState(() => _hasCustom = true);
      widget.editor.selectFilter(FilterId.custom);
      // Re-apply even if "custom" was already selected (new table).
      await widget.onCustomLutImported?.call();
      messenger.showSnackBar(SnackBar(content: Text(l10n.lutImported)));
    } on LutImportException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.error == LutImportError.wrongSize ? l10n.lutImportWrongSize : l10n.lutImportUnreadable),
        ),
      );
    }
  }

  /// Two representative colours (skin, sky) graded by the filter for the tile.
  static List<Color> _previewColors(FilterId filter) {
    const samples = [
      [0.86, 0.62, 0.52],
      [0.35, 0.55, 0.85],
    ];
    final grade = filter.grade;
    return [
      for (final sample in samples)
        if (grade == null)
          Color.from(alpha: 1, red: sample[0], green: sample[1], blue: sample[2])
        else
          _graded(grade, sample),
    ];
  }

  static Color _graded(ColorGrade grade, List<double> rgb) {
    final values = Float64List.fromList(rgb);
    grade.apply(values);
    return Color.from(alpha: 1, red: values[0], green: values[1], blue: values[2]);
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final List<Color> colors;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              AnimatedContainer(
                duration: AppDurations.fast,
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(AppRadii.sm),
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                  border: Border.all(color: selected ? AppColors.accent : AppColors.outline, width: selected ? 2 : 1),
                ),
                child: icon == null ? null : Icon(icon, color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: selected ? AppColors.accent : AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
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
