# Open-Source Audit

Audit date: 2026-10-27. Every repository was shallow-cloned into `third_party/research/`
(git-ignored, never shipped) and inspected locally: README, LICENSE, dependency manifests,
native sources, last commit, platform targets.

Legend for **Final decision**:

- **ADOPT** – used as a dependency or source in production code.
- **REFERENCE** – studied for algorithms/patterns; no code copied into production.
- **REJECT** – not used; reasons listed.

---

## 1. MR-MaoJiu/beauty_cam

| Item | Finding |
|---|---|
| URL | https://github.com/MR-MaoJiu/beauty_cam |
| License | BSD-3-Clause (© 2023 MaoJiu) |
| Last commit | 2024-10-08 (`53d4bcc`) – unmaintained for ~2 years |
| Version | 1.0.5, Dart SDK `>=2.18.5`, `flutter_lints ^2` |
| Technologies | Flutter `PlatformView`, untyped `MethodChannel('beauty_cam')`, Java, Objective-C |
| Android | Wraps `org.wysaid:gpuimage-plus:3.0.0` `CameraRecordGLSurfaceView` (legacy `android.hardware.Camera` API) |
| iOS | Pulls `ios-gpuimage-plus` (OpenGL ES, see §5) as podspec source |
| Really implemented | Single-slider beauty (GPUImage-plus "beautify"), rule-string filters, photo/video capture |
| Not implemented | Face landmarks, reshape, makeup, per-parameter controls, lifecycle handling |
| Reusable modules | None suitable |
| Integration risks | Package `com.example.*`; `PlatformView` (expensive composition, Hybrid Composition jank); deprecated Camera1 API; filters downloaded over HTTP with no integrity check (`HttpURLConnection` in `CameraFlutterPluginView`); OpenGL ES on iOS (deprecated by Apple since iOS 12); no tests of native code |
| Final decision | **REJECT** – reference only for the feature surface. |

## 2. hm21/pro_image_editor

| Item | Finding |
|---|---|
| URL | https://github.com/hm21/pro_image_editor |
| License | BSD-3-Clause (© 2025 Alex Frei). `NOTICES` file bundles Flutter/Dart BSD, MIT (Stefan Humm), MIT (`image` by Brendan Duncan) |
| Last commit | 2026-10-26 (`e5ce9ca`) – actively maintained |
| Version | 14.21.1, Dart `>=3.12`, Flutter `>=3.44` (compatible with our Flutter 3.47.8) |
| Dependencies | `cupertino_ui`, `material_ui`, `http`, `shared_preferences`, `vector_math`, `web`, `plugin_platform_interface` – all permissive (BSD/MIT) |
| Platforms | Android, iOS, macOS, Linux, Web |
| Really implemented | Crop/rotate/flip, tune (brightness/contrast/saturation/…), filters, blur, paint, text, stickers, emoji, undo/redo, history export/import, layered state |
| Reusable modules | `main_editor`, `crop_rotate_editor`, `tune_editor`, `filter_editor`, `text_editor`, `sticker_editor`, state-history import/export (non-destructive projects) |
| Integration risks | Large API surface with frequent major versions (v14) – pin exact version via lockfile; editor renders filters in Flutter (matrix color filters) – beauty effects must come from our native engine and be fed back as a layer/bitmap to keep export parity |
| Final decision | **ADOPT** as a pub dependency in Phase 3 (Photo Editor). License text goes to `LICENSES/THIRD_PARTY_NOTICES.md`. |

## 3. humairaashraf766/face_overlay

| Item | Finding |
|---|---|
| URL | https://github.com/humairaashraf766/face_overlay |
| License | MIT (© 2025 face_overlay contributors). Bundles `face_landmarker.task` (Google, Apache-2.0 model card) |
| Last commit | 2026-07-01 |
| Platforms | Android API 24+, iOS 14+ |
| Really implemented | MediaPipe Face Landmarker (478 points), PNG overlay scaled to face box, multi-face, debug landmark painter |
| Reusable modules | Landmark index tables (face oval, eyes, lips) are MediaPipe's public topology – we re-derive them from MediaPipe's `face_mesh_connections` rather than copying |
| Integration risks | Front camera only; owns its own camera pipeline; landmarks sent to Dart and drawn with `CustomPainter` (fine for overlays, wrong for GPU beauty) |
| Final decision | **REFERENCE** – confirms the MediaPipe-on-both-platforms approach. |

## 4. wysaid/android-GPUImage-plus

| Item | Finding |
|---|---|
| URL | https://github.com/wysaid/android-GPUImage-plus |
| License | MIT (© 2017-2026 Wang Yang) |
| Last commit | 2026-07-28 – maintained; v3.x added CameraX provider |
| Build | AGP 8.13.2, Kotlin 2.0.20, NDK 27.2, compileSdk 35, minSdk 21, demo `targetSdk 25` |
| Technologies | C++ (`cge` core) + JNI + OpenGL ES 2.0, `GLSurfaceView` |
| Really implemented | Rule-string filter engine, LUTs, "beautify" (green-channel high-pass, `cgeBeautifyFilter.cpp`), video recording via FFmpeg |
| Integration risks | **Prebuilt `libffmpeg.so` committed for 4 ABIs with no recorded configure flags → LGPL/GPL compliance cannot be verified**; maven artifact hosted on a personal domain (`maven.wysaid.org`) – supply-chain risk; `GLSurfaceView` renders into its own view, not into a Flutter texture; GLES 2.0 only |
| Final decision | **REFERENCE** – the high-pass "beautify" idea informed our own detail-preserving shader; no code or binaries used. |

## 5. wysaid/ios-gpuimage-plus

