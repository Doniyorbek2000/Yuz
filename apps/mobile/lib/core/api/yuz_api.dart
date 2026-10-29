import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'api_models.dart';
import 'token_store.dart';

typedef _RequestFactory = Future<http.BaseRequest> Function();

/// Client of the Yuz API. Access tokens are refreshed transparently (one
/// refresh at a time); a rejected refresh clears the session and is
/// reported on [sessionExpired].
class YuzApi {
  YuzApi({
    required this._baseUri,
    required this._tokens,
    http.Client? client,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 30),
    this.uploadTimeout = const Duration(minutes: 2),
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final Uri _baseUri;
  final TokenStore _tokens;
  final http.Client _client;
  final DateTime Function() _clock;
  final Duration timeout;
  final Duration uploadTimeout;
  final _sessionExpired = StreamController<void>.broadcast();
  Future<AuthTokens?>? _refreshing;

  Stream<void> get sessionExpired => _sessionExpired.stream;

  Future<bool> get hasSession async => await _tokens.read() != null;

  void close() {
    _client.close();
    _sessionExpired.close();
  }

  // region Auth

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
    required String locale,
  }) async {
    final body = await _json(
      'POST',
      '/v1/auth/register',
      body: {
        'email': email,
        'password': password,
        if (displayName != null && displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
        'locale': locale,
      },
      authenticated: false,
    );
    await _storeTokens(body);
  }

  Future<void> login({required String email, required String password}) async {
    final body = await _json(
      'POST',
      '/v1/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    await _storeTokens(body);
  }

  /// Revokes the session on the server when reachable; always signs out locally.
  Future<void> logout() async {
    final tokens = await _tokens.read();
    await _tokens.clear();
    if (tokens == null) return;
    try {
      await _send(
        () async => _jsonRequest('POST', '/v1/auth/logout', {'refreshToken': tokens.refreshToken}),
        authenticated: false,
      );
    } on ApiException catch (error) {
      debugPrint('Server logout failed (${error.code}); local session cleared');
    }
  }

  // endregion

  // region Account

  Future<UserProfile> me() async => UserProfile.fromJson(await _json('GET', '/v1/me'));

  Future<UserProfile> updateProfile({String? displayName, String? locale}) async =>
      UserProfile.fromJson(await _json('PATCH', '/v1/me', body: {'displayName': ?displayName, 'locale': ?locale}));

  /// Everything the server stores about the user, as pretty-printed JSON.
  Future<Uint8List> exportData() async {
    final data = await _json('GET', '/v1/me/export');
    return utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
  }

  /// Needs the password again; deletes the account, its files and the local session.
  Future<void> deleteAccount(String password) async {
    await _send(() async => _jsonRequest('DELETE', '/v1/me', {'password': password}));
    await _tokens.clear();
  }

  Future<CreditsSummary> credits() async => CreditsSummary.fromJson(await _json('GET', '/v1/credits'));

  Future<void> grantCloudAiConsent(String version) =>
      _json('POST', '/v1/consents/cloud-ai', body: {'version': version});

  Future<void> revokeCloudAiConsent() => _send(() async => _jsonRequest('DELETE', '/v1/consents/cloud-ai'));

  Future<List<StoreProduct>> products() async {
    final response = await _send(() async => _jsonRequest('GET', '/v1/products'));
    final decoded = _decode(response);
    if (decoded is! List) throw const ApiException(ApiException.badResponse);
    return [
      for (final item in decoded)
        if (item is Map) StoreProduct.fromJson(item.cast<String, Object?>()),
    ];
  }

  // endregion

  // region AI jobs

  Future<Map<AiJobType, AiPrice>> pricing() async => parsePricing(await _json('GET', '/v1/ai-jobs/pricing'));

  Future<AiJob> createAiJob({
    required AiJobType type,
    required Uint8List image,
    required String filename,
    Map<String, Object?> params = const {},
  }) async {
    final response = await _send(() async {
      final request = http.MultipartRequest('POST', _uri('/v1/ai-jobs'))
        ..fields['type'] = type.wire
        ..fields['params'] = jsonEncode(params)
        ..files.add(http.MultipartFile.fromBytes('image', image, filename: filename));
      return request;
    }, requestTimeout: uploadTimeout);
    return AiJob.fromJson(_object(response));
  }

  Future<AiJob> aiJob(String id) async => AiJob.fromJson(await _json('GET', '/v1/ai-jobs/${Uri.encodeComponent(id)}'));

  Future<Uint8List> aiJobResult(String id) async {
    final response = await _send(
      () async => _jsonRequest('GET', '/v1/ai-jobs/${Uri.encodeComponent(id)}/result'),
      requestTimeout: uploadTimeout,
    );
    return response.bodyBytes;
  }

  /// Cancels a queued job (refunded) or deletes a finished one with its files.
  Future<void> deleteAiJob(String id) =>
      _send(() async => _jsonRequest('DELETE', '/v1/ai-jobs/${Uri.encodeComponent(id)}'));

  // endregion

  // region Transport

  Uri _uri(String path) => _baseUri.replace(path: '${_baseUri.path}$path');

  http.Request _jsonRequest(String method, String path, [Map<String, Object?>? body]) {
    final request = http.Request(method, _uri(path))..headers['Accept'] = 'application/json';
    if (body != null) {
      request
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    return request;
  }

  Future<Map<String, Object?>> _json(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
  }) async {
    final response = await _send(() async => _jsonRequest(method, path, body), authenticated: authenticated);
    return response.statusCode == HttpStatus.noContent ? const {} : _object(response);
  }

  Future<http.Response> _send(_RequestFactory build, {bool authenticated = true, Duration? requestTimeout}) async {
    var tokens = authenticated ? await _validTokens() : null;
    var response = await _execute(build, tokens, requestTimeout ?? timeout);
    if (authenticated && response.statusCode == HttpStatus.unauthorized && tokens != null) {
      // The access token may have been revoked or expired in flight: refresh once.
      tokens = await _refresh(tokens);
      response = await _execute(build, tokens, requestTimeout ?? timeout);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return response;
    throw _errorFrom(response);
  }

  Future<http.Response> _execute(_RequestFactory build, AuthTokens? tokens, Duration limit) async {
    final request = await build();
    if (tokens != null) request.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    try {
      final streamed = await _client.send(request).timeout(limit);
      return await http.Response.fromStream(streamed).timeout(limit);
    } on TimeoutException {
      throw const ApiException(ApiException.timeout);
    } on SocketException catch (error) {
      throw ApiException(ApiException.network, message: error.message);
    } on HandshakeException catch (error) {
      throw ApiException(ApiException.network, message: error.message);
    } on http.ClientException catch (error) {
      throw ApiException(ApiException.network, message: error.message);
    }
  }

  Future<AuthTokens> _validTokens() async {
    final tokens = await _tokens.read();
    if (tokens == null) {
      _sessionExpired.add(null);
      throw const ApiException(ApiException.sessionExpired);
    }
    // Refresh slightly early so the token does not expire on the way.
    if (tokens.accessExpiresAt.isAfter(_clock().add(const Duration(seconds: 30)))) return tokens;
    return _refresh(tokens);
  }

  Future<AuthTokens> _refresh(AuthTokens stale) async {
    final refreshed = await (_refreshing ??= _performRefresh(stale).whenComplete(() => _refreshing = null));
    if (refreshed == null) throw const ApiException(ApiException.sessionExpired);
    return refreshed;
  }

  Future<AuthTokens?> _performRefresh(AuthTokens stale) async {
    final current = await _tokens.read();
    // Another call already rotated the pair.
    if (current != null && current.refreshToken != stale.refreshToken) return current;
    final response = await _execute(
      () async => _jsonRequest('POST', '/v1/auth/refresh', {'refreshToken': stale.refreshToken}),
      null,
      timeout,
    );
    if (response.statusCode == HttpStatus.unauthorized || response.statusCode == HttpStatus.badRequest) {
      await _tokens.clear();
      _sessionExpired.add(null);
      return null;
    }
    if (response.statusCode != HttpStatus.ok) throw _errorFrom(response);
    return _storeTokens(_object(response));
  }

  Future<AuthTokens> _storeTokens(Map<String, Object?> body) async {
    final access = body['accessToken'];
    final refresh = body['refreshToken'];
    final expiresIn = body['accessTokenExpiresIn'];
    if (access is! String || refresh is! String || expiresIn is! num) {
      throw const ApiException(ApiException.badResponse, message: 'token pair missing');
    }
    final tokens = AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: _clock().add(Duration(seconds: expiresIn.toInt())),
    );
    await _tokens.write(tokens);
    return tokens;
  }

  static Object? _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(ApiException.badResponse, statusCode: response.statusCode);
    }
  }

  static Map<String, Object?> _object(http.Response response) {
    final decoded = _decode(response);
    if (decoded is Map) return decoded.cast<String, Object?>();
    throw ApiException(ApiException.badResponse, statusCode: response.statusCode);
  }

  static ApiException _errorFrom(http.Response response) {
    String? code;
    String? message;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        code = decoded['code'] as String?;
        final raw = decoded['message'];
        message = raw is List ? raw.join('; ') : raw?.toString();
      }
    } on FormatException {
      // Non-JSON error page (proxy, load balancer).
    }
    code ??= switch (response.statusCode) {
      HttpStatus.badRequest => 'validation_failed',
      HttpStatus.unauthorized => ApiException.sessionExpired,
      HttpStatus.notFound => 'not_found',
      HttpStatus.tooManyRequests => 'rate_limited',
      HttpStatus.requestEntityTooLarge => 'image_too_large',
      >= 500 => ApiException.server,
      _ => 'http_${response.statusCode}',
    };
    return ApiException(code, statusCode: response.statusCode, message: message);
  }

  // endregion
}
