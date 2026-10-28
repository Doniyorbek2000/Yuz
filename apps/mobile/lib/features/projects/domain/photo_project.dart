import 'package:flutter/foundation.dart';

import '../../camera/domain/beauty_adjustments.dart';

/// A non-destructive photo edit. The original file is never modified; the
/// beauty look and the editor history (crop, tune, text, stickers…) are
/// stored as data and re-applied whenever the project is opened.
@immutable
class PhotoProject {
  const PhotoProject({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.originalFileName,
    required this.look,
    this.sourceWidth,
    this.sourceHeight,
    this.editorHistory,
    this.lastExportFileName,
    this.fullRenderLookKey,
  });

  static const schemaVersion = 1;

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// File name of the untouched original inside the project directory.
  final String originalFileName;

  /// Upright size of the original (known after the first render).
  final int? sourceWidth;
  final int? sourceHeight;
  final BeautyAdjustments look;

  /// pro_image_editor state history (JSON) applied on top of the beauty render.
  final String? editorHistory;

  /// File name (in the exports directory) of the latest export.
  final String? lastExportFileName;

  /// Look key of the cached full-resolution beauty render, if any.
  final String? fullRenderLookKey;

  PhotoProject copyWith({
    DateTime? updatedAt,
    int? sourceWidth,
    int? sourceHeight,
    BeautyAdjustments? look,
    String? editorHistory,
    String? lastExportFileName,
    String? fullRenderLookKey,
  }) => PhotoProject(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    originalFileName: originalFileName,
    sourceWidth: sourceWidth ?? this.sourceWidth,
    sourceHeight: sourceHeight ?? this.sourceHeight,
    look: look ?? this.look,
    editorHistory: editorHistory ?? this.editorHistory,
    lastExportFileName: lastExportFileName ?? this.lastExportFileName,
    fullRenderLookKey: fullRenderLookKey ?? this.fullRenderLookKey,
  );

  Map<String, Object?> toJson() => {
    'schema': schemaVersion,
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'original': originalFileName,
    'sourceWidth': sourceWidth,
    'sourceHeight': sourceHeight,
    'look': look.toJson(),
    'editorHistory': editorHistory,
    'lastExport': lastExportFileName,
    'fullRenderLookKey': fullRenderLookKey,
  };

  /// Returns null for data that is not a usable project (never throws).
  static PhotoProject? tryFromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final original = json['original'];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (id is! String || id.isEmpty || original is! String || original.isEmpty) return null;
    if (createdAt == null || updatedAt == null) return null;
    final look = json['look'];
    return PhotoProject(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt,
      originalFileName: original,
      sourceWidth: json['sourceWidth'] is int ? json['sourceWidth']! as int : null,
      sourceHeight: json['sourceHeight'] is int ? json['sourceHeight']! as int : null,
      look: look is Map<String, Object?> ? BeautyAdjustments.fromJson(look) : BeautyAdjustments.defaults,
      editorHistory: json['editorHistory'] is String ? json['editorHistory']! as String : null,
      lastExportFileName: json['lastExport'] is String ? json['lastExport']! as String : null,
      fullRenderLookKey: json['fullRenderLookKey'] is String ? json['fullRenderLookKey']! as String : null,
    );
  }
}
