# Feature Matrix

Statuses: **IMPLEMENTED** (code complete, verified where noted) · **TESTED** (automated tests executed and passing) ·
**PARTIAL** (works with documented gaps) · **BLOCKED** (cannot proceed without an external input) · **NOT STARTED**.

"Verified" always names *how*. Native code that has only been compiled in CI and never run on a device is at most
PARTIAL.

Last update: 2026-10-28 (Phase 4 video recording and editor).

## Native beauty engine (`packages/yuz_beauty_engine`)

| Feature | Android | iOS | Evidence |
|---|---|---|---|
| Typed Flutter ⇄ native API (Pigeon 29) | IMPLEMENTED | IMPLEMENTED | generated code; Dart facade unit tests (6) |
| Camera preview into Flutter texture (no PlatformView, no frame copies over channels) | PARTIAL | PARTIAL | CameraX→SurfaceTexture→EGL→SurfaceProducer / AVFoundation→Metal→FlutterTexture; **not yet run on a device** |
| Front/back switch with resource release | PARTIAL | PARTIAL | new SurfaceTexture per binding / session reconfigure; device test pending |
| Flash (off/auto/on/torch); front camera screen flash (white screen + brightness boost) | PARTIAL | PARTIAL | ImageCapture/AVCapturePhoto flash; screen flash TESTED (Dart); native brightness not device-tested |
| Zoom, exposure compensation | PARTIAL | PARTIAL | clamped to device ranges |
| Timer (3 s / 10 s, cancellable) | TESTED (Dart) | TESTED (Dart) | `beauty_camera_controller_test.dart` |
| Photo capture at sensor resolution through the beauty pipeline (CameraX ImageCapture / AVCapturePhotoOutput → still processor), preview-frame fallback | PARTIAL | PARTIAL | front stills mirrored like the preview (EXIF flip / mirrored connection); CI builds; **not run on a device** |
| Still-image beauty processing (`processImage`: EXIF-upright decode, IMAGE-mode face detection, same shaders, original or capped resolution, atomic JPEG) | PARTIAL | PARTIAL | Kotlin geometry/EXIF planner TESTED (7 JUnit); Android type-checked + CI build; iOS CI build; **not run on a device** |
| Video recording with live beauty (H.264 + AAC MP4, processed frames, mic optional) | PARTIAL | PARTIAL | Android MediaCodec/MediaMuxer, iOS AVAssetWriter; timeline/encoder JUnit (7); CI builds; **not run on a device** |
| Video export engine (trim, speed 0.25–4×, multi-clip letterbox, beauty with VIDEO-mode face tracking, LUT, timed overlays, music loop + fade, volume mix) | PARTIAL | PARTIAL | edit plan, letterbox, resampler, mixer, FIFO JUnit (14); Android type-checked; iOS CI build; **not run on a device** |
| Video probe and timeline thumbnails | PARTIAL | PARTIAL | MediaExtractor/MediaMetadataRetriever, AVAsset/AVAssetImageGenerator |
| Resolution / aspect control | PARTIAL | PARTIAL | API supports 720p/1080p, 4:3/16:9; UI fixed to 1080p 16:9 |
| Permission-denied handling | TESTED (Dart) | TESTED (Dart) | native check + typed `PERMISSION_DENIED`; widget tests |
| Camera lifecycle (pause/resume/dispose, interruption errors) | PARTIAL | PARTIAL | Dart side tested; native side device test pending |
| MediaPipe Face Landmarker (live stream, 1-in-flight backpressure, GPU→CPU fallback) | PARTIAL | PARTIAL | tasks-vision 1.0.0 / MediaPipeTasksVision 1.0.0; model SHA-256 pinned |
| Landmark stabilization (One Euro) | TESTED | IMPLEMENTED | Kotlin JUnit (5 tests); Swift port untested |
| Multi-face policy (primary face with hysteresis / all faces ≤4) | TESTED | IMPLEMENTED | Kotlin JUnit (6 tests) |
| No-face / model-missing graceful degradation | IMPLEMENTED | IMPLEMENTED | empty mask / colour-only mode |
| Thermal degradation | IMPLEMENTED | IMPLEMENTED | detection halved at "severe", paused at "critical" |
| Measured performance telemetry (FPS, frame ms, detector ms, drops) | IMPLEMENTED | IMPLEMENTED | Kotlin tracker tested; **no device FPS measured yet** |

## Beauty effects

All effects run in the native GPU pipeline (GLSL ES 3.00 on Android, Metal on iOS, identical maths). "TESTED (GLSL)"
means headless WebGL2 pixel tests of the shipped shader files; the Metal port is compiled in CI but not
pixel-tested; nothing is device-tested yet.

