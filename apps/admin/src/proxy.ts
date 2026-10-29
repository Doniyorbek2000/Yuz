import { type NextRequest, NextResponse } from 'next/server.js';

import { apiUrl, secureCookies } from './lib/config.ts';
import {
  ACCESS_COOKIE,
  EXPIRES_COOKIE,
  isTokenPair,
  needsRefresh,
  REFRESH_COOKIE,
  RefreshCoalescer,
  SESSION_COOKIES,
  sessionCookies,
  type TokenPair,
} from './lib/session.ts';

async function rotate(refreshToken: string): Promise<TokenPair | null> {
  const response = await fetch(`${apiUrl()}/v1/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({ refreshToken }),
    cache: 'no-store',
  });
  if (!response.ok) return null;
  const body: unknown = await response.json();
  return isTokenPair(body) ? body : null;
}

const coalescer = new RefreshCoalescer(rotate);

function toLogin(request: NextRequest, expired: boolean): NextResponse {
  const url = request.nextUrl.clone();
  url.pathname = '/login';
  url.search = expired ? '?expired=1' : '';
  const response = NextResponse.redirect(url);
  for (const name of SESSION_COOKIES) response.cookies.delete(name);
  return response;
}

/**
 * Every page except /login needs a session. An access token about to
 * expire is refreshed here, and the new one is handed to this request's
 * server components as well as stored in the browser.
 */
export async function handleSession(request: NextRequest, refresher: RefreshCoalescer): Promise<NextResponse> {
  if (request.nextUrl.pathname === '/login') return NextResponse.next();
  const refreshToken = request.cookies.get(REFRESH_COOKIE)?.value;
  if (!refreshToken) return toLogin(request, false);
  const expiresAt = Number(request.cookies.get(EXPIRES_COOKIE)?.value);
  if (request.cookies.get(ACCESS_COOKIE) && !needsRefresh(expiresAt)) return NextResponse.next();

  const pair = await refresher.refresh(refreshToken);
  if (!pair) return toLogin(request, true);
  const cookies = sessionCookies(pair, secureCookies());
  for (const cookie of cookies) request.cookies.set(cookie.name, cookie.value);
  const response = NextResponse.next({ request: { headers: request.headers } });
  for (const cookie of cookies) response.cookies.set(cookie.name, cookie.value, cookie.options);
  return response;
}

export function proxy(request: NextRequest): Promise<NextResponse> {
  return handleSession(request, coalescer);
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
