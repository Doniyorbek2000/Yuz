import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';
import 'package:yuz_mobile/features/camera/domain/beauty_adjustments.dart';
import 'package:yuz_mobile/features/camera/domain/color_filters.dart';
import 'package:yuz_mobile/features/video/application/video_editor_controller.dart';
import 'package:yuz_mobile/features/video/data/video_project_repository.dart';
import 'package:yuz_mobile/features/video/domain/video_project.dart';

import '../helpers/test_app.dart';

const _probe = (durationMillis: 10000, width: 1080, height: 1920, hasAudio: true);

VideoClip _clip({int duration = 10000, int start = 0, int? end, double speed = 1, bool audio = true}) => VideoClip(
  id: 'c${Random().nextInt(1 << 30)}',
  fileName: 'clip.mp4',
  durationMillis: duration,
  width: 1080,
  height: 1920,
  hasAudio: audio,
  startMillis: start,
  endMillis: end ?? duration,
  speed: speed,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoProject domain', () {
    test('timeline lengths follow trims and speed', () {
      final project = VideoProject(
        id: '1-a',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        clips: [_clip(start: 1000, end: 5000), _clip(end: 4000, speed: 2)],
        look: BeautyAdjustments.defaults,
      );
      expect(project.clips[0].outputMillis, 4000);
      expect(project.clips[1].outputMillis, 2000);
      expect(project.durationMillis, 6000);
      expect(project.clipStartMillis(1), 4000);
      expect(project.clips[1].keepsSound, isFalse, reason: 'no time-stretching: sped-up clips are silent');
    });

    test('trims are clamped to the clip and the minimum length', () {
      final clip = _clip(duration: 2000);
      expect(clip.trimmed(-50, 99999).startMillis, 0);
      expect(clip.trimmed(-50, 99999).endMillis, 2000);
      final tight = clip.trimmed(1900, 1950);
      expect(tight.trimmedMillis, greaterThanOrEqualTo(kMinClipMillis));
      expect(tight.endMillis, lessThanOrEqualTo(2000));
    });

    test('round-trips through JSON and drops unreadable parts', () {
      final project = VideoProject(
        id: '1-a',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026, 2),
        clips: [_clip(start: 500, end: 3000, speed: 1.5)],
        look: BeautyAdjustments.defaults.withFilter(FilterId.values.last),
        applyBeauty: false,
        overlays: const [
          VideoOverlayItem(
            id: 'o1',
            kind: OverlayKind.text,
            value: 'Salom',
            startMillis: 0,
            endMillis: 1000,
            color: 0xFFE8A598,
            x: 0.3,
            y: 0.7,
            scale: 0.1,
            rotation: 0.5,
          ),
        ],
        musicFileName: 'music_1.m4a',
        musicVolume: 0.4,
        originalVolume: 0.8,
        lastExportFileName: 'YUZ_1.mp4',
      );
      final json = jsonDecode(jsonEncode(project.toJson())) as Map<String, Object?>;
      final restored = VideoProject.tryFromJson(json)!;
      expect(restored.toJson(), project.toJson());

      (json['overlays']! as List).add({'id': 'bad', 'kind': 'nope'});
      (json['clips']! as List).add({'id': 'broken'});
      final tolerant = VideoProject.tryFromJson(json)!;
      expect(tolerant.overlays, hasLength(1));
      expect(tolerant.clips, hasLength(1));

      expect(VideoProject.tryFromJson({...json, 'clips': <Object>[]}), isNull, reason: 'no usable clip');
      expect(VideoProject.tryFromJson('nope'), isNull);
    });

    test('overlay edits stay inside the frame', () {
      const item = VideoOverlayItem(id: 'o', kind: OverlayKind.sticker, value: 'heart', startMillis: 0, endMillis: 10);
      final moved = item.copyWith(x: 4, y: -1, scale: 9);
      expect(moved.x, 1);
      expect(moved.y, 0);
      expect(moved.scale, 0.6);
    });

    test('output size matches the native planner', () {
      expect(videoOutputSize(_clip()), (1080, 1920));
      final uhd = VideoClip(
        id: 'x',
        fileName: 'x.mp4',
        durationMillis: 1000,
        width: 3840,
        height: 2160,
        hasAudio: false,
        startMillis: 0,
        endMillis: 1000,
      );
      expect(videoOutputSize(uhd), (1920, 1080));
    });
  });

  group('VideoProjectRepository', () {
    late Directory root;
    late Directory sources;
    late VideoProjectRepository repository;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('yuz_video_repo');
      sources = await Directory.systemTemp.createTemp('yuz_video_src');
      repository = VideoProjectRepository(root: () async => root, random: Random(3));
    });

    tearDown(() async {
      await root.delete(recursive: true);
      await sources.delete(recursive: true);
    });

    Future<String> source(String name) async => (await File('${sources.path}/$name').writeAsBytes([1, 2, 3])).path;

    test('create copies the clip and lists the project', () async {
      final path = await source('VID_1.MOV');
      final project = await repository.create(path, _probe);
      final files = await repository.filesFor(project.id);
      expect(project.clips.single.fileName, endsWith('.mov'));
      expect(await files.clip(project.clips.single).readAsBytes(), [1, 2, 3]);
      expect(await File(path).exists(), isTrue, reason: 'the source is never moved');
      expect((await repository.list()).single.id, project.id);
    });

    test('projects with missing clip files are skipped', () async {
      final project = await repository.create(await source('a.mp4'), _probe);
      await (await repository.filesFor(project.id)).clip(project.clips.single).delete();
      expect(await repository.list(), isEmpty);
      expect(await repository.load(project.id), isNull);
    });

    test('unused clips are removed and unsafe ids rejected', () async {
      final project = await repository.create(await source('a.mp4'), _probe);
      final extra = await repository.importClip(project, await source('b.mp4'), _probe);
      final files = await repository.filesFor(project.id);
      expect(await files.clip(extra).exists(), isTrue);
      await repository.removeUnusedClips(project);
      expect(await files.clip(extra).exists(), isFalse);
      expect(await files.clip(project.clips.single).exists(), isTrue);

      expect(await repository.load('../x'), isNull);
      await expectLater(repository.filesFor('..'), throwsArgumentError);
    });

    test('music replaces the previous file', () async {
      final project = await repository.create(await source('a.mp4'), _probe);
      final first = await repository.importMusic(project, await source('song.mp3'));
      final withMusic = project.copyWith(musicFileName: first);
      final second = await repository.importMusic(withMusic, await source('other.m4a'));
      final files = await repository.filesFor(project.id);
      expect(await File('${files.directory.path}/$first').exists(), isFalse);
      expect(await File('${files.directory.path}/$second').exists(), isTrue);
      expect(second, endsWith('.m4a'));
    });
  });

  group('VideoEditorController', () {
    late Directory root;
    late Directory sources;
    late FakeEngineHost host;
    late ProviderContainer container;
    late VideoProject project;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('yuz_video_ctrl');
      sources = await Directory.systemTemp.createTemp('yuz_video_ctrl_src');
      host = FakeEngineHost();
      container = await createContainer(host: host, videoProjectsRoot: root);
      final path = (await File('${sources.path}/first.mp4').writeAsBytes([0])).path;
      project = await container.read(videoProjectRepositoryProvider).create(path, _probe);
    });

    tearDown(() async {
      container.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await root.delete(recursive: true);
      await sources.delete(recursive: true);
    });

    NotifierProvider<VideoEditorController, VideoEditorState> provider() => videoEditorControllerProvider(project.id);

    Future<VideoEditorController> open() async {
      final subscription = container.listen(provider(), (_, _) {});
      addTearDown(subscription.close);
      await eventually(() => container.read(provider()).project != null);
      await eventually(() => container.read(provider()).thumbnails.isNotEmpty);
      return container.read(provider().notifier);
    }

    test('loads thumbnails and a look preview of the selected clip', () async {
      await open();
      await eventually(() => container.read(provider()).lookPreviewPath != null);
      final state = container.read(provider());
      expect(state.thumbnails[project.clips.single.id], hasLength(VideoEditorController.thumbnailCount));
      expect(host.imageRequests, isNotEmpty);
    });

    test('clips can be added, trimmed, sped up, moved and removed', () async {
      final controller = await open();
      host.videoMetadata['${sources.path}/second.mp4'] = VideoMetadata(
        durationMillis: 4000,
        width: 1920,
        height: 1080,
        rotationDegrees: 0,
        hasAudio: false,
      );
      await File('${sources.path}/second.mp4').writeAsBytes([0]);
      expect(await controller.addClip('${sources.path}/second.mp4'), isTrue);
      var state = container.read(provider());
      expect(state.project!.clips, hasLength(2));
      expect(state.selectedClip, 1);

      controller
        ..trimSelected(500, 3500)
        ..setSpeed(2);
      state = container.read(provider());
      expect(state.clip!.startMillis, 500);
      expect(state.clip!.outputMillis, 1500);

      controller.moveClip(1, 0);
      state = container.read(provider());
      expect(state.project!.clips.first.durationMillis, 4000);
      expect(state.selectedClip, 0);

      controller.removeClip(0);
      controller.removeClip(0);
      expect(container.read(provider()).project!.clips, hasLength(1), reason: 'the last clip stays');

      VideoProject? saved;
      for (var i = 0; i < 100 && saved?.clips.length != 1; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        saved = await container.read(videoProjectRepositoryProvider).load(project.id);
      }
      expect(saved!.clips.single.durationMillis, 10000);
    });

    test('a failing probe reports an error and changes nothing', () async {
      final controller = await open();
      host.probeFailure = EngineErrorCode.captureFailed;
      await File('${sources.path}/bad.mp4').writeAsBytes([0]);
      expect(await controller.addClip('${sources.path}/bad.mp4'), isFalse);
      final state = container.read(provider());
      expect(state.error, EngineErrorCode.captureFailed);
      expect(state.project!.clips, hasLength(1));
    });

    test('overlays are added at the playhead and clamped to the timeline', () async {
      final controller = await open();
      final text = controller.addText('Salom', color: 0xFFFFFFFF, atMillis: 2000);
      expect(text.startMillis, 2000);
      expect(text.endMillis, 10000);
      expect(container.read(provider()).selectedOverlayId, text.id);

      controller.updateOverlay(text.copyWith(startMillis: -5, endMillis: 999999, x: 0.2));
      final updated = container.read(provider()).selectedOverlay!;
      expect(updated.startMillis, 0);
      expect(updated.endMillis, 10000);
      expect(updated.x, 0.2);

      controller.trimSelected(0, 3000);
      expect(container.read(provider()).project!.overlays.single.endMillis, 3000);

      controller.removeOverlay(text.id);
      expect(container.read(provider()).project!.overlays, isEmpty);
      expect(container.read(provider()).selectedOverlayId, isNull);
    });

    test('export renders overlays, sends the edit and reports progress', () async {
      final controller = await open();
      controller
        ..addSticker('heart', atMillis: 0)
        ..setOriginalVolume(0.5)
        ..trimSelected(1000, 6000);
      await File('${sources.path}/song.mp3').writeAsBytes([0]);
      expect(await controller.setMusic('${sources.path}/song.mp3'), isTrue);

      host.exportGate = Completer<void>();
      final future = controller.export();
      await eventually(() => container.read(provider()).export.progress == 0.5);
      host.exportGate!.complete();
      final result = await future;

      expect(result, isNotNull);
      final request = host.exports.single;
      expect(request.clips.single.startMillis, 1000);
      expect(request.clips.single.endMillis, 6000);
      expect(request.originalVolume, 0.5);
      expect(request.musicPath, isNotNull);
      expect(request.overlays, hasLength(1));
      expect(await File(request.overlays.single.imagePath).exists(), isTrue);
      expect(request.maxLongEdge, 1920);
      final state = container.read(provider());
      expect(state.export.phase, VideoExportPhase.done);
      VideoProject? saved;
      for (var i = 0; i < 100 && saved?.lastExportFileName == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        saved = await container.read(videoProjectRepositoryProvider).load(project.id);
      }
      expect(saved?.lastExportFileName, endsWith('.mp4'));
    });

    test('a cancelled export returns to idle without an error', () async {
      final controller = await open();
      host.exportGate = Completer<void>();
      final future = controller.export();
      await eventually(() => host.exports.isNotEmpty);
      await controller.cancelExport();
      host.exportGate!.complete();
      expect(await future, isNull);
      expect(container.read(provider()).export.phase, VideoExportPhase.idle);
      expect(host.cancelledExports, hasLength(1));
    });

    test('a failed export keeps the error for the UI', () async {
      final controller = await open();
      host.exportFailure = EngineErrorCode.recordingFailed;
      expect(await controller.export(), isNull);
      final export = container.read(provider()).export;
      expect(export.phase, VideoExportPhase.failed);
      expect(export.error, EngineErrorCode.recordingFailed);
    });

    test('beauty off exports only the colour look', () async {
      final controller = await open();
      controller
        ..setApplyBeauty(false)
        ..updateLive(BeautyEffect.skinSmoothing, 80);
      await controller.endEdit();
      await controller.export();
      final request = host.exports.single;
      expect(request.applyBeauty, isFalse);
      expect(request.parameters.skinSmoothing, greaterThan(0), reason: 'the native side drops face effects');
    });
  });
}
