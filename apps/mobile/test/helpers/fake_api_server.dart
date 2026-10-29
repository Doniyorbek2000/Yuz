import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yuz_mobile/core/api/token_store.dart';
import 'package:yuz_mobile/core/api/yuz_api.dart';

/// In-memory stand-in for the Yuz API, following the backend's contract.
class FakeApiServer {
  FakeApiServer({this.consent = false, this.balance = 3, this.accessTtlSeconds = 900});

  bool consent;
  int balance;
  int accessTtlSeconds;
  String password = 'correct horse battery';
  String email = 'dilnoza@example.com';
  String? displayName = 'Dilnoza';
  bool backgroundEnabled = true;

  /// Status sequence the job reports on successive polls.
  List<String> jobStatuses = ['QUEUED', 'RUNNING', 'SUCCEEDED'];
  String? jobError;
  Uint8List resultBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]);

  /// Paths of every request, e.g. "POST /v1/auth/login".
  final List<String> log = [];
  final List<Map<String, String>> uploads = [];
  int _tokenCounter = 0;
  final Set<String> _validAccess = {};
  final Set<String> _validRefresh = {};
  int _poll = 0;

  late final http.Client _jsonClient = MockClient(_handle);

  /// Client that also accepts the multipart job upload.
  late final http.Client client = _UploadAwareClient(this);

  YuzApi api({TokenStore? tokens, DateTime Function()? clock}) => YuzApi(
    baseUri: Uri.parse('https://api.test'),
    tokens: tokens ?? MemoryTokenStore(),
    client: client,
    clock: clock,
  );

  /// Revokes every access token, as if they expired server-side.
  void expireAccessTokens() => _validAccess.clear();

  void revokeRefreshTokens() => _validRefresh.clear();

  Map<String, Object> _issue() {
    _tokenCounter++;
    final access = 'access-$_tokenCounter';
    final refresh = 'refresh-token-$_tokenCounter-padding-padding';
    _validAccess.add(access);
    _validRefresh.add(refresh);
    return {'accessToken': access, 'accessTokenExpiresIn': accessTtlSeconds, 'refreshToken': refresh};
  }

  Map<String, Object?> get _profile => {
    'id': 'user-1',
    'email': email,
    'displayName': displayName,
    'locale': 'uz',
    'role': 'USER',
    'creditBalance': balance,
    'premiumUntil': null,
    'premiumActive': false,
    'cloudAiConsent': {'active': consent, 'currentVersion': '2026-10'},
    'createdAt': '2026-10-01T10:00:00.000Z',
  };

  Map<String, Object?> _job(String status) => {
    'id': 'job-1',
    'type': 'BACKGROUND',
    'status': status,
    'cost': 1,
    'error': status == 'FAILED' ? jobError : null,
    'createdAt': '2026-10-29T10:00:00.000Z',
    'startedAt': null,
    'finishedAt': null,
    'hasResult': status == 'SUCCEEDED',
  };

  static http.Response _json(int status, Object body) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  static http.Response _error(int status, String code) =>
      _json(status, {'statusCode': status, 'code': code, 'message': code});

  Future<http.Response> _handle(http.Request request) async {
    final route = '${request.method} ${request.url.path}';
    log.add(route);
    Map<String, Object?> body() =>
        request.body.isEmpty ? const {} : (jsonDecode(request.body) as Map).cast<String, Object?>();

    switch (route) {
      case 'POST /v1/auth/login':
        final data = body();
        if (data['email'] != email || data['password'] != password) return _error(401, 'invalid_credentials');
        return _json(200, _issue());
      case 'POST /v1/auth/register':
        if (body()['email'] == email) return _error(409, 'email_taken');
        email = body()['email']! as String;
        displayName = body()['displayName'] as String?;
        return _json(201, _issue());
      case 'POST /v1/auth/refresh':
        final token = body()['refreshToken'];
        if (!_validRefresh.remove(token)) return _error(401, 'invalid_refresh_token');
        return _json(200, _issue());
      case 'POST /v1/auth/logout':
        _validRefresh.remove(body()['refreshToken']);
        return http.Response('', 204);
    }

    final auth = request.headers['Authorization'];
    if (auth == null || !_validAccess.contains(auth.replaceFirst('Bearer ', ''))) {
      return _json(401, {'statusCode': 401, 'message': 'Unauthorized'});
    }

    switch (route) {
      case 'GET /v1/me':
        return _json(200, _profile);
      case 'PATCH /v1/me':
        displayName = body()['displayName'] as String? ?? displayName;
        return _json(200, _profile);
      case 'GET /v1/me/export':
        return _json(200, {'exportedAt': '2026-10-29T10:00:00.000Z', 'account': _profile});
      case 'DELETE /v1/me':
        if (body()['password'] != password) return _error(403, 'invalid_password');
        return http.Response('', 204);
      case 'GET /v1/credits':
        return _json(200, {
          'balance': balance,
          'entries': [
            {'id': 'c1', 'amount': 3, 'kind': 'WELCOME', 'reference': 'welcome', 'createdAt': '2026-10-01T10:00:00Z'},
          ],
        });
      case 'POST /v1/consents/cloud-ai':
        if (body()['version'] != '2026-10') return _error(409, 'consent_outdated');
        consent = true;
        return _json(201, {'kind': 'CLOUD_AI', 'version': '2026-10'});
      case 'DELETE /v1/consents/cloud-ai':
        consent = false;
        return http.Response('', 204);
      case 'GET /v1/products':
        return _json(200, [
          {'id': 'app.yuz.credits.10', 'kind': 'credits', 'credits': 10, 'platforms': <String>[]},
          {'id': 'app.yuz.premium.month', 'kind': 'premium', 'premiumDays': 31, 'platforms': <String>[]},
        ]);
      case 'GET /v1/ai-jobs/pricing':
        return _json(200, {
          'PHOTOSHOOT': {'cost': 3, 'enabled': false},
          'HAIRSTYLE': {'cost': 2, 'enabled': false},
          'MAKEUP': {'cost': 1, 'enabled': false},
          'BACKGROUND': {'cost': 1, 'enabled': backgroundEnabled},
        });
      case 'GET /v1/ai-jobs/job-1':
        final status = jobStatuses[_poll < jobStatuses.length ? _poll : jobStatuses.length - 1];
        _poll++;
        return _json(200, _job(status));
      case 'GET /v1/ai-jobs/job-1/result':
        return http.Response.bytes(resultBytes, 200, headers: {'content-type': 'image/png'});
      case 'DELETE /v1/ai-jobs/job-1':
        return http.Response('', 204);
    }
    return _error(404, 'not_found');
  }
}

class _UploadAwareClient extends http.BaseClient {
  _UploadAwareClient(this.server);

  final FakeApiServer server;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.MultipartRequest && request.url.path == '/v1/ai-jobs') {
      server.log.add('POST /v1/ai-jobs');
      final auth = request.headers['Authorization'];
      if (auth == null || !server._validAccess.contains(auth.replaceFirst('Bearer ', ''))) {
        return _streamed(FakeApiServer._json(401, {'statusCode': 401}));
      }
      if (!server.consent) return _streamed(FakeApiServer._error(403, 'consent_required'));
      if (!server.backgroundEnabled) return _streamed(FakeApiServer._error(503, 'ai_type_unavailable'));
      if (server.balance < 1) return _streamed(FakeApiServer._error(402, 'insufficient_credits'));
      server.balance -= 1;
      server.uploads.add({
        ...request.fields,
        'filename': request.files.single.filename ?? '',
        'length': '${request.files.single.length}',
      });
      return _streamed(FakeApiServer._json(201, server._job('QUEUED')));
    }
    return server._jsonClient.send(request);
  }

  static http.StreamedResponse _streamed(http.Response response) =>
      http.StreamedResponse(Stream.value(response.bodyBytes), response.statusCode, headers: response.headers);
}
