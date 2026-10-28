import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/template_layout.dart';

/// Paints a collage into [size]. Shared by the editor preview and the
/// export so the saved image is exactly what the user arranged.
void paintTemplate(
  Canvas canvas,
  Size size, {
  required TemplateLayout layout,
  required TemplateStyle style,
  required Map<int, ui.Image> images,
  required Map<int, SlotTransform> transforms,
  int? selectedSlot,
  Color placeholder = const Color(0xFFE4E1EA),
}) {
  canvas.drawRect(Offset.zero & size, Paint()..color = Color(style.background));
  final radius = Radius.circular(style.cornerRadius * math.min(size.width, size.height));
  for (var index = 0; index < layout.slots.length; index++) {
    final rect = slotRect(layout.slots[index], size, style.spacing);
    final rounded = RRect.fromRectAndRadius(rect, radius);
    final image = images[index];
    canvas
      ..save()
      ..clipRRect(rounded);
    if (image == null) {
      canvas.drawRect(rect, Paint()..color = placeholder);
    } else {
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final source = (transforms[index] ?? const SlotTransform()).sourceRect(imageSize, rect.size);
      canvas.drawImageRect(image, source, rect, Paint()..filterQuality = FilterQuality.high);
    }
    canvas.restore();
    if (index == selectedSlot) {
      canvas.drawRRect(
        rounded.deflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFE8A598),
      );
    }
  }
  final caption = layout.captionArea;
  if (caption != null && style.caption.trim().isNotEmpty) {
    final area = Rect.fromLTWH(
      caption.left * size.width,
      caption.top * size.height,
      caption.width * size.width,
      caption.height * size.height,
    );
    final background = Color(style.background);
    final textColor = background.computeLuminance() > 0.5 ? const Color(0xFF15151C) : const Color(0xFFF5F3F7);
    final painter = TextPainter(
      text: TextSpan(
        text: style.caption.trim(),
        style: TextStyle(fontSize: area.height * 0.32, fontWeight: FontWeight.w600, color: textColor, height: 1.2),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: area.width);
    painter.paint(canvas, Offset(area.left + (area.width - painter.width) / 2, area.center.dy - painter.height / 2));
  }
}

/// Renders the collage at its output size and writes a PNG.
Future<File> renderTemplatePng({
  required TemplateLayout layout,
  required TemplateStyle style,
  required Map<int, ui.Image> images,
  required Map<int, SlotTransform> transforms,
  required File target,
  int longEdge = 1920,
}) async {
  final size = layout.outputSize(longEdge: longEdge);
  final recorder = ui.PictureRecorder();
  paintTemplate(
    Canvas(recorder, Offset.zero & size),
    size,
    layout: layout,
    style: style,
    images: images,
    transforms: transforms,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw const FileSystemException('Collage could not be encoded');
    await target.parent.create(recursive: true);
    return await target.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

/// Decodes a photo for a slot, downscaled so that its long edge is at most
/// [maxEdge] (memory stays bounded with large camera files).
Future<ui.Image> decodeSlotImage(File file, {int maxEdge = 2048}) async {
  final bytes = await file.readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final longEdge = math.max(descriptor.width, descriptor.height);
  final scale = longEdge > maxEdge ? maxEdge / longEdge : 1.0;
  final codec = await descriptor.instantiateCodec(
    targetWidth: (descriptor.width * scale).round(),
    targetHeight: (descriptor.height * scale).round(),
  );
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
  }
}

class TemplatePainter extends CustomPainter {
  TemplatePainter({
    required this.layout,
    required this.style,
    required this.images,
    required this.transforms,
    this.selectedSlot,
  });

  final TemplateLayout layout;
  final TemplateStyle style;
  final Map<int, ui.Image> images;
  final Map<int, SlotTransform> transforms;
  final int? selectedSlot;

  @override
  void paint(Canvas canvas, Size size) => paintTemplate(
    canvas,
    size,
    layout: layout,
    style: style,
    images: images,
    transforms: transforms,
    selectedSlot: selectedSlot,
  );

  @override
  bool shouldRepaint(TemplatePainter old) =>
      old.layout != layout ||
      old.style != style ||
      old.images != images ||
      old.transforms != transforms ||
      old.selectedSlot != selectedSlot;
}
