import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/camera/presentation/beauty_camera_screen.dart';
import '../features/camera/presentation/capture_result_screen.dart';
import '../features/catalog/feature_catalog.dart';
import '../features/catalog/feature_unavailable_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/permissions/permissions_screen.dart';
import '../features/privacy/privacy_screen.dart';
import '../features/projects/presentation/photo_edit_screen.dart';
import '../features/projects/presentation/photo_retouch_screen.dart';
import '../features/projects/presentation/projects_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/video/presentation/video_editor_screen.dart';
import '../features/video/presentation/video_result_screen.dart';

/// Allowed continuation targets for the permission flow (prevents arbitrary
/// deep-link redirects through the `next` query parameter).
const _permissionTargets = {'/home', '/camera'};

GoRouter buildRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    GoRoute(
      path: '/permissions',
      builder: (_, state) {
        final next = state.uri.queryParameters['next'];
        return PermissionsScreen(next: _permissionTargets.contains(next) ? next! : '/home');
      },
    ),
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/camera', builder: (_, _) => const BeautyCameraScreen()),
    GoRoute(
      path: '/capture',
      builder: (_, state) => CaptureResultScreen(filePath: state.uri.queryParameters['path'] ?? ''),
    ),
    GoRoute(
      path: '/projects',
      builder: (_, state) => ProjectsScreen(initialTab: state.uri.queryParameters['tab'] == 'videos' ? 1 : 0),
    ),
    GoRoute(
      path: '/photo/:id',
      builder: (_, state) => PhotoRetouchScreen(projectId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'edit',
          builder: (_, state) => PhotoEditScreen(projectId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/video',
      builder: (_, state) => VideoResultScreen(
        filePath: state.uri.queryParameters['path'] ?? '',
        hasAudio: state.uri.queryParameters['audio'] != '0',
      ),
    ),
    GoRoute(
      path: '/video-editor/new',
      builder: (_, state) => NewVideoProjectScreen(sourcePath: state.uri.queryParameters['source'] ?? ''),
    ),
    GoRoute(
      path: '/video-editor/:id',
      builder: (_, state) => VideoEditorScreen(projectId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(path: '/privacy', builder: (_, _) => const PrivacyScreen()),
    GoRoute(
      path: '/unavailable/:feature',
      builder: (_, state) {
        final name = state.pathParameters['feature'];
        final feature = AppFeature.values.where((f) => f.name == name).firstOrNull ?? AppFeature.help;
        return FeatureUnavailableScreen(feature: feature);
      },
    ),
  ],
  errorBuilder: (_, _) => const HomeScreen(),
);

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});

extension on Iterable<AppFeature> {
  AppFeature? get firstOrNull => isEmpty ? null : first;
}

/// Exposed for tests that need a widget tree with routing.
@visibleForTesting
GoRouter testRouter(String location) => buildRouter(initialLocation: location);
