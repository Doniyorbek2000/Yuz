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
| Metal kernels compiled with `xcrun metal -std=ios-metal2.4 -Werror` | CI (macOS) | ✅ (new step: runtime-compiled kernels were previously unchecked) |
| iOS debug + release build (no codesign) | CI (macOS) | ✅ Runner.app 77.8 MB |

All 5 CI jobs green: https://github.com/Doniyorbek2000/Yuz/actions/runs/40730273854
| On device | — | ❌ not run |

## Phase 3 (photo editor) — code ✅ / device ⏳

Flow: **Projects** → import a photo (original copied into app storage, never modified) → **Retouch** (the same
beauty studio as the camera: looks, filters + intensity, sharpen, skin, face, reshape, makeup; 1600 px live preview
rendered natively, hold-to-compare, pinch-zoom) → **Edit** (full-resolution beauty render opened in
pro_image_editor: crop/rotate/flip/ratio, tune, blur, draw, text, emoji, own stickers, undo/redo, zoom) →
**Done** (JPEG q95 at original resolution into the project and the gallery album "Yuz").

- Engine: new `processImage` Pigeon call. EXIF orientation applied while decoding (Android ExifInterface + matrix,
  iOS CGImageSource transform), IMAGE-mode MediaPipe detection (all faces ≤4), same shader graph as the camera,
  output at original size (≤ GPU max texture, ≤24 MP) or capped long edge, atomic JPEG write.
- New effect: sharpen (both platforms); smoothing radius scales with resolution so preview and export match.
- Non-destructive projects: `project.json` stores the look and the editor history; reopening restores both.
  Full-resolution render is cached per look. Writes are atomic; corrupt projects are skipped.
- Gallery: `gal` (Android MediaStore, legacy write permission only ≤ API 29; iOS add-only photo permission).

Verification (2026-10-28):

| Check | Result |
|---|---|
| App unit + widget + golden tests (incl. 11 project JSON/repository, 9 controller, 7 photo-flow widget tests) | ✅ 87/87 |
| Engine Dart tests | ✅ 16/16 |
| GLSL shader tests (incl. 3 sharpen tests) | ✅ 24/24 |
| Kotlin JUnit (incl. 7 still-image geometry/EXIF tests) | ✅ 40/40 |
| Android sources type-check vs Android 16 framework | ✅ |
| `flutter analyze` (app + engine) | ✅ no issues |
| CI: Android unit tests + APK + AAB, iOS build + Metal compile, Flutter, GLSL, secret scan | ✅ all 5 jobs green — https://github.com/Doniyorbek2000/Yuz/actions/runs/40736691438 |
| On device | ❌ not run |

## Phase 4 (video) — code ✅ / device ⏳

- **Recording:** the processed (beautified) camera frames go into an H.264 encoder (Android: MediaCodec input
  surface at the exact frame size when supported; iOS: AVAssetWriter) with AAC microphone sound when allowed
  (silent fallback otherwise). Shared clock handling, atomic file write, background finishes the take.
- **Editor:** multi-clip timeline with thumbnails, reorder, trim, speed (0.5–2× in the UI), look (same studio as
  camera/photo, beauty on/off), text and stickers placed with drag/pinch/rotate and a time window, music (looping,
  fade-out) with music/clip volume, export with progress and cancel, then save to gallery.
- **Export engine:** Android decodes each trimmed clip into a SurfaceTexture, runs the camera GPU pipeline with
  VIDEO-mode face tracking, letterboxes, draws the overlay PNGs (painted by the same Flutter code as the editor
  preview) and encodes; the soundtrack is decoded, resampled to 44.1 kHz stereo, mixed and AAC-encoded. iOS builds an
  AVComposition (trim, speed, orientation, letterbox, music) and runs Metal beauty + CoreImage overlays per frame.

Verification (2026-10-28): app tests 124/124, engine Dart 18/18, Kotlin JUnit 58/58, GLSL 24/24, Android
type-check (with MediaPipe API stubs) OK. CI after the native export commit: all 5 jobs green (Android APK/AAB, iOS
build). Found and fixed on the way: iOS `await` inside `??` (CI), studio button row overflow at ≤360 px, concurrent
project saves sharing one temp file. Not run on a device.

## Phase 5 (backend) — code ✅ / deploy ⏳

