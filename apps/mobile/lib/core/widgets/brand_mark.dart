import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Original Yuz mark: a soft face silhouette inside a rose-gold ring.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Yuz',
      image: true,
      child: CustomPaint(size: Size.square(size), painter: _BrandMarkPainter()),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final ring = Paint()
      ..shader = const SweepGradient(colors: [AppColors.accent, AppColors.accentStrong, AppColors.accent])
          .createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.12;
    canvas.drawCircle(center, radius * 0.88, ring);

    final face = Paint()..color = AppColors.textPrimary.withValues(alpha: 0.92);
    final faceRect = Rect.fromCenter(center: center, width: radius * 0.9, height: radius * 1.15);
    canvas.drawOval(faceRect, face);

    final detail = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.07;
    final smile = Rect.fromCenter(
      center: center.translate(0, radius * 0.12),
      width: radius * 0.42,
      height: radius * 0.3,
    );
    canvas.drawArc(smile, math.pi * 0.15, math.pi * 0.7, false, detail);
    canvas.drawCircle(
      center.translate(-radius * 0.17, -radius * 0.12),
      radius * 0.05,
      detail..style = PaintingStyle.fill,
    );
    canvas.drawCircle(center.translate(radius * 0.17, -radius * 0.12), radius * 0.05, detail);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
