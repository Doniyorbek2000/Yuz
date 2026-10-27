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

## Planned (not implemented)

Backend (NestJS modular monolith, Prisma/PostgreSQL, BullMQ/Redis, S3-compatible storage), Python AI worker behind
a provider interface, Next.js admin — Phases 5–7.
