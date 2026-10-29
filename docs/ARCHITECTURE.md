# Architecture

## Repository layout

```
apps/mobile/                 Flutter app (feature-first, Riverpod, GoRouter, uz/ru/en)
  lib/app/                   MaterialApp + router
  lib/core/                  theme tokens, widgets, preferences
  lib/features/<feature>/    domain / data / application / presentation
packages/yuz_beauty_engine/  Flutter plugin: native camera + GPU beauty engine
  pigeons/                   single source of truth for the Flutter⇄native API
  android/…/beauty_engine/   Kotlin: camera/, gl/, render/, face/, perf/
  android/src/main/assets/yuz_beauty_engine/shaders/   GLSL ES 3.00 (shipped + CI-tested)
  ios/Classes/               Swift: Camera/, Render/ (Metal), Face/, Perf/
tools/shader-tests/          headless WebGL2 tests for the shipped GLSL
tools/fetch_models.sh        downloads + SHA-256-verifies the MediaPipe model
```

## Frame pipeline

```
Android                                         iOS
CameraX Preview ─► SurfaceTexture (OES)          AVCaptureVideoDataOutput (BGRA, portrait, mirrored front)
CameraX ImageAnalysis (RGBA, keep-latest)        same sample buffer
   └► MediaPipe detectAsync (≤1 in flight)          └► MediaPipe detectAsync (≤1 in flight)
         └► FaceTracker (IoU tracks, One Euro, policy) ─► latest snapshot (atomic)
GL thread: OES ─► original ─► bilateral H/V (½) Metal: bilateral H/V (½) ─► face mask (¼) ─► Gaussian ×2
           ─► face mask (¼) ─► Gaussian ×2              ─► composite ─► CVPixelBuffer (pool)
           ─► composite ─► EGL window surface          ─► FlutterTexture.copyPixelBuffer
              (Flutter SurfaceProducer)
```

- **No raw frames cross the platform channel.** Dart receives a texture id plus ≤10 Hz face status and 1 Hz
  performance samples.
- **Backpressure:** SurfaceTexture latches the newest frame and render requests coalesce; ImageAnalysis uses
  `STRATEGY_KEEP_ONLY_LATEST`; iOS uses `alwaysDiscardsLateVideoFrames` and a 2-frame Metal in-flight semaphore;
  the detector drops frames while busy. Drops are counted.
- **Identity fast path:** with all effects at 0 only the camera copy runs (Android) or the camera buffer is handed
  straight to Flutter (iOS).
- **Preview = export:** capture renders the same composite pass into an offscreen target.

## Beauty algorithm

`mask = faceMask(landmark polygons: oval − eyes − brows − lips, feathered) × skinLikelihood(YCbCr)`
`out  = mix(orig, smooth + fineDetail × texturePreservation, smoothing × 0.92 × mask)` where `smooth` is a separable
cross-bilateral blur and `fineDetail` is the low-amplitude part of `orig − smooth` (pores kept, blemishes removed).
Brightening is a masked gamma lift.

## Dart layers

`presentation` (widgets) → `application` (Riverpod notifiers: `BeautyCameraController`, `BeautyEditorNotifier`)
→ `domain` (`BeautyAdjustments` 0..100, `BeautyEditorState` undo) / `data` (`BeautyPresetRepository`)
→ `BeautyEngine` facade (typed errors, event streams, parameter coalescing) → Pigeon.

The camera controller is `autoDispose`: leaving the screen releases camera, GPU and detector; a session that
finishes opening after the screen left is released again (tested).

## Server side

```
app ──HTTPS──▶ API (NestJS) ──▶ PostgreSQL (users, consents, credit ledger, jobs, purchases, audit log)
                   │  │
                   │  └─ enqueue {jobId} ──▶ Redis / BullMQ "yuz-ai-jobs"
                   │                               │
                   │        ◀── internal API ── AI worker (Python, providers) ── shared storage volume
                   │                                        (uploads in, results out)
admin (Next.js, server-side calls, httpOnly session) ──▶ API /v1/admin
```

- **API** (`apps/backend`): a modular monolith with the modules auth, users, consent, credits, ai-jobs,
  purchases, admin, storage, queue and health. Every route needs an access token unless it is marked public, and
  roles are checked against the database. Configuration is validated at startup (zod).
- **Job lifecycle:** `QUEUED → RUNNING → SUCCEEDED | FAILED | CANCELLED`.
  1. Creating a job spends credits, stores the upload and enqueues only the job id.
  2. The worker claims the job with `/internal/ai-jobs/:id/start`. A job that was cancelled meanwhile answers
     409 and is skipped.
  3. The worker writes `result.{png|jpg}` atomically and reports `complete`, or reports `fail`, which refunds
     the credits exactly once.
- **Worker** (`services/ai-worker`): providers implement `process(image, params) -> (bytes, extension)` for
  their job types. Only `BACKGROUND` is served, with the MediaPipe selfie segmenter on CPU. The API accepts only
  the types listed in `AI_ENABLED_TYPES`, so a type without a provider is refused before it is charged.
- **App** (`apps/mobile/lib/core/api`): a typed client with stable error codes. Riverpod providers hold the
  session (`SessionController`), the account data and the AI background flow, which uploads, polls, downloads
  and then deletes the server copy.
- **Admin** (`apps/admin`): Next.js App Router server components and server actions. Requests pass through a
  proxy that refreshes tokens, and no tokens reach the browser.
