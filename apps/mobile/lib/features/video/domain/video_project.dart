import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../camera/domain/beauty_adjustments.dart';

/// Speeds offered in the editor (the engine accepts 0.25..4).
const kVideoSpeeds = <double>[0.5, 1, 1.5, 2];

/// Clips shorter than this cannot be produced by trimming (engine limit is 100 ms).
const kMinClipMillis = 300;

/// One trimmed source clip. The copied source file lives in the project's
/// clips directory under [fileName] and is never modified.
@immutable
class VideoClip {
  const VideoClip({
    required this.id,
    required this.fileName,
    required this.durationMillis,
    required this.width,
    required this.height,
    required this.hasAudio,
    required this.startMillis,
    required this.endMillis,
    this.speed = 1,
  });

  final String id;
  final String fileName;
  final int durationMillis;

  /// Upright size.
  final int width;
  final int height;
  final bool hasAudio;
  final int startMillis;
  final int endMillis;
  final double speed;

  int get trimmedMillis => endMillis - startMillis;

  /// Length on the output timeline.
  int get outputMillis => (trimmedMillis / speed).round();

  /// Own sound is only kept at normal speed (the engine does not time-stretch).
  bool get keepsSound => hasAudio && speed == 1;

  VideoClip copyWith({int? startMillis, int? endMillis, double? speed}) => VideoClip(
    id: id,
    fileName: fileName,
    durationMillis: durationMillis,
    width: width,
    height: height,
    hasAudio: hasAudio,
    startMillis: startMillis ?? this.startMillis,
    endMillis: endMillis ?? this.endMillis,
    speed: speed ?? this.speed,
  );

  /// Clamps a requested trim to the clip and to [kMinClipMillis].
  VideoClip trimmed(int start, int end) {
    final minimum = math.min(kMinClipMillis, durationMillis);
    final int clampedStart = start.clamp(0, math.max(0, durationMillis - minimum));
    final int clampedEnd = end.clamp(clampedStart + minimum, durationMillis);
    return copyWith(startMillis: clampedStart, endMillis: clampedEnd);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'file': fileName,
    'duration': durationMillis,
    'width': width,
    'height': height,
    'audio': hasAudio,
    'start': startMillis,
    'end': endMillis,
    'speed': speed,
  };

  static VideoClip? tryFromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final file = json['file'];
    final duration = json['duration'];
    final width = json['width'];
    final height = json['height'];
    if (id is! String || file is! String || duration is! int || width is! int || height is! int) return null;
    if (duration <= 0 || width <= 0 || height <= 0) return null;
    final speed = (json['speed'] as num?)?.toDouble() ?? 1;
    final clip = VideoClip(
      id: id,
      fileName: file,
      durationMillis: duration,
      width: width,
      height: height,
      hasAudio: json['audio'] == true,
      startMillis: json['start'] is int ? json['start']! as int : 0,
      endMillis: json['end'] is int ? json['end']! as int : duration,
      speed: speed.clamp(0.25, 4).toDouble(),
    );
    return clip.trimmed(clip.startMillis, clip.endMillis);
  }
}

enum OverlayKind { text, sticker }

/// A text or sticker placed on the frame for a time window of the output.
/// Position is the normalized centre (0..1); [scale] is the height of the
/// item relative to the frame height, so it is resolution independent.
@immutable
class VideoOverlayItem {
  const VideoOverlayItem({
    required this.id,
    required this.kind,
    required this.value,
    required this.startMillis,
    required this.endMillis,
    this.color = 0xFFFFFFFF,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 0.08,
    this.rotation = 0,
  });

  final String id;
  final OverlayKind kind;

  /// The text, or the sticker id.
  final String value;
  final int startMillis;
  final int endMillis;
  final int color;
  final double x;
  final double y;
  final double scale;
  final double rotation;

  bool isVisibleAt(int millis) => millis >= startMillis && millis < endMillis;

  VideoOverlayItem copyWith({
    String? value,
    int? startMillis,
    int? endMillis,
    int? color,
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) => VideoOverlayItem(
    id: id,
    kind: kind,
    value: value ?? this.value,
    startMillis: startMillis ?? this.startMillis,
    endMillis: endMillis ?? this.endMillis,
    color: color ?? this.color,
    x: (x ?? this.x).clamp(0.0, 1.0),
    y: (y ?? this.y).clamp(0.0, 1.0),
    scale: (scale ?? this.scale).clamp(0.02, 0.6),
    rotation: rotation ?? this.rotation,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'value': value,
    'start': startMillis,
    'end': endMillis,
    'color': color,
    'x': x,
    'y': y,
    'scale': scale,
    'rotation': rotation,
  };

  static VideoOverlayItem? tryFromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final value = json['value'];
    final kind = OverlayKind.values.where((k) => k.name == json['kind']).firstOrNull;
    final start = json['start'];
    final end = json['end'];
    if (id is! String || value is! String || value.isEmpty || kind == null || start is! int || end is! int) {
      return null;
    }
    if (end <= start) return null;
    double number(String key, double fallback) => (json[key] as num?)?.toDouble() ?? fallback;
    return VideoOverlayItem(
      id: id,
      kind: kind,
      value: value,
      startMillis: start,
      endMillis: end,
      color: json['color'] is int ? json['color']! as int : 0xFFFFFFFF,
    ).copyWith(x: number('x', 0.5), y: number('y', 0.5), scale: number('scale', 0.08), rotation: number('rotation', 0));
  }
}

