import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';

import '../domain/color_filters.dart';

/// Why an imported image cannot be used as a LUT.
enum LutImportError { unreadable, wrongSize }

class LutImportException implements Exception {
  const LutImportException(this.error);

  final LutImportError error;

  @override
  String toString() => 'LutImportException($error)';
}

/// Produces LUT bytes for filters: built-ins are generated on a background
/// isolate and cached; the custom LUT is imported from an image and stored
/// in app-private storage so it survives restarts.
class FilterLutRepository {
  FilterLutRepository({Future<Directory> Function()? storageDirectory, LutGenerator? generator})
    : _storageDirectory = storageDirectory ?? getApplicationSupportDirectory,
      _generator = generator ?? _generateOnIsolate;

  static const _customFileName = 'custom_filter.lut';

  final Future<Directory> Function() _storageDirectory;
  final LutGenerator _generator;
  final Map<FilterId, Uint8List> _cache = {};

  /// LUT bytes for [filter], or null for [FilterId.none] / a missing custom LUT.
  Future<Uint8List?> lutFor(FilterId filter) async {
    final cached = _cache[filter];
    if (cached != null) return cached;
    final Uint8List? bytes;
    if (filter == FilterId.none) {
      bytes = null;
    } else if (filter == FilterId.custom) {
      bytes = await _readCustom();
    } else {
      bytes = await _generator(filter.grade!);
    }
    if (bytes != null) _cache[filter] = bytes;
    return bytes;
  }

  Future<bool> hasCustomLut() async => (await _customFile()).exists();

  /// Decodes an encoded image (PNG/JPEG) and stores it as the custom LUT.
  /// Throws [LutImportException] when it is not a 512x512 LUT image.
  Future<void> importCustom(Uint8List encodedImage) async {
    final Uint8List rgba;
    final int width;
    final int height;
    try {
      final codec = await ui.instantiateImageCodec(encodedImage);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      width = image.width;
      height = image.height;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      image.dispose();
      codec.dispose();
      if (data == null) throw const LutImportException(LutImportError.unreadable);
      rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on LutImportException {
      rethrow;
    } on Exception catch (error) {
      debugPrint('LUT decode failed: $error');
      throw const LutImportException(LutImportError.unreadable);
    }
    if (!ColorLut.isValid(rgba, width: width, height: height)) {
      throw const LutImportException(LutImportError.wrongSize);
    }
    final file = await _customFile();
    await file.parent.create(recursive: true);
    await file.writeAsBytes(rgba, flush: true);
    _cache[FilterId.custom] = Uint8List.fromList(rgba);
  }

  Future<Uint8List?> _readCustom() async {
    final file = await _customFile();
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return bytes.length == ColorLut.byteLength ? bytes : null;
  }

  Future<File> _customFile() async => File('${(await _storageDirectory()).path}/$_customFileName');

  static Future<Uint8List> _generateOnIsolate(ColorGrade grade) => compute(ColorLut.build, grade);
}

typedef LutGenerator = Future<Uint8List> Function(ColorGrade grade);

final filterLutRepositoryProvider = Provider<FilterLutRepository>((ref) => FilterLutRepository());
