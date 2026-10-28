# Progress

## Phase 0 — Audit & architecture ✅

- Workspace: empty git repository on branch `ccr-a1d0caf5-yhva3p`; new monorepo created (nothing pre-existing to
  preserve).
- Environment: Flutter 3.47.8 / Dart 3.13.7 installed; Kotlin 2.4.0 compiler for local pure-Kotlin tests.
  `dl.google.com` (Android SDK, Google Maven) and `download.swift.org` are blocked by the sandbox network policy →
  Android and iOS builds are verified only in GitHub Actions.
- 8 reference repositories cloned to `third_party/research/` (git-ignored) and audited → `OPEN_SOURCE_AUDIT.md`.
  Decision: own camera stacks (CameraX/GLES, AVFoundation/Metal), MediaPipe 1.0.0 on both platforms,
  pro_image_editor for Phase 3; beauty_cam / GPUImage-plus / ios-gpuimage-plus / wechat_camera_picker not linked.
- Architecture: `docs/ARCHITECTURE.md`. Security: `docs/SECURITY.md`.

## Phase 1 — Flutter project, design system, navigation, native camera ✅ code / ⏳ device

Delivered:

- `packages/yuz_beauty_engine`: Pigeon API; Android Kotlin engine (CameraX, EGL/GLES 3.0, SurfaceProducer,
  MediaPipe, One Euro tracker, thermal, perf); iOS Swift engine (AVFoundation, Metal compute, FlutterTexture,
  MediaPipe); Dart facade.
- Skin smoothing (detail-preserving cross-bilateral + landmark/skin mask), texture preservation, brightening.
- `apps/mobile`: Riverpod + GoRouter, uz/ru/en, dark design system, Splash, Onboarding, Permissions, Home (honest
  feature statuses), Beauty Camera (sliders 0..100, presets, undo/reset, timer, flash, zoom, exposure, capture),
  Settings, Privacy, capture viewer.
- CI: `.github/workflows/ci.yml`.

### Verification results (2026-10-27)

| Check | Where | Result |
|---|---|---|
| Engine Dart: analyze | local | ✅ no issues |
| Engine Dart: unit tests | local | ✅ 6/6 |
| App: analyze | local | ✅ no issues |
| App: unit + widget + golden tests | local | ✅ 39/39 (found and fixed: Home tile overflow at 320 px) |
| GLSL shaders, headless WebGL2 | local + CI | ✅ 8/8; mutation checks confirm the tests detect broken masks and broken edge preservation |
| Pure Kotlin engine logic (JUnit 5) | local (kotlinc 2.4.0) | ✅ 24/24 (found and fixed: One Euro beta 0.02 → 5.0, lag 0.30 → <0.08) |
| Secret scan + forbidden files | CI | ✅ |
| Android: Gradle compile of engine + `testDebugUnitTest`, debug APK, release AAB | CI run #2 | ✅ (AAB **unsigned** — no signing secrets configured) |
| iOS: pod install (MediaPipeTasksVision 1.0.0), debug + release build, no codesign | CI run #2 (macOS) | ✅ |
| On-device camera / FPS | — | ❌ not run (no device in this environment) |

CI history: run #1 found 3 real issues (Pigeon output reformatted locally, Swift closure circular reference,
permission_handler 13 requiring compileSdk 37) → fixed in `0d53076`; run #2
(https://github.com/Doniyorbek2000/Yuz/actions/runs/40582573317) is fully green.

## Phase 2–3 (effects) — code ✅ / device ⏳

Delivered (Android GLSL and iOS Metal with identical maths):

- **Filters:** Natural, Soft, Glow, Portrait, Cinematic, Warm, Cool, Vintage, B&W as colour grades turned into
  512×512 LUTs on a background isolate (single Dart source of truth); custom LUT import (512×512 image),
  persisted in app-private storage; intensity slider.
- **Skin:** smoothing, texture, brightening, even tone, blemishes, shine (matte), glow.
- **Face details:** eye brightening, teeth whitening, dark circles.
- **Reshape:** face slim, jawline, chin, eye enlarge, nose, lips, forehead — landmark-driven local warps sized
  relative to the face and capped for natural results.
- **Makeup:** lipstick, blush, brows, eyeshadow, eyeliner with curated shades, global makeup intensity,
  Everyday/Evening looks.
- **UI:** beauty studio with Looks/Filters/Skin/Face/Reshape/Makeup tabs; face-dependent effects are disabled with
  an explanation when face tracking is unavailable.

Verification (2026-10-28):

| Check | Where | Result |
|---|---|---|
| GLSL shaders (21 tests: skin, regions, makeup, LUT, warp) | local + CI | ✅ 21/21 — found and fixed: bilateral blur keeps strong blemishes → added wide base blur |
| Kotlin pure logic (mask geometry, warp builder, tracker…) | local + CI Gradle | ✅ 33/33 |
| Android sources vs Android 16 framework + Flutter embedding | local (kotlinc + android-all) | ✅ type-check OK |
| Engine Dart (LUT generator, API facade) | local + CI | ✅ 15/15 |
| App (unit, widget, golden) | local + CI | ✅ 60/60 |
| Android debug APK + release AAB | CI | ✅ (AAB unsigned) |
| iOS build | CI (macOS) | see CI run below |
| On device | — | ❌ not run |

## Next — continue here

1. Run `apps/mobile/integration_test/camera_flow_test.dart` on one Android and one iOS device; record measured FPS,
   fix orientation/mirroring if wrong; update FEATURE_MATRIX statuses from PARTIAL to TESTED.
2. Metal pixel tests on the macOS runner (same fixtures as tools/shader-tests).
3. Phase 3 remainder: full-resolution still capture, photo editor (pro_image_editor),
   non-destructive projects.
