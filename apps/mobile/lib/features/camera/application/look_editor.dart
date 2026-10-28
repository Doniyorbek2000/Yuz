import '../domain/beauty_adjustments.dart';
import '../domain/beauty_preset.dart';
import '../domain/color_filters.dart';

/// Edits a look (camera or photo project). The studio panel only talks to
/// this interface, so the same UI drives the live camera and photo editing.
abstract interface class LookEditor {
  /// Call when a slider drag starts so the whole drag is one undo step.
  void beginEdit();

  void updateLive(BeautyEffect effect, int value);

  Future<void> endEdit();

  void applyPreset(BeautyPreset preset);

  void selectFilter(FilterId filter);

  void selectColor(MakeupItem item, int color);

  void undo();

  void reset();
}