| Effect | Status | Evidence |
|---|---|---|
| Skin smoothing (detail-preserving, landmark + YCbCr skin mask) | TESTED (GLSL) | variance, edge, non-skin, identity tests + mutation checks |
| Natural texture preservation | TESTED (GLSL) | fine-detail retention test |
| Skin brightening | TESTED (GLSL) | bounded luma lift |
| Skin tone (evening chroma from low-frequency base) | TESTED (GLSL) | chroma spread 7 → ~1.4 |
| Blemish reduction | TESTED (GLSL) | dark-spot contrast halved |
| Shine reduction | TESTED (GLSL) | highlights only, mid-tones unchanged |
| Glow | TESTED (GLSL) | luma lift on skin |
| Eye brightening, teeth whitening, dark circles | TESTED (GLSL) | "changes only its own region" test |
| Face reshape: slim, jawline, chin, eye enlarge, nose, lips, forehead | TESTED (GLSL warp + Kotlin builder) | warp identity/bulge/translate/locality tests; 7 builder tests |
| Makeup: lipstick, blush, brows, eyeshadow, eyeliner + shade palettes + intensity | TESTED (GLSL) | per-region tests, lipstick hue test, mask geometry tests |
| Natural makeup presets (Everyday, Evening) | TESTED (Dart) | preset tests |
| Filters: Natural, Soft, Glow, Portrait, Cinematic, Warm, Cool, Vintage, B&W | TESTED (Dart LUT + GLSL lookup) | LUT layout/grade tests; identity & monochrome LUT in shader |
| Custom LUT import (512×512 PNG/JPEG) | TESTED (Dart) | valid/wrong-size/unreadable/persistence tests |
| 0..100 slider per parameter, undo, reset, save/delete presets | TESTED | unit + widget tests |
| Sharpen (unsharp mask from half-res gaussian, reduced on smoothed skin) | TESTED (GLSL) | 3 tests: identity at 0, edge contrast gain, skin protection |
| Resolution-independent smoothing (blur step ∝ long edge / 1280) | TESTED (GLSL path) / IMPLEMENTED (Metal) | preview (1600 px) and full-resolution export match in look |
| Multiple faces | IMPLEMENTED | masks MAX-accumulated per face; warps for every beautified face (≤16 warps total) |

## App screens (`apps/mobile`)

| Screen | Status |
|---|---|
| Splash, Onboarding, Permissions, Home, Settings (language, perf overlay), Privacy | TESTED (widget tests) |
| AI Camera / Beauty | PARTIAL (UI tested with fake engine; native device run pending) |
| Capture result viewer | IMPLEMENTED |
| Projects (import from gallery, grid, thumbnails, delete; original copied, never modified; corrupt projects skipped; path-traversal-safe ids) | TESTED (unit + widget, fake engine) |
| Photo retouch step (all camera beauty/filter/reshape/makeup tools on a photo, 1600 px live preview, latest-wins rendering, hold-to-compare, zoom) | PARTIAL — TESTED with fake engine; native render not run on a device |
| Photo editor (pro_image_editor 14.21.1): crop, rotate, flip, ratio, tune (brightness, contrast, saturation, exposure, hue, temperature, fade, tint), blur, draw, text, emoji, own sticker set, undo/redo, zoom | PARTIAL — opens without framework errors in a widget test; tool interactions not device-tested |
| Non-destructive save: beauty look + editor history (JSON) stored per project and restored on reopen; full-resolution render cached per look | TESTED (unit) for storage; history import relies on pro_image_editor |
| Export: JPEG q95 at original resolution into the project and the system gallery ("Yuz" album, gal) with denied-access fallback | PARTIAL — TESTED (unit, fake gallery); gallery write not device-tested |
| Camera video mode (timer, elapsed time, no-sound hint, 3 min cap, lens/back locked while recording, finish on background) | TESTED (unit + widget, fake engine) |
| Video result (looped playback, save to gallery, open in editor) | TESTED (widget, fake player) |
| Video editor: clips (add, reorder, remove), trim, speed, look (studio + one-frame look preview, beauty on/off), text and stickers (drag, pinch, rotate, colour, time window), music (loop, fade, volumes), export with progress and cancel; non-destructive project storage | PARTIAL — TESTED with fake engine (domain, repository, controller, widget at 320 px); native export not run on a device |
| Templates (7 collage layouts, per-slot pan/zoom, background, spacing, corners, caption, 1920 px PNG to gallery) | TESTED (unit + widget) |
| AI Photoshoot/Hairstyle/Makeup/Background, Premium, Credits, Profile, Help, Account deletion | NOT STARTED — shown as "Planned" and routed to an honest "not available" screen |
| Localization uz / ru / en | TESTED |

## Platform / infrastructure

| Item | Status |
|---|---|
| Backend (NestJS, Prisma, BullMQ), AI worker, admin panel | NOT STARTED (Phase 5–7) |
| CI workflow (Flutter, shaders, Android unit/APK/AAB, iOS no-codesign, secrets) | IMPLEMENTED — see PROGRESS.md for run results |
| Android release signing | BLOCKED — needs upload keystore (secrets) |
| iOS signing / TestFlight | BLOCKED — needs Apple Developer team, certificates, profiles |
