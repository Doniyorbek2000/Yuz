# Yuz — AI Beauty Camera & Editor

Flutter app (Android + iOS) with a native real-time beauty engine, plus the server side for accounts and cloud AI.
Original brand, design and code.

| Component | Path |
|---|---|
| Mobile app (Flutter) | `apps/mobile` |
| Native beauty engine (Kotlin CameraX + GLES, Swift AVFoundation + Metal, MediaPipe) | `packages/yuz_beauty_engine` |
| API (NestJS, Prisma/PostgreSQL, BullMQ/Redis) | [`apps/backend`](apps/backend/README.md) |
| AI worker (Python, MediaPipe) | [`services/ai-worker`](services/ai-worker/README.md) |
| Admin panel (Next.js) | [`apps/admin`](apps/admin/README.md) |
| Local/single-host stack | `deploy/docker-compose.yml` |

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
- Node 22 (API, admin panel, shader tests), Python 3.13 (AI worker), PostgreSQL 16 + Redis 7 (or Docker)

## Setup

```bash
./tools/fetch_models.sh                 # downloads + verifies the MediaPipe models
cd apps/mobile
flutter pub get
flutter run                             # real device required for the camera
# accounts and cloud AI: point the app at an API (HTTPS; plain HTTP only in debug for local hosts)
flutter run --dart-define=YUZ_API_URL=http://10.0.2.2:3000
```

Server stack: copy `deploy/.env.example` to `deploy/.env`, fill every secret, then
`docker compose -f deploy/docker-compose.yml --env-file deploy/.env up --build`; grant the first admin with
`docker compose -f deploy/docker-compose.yml exec api node dist/cli/set-role.js you@example.com ADMIN`.

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
# API e2e (needs Postgres + Redis), AI worker, admin panel
cd apps/backend && npm ci && npm test
cd services/ai-worker && pip install -r requirements.lock -e '.[dev]' && pytest
cd apps/admin && npm ci && npm run typecheck && npm run lint && npm test && npm run build
# on-device flow + measured FPS
cd apps/mobile && flutter test integration_test/camera_flow_test.dart -d <device>
```

Regenerate the platform API after editing `packages/yuz_beauty_engine/pigeons/beauty_engine_api.dart`:
`dart run pigeon --input pigeons/beauty_engine_api.dart`.
