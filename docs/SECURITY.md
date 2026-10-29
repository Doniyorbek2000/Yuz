# Security & Privacy

## On the device

- Camera frames, landmarks and every beauty, retouch, filter, template and video effect run on the device. Nothing
  is uploaded for them.
- Captures and projects are written to app-private storage, and preferences to `shared_preferences`.
- The app talks only to the API configured at build time (`--dart-define=YUZ_API_URL`). Release builds accept
  HTTPS only. Plain HTTP works only in debug builds, and only for local hosts (Android network security config for
  debug, iOS `NSAllowsLocalNetworking`). Builds without an API have no account or cloud features and say so.
- Session tokens are stored in the iOS Keychain (after first unlock, never synced to other devices) and in
  Android Keystore-backed storage. They are excluded from Android cloud backup and device transfer, because a
  restored copy could not be decrypted. The access token is refreshed once for all concurrent calls. When the
  refresh token is rejected, the local session is cleared.
- The permission flow only continues to an allow-listed route. Arbitrary `next=` targets are rejected.
- The MediaPipe models are downloaded from Google's official bucket and verified against pinned SHA-256 values in
  `tools/models.sha256` before they are bundled or baked into the worker image.

## Cloud AI

- **Consent first.** The API refuses uploads (`403 consent_required`) until the user accepts the current version of
  the consent text on a dedicated screen. That screen explains what is uploaded, when it is deleted, and that photos
  must show only the user or people who agreed. Changing the text version requires consent again. Revoking consent
  cancels queued jobs, refunds them and deletes their uploads.
- **Only what is needed.** The app uploads only the photo the user chose, re-encoded to a JPEG of at most 2560 px.
  The API checks the file type by its magic bytes and enforces a size limit before it charges credits.
- **Short-lived data.** The uploaded photo is deleted as soon as the job succeeds, fails or is cancelled. The app
  deletes the result from the server once it is downloaded. Anything left over is purged after
  `RESULT_RETENTION_DAYS` (7 days by default). Deleting the account deletes every file.
- **Ownership.** Every job and result lookup is scoped to its owner, and other users get `404`. Storage keys are
  resolved inside the storage root, and keys that escape it are rejected by both the API and the worker.
- **Worker isolation.** The worker authenticates to a separate internal API with a shared token (at least 32
  characters) and never sees user tokens. It runs as a non-root container and limits image size (`MAX_PIXELS`).
  Failures are reported as codes, never stack traces.
- **No training.** Photos are used only to produce the user's result.

## Accounts and API

- Passwords are hashed with argon2id. Unknown emails and wrong passwords return the same error after the same
  amount of work.
- Access tokens are short-lived JWTs (15 minutes by default). Refresh tokens are random, stored only as hashes,
  rotated on every use, and reuse of a rotated token revokes the whole login family. Auth endpoints are
  rate-limited.
- The current database row decides access on every request, so deleting an account or changing a role takes
  effect immediately.
- Account deletion needs the password again. Purchases are kept anonymized, because stores and tax law require
  them. Data export returns everything stored about the user except the password hash.
- Credits use a ledger. Every change writes one row and updates the balance in the same transaction. Spends are
  conditional, so the balance never goes negative, and idempotency keys make retries harmless.
- Store purchases are never trusted from the client. They are verified server-side with the store APIs, which
  remain BLOCKED until credentials exist; until then the API answers 503.
- Logs carry IDs and error codes. They never contain tokens, emails, passwords or images.

## Admin panel

- Only `ADMIN` accounts can sign in. The role is granted by a CLI run next to the database; there is no HTTP
  endpoint that grants it.
- The browser never sees tokens. They live in `httpOnly`, `SameSite=Strict` cookies that are `Secure` by default,
  and a session lasts at most 12 hours. Server actions add Next.js's built-in origin check.
- Credit adjustments need a reason, are idempotent per form render, and are written to the audit log together with
  role changes and account deletions.
- Every page sends `X-Frame-Options: DENY`, `noindex` and `no-referrer`. The compose stack binds the panel to
  loopback; reach it through a VPN or an SSH tunnel.

## Repository hygiene

- `.env*` files, keystores, `key.properties`, provisioning profiles, model binaries and Redis dumps are
  git-ignored.
- CI fails if such files are tracked, runs gitleaks over the full history, and runs `npm audit` for the API and
  the admin panel.
- Signing material is injected only from GitHub secrets at build time (see RELEASE_SIGNING.md).
