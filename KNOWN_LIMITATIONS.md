# Known Limitations

## Verification gaps (must be closed before calling anything "ready")

1. **No device run yet.** The Android and iOS engines have not been executed on hardware. Camera orientation
   (sensor rotation + front mirroring), SurfaceProducer lifecycle and Metal texture usage are implemented from the
   platform contracts and unit-tested where pure, but need a device pass (`integration_test/camera_flow_test.dart`).
2. **No FPS measured.** The engine reports measured FPS/frame time; no number has been collected. Targets (24–30 FPS
   MVP, 30–60 FPS pro) are unverified.
3. **Local build environment.** The development container cannot reach `dl.google.com`/Google Maven or
   `download.swift.org`, so Gradle/Android and Swift builds run only in GitHub Actions.
4. **Metal kernels** are a line-by-line port of the GLSL shaders, but only the GLSL versions are pixel-tested
   (headless WebGL2). Metal is compiled at runtime and has not been pixel-compared.
5. **"GPU frame ms"** is GL/Metal-thread wall time per frame (submit + swap / command-buffer completion), not a GPU
   timer query.

## Functional limitations

- Photo capture saves the processed preview frame (≤1080p). Full-resolution still capture through the same shaders is
  planned for Phase 3 together with the photo editor.
- Flash is torch-assisted; the front camera has no screen-flash yet.
- Only skin smoothing, texture preservation and brightening exist. All other beauty, reshape, makeup and filter
  features are NOT STARTED.
- Face mask exclusions (eyes, brows, lips) use fixed dilation factors; very large head yaw can let the mask touch
  the hairline. Colour-based skin detection limits spill onto hair and background.
- Captures are stored in app-private storage; saving to the system gallery is not implemented.

## Third-party / legal

- `face_landmarker.task` checksum in `tools/models.sha256` was pinned on first download (trust-on-first-use from
  Google's official bucket). Re-verify the model card license (Apache-2.0) before store release.
- Dependency versions are pinned through `pubspec.lock` / Gradle / podspec. CameraX 1.4.2 and MediaPipe 1.0.0 were
  taken from the official MediaPipe sample (2026-10); newer CameraX releases could not be listed from this
  environment.
