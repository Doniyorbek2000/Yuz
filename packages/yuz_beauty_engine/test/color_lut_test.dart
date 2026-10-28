import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

void main() {
  group('ColorLut.build', () {
    test('produces a 512x512 RGBA table', () {
      final lut = ColorLut.build(ColorGrade.identity);
      expect(lut.length, ColorLut.byteLength);
      expect(ColorLut.isValid(lut, width: 512, height: 512), isTrue);
      expect(ColorLut.isValid(lut, width: 256, height: 1024), isFalse);
    });

    test('identity grade maps every lattice colour to itself', () {
      final lut = ColorLut.build(ColorGrade.identity);
      for (final rgb in const [
        [0.0, 0.0, 0.0],
        [1.0, 1.0, 1.0],
        [0.2, 0.6, 0.9],
        [0.73, 0.11, 0.48],
      ]) {
        final out = ColorLut.lookupNearest(lut, rgb[0], rgb[1], rgb[2]);
        for (var i = 0; i < 3; i++) {
          expect(
            out[i],
            closeTo(rgb[i], 1 / 63 + 1 / 255),
            reason: '$rgb channel $i',
          );
        }
      }
    });

    test('layout: blue selects the tile, red is x and green is y', () {
      final lut = ColorLut.build(ColorGrade.identity);
      // Tile 9 (blue = 9/63) is at tile row 1, column 1; pixel (64+63, 64+0) is r=1, g=0.
      final offset = ((64 + 0) * 512 + (64 + 63)) * 4;
      expect(lut[offset], 255);
      expect(lut[offset + 1], 0);
      expect(lut[offset + 2], (9 / 63 * 255).round());
      expect(lut[offset + 3], 255);
    });

    test('monochrome grade outputs grey', () {
      final lut = ColorLut.build(const ColorGrade(monochrome: true));
      final out = ColorLut.lookupNearest(lut, 0.8, 0.3, 0.2);
      expect(out[0], closeTo(out[1], 1 / 255));
      expect(out[1], closeTo(out[2], 1 / 255));
    });

    test('temperature warms reds and cools blues', () {
      final lut = ColorLut.build(const ColorGrade(temperature: 1));
      final out = ColorLut.lookupNearest(lut, 0.5, 0.5, 0.5);
      expect(out[0], greaterThan(0.55));
      expect(out[2], lessThan(0.45));
    });

    test('fade lifts blacks', () {
      final lut = ColorLut.build(const ColorGrade(fade: 1));
      expect(ColorLut.lookupNearest(lut, 0, 0, 0)[0], greaterThan(0.07));
      expect(ColorLut.lookupNearest(lut, 1, 1, 1)[0], lessThan(0.9));
    });

    test('contrast expands around mid grey', () {
      final lut = ColorLut.build(const ColorGrade(contrast: 0.5));
      expect(ColorLut.lookupNearest(lut, 0.3, 0.3, 0.3)[0], lessThan(0.27));
      expect(ColorLut.lookupNearest(lut, 0.7, 0.7, 0.7)[0], greaterThan(0.73));
    });
  });

  test('neutralBeautyParameters is the engine identity', () {
    final p = neutralBeautyParameters();
    expect(p.skinSmoothing, 0);
    expect(p.faceSlim, 0);
    expect(p.lipstick, 0);
    expect(p.filterIntensity, 0);
    expect(p.makeupIntensity, 1);
    expect(p.texturePreservation, 0.5);
  });
}
