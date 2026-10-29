import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_mobile/app/app.dart';
import 'package:yuz_mobile/app/router.dart';
import 'package:yuz_mobile/core/api/api_providers.dart';
import 'package:yuz_mobile/core/api/token_store.dart';
import 'package:yuz_mobile/core/storage/preferences.dart';
import 'package:yuz_mobile/features/account/application/session_controller.dart';
import 'package:yuz_mobile/features/account/presentation/account_screen.dart';
import 'package:yuz_mobile/features/ai/application/ai_background_controller.dart';
import 'package:yuz_mobile/features/ai/data/photo_source.dart';

import '../helpers/fake_api_server.dart';
import '../helpers/test_app.dart';

class _FixedPhotoSource implements PhotoSource {
  _FixedPhotoSource(this.path);

  final String path;

  @override
  Future<String?> pick(PhotoOrigin origin) async => path;
}

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46, 0x49, 0x46]);

/// Real I/O plus fake time (the job polling uses timers).
Future<void> settleAll(WidgetTester tester, {int rounds = 30}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  late Directory temp;

  setUp(() async => temp = await Directory.systemTemp.createTemp('yuz_account_test'));
  tearDown(() => temp.delete(recursive: true));

  /// [server] null = build without an API URL.
  Future<ProviderContainer> pump(
    WidgetTester tester,
    String location, {
    FakeApiServer? server,
    bool signedIn = false,
    FakeGallerySaver? gallery,
    List<String>? exports,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final tokens = MemoryTokenStore();
    final api = server?.api(tokens: tokens);
    if (signedIn && api != null) {
      await tester.runAsync(() => api.login(email: server!.email, password: server.password));
    }
    final source = File('${temp.path}/photo.jpg')..writeAsBytesSync(_jpeg);
    final container = await createContainer(
      preferences: const {PreferenceKeys.onboardingCompleted: true},
      projectsRoot: Directory('${temp.path}/projects'),
      gallerySaver: gallery,
      extraOverrides: [
        yuzApiProvider.overrideWithValue(api),
        photoSourceProvider.overrideWithValue(_FixedPhotoSource(source.path)),
        aiResultDirectoryProvider.overrideWithValue(() async => Directory('${temp.path}/results')..createSync()),
        aiPollingPolicyProvider.overrideWithValue(
          const AiPollingPolicy(interval: Duration(milliseconds: 1), maxWait: Duration(seconds: 5)),
        ),
        exportSaverProvider.overrideWithValue((name, bytes) async {
          exports?.add(name);
          return true;
        }),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: YuzApp(router: testRouter(location)),
      ),
    );
    await settleIo(tester);
    return container;
  }

  testWidgets('builds without a server say so instead of failing', (tester) async {
    await pump(tester, '/account');
    expect(find.text('Accounts are not available in this build'), findsOneWidget);
    await pump(tester, '/ai/background');
    expect(find.text('Accounts are not available in this build'), findsOneWidget);
  });

  testWidgets('signs in and shows the profile with credits', (tester) async {
    final server = FakeApiServer();
    await pump(tester, '/account', server: server);
    await tester.tap(find.byKey(const ValueKey('account-sign-in')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('auth-email')), server.email);
    await tester.enterText(find.byKey(const ValueKey('auth-password')), 'wrong password');
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await settleIo(tester);
    expect(find.text('Email or password is incorrect.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('auth-password')), server.password);
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await settleIo(tester);
    expect(find.text('Dilnoza'), findsOneWidget);
    expect(find.textContaining('3 credits'), findsOneWidget);
  });

  testWidgets('registration validates input before calling the server', (tester) async {
    final server = FakeApiServer();
    await pump(tester, '/account/auth?mode=register', server: server);
    await tester.enterText(find.byKey(const ValueKey('auth-email')), 'not-an-email');
    await tester.enterText(find.byKey(const ValueKey('auth-password')), 'short');
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Use at least 10 characters'), findsOneWidget);
    expect(server.log, isEmpty);
  });

  testWidgets('consent is granted only through the explicit consent screen', (tester) async {
    final server = FakeApiServer();
    final container = await pump(tester, '/account', server: server, signedIn: true);
    expect(find.text('Not allowed. Nothing is uploaded.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-consent')));
    await tester.pumpAndSettle();
    expect(find.textContaining('never for advertising'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('consent-accept')));
    await settleIo(tester);
    expect(server.consent, isTrue);
    expect(container.read(currentProfileProvider)!.cloudAiConsent, isTrue);
    expect(find.textContaining('Allowed.'), findsOneWidget);
  });

  testWidgets('exports data and deletes the account with the password', (tester) async {
    final server = FakeApiServer();
    final exports = <String>[];
    final container = await pump(tester, '/account', server: server, signedIn: true, exports: exports);
    await tester.tap(find.text('Download my data'));
    await settleIo(tester);
    expect(exports, ['yuz-data-export.json']);

    await tester.scrollUntilVisible(find.byKey(const ValueKey('account-delete')), 100);
    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('prompt-field')), 'wrong');
    await tester.tap(find.byKey(const ValueKey('prompt-confirm')));
    await settleIo(tester);
    expect(find.text('The password is incorrect.'), findsOneWidget);
    expect(container.read(currentProfileProvider), isNotNull);

    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('prompt-field')), server.password);
    await tester.tap(find.byKey(const ValueKey('prompt-confirm')));
    await settleIo(tester);
    expect(container.read(sessionControllerProvider).value, isA<SignedOut>());
    expect(find.byKey(const ValueKey('account-sign-in')), findsOneWidget);
  });

  testWidgets('store shows prices and never offers a purchase it cannot verify', (tester) async {
    final server = FakeApiServer();
    await pump(tester, '/account/store', server: server, signedIn: true);
    expect(find.byKey(const ValueKey('store-blocked')), findsOneWidget);
    expect(find.text('Premium · 31 days'), findsOneWidget);
    final buttons = tester.widgetList<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Unavailable'));
    expect(buttons, isNotEmpty);
    expect(buttons.every((button) => button.onPressed == null), isTrue);
    await tester.scrollUntilVisible(find.text('Welcome bonus'), 200);
    expect(find.text('Welcome bonus'), findsOneWidget);
  });

  testWidgets('AI background asks to sign in, then for consent', (tester) async {
    final server = FakeApiServer();
    await pump(tester, '/ai/background', server: server);
    expect(find.byKey(const ValueKey('ai-sign-in')), findsOneWidget);

    await pump(tester, '/ai/background', server: server, signedIn: true);
    expect(find.byKey(const ValueKey('ai-consent')), findsOneWidget);
    expect(server.uploads, isEmpty);
  });

  testWidgets('AI background processes a photo and saves the result', (tester) async {
    final server = FakeApiServer(consent: true);
    final gallery = FakeGallerySaver();
    await pump(tester, '/ai/background', server: server, signedIn: true, gallery: gallery);
    final start = find.byKey(const ValueKey('ai-start'));
    expect(tester.widget<FilledButton>(start).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('ai-pick-gallery')));
    await settleIo(tester);
    await tester.tap(find.byKey(const ValueKey('ai-mode-remove')));
    await tester.pump();
    await tester.tap(start);
    await settleAll(tester);

    expect(server.uploads.single['params'], '{"mode":"remove"}');
    expect(find.byKey(const ValueKey('ai-save')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-save')));
    await settleIo(tester);
    expect(gallery.saved, hasLength(1));
    expect(find.text('Saved to your gallery'), findsOneWidget);
  });

  testWidgets('AI background explains a refusal from the worker', (tester) async {
    final server = FakeApiServer(consent: true)
      ..jobStatuses = ['RUNNING', 'FAILED']
      ..jobError = 'invalid_input:no_person_detected';
    await pump(tester, '/ai/background', server: server, signedIn: true);
    await tester.tap(find.byKey(const ValueKey('ai-pick-gallery')));
    await settleIo(tester);
    await tester.tap(find.byKey(const ValueKey('ai-start')));
    await settleAll(tester);
    expect(find.textContaining('No person was found'), findsOneWidget);
  });

  testWidgets('help answers common questions', (tester) async {
    await pump(tester, '/help');
    await tester.tap(find.text('Are my photos uploaded?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('run entirely on your phone'), findsOneWidget);
  });

  testWidgets('AI background and account fit a small phone', (tester) async {
    final server = FakeApiServer(consent: true);
    for (final location in ['/ai/background', '/account', '/account/store', '/account/consent']) {
      await pump(tester, location, server: server, signedIn: true);
      tester.view.physicalSize = const Size(320, 568) * 3;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: location);
    }

    await pump(tester, '/ai/background', server: server, signedIn: true);
    tester.view.physicalSize = const Size(320, 568) * 3;
    await tester.tap(find.byKey(const ValueKey('ai-pick-gallery')));
    await settleIo(tester);
    await tester.tap(find.byKey(const ValueKey('ai-mode-color')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-swatch-#9EC9F5')), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Unmount here so auto-dispose timers of the five screens run inside the test.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