| Item | Finding |
|---|---|
| URL | https://github.com/wysaid/ios-gpuimage-plus |
| License | MIT (© 2017 Wang Yang) |
| Last commit | 2020-11-18 – abandoned |
| Technologies | OpenGL ES / EAGL (`cgeSharedGLContext.h`), podspec `platform :ios, "7.0"` |
| Integration risks | OpenGL ES deprecated on Apple platforms; no Metal; no maintenance |
| Final decision | **REJECT** – iOS engine is written on Metal. |

## 6. google-ai-edge/mediapipe-samples

| Item | Finding |
|---|---|
| URL | https://github.com/google-ai-edge/mediapipe-samples |
| License | Apache-2.0 |
| Last commit | 2026-10-19 – actively maintained |
| Face Landmarker sample | Android: CameraX 1.4.2, `com.google.mediapipe:tasks-vision:1.0.0`, `LIVE_STREAM` mode with `detectAsync`, model downloaded at build time from `storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task`. iOS: `MediaPipeTasksVision` via SPM on `master` branch (non-reproducible); CocoaPods `MediaPipeTasksVision` 1.0.0 exists on trunk (verified on cdn.cocoapods.org) |
| Model | `face_landmarker.task` – Google model card states Apache-2.0. **Must be re-checked against the model card before store release** (tracked in KNOWN_LIMITATIONS.md) |
| Reusable modules | `FaceLandmarkerHelper.kt` / `FaceLandmarkerService.swift` usage patterns (options, live-stream callbacks, timestamp monotonicity) |
| Integration risks | Sample converts every frame to `Bitmap` on the UI thread path – we keep conversion on the analysis executor and drop frames while inference is in flight |
| Final decision | **ADOPT** the libraries (`tasks-vision` 1.0.0 / `MediaPipeTasksVision` 1.0.0, CocoaPods for reproducibility) and model; integration code is our own. |

## 7. fluttercandies/flutter_wechat_camera_picker

| Item | Finding |
|---|---|
| URL | https://github.com/fluttercandies/flutter_wechat_camera_picker |
| License | Apache-2.0 |
| Last commit | 2026-08-13 – maintained |
| Dependencies | `camera` plugin, `photo_manager`, `sensors_plus`, `video_player`, `wechat_picker_library` |
| Integration risks | Owns a second camera stack (`camera` plugin) → two camera lifecycles competing for the device; WeChat-styled UI |
| Final decision | **REJECT** for camera. Sister package `wechat_assets_picker` (same org/license) is a **candidate** for gallery import in Phase 3; `image_picker` (first-party) is the default. |

## 8. arraypress/swift-face-beauty

| Item | Finding |
|---|---|
| URL | https://github.com/arraypress/swift-face-beauty |
| License | MIT (© 2026 David Sherlock / ArrayPress) |
| Last commit | 2026-10-11 |
| Requirements | **iOS 26 / macOS 26, Swift 6.2** |
| Technologies | Apple Vision landmarks + Core Image (`CIBumpDistortion`, precompiled `.metallib` warp kernel) |
| Really implemented | Eye enlarge, face slim, eye brighten, teeth whiten – shared builder for preview/export |
| Integration risks | Deployment target far above our iOS 15 minimum; Vision landmarks ≠ MediaPipe topology (two trackers would diverge between platforms) |
| Final decision | **REFERENCE** – its "one builder for preview and export" principle is adopted; warp maths re-implemented on MediaPipe landmarks in Phase 3 with attribution if any formula is ported. |

---

## Integration strategy (result)

1. **One camera stack per platform**, owned by our `yuz_beauty_engine` plugin: CameraX + EGL/GLES 3.0 on Android,
   AVFoundation + Metal on iOS. No third-party camera plugin is linked.
2. **Rendering into Flutter textures** (`TextureRegistry.SurfaceProducer` / `FlutterTexture`), never `PlatformView`,
   never raw frames over channels.
3. **Typed Flutter ⇄ native contract** generated by Pigeon (`packages/yuz_beauty_engine/pigeons/`).
4. **MediaPipe Face Landmarker** 1.0.0 on both platforms; one landmark topology → identical masks on Android and iOS.
5. **Own shaders** (GLSL ES 3.00 and Metal) with the *same* algorithm; GLSL is verified headlessly in CI via WebGL2.
6. **pro_image_editor** for the photo editor UI (adopted in Phase 3: crop/tune/text/stickers on top of our native
   full-resolution beauty render; its filter editor is disabled so colour grading stays in our LUT pipeline).

## Licenses of shipped dependencies (current)

| Component | License | Shipped in |
|---|---|---|
| Flutter / Dart SDK | BSD-3-Clause | app |
| flutter_riverpod 3.x | MIT | app |
| go_router 18.x | BSD-3-Clause | app |
| shared_preferences, path_provider | BSD-3-Clause | app |
| permission_handler 12.x | MIT | app |
| intl | BSD-3-Clause | app |
| image_picker 1.2.x | BSD-3-Clause | app |
| pro_image_editor 14.21.1 (+ material_ui, cupertino_ui) | BSD-3-Clause | app |
| gal 2.3.x | BSD-3-Clause | app |
| pigeon (dev only, generated code is ours) | BSD-3-Clause | build tool |
| androidx.camera (CameraX) | Apache-2.0 | Android |
| com.google.mediapipe:tasks-vision | Apache-2.0 | Android |
| MediaPipeTasksVision (CocoaPods) | Apache-2.0 | iOS |
| face_landmarker.task model | Apache-2.0 (model card – re-verify before release) | both |

Full notice texts: `LICENSES/THIRD_PARTY_NOTICES.md`.
