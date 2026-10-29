import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yuz_mobile/core/api/api_config.dart';
import 'package:yuz_mobile/core/api/api_exception.dart';
import 'package:yuz_mobile/core/api/api_models.dart';
import 'package:yuz_mobile/core/api/token_store.dart';
import 'package:yuz_mobile/core/api/yuz_api.dart';

import '../helpers/fake_api_server.dart';

void main() {
  group('parseApiBaseUrl', () {
    test('accepts https and strips the trailing slash', () {
      expect(parseApiBaseUrl('https://api.yuz.app/', allowInsecure: false).toString(), 'https://api.yuz.app');
      expect(parseApiBaseUrl(' https://x.app/api ', allowInsecure: false)!.path, '/api');
    });

    test('rejects empty, malformed, credentialed and insecure URLs', () {
      for (final raw in ['', 'api.yuz.app', 'ftp://x.app', 'https://user:pw@x.app', 'https://x.app?q=1']) {
        expect(parseApiBaseUrl(raw, allowInsecure: false), isNull, reason: raw);
      }
      expect(parseApiBaseUrl('http://10.0.2.2:3000', allowInsecure: false), isNull);
      expect(parseApiBaseUrl('http://10.0.2.2:3000', allowInsecure: true), isNotNull);
    });
  });

  group('YuzApi', () {
    late FakeApiServer server;
    late MemoryTokenStore tokens;
    late YuzApi api;

    setUp(() {
      server = FakeApiServer(consent: true);
      tokens = MemoryTokenStore();
      api = server.api(tokens: tokens);
    });

    test('login stores the session and reads the profile', () async {
      await api.login(email: server.email, password: server.password);
      expect(tokens.tokens, isNotNull);
      final profile = await api.me();
      expect(profile.email, server.email);
      expect(profile.creditBalance, 3);
      expect(profile.cloudAiConsent, isTrue);
      expect(profile.consentVersion, '2026-10');
    });

    test('maps backend error codes', () async {
      await expectLater(
        api.login(email: server.email, password: 'wrong password'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_credentials')),
      );
      await expectLater(
        api.register(email: server.email, password: 'long enough password', locale: 'uz'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'email_taken')),
      );
    });

    test('refreshes an expired access token before the call', () async {
      var now = DateTime(2026, 10, 29, 12);
      api = server.api(tokens: tokens, clock: () => now);
      await api.login(email: server.email, password: server.password);
      now = now.add(const Duration(minutes: 20));
      await api.me();
      expect(server.log, containsAllInOrder(['POST /v1/auth/login', 'POST /v1/auth/refresh', 'GET /v1/me']));
    });

    test('retries once with a refreshed token after a 401', () async {
      await api.login(email: server.email, password: server.password);
      server.expireAccessTokens();
      final profile = await api.me();
      expect(profile.email, server.email);
      expect(server.log.where((r) => r == 'POST /v1/auth/refresh'), hasLength(1));
    });

    test('concurrent calls share a single refresh', () async {
      await api.login(email: server.email, password: server.password);
      server.expireAccessTokens();
      await Future.wait([api.me(), api.credits(), api.pricing()]);
      expect(server.log.where((r) => r == 'POST /v1/auth/refresh'), hasLength(1));
    });

    test('a rejected refresh clears the session and reports it', () async {
      await api.login(email: server.email, password: server.password);
      server
        ..expireAccessTokens()
        ..revokeRefreshTokens();
      final expired = expectLater(api.sessionExpired, emits(null));
      await expectLater(
        api.me(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiException.sessionExpired)),
      );
      await expired;
      expect(tokens.tokens, isNull);
    });

    test('uploads AI jobs as multipart with type and params', () async {
      await api.login(email: server.email, password: server.password);
      final job = await api.createAiJob(
        type: AiJobType.background,
        image: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        filename: 'photo.jpg',
        params: {'mode': 'blur'},
      );
      expect(job.status, AiJobStatus.queued);
      expect(server.uploads.single, {
        'type': 'BACKGROUND',
        'params': '{"mode":"blur"}',
        'filename': 'photo.jpg',
        'length': '4',
      });
    });

    test('pricing reports which types a worker serves', () async {
      await api.login(email: server.email, password: server.password);
      final pricing = await api.pricing();
      expect(pricing[AiJobType.background]!.enabled, isTrue);
      expect(pricing[AiJobType.photoshoot]!.enabled, isFalse);
    });

    test('logout clears the local session even when the server is unreachable', () async {
      await api.login(email: server.email, password: server.password);
      final offline = YuzApi(
        baseUri: Uri.parse('https://api.test'),
        tokens: tokens,
        client: MockClient((_) => throw const SocketException('offline')),
      );
      await offline.logout();
      expect(tokens.tokens, isNull);
    });

    test('network failures, timeouts and HTML error pages get client codes', () async {
      final failing = YuzApi(
        baseUri: Uri.parse('https://api.test'),
        tokens: MemoryTokenStore(),
        client: MockClient((_) => throw const SocketException('offline')),
      );
      await expectLater(
        failing.login(email: 'a@b.co', password: 'x'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiException.network)),
      );

      final gateway = YuzApi(
        baseUri: Uri.parse('https://api.test'),
        tokens: MemoryTokenStore(),
        client: MockClient((_) async => http.Response('<html>Bad gateway</html>', 502)),
      );
      await expectLater(
        gateway.login(email: 'a@b.co', password: 'x'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiException.server)),
      );

      final slow = YuzApi(
        baseUri: Uri.parse('https://api.test'),
        tokens: MemoryTokenStore(),
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        slow.login(email: 'a@b.co', password: 'x'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiException.timeout)),
      );
    });

    test('export returns readable JSON', () async {
      await api.login(email: server.email, password: server.password);
      final export = jsonDecode(utf8.decode(await api.exportData())) as Map;
      expect((export['account'] as Map)['email'], server.email);
    });
  });

  test('stored tokens survive a JSON round trip', () {
    final tokens = AuthTokens(accessToken: 'a', refreshToken: 'r', accessExpiresAt: DateTime.utc(2026, 10, 29, 12));
    final restored = AuthTokens.fromJson(jsonDecode(jsonEncode(tokens.toJson())));
    expect(restored!.accessExpiresAt, tokens.accessExpiresAt);
    expect(AuthTokens.fromJson({'accessToken': 1}), isNull);
  });
}
