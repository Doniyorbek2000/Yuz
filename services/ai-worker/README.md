# Yuz AI worker

Consumes the `yuz-ai-jobs` BullMQ queue that the API (`apps/backend`) fills and
runs each job through a provider. For every job it:

1. claims the job with `POST /internal/ai-jobs/:id/start` (a job that was
   cancelled meanwhile is skipped),
2. reads the upload from the storage volume it shares with the API,
3. runs the provider off the event loop,
4. writes `{outputPrefix}/result.{png|jpg}` atomically, then reports
   `complete`. Any failure is reported with `fail`, and the API refunds the
   credits.

## Providers

| Job type | Provider | Status |
|---|---|---|
| `BACKGROUND` | MediaPipe selfie segmenter on CPU; modes `blur`, `color` (`#RRGGBB`), `remove` (transparent PNG) | IMPLEMENTED + TESTED |
| `PHOTOSHOOT`, `HAIRSTYLE`, `MAKEUP` | — | BLOCKED: these need a generative model, meaning a paid API or a GPU. They wait on the owner's approval. |

The API only accepts the job types listed in `AI_ENABLED_TYPES`, which
defaults to `BACKGROUND`. Until a worker serves a type, the API answers it
with `503 ai_type_unavailable` and charges nothing.

## Configuration

| Variable | Default | Notes |
|---|---|---|
| `WORKER_TOKEN` | — | Required. At least 32 characters, and must match the API. |
| `API_URL` | `http://localhost:3000` | |
| `REDIS_URL` | `redis://localhost:6379/0` | Must be the same Redis the API uses. |
| `STORAGE_DIR` | `./storage` | The volume shared with the API. |
| `MODEL_DIR` | `./models` | The Docker image sets this to `/opt/yuz/models`. |
| `CONCURRENCY` | `2` | 1..16 |
| `MAX_PIXELS` | `24000000` | Larger photos fail with `invalid_input:image_too_large`. |

## Development

```bash
python3.13 -m venv .venv && . .venv/bin/activate
pip install -r requirements.lock -e '.[dev]'
../../tools/fetch_models.sh segmenter      # verified against tools/models.sha256
ruff check . && ruff format --check .
TEST_REDIS_URL=redis://localhost:6379/0 pytest
```

Without `TEST_REDIS_URL`, the queue round-trip test is skipped. Without the
model file, the real-model test is skipped.
