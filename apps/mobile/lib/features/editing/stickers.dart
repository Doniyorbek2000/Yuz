import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Yuz's own sticker set (vector icons, no third-party artwork). Stickers are
/// stored by id so saved photo and video projects can rebuild them.
const yuzStickers = <String, (IconData, Color)>{
  'heart': (Icons.favorite_rounded, Color(0xFFF07B7B)),
  'sparkle': (Icons.auto_awesome_rounded, Color(0xFFF2C46D)),
  'star': (Icons.star_rounded, Color(0xFFF2C46D)),
  'crown': (Icons.workspace_premium_rounded, Color(0xFFE8A598)),
  'flower': (Icons.local_florist_rounded, Color(0xFFE8A598)),
  'sun': (Icons.wb_sunny_rounded, Color(0xFFF2C46D)),
  'moon': (Icons.nightlight_round, Color(0xFFA9A6B5)),
  'cloud': (Icons.cloud_rounded, Color(0xFFF5F3F7)),
  'bolt': (Icons.bolt_rounded, Color(0xFFF2C46D)),
  'bird': (Icons.flutter_dash_rounded, Color(0xFF7FB8F0)),
  'music': (Icons.music_note_rounded, Color(0xFFF5F3F7)),
  'camera': (Icons.photo_camera_rounded, Color(0xFFF5F3F7)),
  'smile': (Icons.sentiment_very_satisfied_rounded, Color(0xFFF2C46D)),
  'glam': (Icons.face_retouching_natural_rounded, Color(0xFFF07B7B)),
  'diamond': (Icons.diamond_rounded, Color(0xFF7FD1A8)),
  'fire': (Icons.local_fire_department_rounded, Color(0xFFD9826F)),
};

/// Prefix of sticker ids in pro_image_editor histories.
const stickerIdPrefix = 'yuz-sticker:';

/// Icon and colour of [name]; unknown ids (e.g. from a newer app version)
/// render as a neutral placeholder instead of failing.
(IconData, Color) stickerStyle(String name) => yuzStickers[name] ?? (Icons.help_outline_rounded, AppColors.textMuted);

const stickerShadow = Shadow(blurRadius: 8, color: Color(0x66000000));

Widget stickerWidget(String name, {double size = 120}) {
  final (icon, color) = stickerStyle(name);
  return Icon(icon, size: size, color: color, shadows: const [stickerShadow]);
}
