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

- Camera capture saves the processed preview frame (≤1080p). Imported photos are processed at full resolution
  (`processImage`), capped at the GPU texture limit (≤8192 px, ≤24 MP); larger photos are downscaled, never upscaled.
- Flash is torch-assisted; the front camera has no screen-flash yet.
- Masks are built from the un-warped landmarks; with strong reshape (e.g. eye enlarge 100) makeup and eye masks can
  sit up to a few pixels off the warped feature.
- Up to 16 reshape warps per frame in total: with "all faces" policy and several faces, warps beyond 16 are dropped.
- Eyeshadow/eyeliner/under-eye regions are derived from the eye contour (scaled and shifted), not from dedicated
  landmarks; they assume an upright, roughly frontal face.
- Custom LUTs must use the standard 512×512 (8×8 tiles of 64³) layout; .cube files are not supported yet.
- Face mask exclusions (eyes, brows, lips) use fixed dilation factors; very large head yaw can let the mask touch
  the hairline. Colour-based skin detection limits spill onto hair and background.
- Camera captures are stored in app-private storage; only photo-editor exports are saved to the system gallery.
- Photo editor: the beauty look is baked into a full-resolution render first; changing the look after editing keeps
  the editor layers (re-imported from history) but crop/tune are re-applied by pro_image_editor, which recalculates
  layer positions for the new image. Large images (>12 MP) can take several seconds to export on mid-range phones
  (not measured yet).
- Editor colour adjustments (tune) run in Flutter colour matrices on export, not in the native engine; sharpening is
  done natively in the retouch step because pro_image_editor has no sharpen tool.
- Imports: HEIC/HEIF is decoded by the platform (Android 9+/iOS). RAW and animated images are not supported.
- Stickers are an own vector icon set (Material Icons, Apache-2.0); no downloadable sticker packs yet.

## Third-party / legal

- `face_landmarker.task` checksum in `tools/models.sha256` was pinned on first download (trust-on-first-use from
  Google's official bucket). Re-verify the model card license (Apache-2.0) before store release.
- Dependency versions are pinned through `pubspec.lock` / Gradle / podspec. CameraX 1.4.2 and MediaPipe 1.0.0 were
  taken from the official MediaPipe sample (2026-10); newer CameraX releases could not be listed from this
  environment.
