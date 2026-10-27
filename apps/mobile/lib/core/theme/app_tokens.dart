import 'package:flutter/material.dart';

/// Design tokens. Every colour, radius, spacing and duration in the app comes
/// from here so the visual language stays consistent.
abstract final class AppColors {
  static const background = Color(0xFF0B0B0F);
  static const surface = Color(0xFF15151C);
  static const surfaceRaised = Color(0xFF1E1E28);
  static const outline = Color(0xFF2C2C3A);
  static const textPrimary = Color(0xFFF5F3F7);
  static const textSecondary = Color(0xFFA9A6B5);
  static const textMuted = Color(0xFF6E6B7B);

  /// Brand accent: warm rose gold.
  static const accent = Color(0xFFE8A598);
  static const accentStrong = Color(0xFFD9826F);
  static const onAccent = Color(0xFF1A0F0C);

  static const success = Color(0xFF7FD1A8);
  static const warning = Color(0xFFF2C46D);
  static const danger = Color(0xFFF07B7B);
  static const scrim = Color(0xB3000000);
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppRadii {
  static const sm = Radius.circular(10);
  static const md = Radius.circular(16);
  static const lg = Radius.circular(24);
  static const pill = Radius.circular(999);
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}
