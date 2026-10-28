import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../camera/domain/beauty_adjustments.dart';
import '../domain/photo_project.dart';

/// Files of one project (all inside its own directory).
class ProjectFiles {
  ProjectFiles(this.directory, PhotoProject project)
    : original = File('${directory.path}/${project.originalFileName}'),
      metadata = File('${directory.path}/project.json'),
      beautyFull = File('${directory.path}/beauty_full.jpg'),
      exports = Directory('${directory.path}/exports');

  final Directory directory;
  final File original;
  final File metadata;

  /// Full-resolution beauty render that the photo editor works on.
  final File beautyFull;
  final Directory exports;

  /// Alternating preview files: a new path per render avoids stale image caches.
  File preview(int version) => File('${directory.path}/preview_${version.isEven ? 'a' : 'b'}.jpg');
}

/// Stores projects under `<app support>/projects/<id>/`. Metadata writes are
/// atomic (temp file + rename) and corrupt projects are skipped, never fatal.
class ProjectRepository {
  ProjectRepository({Future<Directory> Function()? root, DateTime Function()? clock, Random? random})
    : _root = root ?? _defaultRoot,
      _clock = clock ?? DateTime.now,
      _random = random ?? Random.secure();

  static const _supportedExtensions = {'jpg', 'jpeg', 'png', 'heic', 'heif', 'webp'};

  final Future<Directory> Function() _root;
  final DateTime Function() _clock;
  final Random _random;

  static Future<Directory> _defaultRoot() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/projects');

  Future<List<PhotoProject>> list() async {
    final root = await _root();
    if (!await root.exists()) return const [];
    final projects = <PhotoProject>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final project = await _read(File('${entity.path}/project.json'));
      if (project != null) projects.add(project);
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<PhotoProject?> load(String id) async {
    if (!_isSafeId(id)) return null;
    return _read(File('${(await _root()).path}/$id/project.json'));
  }

  /// Copies [sourcePath] into a new project; the source is never modified.
  Future<PhotoProject> create(String sourcePath, {BeautyAdjustments? look}) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw FileSystemException('Source image not found', sourcePath);
    final dot = sourcePath.lastIndexOf('.');
    final extension = dot < 0 ? 'jpg' : sourcePath.substring(dot + 1).toLowerCase();
    final now = _clock();
    final id = '${now.microsecondsSinceEpoch}-${_random.nextInt(1 << 32).toRadixString(16)}';
    final directory = Directory('${(await _root()).path}/$id');
    await directory.create(recursive: true);
    final project = PhotoProject(
      id: id,
      createdAt: now,
      updatedAt: now,
      originalFileName: 'original.${_supportedExtensions.contains(extension) ? extension : 'jpg'}',
      look: look ?? BeautyAdjustments.defaults,
    );
    try {
      await source.copy(files(directory, project).original.path);
      await _write(directory, project);
    } on Object {
      await directory.delete(recursive: true);
      rethrow;
    }
    return project;
  }

  Future<PhotoProject> save(PhotoProject project) async {
    final updated = project.copyWith(updatedAt: _clock());
    await _write(await directoryFor(project.id), updated);
    return updated;
  }

  Future<void> delete(String id) async {
    if (!_isSafeId(id)) return;
    final directory = await directoryFor(id);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<Directory> directoryFor(String id) async {
    if (!_isSafeId(id)) throw ArgumentError.value(id, 'id', 'invalid project id');
    return Directory('${(await _root()).path}/$id');
  }

  Future<ProjectFiles> filesFor(PhotoProject project) async => files(await directoryFor(project.id), project);

  ProjectFiles files(Directory directory, PhotoProject project) => ProjectFiles(directory, project);

  Future<void> _write(Directory directory, PhotoProject project) async {
    final target = File('${directory.path}/project.json');
    final temp = File('${directory.path}/.project.json.tmp');
    await temp.writeAsString(jsonEncode(project.toJson()), flush: true);
    await temp.rename(target.path);
  }

  Future<PhotoProject?> _read(File file) async {
    try {
      if (!await file.exists()) return null;
      final project = PhotoProject.tryFromJson(jsonDecode(await file.readAsString()));
      if (project == null) return null;
      final original = File('${file.parent.path}/${project.originalFileName}');
      return await original.exists() ? project : null;
    } on FormatException catch (error) {
      debugPrint('Skipping corrupt project ${file.path}: $error');
      return null;
    } on FileSystemException catch (error) {
      debugPrint('Skipping unreadable project ${file.path}: $error');
      return null;
    }
  }

  /// Ids are generated here; rejecting anything else prevents path traversal
  /// through deep links such as /photo/../../etc.
  static bool _isSafeId(String id) => RegExp(r'^[0-9]+-[0-9a-f]+$').hasMatch(id);
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) => ProjectRepository());