/// A non-destructive video edit: source clips are copied once; trims,
/// speed, look, overlays and sound settings are data, applied on export.
@immutable
class VideoProject {
  const VideoProject({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.clips,
    required this.look,
    this.applyBeauty = true,
    this.overlays = const [],
    this.musicFileName,
    this.musicVolume = 0.6,
    this.originalVolume = 1,
    this.lastExportFileName,
  });

  static const schemaVersion = 1;

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<VideoClip> clips;
  final BeautyAdjustments look;

  /// false applies only the colour look (filter, sharpen).
  final bool applyBeauty;
  final List<VideoOverlayItem> overlays;
  final String? musicFileName;
  final double musicVolume;
  final double originalVolume;
  final String? lastExportFileName;

  int get durationMillis => clips.fold(0, (sum, clip) => sum + clip.outputMillis);

  /// Output-timeline start of the clip at [index].
  int clipStartMillis(int index) => clips.take(index).fold(0, (sum, clip) => sum + clip.outputMillis);

  VideoProject copyWith({
    DateTime? updatedAt,
    List<VideoClip>? clips,
    BeautyAdjustments? look,
    bool? applyBeauty,
    List<VideoOverlayItem>? overlays,
    String? musicFileName,
    bool clearMusic = false,
    double? musicVolume,
    double? originalVolume,
    String? lastExportFileName,
  }) => VideoProject(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    clips: clips ?? this.clips,
    look: look ?? this.look,
    applyBeauty: applyBeauty ?? this.applyBeauty,
    overlays: overlays ?? this.overlays,
    musicFileName: clearMusic ? null : (musicFileName ?? this.musicFileName),
    musicVolume: (musicVolume ?? this.musicVolume).clamp(0.0, 1.0),
    originalVolume: (originalVolume ?? this.originalVolume).clamp(0.0, 1.0),
    lastExportFileName: lastExportFileName ?? this.lastExportFileName,
  );

  Map<String, Object?> toJson() => {
    'schema': schemaVersion,
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'clips': clips.map((c) => c.toJson()).toList(),
    'look': look.toJson(),
    'applyBeauty': applyBeauty,
    'overlays': overlays.map((o) => o.toJson()).toList(),
    'music': musicFileName,
    'musicVolume': musicVolume,
    'originalVolume': originalVolume,
    'lastExport': lastExportFileName,
  };

  /// Returns null for data that is not a usable project (never throws).
  /// Unreadable clips or overlays are dropped individually.
  static VideoProject? tryFromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (id is! String || id.isEmpty || createdAt == null || updatedAt == null) return null;
    final clips = (json['clips'] is List ? json['clips']! as List : const [])
        .map(VideoClip.tryFromJson)
        .whereType<VideoClip>()
        .toList(growable: false);
    if (clips.isEmpty) return null;
    final look = json['look'];
    return VideoProject(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt,
      clips: clips,
      look: look is Map<String, Object?> ? BeautyAdjustments.fromJson(look) : BeautyAdjustments.defaults,
      applyBeauty: json['applyBeauty'] != false,
      overlays: (json['overlays'] is List ? json['overlays']! as List : const [])
          .map(VideoOverlayItem.tryFromJson)
          .whereType<VideoOverlayItem>()
          .toList(growable: false),
      musicFileName: json['music'] is String ? json['music']! as String : null,
      musicVolume: ((json['musicVolume'] as num?)?.toDouble() ?? 0.6).clamp(0.0, 1.0),
      originalVolume: ((json['originalVolume'] as num?)?.toDouble() ?? 1).clamp(0.0, 1.0),
      lastExportFileName: json['lastExport'] is String ? json['lastExport']! as String : null,
    );
  }
}

/// Output size the engine will use: the first clip's aspect, long edge
/// <= [maxLongEdge] (never upscaled), even dimensions. Mirrors
/// VideoEditPlanner.outputSize (Kotlin) and VideoExporter.outputSize (Swift).
(int, int) videoOutputSize(VideoClip first, {int maxLongEdge = 1920}) {
  final longEdge = math.max(first.width, first.height);
  final scale = math.min(1.0, maxLongEdge / longEdge);
  int even(double value) => math.max(2, (value.toInt() ~/ 2) * 2);
  return (even(first.width * scale), even(first.height * scale));
}
