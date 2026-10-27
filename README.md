# Yuz — AI Beauty Camera & Editor

Flutter app (Android + iOS) with a native real-time beauty engine. Original brand, design and code.

| Document | Purpose |
|---|---|
| [PROGRESS.md](PROGRESS.md) | Phase log, verification results, next step |
| [FEATURE_MATRIX.md](FEATURE_MATRIX.md) | Honest status of every feature |
| [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) | What is not verified / not done |
| [OPEN_SOURCE_AUDIT.md](OPEN_SOURCE_AUDIT.md) | Audit of reference repositories and integration decisions |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Pipeline and code structure |
| [docs/SECURITY.md](docs/SECURITY.md) | Security & privacy design |
| [docs/RELEASE_SIGNING.md](docs/RELEASE_SIGNING.md) | Android / iOS signing setup |
| [LICENSES/THIRD_PARTY_NOTICES.md](LICENSES/THIRD_PARTY_NOTICES.md) | Third-party licenses |

## Requirements

- Flutter 3.47.8 (Dart 3.13.7), JDK 17, Android SDK 36 (min SDK 24, GLES 3.0)
- Xcode with iOS 15.0+ deployment target, CocoaPods
- Node 22 (shader tests only)

## Setup

```bash
./tools/fetch_models.sh                 # downloads + verifies face_landmarker.task
cd apps/mobile
flutter pub get
flutter run                             # real device required for the camera
```

## Checks

```bash
# engine package
cd packages/yuz_beauty_engine && flutter analyze && flutter test
# app
cd apps/mobile && flutter analyze && flutter test
# shipped GLSL shaders in headless WebGL2
cd tools/shader-tests && npm ci && npx playwright install chromium && npm test
# Kotlin engine unit tests (after `flutter build apk --config-only` in apps/mobile)
cd apps/mobile/android && ./gradlew :yuz_beauty_engine:testDebugUnitTest
# on-device flow + measured FPS
cd apps/mobile && flutter test integration_test/camera_flow_test.dart -d <device>
```

Regenerate the platform API after editing `packages/yuz_beauty_engine/pigeons/beauty_engine_api.dart`:
`dart run pigeon --input pigeons/beauty_engine_api.dart`.
