# Security & Privacy

## Current build (on-device only)

- Camera frames, landmarks and beauty processing never leave the device; the app has no network calls.
- Captures are written to app-private storage (`getApplicationDocumentsDirectory()/captures`).
- Preferences (language, presets, last look) are stored with `shared_preferences`; no personal data.
- The permission flow only continues to an allow-listed route (`/home`, `/camera`); arbitrary `next=` targets are
  rejected (widget-tested).
- The face model is downloaded from Google's official bucket and verified against a pinned SHA-256
  (`tools/models.sha256`) before it is bundled.
- iOS privacy manifest is bundled with the engine pod; `NSCameraUsageDescription` states on-device processing.

## Repository hygiene

- `.env*`, keystores, `key.properties`, provisioning profiles and model binaries are git-ignored.
- CI fails if such files are tracked and runs gitleaks over the full history.
- Signing material is only injected from GitHub secrets at build time (see RELEASE_SIGNING.md).

## Requirements for upcoming phases

- Cloud AI: explicit per-upload consent, "only my face or people who consented" attestation, signed short-lived
  upload URLs, server-side ownership checks, retention limits, deletion on account removal.
- Auth: short-lived access tokens, rotating refresh tokens with reuse detection, rate limiting.
- Logs: redact tokens, emails and media URLs.
