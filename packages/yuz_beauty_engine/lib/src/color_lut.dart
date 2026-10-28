import 'dart:math' as math;
import 'dart:typed_data';

/// Colour lookup tables in the engine's format: 512x512 RGBA, 8x8 tiles of
/// 64x64. Blue selects the tile (row-major, first data row = top), red is x
/// and green is y inside a tile. This is the de-facto standard "HALD 64"
/// layout used by most LUT tools, so exported LUT PNGs load as-is.
abstract final class ColorLut {
  static const size = 512;
  static const byteLength = size * size * 4;
  static const _levels = 64;

  /// Builds a LUT by applying [grade] to every lattice colour.
  static Uint8List build(ColorGrade grade) {
    final bytes = Uint8List(byteLength);
    final rgb = Float64List(3);
    for (var y = 0; y < size; y++) {
      final tileRow = y ~/ _levels;
      final g = (y % _levels) / (_levels - 1);
      for (var x = 0; x < size; x++) {
        final tile = tileRow * 8 + x ~/ _levels;
        rgb[0] = (x % _levels) / (_levels - 1);
        rgb[1] = g;
        rgb[2] = tile / (_levels - 1);
        grade.apply(rgb);
        final offset = (y * size + x) * 4;
        bytes[offset] = _toByte(rgb[0]);
        bytes[offset + 1] = _toByte(rgb[1]);
        bytes[offset + 2] = _toByte(rgb[2]);
        bytes[offset + 3] = 255;
      }
    }
    return bytes;
  }

  /// The colour the engine would produce for [r],[g],[b] (0..1) with [lut],
  /// sampling the nearest lattice point. Used by tests and previews.
  static List<double> lookupNearest(
    Uint8List lut,
    double r,
    double g,
    double b,
  ) {
    final ri = (r.clamp(0, 1) * (_levels - 1)).round();
    final gi = (g.clamp(0, 1) * (_levels - 1)).round();
    final bi = (b.clamp(0, 1) * (_levels - 1)).round();
    final x = (bi % 8) * _levels + ri;
    final y = (bi ~/ 8) * _levels + gi;
    final offset = (y * size + x) * 4;
    return [lut[offset] / 255, lut[offset + 1] / 255, lut[offset + 2] / 255];
  }

  /// Checks that [rgba] is a decoded 512x512 RGBA image.
  static bool isValid(
    Uint8List rgba, {
    required int width,
    required int height,
  }) => width == size && height == size && rgba.length == byteLength;

  static int _toByte(double value) => (value.clamp(0.0, 1.0) * 255).round();
}

/// A global colour grade. All fields default to "no change".
class ColorGrade {
  const ColorGrade({
    this.exposure = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.temperature = 0,
    this.tint = 0,
    this.fade = 0,
    this.shadowTint = const [0.5, 0.5, 0.5],
    this.highlightTint = const [0.5, 0.5, 0.5],
    this.splitToneStrength = 0,
    this.monochrome = false,
  });

  /// Stops (-1..1 typical).
  final double exposure;

  /// -1..1, 0 = unchanged.
  final double contrast;

  /// -1..1, -1 = greyscale.
  final double saturation;

  /// -1 (cool) .. 1 (warm).
  final double temperature;

  /// -1 (green) .. 1 (magenta).
  final double tint;

  /// 0..1, lifts blacks and lowers whites (film fade).
  final double fade;

  /// RGB 0..1 colours blended into shadows / highlights (0.5 grey = neutral).
  final List<double> shadowTint;
  final List<double> highlightTint;
  final double splitToneStrength;
  final bool monochrome;

  static const identity = ColorGrade();

  /// Applies the grade in place to an RGB triple in 0..1.
  void apply(Float64List rgb) {
    final gain = math.pow(2, exposure).toDouble();
    var r = rgb[0] * gain;
    var g = rgb[1] * gain;
    var b = rgb[2] * gain;

    r += 0.08 * temperature;
    b -= 0.08 * temperature;
    g -= 0.06 * tint;

    final contrastGain = 1 + contrast;
    r = (r - 0.5) * contrastGain + 0.5;
    g = (g - 0.5) * contrastGain + 0.5;
    b = (b - 0.5) * contrastGain + 0.5;

    var luma = 0.299 * r + 0.587 * g + 0.114 * b;
    final saturationGain = monochrome ? 0.0 : 1 + saturation;
    r = luma + (r - luma) * saturationGain;
    g = luma + (g - luma) * saturationGain;
    b = luma + (b - luma) * saturationGain;

    if (splitToneStrength > 0) {
      luma = (0.299 * r + 0.587 * g + 0.114 * b).clamp(0.0, 1.0);
      final shadowWeight = (1 - luma) * (1 - luma) * splitToneStrength;
      final highlightWeight = luma * luma * splitToneStrength;
      r +=
          (shadowTint[0] - 0.5) * shadowWeight +
          (highlightTint[0] - 0.5) * highlightWeight;
      g +=
          (shadowTint[1] - 0.5) * shadowWeight +
          (highlightTint[1] - 0.5) * highlightWeight;
      b +=
          (shadowTint[2] - 0.5) * shadowWeight +
          (highlightTint[2] - 0.5) * highlightWeight;
    }

    if (fade > 0) {
      final scale = 1 - 0.25 * fade;
      final lift = 0.08 * fade;
      r = r * scale + lift;
      g = g * scale + lift;
      b = b * scale + lift;
    }

    rgb[0] = r.clamp(0.0, 1.0);
    rgb[1] = g.clamp(0.0, 1.0);
    rgb[2] = b.clamp(0.0, 1.0);
  }
}
