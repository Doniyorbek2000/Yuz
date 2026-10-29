/** Base URL of the Yuz API as seen from this server (never exposed to browsers). */
export function apiUrl(env: Record<string, string | undefined> = process.env): string {
  const raw = env.API_URL?.trim();
  if (!raw) throw new Error('API_URL is not set');
  const url = new URL(raw);
  if (url.protocol !== 'https:' && url.protocol !== 'http:') throw new Error('API_URL must be http(s)');
  return url.toString().replace(/\/$/, '');
}

/** Cookies are Secure unless explicitly running over plain HTTP locally. */
export function secureCookies(env: Record<string, string | undefined> = process.env): boolean {
  return env.ADMIN_INSECURE_COOKIES !== 'true';
}