`apps/backend`: NestJS 11 API with Prisma 7 (PostgreSQL 16) and BullMQ 6 (Redis 7) — auth (argon2id, short JWTs,
rotating refresh tokens with reuse detection, rate limiting), profile, JSON data export, password-confirmed account
deletion (files included, purchases anonymized), versioned cloud-AI consent, credit ledger (atomic, idempotent, no
overdraw), AI job lifecycle with a token-protected worker API and refunds, retention purge, purchase verification flow
(store verifiers BLOCKED on credentials), health. Docker image (non-root, health check), compose stack with a
migration job, CI job with Postgres/Redis services.

Verification (2026-10-28): 25 e2e tests against real Postgres + Redis, stable over repeated runs; typecheck, ESLint
(type-aware), Prettier, `npm audit --omit=dev` clean; compiled build boots and serves `/health`. Found and fixed:
NestJS 12 is ESM-only (Jest on Node 22 cannot load it → NestJS 11 LTS line), multer and js-yaml advisories (patched
via overrides), registration and welcome credits made atomic.

## Phase 6 — AI worker and app AI/account features ✅ code / ⏳ deploy + device

- `services/ai-worker`: Python 3.13 BullMQ consumer. Claims jobs through the internal API, runs the MediaPipe selfie
  segmenter (blur / solid colour / transparent cut-out), writes the result atomically to the shared volume, reports
  complete/fail (refunded). EXIF rotation, size limits, no-person detection, graceful SIGTERM. Docker image with the
  model downloaded and SHA-256 verified; compose `worker` service.
- API: `AI_ENABLED_TYPES` (default BACKGROUND) — unserved types answer 503 before charging; pricing shows `enabled`.
- App: typed API client (single-flight refresh, stable error codes, HTTPS-only release URL via `YUZ_API_URL`),
  tokens in Keychain/Keystore (excluded from Android backups), account screens, consent screen, AI Background,
  Credits & Premium (purchases honestly unavailable), Help. Generative AI tiles marked BLOCKED.

Verification (2026-10-29): worker 25/25 pytest (real model + real Redis), ruff clean; backend 26/26 then 31/31 e2e;
app 164/164 tests, analyze clean; CI all jobs green including iOS and Android builds with the new plugins and the
worker image. Found and fixed: MediaPipe segmenter crashing at interpreter exit (explicit close), session provider
written after dispose, error snackbar delayed behind a closing one, camera permission text that claimed photos are
never uploaded.

## Phase 7 — Admin panel ✅ code / ⏳ deploy

- API: `/v1/admin/*` (ADMIN role checked from the database per request): stats, user search and detail, idempotent
  audited credit adjustments, AI jobs, audit log; `dist/cli/set-role.js` grants/revokes admin (no HTTP endpoint).
- `apps/admin`: Next.js 16 App Router; login limited to admins; tokens only in httpOnly SameSite=Strict cookies,
  12 h sessions, proxy-side refresh with per-process coalescing; overview, users, user detail with credit form, AI
  jobs, audit log; security headers; standalone Docker image; compose service on loopback.

Verification (2026-10-29): API 31/31 e2e; admin typecheck, ESLint, 11/11 node tests, production build; Chromium run
against the real API (non-admin refused, wrong password, adjustment + ledger + audit, overdraw refused, forced token
refresh, 375 px without horizontal scroll, sign-out). Found and fixed: React 19 form reset clearing the email after a
failed login and the credit form values after an error; a remount key that hid the success message.

## Next — continue here

1. Run `apps/mobile/integration_test/camera_flow_test.dart` on one Android and one iOS device; record measured FPS,
   fix orientation/mirroring if wrong; update FEATURE_MATRIX statuses from PARTIAL to TESTED.
2. Metal pixel tests on the macOS runner (same fixtures as tools/shader-tests).
3. Device pass of the photo flow: EXIF orientations 1–8, a 48 MP photo (downscale path), HEIC, export time, gallery
   permission prompts on Android 9/10/14 and iOS.
4. Owner decisions: generative AI provider (paid API or GPU), store credentials (purchases), hosting/domain/TLS,
   Apple/Google sign-in, email provider (verification and password reset). Each is BLOCKED until approved.
5. Device pass of recording and export (A/V sync, rotation of portrait/landscape sources, HEVC sources, export
   speed with face effects); then full-sensor still capture, templates, backend (Phase 5).
