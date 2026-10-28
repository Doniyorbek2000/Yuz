import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';
import 'package:yuz_mobile/features/camera/application/beauty_camera_controller.dart';
import 'package:yuz_mobile/features/camera/data/filter_lut_repository.dart';
import 'package:yuz_mobile/features/camera/domain/beauty_adjustments.dart';
import 'package:yuz_mobile/features/camera/domain/beauty_preset.dart';
import 'package:yuz_mobile/features/camera/domain/color_filters.dart';

import '../helpers/test_app.dart';

Future<Uint8List> encodePng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
      .drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = const Color(0xFF808080));
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BeautyAdjustments (full look)', () {
    test('defaults are the engine identity', () {
      final p = BeautyAdjustments.defaults.toEngineParameters();
      final neutral = neutralBeautyParameters();
      expect(p.encode(), neutral.encode());
    });

    test('maps every effect to its engine field', () {
      final look = BeautyAdjustments({for (final e in BeautyEffect.values) e: 40}, filter: FilterId.warm);
      final p = look.toEngineParameters();
      for (final value in [
        p.skinSmoothing,
        p.texturePreservation,
        p.skinBrightening,
        p.skinTone,
        p.blemishReduction,
        p.shineReduction,
        p.glow,
        p.eyeBrightening,
        p.teethWhitening,
        p.darkCircles,
        p.faceSlim,
        p.jawline,
        p.chin,
        p.eyeEnlarge,
        p.noseSlim,
        p.lips,
        p.forehead,
        p.lipstick,
        p.blush,
        p.eyebrows,
        p.eyeshadow,
        p.eyeliner,
        p.makeupIntensity,
        p.filterIntensity,
      ]) {
        expect(value, 0.4);
      }
    });

    test('filter intensity is zero while no filter is selected', () {
      final look = BeautyAdjustments({BeautyEffect.filterIntensity: 90});
      expect(look.toEngineParameters().filterIntensity, 0);
      expect(look.withFilter(FilterId.cool).toEngineParameters().filterIntensity, 0.9);
    });

    test('makeup colours are carried to the engine', () {
      final look = BeautyAdjustments.defaults.withColor(MakeupItem.lipstick, 0xFF9E2B3A);
      expect(look.toEngineParameters().lipstickColor, 0xFF9E2B3A);
      expect(look.toEngineParameters().blushColor, MakeupItem.blush.defaultColor);
    });

    test('JSON round trip keeps values, filter and colours', () {
      final look = BeautyAdjustments(
        {BeautyEffect.faceSlim: 33, BeautyEffect.eyeliner: 12},
        filter: FilterId.vintage,
        colors: {MakeupItem.eyeshadow: 0xFF7D5A78},
      );
      expect(BeautyAdjustments.fromJson(look.toJson()), look);
    });

    test('JSON from the previous version (flat values only) still loads', () {
      final legacy = BeautyAdjustments.fromJson({'skinSmoothing': 42, 'texturePreservation': 70});
      expect(legacy.valueOf(BeautyEffect.skinSmoothing), 42);
      expect(legacy.filter, FilterId.none);
      expect(legacy.colorOf(MakeupItem.lipstick), MakeupItem.lipstick.defaultColor);
    });

    test('unknown filter names fall back to none', () {
      expect(BeautyAdjustments.fromJson({'filter': 'sepia2099'}).filter, FilterId.none);
    });

    test('usesFaceEffects detects reshape and makeup but not skin or makeup intensity', () {
      expect(BeautyAdjustments({BeautyEffect.skinSmoothing: 80}).usesFaceEffects, isFalse);
      expect(BeautyAdjustments.defaults.usesFaceEffects, isFalse);
      expect(BeautyAdjustments({BeautyEffect.eyeEnlarge: 1}).usesFaceEffects, isTrue);
      expect(BeautyAdjustments({BeautyEffect.lipstick: 1}).usesFaceEffects, isTrue);
    });

    test('every built-in preset has a distinct look and every category has effects', () {
      final looks = BeautyPreset.builtIns.map((p) => p.adjustments).toSet();
      expect(looks.length, BeautyPreset.builtIns.length);
      for (final category in BeautyCategory.values) {
        expect(BeautyEffect.inCategory(category), isNotEmpty);
      }
    });

    test('every makeup effect has a palette and its default shade is first', () {
      for (final effect in BeautyEffect.values.where((e) => e.makeupItem != null)) {
        final item = effect.makeupItem!;
        expect(item.palette, isNotEmpty);
        expect(item.defaultColor, item.palette.first);
      }
    });
  });

  group('FilterLutRepository', () {
    late Directory directory;
    var generated = 0;

    FilterLutRepository repository() => FilterLutRepository(
      storageDirectory: () async => directory,
      generator: (grade) async {
        generated++;
        return ColorLut.build(grade);
      },
    );

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('yuz_filters');
      generated = 0;
    });

    tearDown(() => directory.delete(recursive: true));

    test('none has no LUT; built-ins are generated once and cached', () async {
      final repo = repository();
      expect(await repo.lutFor(FilterId.none), isNull);
      final first = await repo.lutFor(FilterId.blackWhite);
      final second = await repo.lutFor(FilterId.blackWhite);
      expect(first!.length, ColorLut.byteLength);
      expect(identical(first, second), isTrue);
      expect(generated, 1);
    });

    test('custom LUT: missing until imported, then persisted across instances', () async {
      expect(await repository().lutFor(FilterId.custom), isNull);
      await repository().importCustom(await encodePng(512, 512));
      final reloaded = repository();
      expect(await reloaded.hasCustomLut(), isTrue);
      expect((await reloaded.lutFor(FilterId.custom))!.length, ColorLut.byteLength);
    });

    test('rejects images that are not 512x512', () async {
      await expectLater(
        repository().importCustom(await encodePng(256, 256)),
        throwsA(isA<LutImportException>().having((e) => e.error, 'error', LutImportError.wrongSize)),
      );
      expect(await repository().hasCustomLut(), isFalse);
    });

    test('rejects data that is not an image', () async {
      await expectLater(
        repository().importCustom(Uint8List.fromList(List.filled(64, 7))),
        throwsA(isA<LutImportException>().having((e) => e.error, 'error', LutImportError.unreadable)),
      );
    });
  });

  group('camera + filters', () {
    test('camera start uploads the current filter LUT; switching filters re-uploads', () async {
      final host = FakeEngineHost();
      final container = await createContainer(
        host: host,
        preferences: {'beauty.last.v1': '{"filter":"warm","filterIntensity":80}'},
      );
      final subscription = container.listen(beautyCameraControllerProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(beautyCameraControllerProvider.notifier).start();
      expect(host.luts.single?.length, ColorLut.byteLength);
      expect(host.parameters.last.filterIntensity, 0.8);

      container.read(beautyEditorProvider.notifier).selectFilter(FilterId.none);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(host.luts.last, isNull);
      expect(host.parameters.last.filterIntensity, 0);
    });

    test('rapid filter switching applies only the latest LUT', () async {
      final host = FakeEngineHost();
      final container = await createContainer(host: host);
      final subscription = container.listen(beautyCameraControllerProvider, (_, _) {});
      addTearDown(subscription.close);
      final camera = container.read(beautyCameraControllerProvider.notifier);
      await camera.start();
      host.luts.clear();
      await Future.wait([camera.applyFilterLut(FilterId.warm), camera.applyFilterLut(FilterId.none)]);
      expect(host.luts, [null]);
    });
  });
}
