import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../camera/domain/beauty_adjustments.dart';
import '../domain/video_project.dart';

/// Directories and files of one video project.
class VideoProjectFiles {
  VideoProjectFiles(this.directory)
    : metadata = File('${directory.path}/project.json'),
      clips = Directory('${directory.path}/clips'),
      thumbnails = Directory('${directory.path}/thumbs'),
      overlays = Directory('${directory.path}/overlays'),
      exports = Directory('${directory.path}/exports'),
      previews = Directory('${directory.path}/previews');

  final Directory directory;
  final File metadata;
  final Directory clips;
  final Directory thumbnails;

  /// Overlay PNGs rendered for the latest export.
  final Directory overlays;
  final Directory exports;

  /// Look previews (beautified still of a clip frame).
  final Directory previews;

  File clip(VideoClip clip) => File('${clips.path}/${clip.fileName}');

  Directory thumbnailsFor(VideoClip clip) => Directory('${thumbnails.path}/${clip.id}');

  File? music(VideoProject project) {
    final name = project.musicFileName;
    return name == null ? null : File('${directory.path}/$name');
  }
}

/// Metadata the repository needs about a source video (from the engine probe).
typedef VideoProbeResult = ({int durationMillis, int width, int height, bool hasAudio});

/// Stores video projects under `<app support>/videos/<id>/`. Sources are
/// copied in (the user's files are never touched); metadata writes are
/// atomic and corrupt projects are skipped.
class VideoProjectRepository {
  VideoProjectRepository({Future<Directory> Function()? root, DateTime Function()? clock, Random? random})
    : _root = root ?? _defaultRoot,
      _clock = clock ?? DateTime.now,
      _random = random ?? Random.secure();

  static const _videoExtensions = {'mp4', 'mov', 'm4v', '3gp', 'webm', 'mkv'};
  static const _audioExtensions = {'mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac', 'mp4'};

  final Future<Directory> Function() _root;
  final DateTime Function() _clock;
  final Random _random;

  static Future<Directory> _defaultRoot() async => Directory('${(await getApplicationSupportDirectory()).path}/videos');

  Future<List<VideoProject>> list() async {
    final root = await _root();
    if (!await root.exists()) return const [];
    final projects = <VideoProject>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final project = await _read(VideoProjectFiles(entity));
      if (project != null) projects.add(project);
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<VideoProject?> load(String id) async {
    if (!isSafeId(id)) return null;
    return _read(VideoProjectFiles(Directory('${(await _root()).path}/$id')));
  }

  /// Creates a project from one video; [probe] describes it.
  Future<VideoProject> create(String sourcePath, VideoProbeResult probe, {BeautyAdjustments? look}) async {
    final now = _clock();
    final id = '${now.microsecondsSinceEpoch}-${_random.nextInt(1 << 32).toRadixString(16)}';
    final files = VideoProjectFiles(Directory('${(await _root()).path}/$id'));
    await files.clips.create(recursive: true);
    try {
      final clip = await _copyClip(files, sourcePath, probe);
      final project = VideoProject(
        id: id,
        createdAt: now,
        updatedAt: now,
        clips: [clip],
        look: look ?? BeautyAdjustments.defaults,
      );
      await _write(files, project);
      return project;
    } on Object {
      await files.directory.delete(recursive: true);
      rethrow;
    }
  }

  /// Copies another source into [project]'s clips directory; returns the clip to append.
  Future<VideoClip> importClip(VideoProject project, String sourcePath, VideoProbeResult probe) async =>
      _copyClip(await filesFor(project.id), sourcePath, probe);

  /// Copies a music file into the project; returns its stored file name.
  Future<String> importMusic(VideoProject project, String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw FileSystemException('Music file not found', sourcePath);
    final files = await filesFor(project.id);
    final extension = _extensionOf(sourcePath);
    final name = 'music_${_token()}.${_audioExtensions.contains(extension) ? extension : 'm4a'}';
    await source.copy('${files.directory.path}/$name');
    final previous = files.music(project);
    if (previous != null && await previous.exists()) await previous.delete();
    return name;
  }

  Future<VideoProject> save(VideoProject project) async {
    final updated = project.copyWith(updatedAt: _clock());
    await _write(await filesFor(project.id), updated);
    return updated;
  }

  /// Deletes clip files that the project no longer references.
  Future<void> removeUnusedClips(VideoProject project) async {
    final files = await filesFor(project.id);
    if (!await files.clips.exists()) return;
    final used = project.clips.map((c) => c.fileName).toSet();
    await for (final entity in files.clips.list()) {
      if (entity is File && !used.contains(entity.uri.pathSegments.last)) await entity.delete();
    }
  }

  Future<void> delete(String id) async {
    if (!isSafeId(id)) return;
    final directory = Directory('${(await _root()).path}/$id');
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<VideoProjectFiles> filesFor(String id) async {
    if (!isSafeId(id)) throw ArgumentError.value(id, 'id', 'invalid project id');
    return VideoProjectFiles(Directory('${(await _root()).path}/$id'));
  }

  Future<VideoClip> _copyClip(VideoProjectFiles files, String sourcePath, VideoProbeResult probe) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw FileSystemException('Video not found', sourcePath);
    if (probe.durationMillis <= 0 || probe.width <= 0 || probe.height <= 0) {
      throw FileSystemException('Unsupported video', sourcePath);
    }
    final extension = _extensionOf(sourcePath);
    final id = _token();
    final fileName = 'clip_$id.${_videoExtensions.contains(extension) ? extension : 'mp4'}';
    await files.clips.create(recursive: true);
    await source.copy('${files.clips.path}/$fileName');
    return VideoClip(
      id: id,
      fileName: fileName,
      durationMillis: probe.durationMillis,
      width: probe.width,
      height: probe.height,
      hasAudio: probe.hasAudio,
      startMillis: 0,
      endMillis: probe.durationMillis,
    );
  }

  String _token() => _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');

  static String _extensionOf(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  Future<void> _write(VideoProjectFiles files, VideoProject project) async {
    await files.directory.create(recursive: true);
    // Unique temp name: concurrent saves must not rename each other's file.
    final temp = File('${files.directory.path}/.project.json.${_token()}.tmp');
    await temp.writeAsString(jsonEncode(project.toJson()), flush: true);
    await temp.rename(files.metadata.path);
  }

  Future<VideoProject?> _read(VideoProjectFiles files) async {
    try {
      if (!await files.metadata.exists()) return null;
      final project = VideoProject.tryFromJson(jsonDecode(await files.metadata.readAsString()));
      if (project == null) return null;
      // A project whose clips were deleted outside the app is not usable.
      for (final clip in project.clips) {
        if (!await files.clip(clip).exists()) return null;
      }
      return project;
    } on FormatException catch (error) {
      debugPrint('Skipping corrupt video project ${files.directory.path}: $error');
      return null;
    } on FileSystemException catch (error) {
      debugPrint('Skipping unreadable video project ${files.directory.path}: $error');
      return null;
    }
  }

  /// Ids are generated here; anything else (e.g. from a deep link) is rejected.
  static bool isSafeId(String id) => RegExp(r'^[0-9]+-[0-9a-f]+$').hasMatch(id);
}

final videoProjectRepositoryProvider = Provider<VideoProjectRepository>((ref) => VideoProjectRepository());
