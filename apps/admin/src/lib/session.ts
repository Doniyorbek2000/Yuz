export const ACCESS_COOKIE = 'yuz_admin_at';
export const REFRESH_COOKIE = 'yuz_admin_rt';
export const EXPIRES_COOKIE = 'yuz_admin_exp';
export const SESSION_COOKIES = [ACCESS_COOKIE, REFRESH_COOKIE, EXPIRES_COOKIE] as const;

/** Admin sessions end after 12 hours regardless of the API's refresh-token lifetime. */
export const SESSION_MAX_AGE_SECONDS = 12 * 60 * 60;

/** Refresh this long before the access token expires. */
const REFRESH_MARGIN_MS = 30_000;

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresIn: number;
}

export interface CookieSpec {
  name: string;
  value: string;
  options: {
    httpOnly: true;
    secure: boolean;
    sameSite: 'strict';
    path: '/';
    maxAge: number;
  };
}

export function isTokenPair(value: unknown): value is TokenPair {
  if (typeof value !== 'object' || value === null) return false;
  const pair = value as Record<string, unknown>;
  return (
    typeof pair.accessToken === 'string' &&
    typeof pair.refreshToken === 'string' &&
    typeof pair.accessTokenExpiresIn === 'number'
  );
}

/** httpOnly + SameSite=Strict: scripts cannot read them and other sites cannot send them. */
export function sessionCookies(pair: TokenPair, secure: boolean, now = Date.now()): CookieSpec[] {
  const options = (maxAge: number) =>
    ({ httpOnly: true, secure, sameSite: 'strict', path: '/', maxAge }) as const;
  const expiresAt = now + pair.accessTokenExpiresIn * 1000;
  return [
    { name: ACCESS_COOKIE, value: pair.accessToken, options: options(pair.accessTokenExpiresIn) },
    { name: REFRESH_COOKIE, value: pair.refreshToken, options: options(SESSION_MAX_AGE_SECONDS) },
    { name: EXPIRES_COOKIE, value: String(expiresAt), options: options(SESSION_MAX_AGE_SECONDS) },
  ];
}

export function needsRefresh(expiresAt: number | undefined, now = Date.now()): boolean {
  return expiresAt === undefined || !Number.isFinite(expiresAt) || expiresAt - now < REFRESH_MARGIN_MS;
}

/**
 * Concurrent requests (parallel page loads, prefetches) with the same
 * refresh token share one rotation; rotating twice would look like token
 * theft to the API and revoke the session. Per server process.
 */
export class RefreshCoalescer {
  private readonly pending = new Map<string, { result: Promise<TokenPair | null>; at: number }>();
  private readonly rotate: (refreshToken: string) => Promise<TokenPair | null>;
  private readonly ttlMs: number;
  private readonly clock: () => number;

  constructor(
    rotate: (refreshToken: string) => Promise<TokenPair | null>,
    ttlMs = 15_000,
    clock: () => number = Date.now,
  ) {
    this.rotate = rotate;
    this.ttlMs = ttlMs;
    this.clock = clock;
  }

  refresh(refreshToken: string): Promise<TokenPair | null> {
    const now = this.clock();
    for (const [token, entry] of this.pending) {
      if (now - entry.at > this.ttlMs) this.pending.delete(token);
    }
    const existing = this.pending.get(refreshToken);
    if (existing) return existing.result;
    const result = this.rotate(refreshToken).catch(() => null);
    this.pending.set(refreshToken, { result, at: now });
    return result;
  }
}
