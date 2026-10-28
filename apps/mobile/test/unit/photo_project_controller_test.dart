import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuz_beauty_engine/yuz_beauty_engine.dart';
import 'package:yuz_mobile/features/camera/domain/beauty_adjustments.dart';
import 'package:yuz_mobile/features/camera/domain/beauty_preset.dart';
import 'package:yuz_mobile/features/projects/application/photo_project_controller.dart';
import 'package:yuz_mobile/features/projects/data/project_repository.dart';
import 'package:yuz_mobile/features/projects/domain/photo_project.dart';

import '../helpers/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late FakeEngineHost host;
  late FakeGallerySaver gallery;
  late ProviderContainer container;
  late PhotoProject project;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('yuz_controller_projects');
    host = FakeEngineHost();
    gallery = FakeGallerySaver();
    container = await createContainer(host: host, projectsRoot: root, gallerySaver: gallery);
    final source = File('${root.parent.path}/yuz_source_${DateTime.now().microsecondsSinceEpoch}.png')
      ..writeAsBytesSync(kTinyPng);
    addTearDown(() => source.existsSync() ? source.deleteSync() : null);
    project = await container.read(projectRepositoryProvider).create(source.path);
  });

  tearDown(() async {
    container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (await root.exists()) await root.delete(recursive: true);
  });

  NotifierProvider<PhotoProjectController, PhotoProjectState> provider() => photoProjectControllerProvider(project.id);

  Future<PhotoProjectController> open() async {
    final subscription = container.listen(provider(), (_, _) {});
    addTearDown(subscription.close);
    await eventually(() => container.read(provider()).previewPath != null);
    return container.read(provider().notifier);
  }

  test('loading renders a preview at the preview resolution', () async {
    await open();
    final state = container.read(provider());
    expect(state.loading, isFalse);
    expect(state.faceCount, 1);
    expect(state.faceTrackingAvailable, isTrue);
    expect(host.imageRequests.single.maxLongEdge, kPhotoPreviewLongEdge);
    expect(host.imageRequests.single.inputPath, endsWith('original.png'));
  });

  test('an unknown project reports notFound', () async {
    final missing = photoProjectControllerProvider('1-dead');
    final subscription = container.listen(missing, (_, _) {});
    addTearDown(subscription.close);
    await eventually(() => container.read(missing).notFound);
    expect(host.imageRequests, isEmpty);
  });

  test('slider edits during a render collapse into one follow-up render', () async {
    final controller = await open();
    host.processImageGate = Completer<void>();

    controller
      ..beginEdit()
      ..updateLive(BeautyEffect.skinSmoothing, 10);
    await eventually(() => host.imageRequests.length == 2);
    for (var value = 11; value <= 60; value++) {
      controller.updateLive(BeautyEffect.skinSmoothing, value);
    }
    host.processImageGate!.complete();
    host.processImageGate = null;
    await eventually(() => !container.read(provider()).rendering && host.imageRequests.length == 3);
    await controller.endEdit();

    expect(host.imageRequests.length, 3, reason: 'initial + in-flight + one coalesced render');
    final last = BeautyAdjustments.defaults.withValue(BeautyEffect.skinSmoothing, 60).toEngineParameters();
    expect(host.imageRequests.last.parameters.skinSmoothing, last.skinSmoothing);
  });

  test('render failures surface an error code and keep the controller usable', () async {
    final controller = await open();
    host.processImageFailure = EngineErrorCode.gpuInitializationFailed;
    controller.applyPreset(BeautyPreset.builtIns.last);
    await eventually(() => container.read(provider()).renderError != null);
    expect(container.read(provider()).renderError, EngineErrorCode.gpuInitializationFailed);

    host.processImageFailure = null;
    controller.undo();
    await eventually(() => container.read(provider()).renderError == null);
  });

  test('look changes are persisted to the project', () async {
    final controller = await open();
    controller.updateLive(BeautyEffect.sharpen, 35);
    await controller.endEdit();
    // Persisting is debounced (400 ms) and survives a later reload.
    await eventually(() => container.read(provider()).project!.look.valueOf(BeautyEffect.sharpen) == 35);
    final saved = (await container.read(projectRepositoryProvider).load(project.id))!;
    expect(saved.look.valueOf(BeautyEffect.sharpen), 35);
  });

  test('full resolution render is cached per look', () async {
    final controller = await open();
    final first = await controller.prepareFullResolution();
    expect(await first.exists(), isTrue);
    expect(host.imageRequests.last.maxLongEdge, 0, reason: 'export renders at the original size');
    final rendered = host.imageRequests.length;

    await controller.prepareFullResolution();
    expect(host.imageRequests.length, rendered, reason: 'same look → cache hit');

    final saved = (await container.read(projectRepositoryProvider).load(project.id))!;
    expect(saved.sourceWidth, 3000);
    expect(saved.sourceHeight, 4000);

    controller.updateLive(BeautyEffect.skinSmoothing, 70);
    await controller.endEdit();
    await eventually(() => !container.read(provider()).rendering);
    final before = host.imageRequests.length;
    await controller.prepareFullResolution();
    expect(host.imageRequests.length, before + 1, reason: 'a new look re-renders');
  });

  test('saveExport writes the JPEG, history and gallery copy', () async {
    final controller = await open();
    final jpeg = Uint8List.fromList(List<int>.generate(64, (i) => i));

    final (file, savedToGallery) = await controller.saveExport(jpeg, '{"v":1}');

    expect(savedToGallery, isTrue);
    expect(await file.readAsBytes(), jpeg);
    expect(gallery.saved.single, file.path);
    final saved = (await container.read(projectRepositoryProvider).load(project.id))!;
    expect(saved.lastExportFileName, file.uri.pathSegments.last);
    expect(saved.editorHistory, '{"v":1}');
  });

  test('a denied gallery still keeps the export in the project', () async {
    gallery.accept = false;
    final controller = await open();
    final (file, savedToGallery) = await controller.saveExport(Uint8List.fromList([1, 2, 3]), null);
    expect(savedToGallery, isFalse);
    expect(await file.exists(), isTrue);
  });

  test('editor history survives reopening the project', () async {
    final controller = await open();
    await controller.saveEditorHistory('{"layers":[]}');
    final reloaded = (await container.read(projectRepositoryProvider).load(project.id))!;
    expect(reloaded.editorHistory, '{"layers":[]}');
  });
}
