# Yuz API (`apps/backend`)

NestJS 11 · Prisma 7 (PostgreSQL 16) · BullMQ 6 (Redis 7) · Node 22.

## What it does

| Area | Endpoints | Notes |
|---|---|---|
| Auth | `POST /v1/auth/register·login·refresh·logout` | argon2id; 15 min HS256 access JWT; opaque refresh tokens stored hashed, rotated on every use, a replayed token revokes the whole login family; per-client rate limit |
| Account | `GET·PATCH·DELETE /v1/me`, `GET /v1/me/export` | deletion needs the password, removes every row and file of the user (purchases are kept anonymized for accounting); JSON export of all stored data |
| Consent | `GET /v1/consents`, `POST·DELETE /v1/consents/cloud-ai` | versioned cloud-AI consent; revoking cancels and refunds queued jobs |
| Credits | `GET /v1/credits` | ledger + cached balance changed in one transaction; spends are conditional updates (no overdraw under concurrency); idempotency keys |
| AI jobs | `POST /v1/ai-jobs` (multipart `image`), `GET /v1/ai-jobs[/:id[/result]]`, `DELETE /v1/ai-jobs/:id`, `GET /v1/ai-jobs/pricing` | consent + credits checked; image type from magic bytes; upload deleted when processing ends; results purged after `RESULT_RETENTION_DAYS` |
| Worker API | `POST /internal/ai-jobs/:id/start·complete·fail` | shared `WORKER_TOKEN` (constant-time check); failures refund exactly once |
| Purchases | `GET /v1/products`, `POST /v1/purchases/verify` | server-side verification, one grant per store transaction; **store verifiers are not configured** (App Store / Google Play credentials needed) → `503 store_verification_unavailable` |
| Health | `GET /health` | database + queue, 503 when degraded |

Errors are `{ statusCode, code, message }`; the app localizes `code`. OpenAPI UI at `/docs` outside production.

## Develop

```bash
npm ci
cp ../../.env.example .env      # fill JWT_SECRET, WORKER_TOKEN (openssl rand -hex 32)
npx prisma migrate deploy && npx prisma generate
npm run start:dev
```

## Test

The e2e suites boot the real application against PostgreSQL and Redis (CI runs them as services):

```bash
DATABASE_URL=postgresql://user:pass@localhost:5432/yuz_test REDIS_URL=redis://localhost:6379/15 npm test
npm run typecheck && npm run lint && npm run format:check
```

## Deploy

`deploy/docker-compose.yml` runs Postgres, Redis, a one-off migration job and the API (non-root, health-checked).
TLS termination belongs to a reverse proxy in front of it; production deployment needs the owner's approval.
