import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_mobile/features/templates/domain/template_layout.dart';

void main() {
  test('every built-in layout keeps its slots inside the canvas without overlap', () {
    for (final layout in kTemplateLayouts) {
      final size = layout.outputSize();
      final rects = [for (final slot in layout.slots) slotRect(slot, size, 0.02)];
      for (final rect in rects) {
        expect(rect.left, greaterThanOrEqualTo(0), reason: layout.id);
        expect(rect.top, greaterThanOrEqualTo(0), reason: layout.id);
        expect(rect.right, lessThanOrEqualTo(size.width), reason: layout.id);
        expect(rect.bottom, lessThanOrEqualTo(size.height), reason: layout.id);
        expect(rect.width, greaterThan(0), reason: layout.id);
      }
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          final overlap = rects[i].intersect(rects[j]);
          expect(overlap.width <= 0 || overlap.height <= 0, isTrue, reason: '${layout.id}: slots $i and $j overlap');
        }
      }
    }
  });

  test('output size keeps the aspect with an even long edge', () {
    const story = TemplateLayout(id: 's', aspectRatio: 9 / 16, slots: []);
    expect(story.outputSize(), const Size(1080, 1920));
    const square = TemplateLayout(id: 'q', aspectRatio: 1, slots: []);
    expect(square.outputSize(longEdge: 1080), const Size(1080, 1080));
    const portrait = TemplateLayout(id: 'p', aspectRatio: 4 / 5, slots: []);
    expect(portrait.outputSize(), const Size(1536, 1920));
  });

  test('gaps are full on the border and half between slots', () {
    const size = Size(1000, 1000);
    final left = slotRect(const Rect.fromLTWH(0, 0, 0.5, 1), size, 0.02);
    final right = slotRect(const Rect.fromLTWH(0.5, 0, 0.5, 1), size, 0.02);
    expect(left.left, 20);
    expect(right.left - left.right, 20, reason: 'two half gaps make one gap');
    expect(size.width - right.right, 20);
  });

  test('cover fit fills the slot and pan stays within the photo', () {
    const transform = SlotTransform();
    const image = Size(4000, 3000);
    const slot = Size(500, 1000);
    final source = transform.sourceRect(image, slot);
    expect(source.height, closeTo(3000, 0.001), reason: 'portrait slot uses the full image height');
    expect(source.width / source.height, closeTo(0.5, 0.001));
    expect(source.left, closeTo((4000 - source.width) / 2, 0.001));

    final pannedLeft = transform.copyWith(panX: -1).sourceRect(image, slot);
    expect(pannedLeft.left, closeTo(0, 0.001));
    final pannedRight = transform.copyWith(panX: 5).sourceRect(image, slot);
    expect(pannedRight.right, closeTo(4000, 0.001));

    final zoomed = transform.copyWith(zoom: 2).sourceRect(image, slot);
    expect(zoomed.height, closeTo(1500, 0.001));
    expect(transform.copyWith(zoom: 0.2).zoom, 1, reason: 'never smaller than cover');
  });
}
