import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

enum PhotoOrigin { gallery, camera }

/// Picks a photo for cloud processing. The pickers re-encode to JPEG with
/// the EXIF rotation applied and cap the size, so uploads stay small and no
/// location metadata leaves the device.
abstract interface class PhotoSource {
  Future<String?> pick(PhotoOrigin origin);
}

class ImagePickerPhotoSource implements PhotoSource {
  ImagePickerPhotoSource({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const maxEdge = 2560.0;

  final ImagePicker _picker;

  @override
  Future<String?> pick(PhotoOrigin origin) async {
    final file = await _picker.pickImage(
      source: origin == PhotoOrigin.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: maxEdge,
      maxHeight: maxEdge,
      imageQuality: 92,
      requestFullMetadata: false,
    );
    return file?.path;
  }
}

final photoSourceProvider = Provider<PhotoSource>((ref) => ImagePickerPhotoSource());

/// Where downloaded AI results are kept until the user saves them.
final aiResultDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => () async {
    final directory = Directory('${(await getTemporaryDirectory()).path}/ai_results');
    await directory.create(recursive: true);
    return directory;
  },
);

/// File type by magic bytes; the API accepts JPEG, PNG and WebP.
String? imageExtension(Uint8List bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'jpg';
  if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
    return 'png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'webp';
  }
  return null;
}
