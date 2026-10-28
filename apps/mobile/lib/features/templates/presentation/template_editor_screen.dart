import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../camera/presentation/engine_error_text.dart';
import '../application/template_editor_controller.dart';
import '../domain/template_layout.dart';
import 'template_painter.dart';

/// Picks a photo for a slot; overridable in tests.
final templatePhotoPickerProvider = Provider<Future<String?> Function()>((ref) {
  return () async => (await ImagePicker().pickImage(source: ImageSource.gallery))?.path;
});

const _backgrounds = <int>[0xFFF5F3F7, 0xFF0B0B0F, 0xFFE8A598, 0xFFF2E6D9, 0xFF2C2C3A, 0xFFDCE9E2, 0xFFE1E8F5];

class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({super.key});

  @override
  ConsumerState<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  SlotTransform? _gestureStart;

  TemplateEditorController get _controller => ref.read(templateEditorControllerProvider.notifier);

  Future<void> _pick(int slot) async {
    final path = await ref.read(templatePhotoPickerProvider)();
    if (path == null || !mounted) return;
    await _controller.setPhoto(slot, path);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await _controller.save();
    if (result == null) return;
    messenger.showSnackBar(SnackBar(content: Text(result.$2 ? l10n.photoSavedToGallery : l10n.photoSavedInApp)));
  }

  int? _slotAt(Offset position, Size size, TemplateEditorState state) {
    for (var index = 0; index < state.layout.slots.length; index++) {
      if (slotRect(state.layout.slots[index], size, state.style.spacing).contains(position)) return index;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(templateEditorControllerProvider);
    ref.listen(templateEditorControllerProvider.select((s) => s.error), (_, error) {
      if (error == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message(l10n))));
      _controller.acknowledgeError();
    });
    final selected = state.selectedSlot;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.templatesTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton.icon(
              key: const ValueKey('template-save'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: state.images.isEmpty || state.saving ? null : _save,
              icon: state.saving
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(l10n.templatesSave),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: AspectRatio(
                  aspectRatio: state.layout.aspectRatio,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest;
                      return GestureDetector(
                        key: const ValueKey('template-canvas'),
                        onTapUp: (details) {
                          final slot = _slotAt(details.localPosition, size, state);
                          if (slot == null) {
                            _controller.selectSlot(null);
                          } else if (!state.images.containsKey(slot)) {
                            _pick(slot);
                          } else {
                            _controller.selectSlot(slot);
                          }
                        },
                        onScaleStart: (details) {
                          final slot = _slotAt(details.localFocalPoint, size, state);
                          if (slot != null && state.images.containsKey(slot)) _controller.selectSlot(slot);
                          final active = slot ?? state.selectedSlot;
                          _gestureStart = active == null ? null : (state.transforms[active] ?? const SlotTransform());
                        },
                        onScaleUpdate: (details) {
                          final slot = ref.read(templateEditorControllerProvider).selectedSlot;
                          final start = _gestureStart;
                          if (slot == null || start == null) return;
                          final rect = slotRect(state.layout.slots[slot], size, state.style.spacing);
                          final current = ref.read(templateEditorControllerProvider).transforms[slot] ?? start;
                          // Dragging right reveals more of the left side of the photo.
                          _controller.updateTransform(
                            slot,
                            current.copyWith(
                              zoom: start.zoom * details.scale,
                              panX: current.panX - details.focalPointDelta.dx / rect.width * 2,
                              panY: current.panY - details.focalPointDelta.dy / rect.height * 2,
                            ),
                          );
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: TemplatePainter(
                                layout: state.layout,
                                style: state.style,
                                images: state.images,
                                transforms: state.transforms,
                                selectedSlot: selected,
                              ),
                            ),
                            for (var index = 0; index < state.layout.slots.length; index++)
                              if (!state.images.containsKey(index) || state.loadingSlot == index)
                                Positioned.fromRect(
                                  rect: slotRect(state.layout.slots[index], size, state.style.spacing),
                                  child: IgnorePointer(
                                    child: Center(
                                      child: state.loadingSlot == index
                                          ? const CircularProgressIndicator(strokeWidth: 2)
                                          : Icon(
                                              Icons.add_photo_alternate_outlined,
                                              key: ValueKey('slot-empty-$index'),
                                              color: AppColors.textMuted,
                                              size: 32,
                                            ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (selected != null && state.images.containsKey(selected))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.templatesSlotHint, style: Theme.of(context).textTheme.bodySmall)),
                  TextButton.icon(
                    key: const ValueKey('slot-replace'),
                    onPressed: () => _pick(selected),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: Text(l10n.templatesReplace),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: _TemplateControls(state: state, controller: _controller),
          ),
        ],
      ),
    );
  }
}

class _TemplateControls extends StatelessWidget {
  const _TemplateControls({required this.state, required this.controller});

  final TemplateEditorState state;
  final TemplateEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = state.style;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 76,
            child: ListView.separated(
              key: const ValueKey('template-layouts'),
              scrollDirection: Axis.horizontal,
              itemCount: kTemplateLayouts.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final layout = kTemplateLayouts[index];
                final selected = layout.id == state.layout.id;
                return GestureDetector(
                  key: ValueKey('layout-${layout.id}'),
                  onTap: () => controller.selectLayout(layout),
                  child: Container(
                    width: 64,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: const BorderRadius.all(AppRadii.sm),
                      border: Border.all(color: selected ? AppColors.accent : Colors.transparent, width: 2),
                    ),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: layout.aspectRatio,
                        child: CustomPaint(
                          painter: TemplatePainter(
                            layout: layout,
                            style: const TemplateStyle(background: 0xFF2C2C3A, spacing: 0.06, cornerRadius: 0.04),
                            images: const {},
                            transforms: const {},
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _backgrounds.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final color = _backgrounds[index];
                return Semantics(
                  button: true,
                  selected: style.background == color,
                  label: '${l10n.templatesBackground} ${index + 1}',
                  child: GestureDetector(
                    key: ValueKey('background-$color'),
                    onTap: () => controller.editStyle((s) => s.copyWith(background: color)),
                    child: Container(
                      width: 30,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: style.background == color ? AppColors.accent : AppColors.outline,
                          width: style.background == color ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              const Icon(Icons.space_bar_rounded, size: 18, color: AppColors.textSecondary),
              Expanded(
                child: Slider(
                  key: const ValueKey('template-spacing'),
                  value: style.spacing,
                  max: 0.08,
                  semanticFormatterCallback: (v) => '${l10n.templatesSpacing} ${(v / 0.08 * 100).round()}',
                  onChanged: (v) => controller.editStyle((s) => s.copyWith(spacing: v)),
                ),
              ),
              const Icon(Icons.rounded_corner_rounded, size: 18, color: AppColors.textSecondary),
              Expanded(
                child: Slider(
                  key: const ValueKey('template-corners'),
                  value: style.cornerRadius,
                  max: 0.1,
                  semanticFormatterCallback: (v) => '${l10n.templatesCorners} ${(v / 0.1 * 100).round()}',
                  onChanged: (v) => controller.editStyle((s) => s.copyWith(cornerRadius: v)),
                ),
              ),
            ],
          ),
          if (state.layout.captionArea != null)
            TextField(
              key: const ValueKey('template-caption'),
              maxLength: 60,
              decoration: InputDecoration(hintText: l10n.templatesCaptionHint, isDense: true, counterText: ''),
              onChanged: (value) => controller.editStyle((s) => s.copyWith(caption: value)),
            ),
        ],
      ),
    );
  }
}
