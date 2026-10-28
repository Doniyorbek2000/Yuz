import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../editing/stickers.dart';
import '../domain/video_project.dart';

/// Paints one overlay into a frame of [size]. Used both for the live editor
/// preview and for the PNGs the native exporter composites, so the export
/// matches what the user placed.
void paintOverlayItem(Canvas canvas, Size size, VideoOverlayItem item) {
  final painter = overlayTextPainter(item, size);
  canvas
    ..save()
    ..translate(item.x * size.width, item.y * size.height)
    ..rotate(item.rotation);
  painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
  canvas.restore();
}

/// Laid-out painter of [item] for a frame of [size] (also used for hit tests).
TextPainter overlayTextPainter(VideoOverlayItem item, Size size) {
  final fontSize = item.scale * size.height;
  const shadows = [Shadow(blurRadius: 6, color: Color(0x99000000), offset: Offset(0, 1))];
  final TextSpan span;
  switch (item.kind) {
    case OverlayKind.text:
      span = TextSpan(
        text: item.value,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.15,
          fontWeight: FontWeight.w700,
          color: Color(item.color),
          shadows: shadows,
        ),
      );
    case OverlayKind.sticker:
      final (icon, color) = stickerStyle(item.value);
      span = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: fontSize,
          height: 1,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
          shadows: const [stickerShadow],
        ),
      );
  }
  return TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr)
    ..layout(maxWidth: size.width * 0.92);
}

/// Hit test in frame coordinates (rotation-aware, with a touch margin).
bool overlayContains(VideoOverlayItem item, Size size, Offset point) {
  final painter = overlayTextPainter(item, size);
  final local = point - Offset(item.x * size.width, item.y * size.height);
  final cos = math.cos(-item.rotation);
  final sin = math.sin(-item.rotation);
  final rotated = Offset(local.dx * cos - local.dy * sin, local.dx * sin + local.dy * cos);
  const margin = 16.0;
  return rotated.dx.abs() <= painter.width / 2 + margin && rotated.dy.abs() <= painter.height / 2 + margin;
}

/// Renders [item] alone into a transparent PNG of the output size.
Future<File> renderOverlayPng(VideoOverlayItem item, int width, int height, File target) async {
  final recorder = ui.PictureRecorder();
  final size = Size(width.toDouble(), height.toDouble());
  paintOverlayItem(Canvas(recorder, Offset.zero & size), size, item);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw const FileSystemException('Overlay could not be encoded');
    await target.parent.create(recursive: true);
    return await target.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

/// Paints every overlay visible at [millis] (editor preview layer).
class OverlayLayerPainter extends CustomPainter {
  OverlayLayerPainter({required this.overlays, required this.millis, this.selectedId});

  final List<VideoOverlayItem> overlays;
  final int millis;
  final String? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in overlays) {
      if (!item.isVisibleAt(millis) && item.id != selectedId) continue;
      paintOverlayItem(canvas, size, item);
      if (item.id == selectedId) {
        final painter = overlayTextPainter(item, size);
        canvas
          ..save()
          ..translate(item.x * size.width, item.y * size.height)
          ..rotate(item.rotation)
          ..drawRect(
            Rect.fromCenter(center: Offset.zero, width: painter.width + 12, height: painter.height + 12),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color(0xFFE8A598),
          )
          ..restore();
      }
    }
  }

  @override
  bool shouldRepaint(OverlayLayerPainter oldDelegate) =>
      oldDelegate.overlays != overlays || oldDelegate.millis != millis || oldDelegate.selectedId != selectedId;
}
