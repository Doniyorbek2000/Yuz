import 'package:flutter/foundation.dart';

/// Base URL of the Yuz API, set per build:
///   flutter run --dart-define=YUZ_API_URL=https://api.example.com
/// Builds without it have no account or cloud AI features and say so.
const String configuredApiUrl = String.fromEnvironment('YUZ_API_URL');

/// Release builds only talk to HTTPS. Plain HTTP is allowed in debug builds
/// for a local API (emulator: http://10.0.2.2:3000).
Uri? parseApiBaseUrl(String raw, {bool allowInsecure = kDebugMode}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && !(allowInsecure && uri.scheme == 'http')) return null;
  if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) return null;
  final path = uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path;
  return uri.replace(path: path);
}
