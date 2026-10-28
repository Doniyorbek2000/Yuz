import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:yuz_mobile/app/app.dart';
import 'package:yuz_mobile/app/router.dart';
import 'package:yuz_mobile/core/storage/preferences.dart';
import 'package:yuz_mobile/features/projects/data/project_repository.dart';
import 'package:yuz_mobile/features/projects/domain/photo_project.dart';
import 'package:yuz_mobile/features/projects/presentation/photo_edit_screen.dart';
import 'package:yuz_mobile/features/projects/presentation/projects_screen.dart';

import '../helpers/test_app.dart';

class _Harness {
  _Harness(this.container, this.root, this.host);

  final ProviderContainer container;
  final Directory root;
  final FakeEngineHost host;

  ProjectRepository get repository => container.read(projectRepositoryProvider);
}

Future<_Harness> _pump(
  WidgetTester tester,
  String location, {
  Future<PhotoProject> Function(ProjectRepository repository, Directory scratch)? seed,
  String? pickedPath,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final root = (await tester.runAsync(() => Directory.systemTemp.createTemp('yuz_widget_projects')))!;
  addTearDown(() => tester.runAsync(() => root.delete(recursive: true)));
  final host = FakeEngineHost();
  final container = await createContainer(
    host: host,
    projectsRoot: root,
    preferences: const {PreferenceKeys.onboardingCompleted: true},
    extraOverrides: [photoPickerProvider.overrideWithValue(() async => pickedPath)],
  );
  var resolved = location;
  if (seed != null) {
    final project = (await tester.runAsync(() => seed(container.read(projectRepositoryProvider), root.parent)))!;
    resolved = location.replaceAll(':id', project.id);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: YuzApp(router: testRouter(resolved)),
    ),
  );
  await settleIo(tester);
  return _Harness(container, root, host);
}

Future<PhotoProject> _seedProject(ProjectRepository repository, Directory scratch) async {
  final source = File('${scratch.path}/yuz_seed_${DateTime.now().microsecondsSinceEpoch}.png');
  await source.writeAsBytes(kTinyPng);
  final project = await repository.create(source.path);
  await source.delete();
  return project;
}

/// Path behind an Image.file provider (cacheWidth wraps it in a ResizeImage).
String _filePath(ImageProvider provider) => switch (provider) {
  FileImage(:final file) => file.path,
  ResizeImage(:final imageProvider) => _filePath(imageProvider),
  _ => '',
};

void main() {
  testWidgets('projects screen shows the empty state', (tester) async {
    await _pump(tester, '/projects');
    expect(find.text('No projects yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-project')), findsOneWidget);
  });

  testWidgets('saved projects are listed and can be deleted', (tester) async {
    final harness = await _pump(tester, '/projects', seed: _seedProject);
    final tile = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && '${(w.key! as ValueKey).value}'.startsWith('project-'),
    );
    expect(tile, findsOneWidget);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete project?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await settleIo(tester);
    await tester.pumpAndSettle();

    expect(find.text('No projects yet'), findsOneWidget);
    expect((await tester.runAsync(harness.repository.list))!, isEmpty);
  });

  testWidgets('importing a photo creates a project and opens the retouch step', (tester) async {
    final scratch = (await tester.runAsync(() => Directory.systemTemp.createTemp('yuz_pick')))!;
    addTearDown(() => tester.runAsync(() => scratch.delete(recursive: true)));
    final picked = File('${scratch.path}/IMG_0001.png');
    await tester.runAsync(() => picked.writeAsBytes(kTinyPng));

    final harness = await _pump(tester, '/projects', pickedPath: picked.path);
    await tester.tap(find.byKey(const ValueKey('new-project')));
    await settleIo(tester, rounds: 40);

    expect(find.text('Retouch'), findsOneWidget);
    final projects = (await tester.runAsync(harness.repository.list))!;
    expect(projects, hasLength(1));
    expect(harness.host.imageRequests, isNotEmpty, reason: 'the beauty preview is rendered natively');
  });

  testWidgets('retouch screen renders the look and supports hold-to-compare', (tester) async {
    final harness = await _pump(tester, '/photo/:id', seed: _seedProject);
    await settleIo(tester);

    expect(find.text('Retouch'), findsOneWidget);
    expect(find.text('1 face'), findsOneWidget);
    expect(harness.host.imageRequests.first.maxLongEdge, 1600);

    final compare = find.byKey(const ValueKey('photo-compare'));
    final gesture = await tester.startGesture(tester.getCenter(compare));
    await tester.pump();
    expect(find.byWidgetPredicate((w) => w is Image && _filePath(w.image).contains('original')), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unknown project id shows a clear message', (tester) async {
    await _pump(tester, '/photo/1-abc');
    expect(find.text('This project no longer exists.'), findsOneWidget);
  });

  testWidgets('the editor opens on the full-resolution render without framework errors', (tester) async {
    final harness = await _pump(tester, '/photo/:id/edit', seed: _seedProject);
    await settleIo(tester, rounds: 40);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(ProImageEditor), findsOneWidget);
    expect(harness.host.imageRequests.map((r) => r.maxLongEdge), contains(0));
  });

  test('sticker ids saved in a history rebuild the same sticker', () {
    final widget = loadSticker('yuz-sticker:heart') as Icon;
    expect(widget.icon, Icons.favorite_rounded);
    expect((loadSticker('unknown') as Icon).icon, Icons.help_outline_rounded);
  });
}
