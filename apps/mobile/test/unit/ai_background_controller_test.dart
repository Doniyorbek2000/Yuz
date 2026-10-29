import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_mobile/core/api/api_providers.dart';
import 'package:yuz_mobile/core/api/token_store.dart';
import 'package:yuz_mobile/features/account/application/session_controller.dart';
import 'package:yuz_mobile/features/ai/application/ai_background_controller.dart';
import 'package:yuz_mobile/features/ai/data/photo_source.dart';

import '../helpers/fake_api_server.dart';
import '../helpers/test_app.dart';

class FakePhotoSource implements PhotoSource {
  FakePhotoSource(this.path);

  String? path;

  @override
  Future<String?> pick(PhotoOrigin origin) async => path;
}

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46, 0x49, 0x46]);

void main() {
  late Directory temp;
  late FakeApiServer server;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('yuz_ai_test');
    server = FakeApiServer(consent: true);
  });

  tearDown(() => temp.delete(recursive: true));

  Future<ProviderContainer> signedInContainer({Uint8List? photo, FakeGallerySaver? gallery}) async {
    final source = File('${temp.path}/source.jpg')..writeAsBytesSync(photo ?? _jpeg);
    final tokens = MemoryTokenStore();
    final api = server.api(tokens: tokens);
    await api.login(email: server.email, password: server.password);
    final container = await createContainer(
      projectsRoot: Directory('${temp.path}/projects'),
      gallerySaver: gallery,
      extraOverrides: [
        yuzApiProvider.overrideWithValue(api),
        photoSourceProvider.overrideWithValue(FakePhotoSource(source.path)),
        aiResultDirectoryProvider.overrideWithValue(() async => Directory('${temp.path}/results')..createSync()),
        aiPollingPolicyProvider.overrideWithValue(
          const AiPollingPolicy(interval: Duration(milliseconds: 1), maxWait: Duration(seconds: 5)),
        ),
      ],
    );
    expect(await container.read(sessionControllerProvider.future), isA<SignedIn>());
    container.listen(aiBackgroundControllerProvider, (_, _) {});
    return container;
  }

  test('uploads, follows the job and downloads the result', () async {
    final container = await signedInContainer();
    final controller = container.read(aiBackgroundControllerProvider.notifier);
    await controller.pick(PhotoOrigin.gallery);
    controller
      ..setMode(BackgroundMode.color)
      ..setColor(const Color(0xFF9EC9F5));
    await controller.start();

    final state = container.read(aiBackgroundControllerProvider);
    expect(state.stage, AiStage.done);
    expect(File(state.resultPath!).readAsBytesSync(), server.resultBytes);
    expect(state.resultPath, endsWith('.png'));
    expect(server.uploads.single['params'], '{"mode":"color","color":"#9EC9F5"}');
    expect(server.uploads.single['filename'], 'photo.jpg');
    await eventually(() => server.log.contains('DELETE /v1/ai-jobs/job-1'));
    // Polled through queued and running before the result.
    expect(server.log.where((r) => r == 'GET /v1/ai-jobs/job-1'), hasLength(3));
  });

  test('reports the worker failure reason', () async {
    server
      ..jobStatuses = ['QUEUED', 'FAILED']
      ..jobError = 'invalid_input:no_person_detected';
    final container = await signedInContainer();
    final controller = container.read(aiBackgroundControllerProvider.notifier);
    await controller.pick(PhotoOrigin.gallery);
    await controller.start();
    final state = container.read(aiBackgroundControllerProvider);
    expect(state.stage, AiStage.failed);
    expect(state.errorCode, 'invalid_input:no_person_detected');
  });

  test('refuses files that are not JPEG, PNG or WebP before uploading', () async {
    final container = await signedInContainer(photo: Uint8List.fromList(utf8Bytes('ftypheic not supported')));
    final controller = container.read(aiBackgroundControllerProvider.notifier);
    await controller.pick(PhotoOrigin.gallery);
    await controller.start();
    expect(container.read(aiBackgroundControllerProvider).errorCode, 'unsupported_image');
    expect(server.uploads, isEmpty);
  });

  test('surfaces API refusals such as missing credits', () async {
    server.balance = 0;
    final container = await signedInContainer();
    final controller = container.read(aiBackgroundControllerProvider.notifier);
    await controller.pick(PhotoOrigin.gallery);
    await controller.start();
    expect(container.read(aiBackgroundControllerProvider).errorCode, 'insufficient_credits');
  });

  test('cancels a queued job', () async {
    server.jobStatuses = ['QUEUED'];
    final container = await signedInContainer();
    final controller = container.read(aiBackgroundControllerProvider.notifier);
    await controller.pick(PhotoOrigin.gallery);
    final running = controller.start();
    await eventually(() => container.read(aiBackgroundControllerProvider).stage == AiStage.queued);
    await controller.cancel();
    await running;
    final state = container.read(aiBackgroundControllerProvider);
    expect(state.stage, AiStage.idle);
    expect(state.jobId, isNull);
    expect(server.log, contains('DELETE /v1/ai-jobs/job-1'));
  });

  test('saves the result to the gallery and opens it as a project', () async {
    final gallery = FakeGallerySaver();
    final container = await signedInContainer(gallery: gallery);
    final controller = container.read(aiBackgroundControllerProvider.notifier);
    await controller.pick(PhotoOrigin.gallery);
    await controller.start();
    expect(await controller.saveToGallery(), isTrue);
    expect(gallery.saved.single, container.read(aiBackgroundControllerProvider).resultPath);
    expect(container.read(aiBackgroundControllerProvider).savedToGallery, isTrue);
    expect(await controller.openAsProject(), isNotNull);
  });

  test('hex colours are upper-case #RRGGBB', () {
    expect(hexColor(const Color(0xFF0A0B0C)), '#0A0B0C');
    expect(imageExtension(_jpeg), 'jpg');
    expect(imageExtension(Uint8List.fromList([1, 2, 3])), isNull);
  });
}

List<int> utf8Bytes(String text) => text.codeUnits;
