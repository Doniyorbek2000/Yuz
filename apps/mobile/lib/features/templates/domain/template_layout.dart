import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// A collage layout: normalized slot rectangles (0..1) inside a canvas of
/// the given aspect ratio. Spacing and corner radius are applied when
/// painting, so the same layout works for every style.
@immutable
class TemplateLayout {
  const TemplateLayout({required this.id, required this.aspectRatio, required this.slots, this.captionArea});

  final String id;

  /// width / height
  final double aspectRatio;
  final List<Rect> slots;

  /// Optional band for a caption (normalized), e.g. a story frame footer.
  final Rect? captionArea;

  /// Output size with the long edge at [longEdge] (even, for encoders and galleries).
  Size outputSize({int longEdge = 1920}) {
    final width = aspectRatio >= 1 ? longEdge.toDouble() : longEdge * aspectRatio;
    final height = aspectRatio >= 1 ? longEdge / aspectRatio : longEdge.toDouble();
    return Size((width / 2).round() * 2.0, (height / 2).round() * 2.0);
  }
}

/// Built-in layouts (own designs).
const kTemplateLayouts = <TemplateLayout>[
  TemplateLayout(
    id: 'duo-stack',
    aspectRatio: 9 / 16,
    slots: [Rect.fromLTWH(0, 0, 1, 0.5), Rect.fromLTWH(0, 0.5, 1, 0.5)],
  ),
  TemplateLayout(id: 'duo-side', aspectRatio: 1, slots: [Rect.fromLTWH(0, 0, 0.5, 1), Rect.fromLTWH(0.5, 0, 0.5, 1)]),
  TemplateLayout(
    id: 'trio',
    aspectRatio: 9 / 16,
    slots: [Rect.fromLTWH(0, 0, 1, 1 / 3), Rect.fromLTWH(0, 1 / 3, 1, 1 / 3), Rect.fromLTWH(0, 2 / 3, 1, 1 / 3)],
  ),
  TemplateLayout(
    id: 'grid4',
    aspectRatio: 1,
    slots: [
      Rect.fromLTWH(0, 0, 0.5, 0.5),
      Rect.fromLTWH(0.5, 0, 0.5, 0.5),
      Rect.fromLTWH(0, 0.5, 0.5, 0.5),
      Rect.fromLTWH(0.5, 0.5, 0.5, 0.5),
    ],
  ),
  TemplateLayout(
    id: 'feature',
    aspectRatio: 4 / 5,
    slots: [Rect.fromLTWH(0, 0, 1, 0.62), Rect.fromLTWH(0, 0.62, 0.5, 0.38), Rect.fromLTWH(0.5, 0.62, 0.5, 0.38)],
  ),
  TemplateLayout(
    id: 'story-frame',
    aspectRatio: 9 / 16,
    slots: [Rect.fromLTWH(0.06, 0.05, 0.88, 0.74)],
    captionArea: Rect.fromLTWH(0.06, 0.82, 0.88, 0.13),
  ),
  TemplateLayout(
    id: 'film',
    aspectRatio: 9 / 16,
    slots: [
      Rect.fromLTWH(0.12, 0.02, 0.76, 0.235),
      Rect.fromLTWH(0.12, 0.265, 0.76, 0.235),
      Rect.fromLTWH(0.12, 0.51, 0.76, 0.235),
      Rect.fromLTWH(0.12, 0.755, 0.76, 0.225),
    ],
  ),
];

/// How a photo sits in its slot: zoom >= 1 over a "cover" fit, and a
/// normalized pan (-1..1 per axis) within the overflow.
@immutable
class SlotTransform {
  const SlotTransform({this.zoom = 1, this.panX = 0, this.panY = 0});

  final double zoom;
  final double panX;
  final double panY;

  SlotTransform copyWith({double? zoom, double? panX, double? panY}) => SlotTransform(
    zoom: (zoom ?? this.zoom).clamp(1.0, 4.0),
    panX: (panX ?? this.panX).clamp(-1.0, 1.0),
    panY: (panY ?? this.panY).clamp(-1.0, 1.0),
  );

  /// Source rectangle of an image of [imageSize] drawn into [slot] (cover fit).
  Rect sourceRect(Size imageSize, Size slot) {
    final cover = math.max(slot.width / imageSize.width, slot.height / imageSize.height) * zoom;
    final width = slot.width / cover;
    final height = slot.height / cover;
    final spareX = imageSize.width - width;
    final spareY = imageSize.height - height;
    final left = spareX / 2 + panX * spareX / 2;
    final top = spareY / 2 + panY * spareY / 2;
    return Rect.fromLTWH(left, top, width, height);
  }
}

/// Style of a collage, independent of the photos.
@immutable
class TemplateStyle {
  const TemplateStyle({this.background = 0xFFF5F3F7, this.spacing = 0.02, this.cornerRadius = 0.02, this.caption = ''});

  final int background;

  /// Gap between slots and border, as a fraction of the short edge.
  final double spacing;

  /// Slot corner radius, as a fraction of the short edge.
  final double cornerRadius;
  final String caption;

  TemplateStyle copyWith({int? background, double? spacing, double? cornerRadius, String? caption}) => TemplateStyle(
    background: background ?? this.background,
    spacing: (spacing ?? this.spacing).clamp(0.0, 0.08),
    cornerRadius: (cornerRadius ?? this.cornerRadius).clamp(0.0, 0.1),
    caption: caption ?? this.caption,
  );
}

/// Slot rectangle in pixels for a canvas of [size], with the gap applied.
Rect slotRect(Rect normalized, Size size, double spacing) {
  final gap = spacing * math.min(size.width, size.height);
  final rect = Rect.fromLTWH(
    normalized.left * size.width,
    normalized.top * size.height,
    normalized.width * size.width,
    normalized.height * size.height,
  );
  // A full gap on the canvas border, half a gap on edges shared with another slot.
  const edge = 0.0001;
  return Rect.fromLTRB(
    rect.left + (normalized.left <= edge ? gap : gap / 2),
    rect.top + (normalized.top <= edge ? gap : gap / 2),
    rect.right - (normalized.right >= 1 - edge ? gap : gap / 2),
    rect.bottom - (normalized.bottom >= 1 - edge ? gap : gap / 2),
  );
}
