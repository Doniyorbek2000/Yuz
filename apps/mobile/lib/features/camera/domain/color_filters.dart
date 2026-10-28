import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

/// Colour filters. Built-ins are defined as [ColorGrade]s and turned into a
/// 512x512 LUT on a background isolate; [custom] is a user-imported LUT.
enum FilterId {
  none(null),
  natural(ColorGrade(saturation: 0.06, contrast: 0.04)),
  soft(ColorGrade(contrast: -0.12, fade: 0.25, exposure: 0.08, saturation: -0.08)),
  glow(ColorGrade(exposure: 0.16, contrast: -0.06, temperature: 0.1, fade: 0.1)),
  portrait(
    ColorGrade(
      saturation: -0.05,
      temperature: 0.06,
      contrast: 0.06,
      highlightTint: [0.6, 0.52, 0.45],
      splitToneStrength: 0.25,
    ),
  ),
  cinematic(
    ColorGrade(
      contrast: 0.15,
      saturation: -0.1,
      shadowTint: [0.32, 0.52, 0.6],
      highlightTint: [0.68, 0.52, 0.38],
      splitToneStrength: 0.6,
    ),
  ),
  warm(ColorGrade(temperature: 0.35, saturation: 0.05)),
  cool(ColorGrade(temperature: -0.35, tint: -0.05)),
  vintage(
    ColorGrade(
      fade: 0.35,
      saturation: -0.25,
      temperature: 0.2,
      contrast: -0.08,
      shadowTint: [0.45, 0.55, 0.45],
      splitToneStrength: 0.3,
    ),
  ),
  blackWhite(ColorGrade(monochrome: true, contrast: 0.15)),
  custom(null);

  const FilterId(this.grade);

  /// null for [none] and [custom].
  final ColorGrade? grade;

  static List<FilterId> get builtIns => values.where((f) => f.grade != null).toList(growable: false);
}
