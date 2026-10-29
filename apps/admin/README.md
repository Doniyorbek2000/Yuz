# Yuz admin panel

Back office for operators, built with Next.js 16 (App Router, server components and server actions):

- **Overview**: users, new sign-ups, AI jobs by status, and credit flows over the last 30 days.
- **Users**: search by email, name or id; open a profile with its ledger, AI jobs and consent.
- **Credit adjustments**: amount plus a reason the user can see. They are idempotent, so a
  double submit applies once, and each one is written to the audit log.
- **AI jobs**: filter by status and type, and see failure reasons.
- **Audit log**: role changes, credit adjustments and account deletions.

## Security model

- The browser never sees API tokens. They live in `httpOnly`, `SameSite=Strict` cookies that
  are `Secure` by default, and an admin session lasts at most 12 hours.
- Only accounts with the `ADMIN` role can sign in. The API checks the role from the database on
  every request, so revoking it takes effect immediately.
- There is no endpoint that grants the admin role. Use the API's CLI instead:
  `node dist/cli/set-role.js you@example.com ADMIN`, run inside the API container.
- The proxy (`src/proxy.ts`) refreshes access tokens. Concurrent requests share a single
  rotation per process. Run one instance, or put sticky sessions in front of it.
- Every page sends `X-Frame-Options: DENY`, `noindex` and `no-referrer`. Expose the panel only
  behind your VPN or an IP allow-list.

## Configuration

| Variable | Notes |
|---|---|
| `API_URL` | Yuz API base URL as seen from this server, e.g. `http://api:3000`. |
| `ADMIN_INSECURE_COOKIES` | `true` only for local plain-HTTP testing. |

## Development

```bash
npm ci
API_URL=http://localhost:3000 ADMIN_INSECURE_COOKIES=true npm run dev   # http://localhost:3001
npm run typecheck && npm run lint && npm test && npm run build
```
