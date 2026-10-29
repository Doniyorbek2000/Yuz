import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@immutable
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken, required this.accessExpiresAt});

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;

  Map<String, Object> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessExpiresAt': accessExpiresAt.toUtc().toIso8601String(),
  };

  static AuthTokens? fromJson(Object? json) {
    if (json is! Map) return null;
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    final expires = DateTime.tryParse(json['accessExpiresAt']?.toString() ?? '');
    if (access is! String || refresh is! String || expires == null) return null;
    return AuthTokens(accessToken: access, refreshToken: refresh, accessExpiresAt: expires);
  }
}

/// Where the session tokens live between app launches.
abstract interface class TokenStore {
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();
}

/// Keychain (iOS, readable after first unlock, never synced to other
/// devices) and EncryptedSharedPreferences/Keystore (Android).
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            aOptions: AndroidOptions(),
          );

  static const _key = 'yuz.session.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      return raw == null ? null : AuthTokens.fromJson(jsonDecode(raw));
    } on Exception catch (error) {
      // A corrupted or inaccessible entry means "signed out", not a crash.
      debugPrint('Token store read failed: $error');
      return null;
    }
  }

  @override
  Future<void> write(AuthTokens tokens) => _storage.write(key: _key, value: jsonEncode(tokens.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.tokens]);

  AuthTokens? tokens;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> write(AuthTokens tokens) async => this.tokens = tokens;

  @override
  Future<void> clear() async => tokens = null;
}
