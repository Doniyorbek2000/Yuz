import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_mobile/features/camera/domain/beauty_adjustments.dart';
import 'package:yuz_mobile/features/camera/domain/color_filters.dart';
import 'package:yuz_mobile/features/projects/data/project_repository.dart';
import 'package:yuz_mobile/features/projects/domain/photo_project.dart';

import '../helpers/test_app.dart';

void main() {
  late Directory root;
  late Directory sources;
  late DateTime now;
  late ProjectRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('yuz_projects');
    sources = await Directory.systemTemp.createTemp('yuz_sources');
    now = DateTime.utc(2026, 10, 1, 12);
    repository = ProjectRepository(root: () async => root, clock: () => now, random: Random(7));
  });

  tearDown(() async {
    await root.delete(recursive: true);
    await sources.delete(recursive: true);
  });

  Future<String> source(String name) async {
    final file = File('${sources.path}/$name');
    await file.writeAsBytes(kTinyPng);
    return file.path;
  }

  group('PhotoProject JSON', () {
    test('round-trips every field', () {
      final project = PhotoProject(
        id: '1-ab',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026, 2),
        originalFileName: 'original.jpg',
        look: BeautyAdjustments.defaults.withValue(BeautyEffect.sharpen, 40).withFilter(FilterId.values.last),
        sourceWidth: 3000,
        sourceHeight: 4000,
        editorHistory: '{"history":[]}',
        lastExportFileName: 'YUZ_1.jpg',
        fullRenderLookKey: 'k',
      );
      final restored = PhotoProject.tryFromJson(jsonDecode(jsonEncode(project.toJson())))!;
      expect(restored.toJson(), project.toJson());
      expect(restored.look, project.look);
    });

    test('rejects unusable data without throwing', () {
      expect(PhotoProject.tryFromJson(null), isNull);
      expect(PhotoProject.tryFromJson([1, 2]), isNull);
      expect(PhotoProject.tryFromJson({'id': '1-a', 'original': 'o.jpg'}), isNull);
      expect(
        PhotoProject.tryFromJson({
          'id': '1-a',
          'original': 'o.jpg',
          'createdAt': 'nope',
          'updatedAt': '2026-01-01T00:00:00Z',
        }),
        isNull,
      );
    });

    test('falls back to the default look when the look is missing', () {
      final project = PhotoProject.tryFromJson({
        'id': '1-a',
        'original': 'o.jpg',
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-01-01T00:00:00Z',
        'sourceWidth': 'wide',
      })!;
      expect(project.look, BeautyAdjustments.defaults);
      expect(project.sourceWidth, isNull);
    });
  });

  group('ProjectRepository', () {
    test('create copies the original and never touches the source', () async {
      final path = await source('IMG_1.HEIC');
      final project = await repository.create(path);

      final files = await repository.filesFor(project);
      expect(project.originalFileName, 'original.heic');
      expect(await files.original.readAsBytes(), kTinyPng);
      expect(await File(path).readAsBytes(), kTinyPng);
      expect(await files.metadata.exists(), isTrue);
      expect((await repository.load(project.id))!.toJson(), project.toJson());
    });

    test('unknown extensions are stored as jpg', () async {
      final project = await repository.create(await source('photo.exe'));
      expect(project.originalFileName, 'original.jpg');
    });

    test('create fails for a missing source and leaves nothing behind', () async {
      await expectLater(repository.create('${sources.path}/missing.jpg'), throwsA(isA<FileSystemException>()));
      expect(await root.exists() ? await root.list().length : 0, 0);
    });

    test('list is newest first and skips corrupt or orphaned projects', () async {
      final first = await repository.create(await source('a.jpg'));
      now = now.add(const Duration(minutes: 1));
      final second = await repository.create(await source('b.jpg'));

      final corrupt = Directory('${root.path}/9-corrupt')..createSync();
      File('${corrupt.path}/project.json').writeAsStringSync('{not json');
      final orphan = await repository.create(await source('c.jpg'));
      await (await repository.filesFor(orphan)).original.delete();
      Directory('${root.path}/empty').createSync();

      final ids = (await repository.list()).map((p) => p.id).toList();
      expect(ids, [second.id, first.id]);
    });

    test('save updates the timestamp atomically', () async {
      final project = await repository.create(await source('a.jpg'));
      now = now.add(const Duration(hours: 1));
      final saved = await repository.save(project.copyWith(editorHistory: '{}'));

      expect(saved.updatedAt, now);
      final loaded = (await repository.load(project.id))!;
      expect(loaded.editorHistory, '{}');
      expect(loaded.updatedAt, now);
      final leftovers = (await repository.directoryFor(project.id)).listSync().map((e) => e.path);
      expect(leftovers.where((p) => p.endsWith('.tmp')), isEmpty);
    });

    test('concurrent saves never collide on the temp file', () async {
      final project = await repository.create(await source('a.jpg'));
      await Future.wait([for (var i = 0; i < 8; i++) repository.save(project.copyWith(editorHistory: '{"v":$i}'))]);
      final loaded = (await repository.load(project.id))!;
      expect(loaded.editorHistory, startsWith('{"v":'));
      final leftovers = (await repository.directoryFor(project.id)).listSync().map((e) => e.path);
      expect(leftovers.where((p) => p.endsWith('.tmp')), isEmpty);
    });

    test('delete removes the whole project directory', () async {
      final project = await repository.create(await source('a.jpg'));
      await repository.delete(project.id);
      expect(await (await repository.directoryFor(project.id)).exists(), isFalse);
      expect(await repository.list(), isEmpty);
    });

    test('rejects ids that could escape the projects directory', () async {
      final outside = File('${root.parent.path}/project.json')..writeAsStringSync('{}');
      addTearDown(() => outside.existsSync() ? outside.deleteSync() : null);

      expect(await repository.load('../'), isNull);
      expect(await repository.load('..'), isNull);
      expect(await repository.load('1-ab/../../x'), isNull);
      await repository.delete('..');
      expect(await root.exists(), isTrue);
      await expectLater(repository.directoryFor('../x'), throwsArgumentError);
    });

    test('preview files alternate so image caches never show a stale render', () async {
      final project = await repository.create(await source('a.jpg'));
      final files = await repository.filesFor(project);
      expect(files.preview(1).path, isNot(files.preview(2).path));
      expect(files.preview(1).path, files.preview(3).path);
    });
  });
}
