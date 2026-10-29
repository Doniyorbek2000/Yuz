import assert from 'node:assert/strict';
import { test } from 'node:test';

import { NextRequest } from 'next/server.js';

import { ACCESS_COOKIE, EXPIRES_COOKIE, REFRESH_COOKIE, RefreshCoalescer, type TokenPair } from './lib/session.ts';
import { handleSession } from './proxy.ts';

process.env.API_URL = 'https://api.test';

function request(path: string, cookies: Record<string, string> = {}): NextRequest {
  const header = Object.entries(cookies)
    .map(([name, value]) => `${name}=${value}`)
    .join('; ');
  return new NextRequest(`https://admin.test${path}`, { headers: header ? { cookie: header } : {} });
}

const fresh: TokenPair = { accessToken: 'a2', refreshToken: 'r2', accessTokenExpiresIn: 900 };

test('pages without a session go to login', async () => {
  const response = await handleSession(request('/users'), new RefreshCoalescer(async () => fresh));
  assert.equal(response.status, 307);
  assert.equal(new URL(response.headers.get('location')!).pathname, '/login');
});

test('the login page itself is always reachable', async () => {
  const response = await handleSession(request('/login'), new RefreshCoalescer(async () => null));
  assert.equal(response.headers.get('location'), null);
});

test('a valid access token passes through without refreshing', async () => {
  let rotated = false;
  const response = await handleSession(
    request('/', {
      [ACCESS_COOKIE]: 'a1',
      [REFRESH_COOKIE]: 'r1',
      [EXPIRES_COOKIE]: String(Date.now() + 600_000),
    }),
    new RefreshCoalescer(async () => {
      rotated = true;
      return fresh;
    }),
  );
  assert.equal(rotated, false);
  assert.equal(response.headers.get('location'), null);
});

test('an expiring token is rotated and the new cookies are set', async () => {
  const response = await handleSession(
    request('/', { [ACCESS_COOKIE]: 'a1', [REFRESH_COOKIE]: 'r1', [EXPIRES_COOKIE]: String(Date.now() + 1_000) }),
    new RefreshCoalescer(async (token) => (token === 'r1' ? fresh : null)),
  );
  assert.equal(response.headers.get('location'), null);
  assert.equal(response.cookies.get(ACCESS_COOKIE)?.value, 'a2');
  assert.equal(response.cookies.get(REFRESH_COOKIE)?.value, 'r2');
  assert.equal(response.cookies.get(ACCESS_COOKIE)?.httpOnly, true);
  // Server components of this same request see the new access token.
  assert.match(response.headers.get('x-middleware-request-cookie') ?? '', /a2/);
});

test('a rejected refresh clears the session and explains it', async () => {
  const response = await handleSession(
    request('/jobs', { [REFRESH_COOKIE]: 'revoked' }),
    new RefreshCoalescer(async () => null),
  );
  const location = new URL(response.headers.get('location')!);
  assert.equal(location.pathname, '/login');
  assert.equal(location.searchParams.get('expired'), '1');
  assert.equal(response.cookies.get(REFRESH_COOKIE)?.value, '');
});
