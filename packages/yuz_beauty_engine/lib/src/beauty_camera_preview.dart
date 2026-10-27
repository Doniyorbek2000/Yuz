import 'package:flutter/widgets.dart';

import 'generated/beauty_engine_api.g.dart';

/// Displays the native beauty texture with its real aspect ratio, filling
/// the available space (centre-cropped, like a native camera viewfinder).
class BeautyCameraPreview extends StatelessWidget {
  const BeautyCameraPreview({required this.descriptor, super.key});

  final PreviewDescriptor descriptor;

  @override
  Widget build(BuildContext context) {
    final width = descriptor.width.toDouble();
    final height = descriptor.height.toDouble();
    if (width <= 0 || height <= 0) return const SizedBox.expand();
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: width,
          height: height,
          child: Texture(
            textureId: descriptor.textureId,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
