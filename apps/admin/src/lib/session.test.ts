import assert from 'node:assert/strict';
import { test } from 'node:test';

import { apiUrl, secureCookies } from './config.ts';
import { parseAdjustment, signed } from './format.ts';
import {
  ACCESS_COOKIE,
  needsRefresh,
  REFRESH_COOKIE,
  RefreshCoalescer,
  SESSION_MAX_AGE_SECONDS,
  sessionCookies,
  type TokenPair,
} from './session.ts';

const pair: TokenPair = { accessToken: 'a1', refreshToken: 'r1', accessTokenExpiresIn: 900 };

test('session cookies are httpOnly, strict and bounded', () => {
  const cookies = sessionCookies(pair, true, 1_000);
  assert.equal(cookies.length, 3);
  for (const cookie of cookies) {
    assert.equal(cookie.options.httpOnly, true);
    assert.equal(cookie.options.sameSite, 'strict');
    assert.equal(cookie.options.secure, true);
  }
  assert.equal(cookies.find((c) => c.name === ACCESS_COOKIE)?.options.maxAge, 900);
  assert.equal(cookies.find((c) => c.name === REFRESH_COOKIE)?.options.maxAge, SESSION_MAX_AGE_SECONDS);
  assert.equal(cookies.at(-1)?.value, String(1_000 + 900_000));
});

test('refreshes shortly before expiry or when the expiry is unknown', () => {
  assert.equal(needsRefresh(undefined, 0), true);
  assert.equal(needsRefresh(Number.NaN, 0), true);
  assert.equal(needsRefresh(60_000, 0), false);
  assert.equal(needsRefresh(20_000, 0), true);
});

test('concurrent refreshes of one token rotate it once', async () => {
  let calls = 0;
  let now = 0;
  const coalescer = new RefreshCoalescer(
    async (token) => {
      calls++;
      return { ...pair, refreshToken: `${token}-next` };
    },
    15_000,
    () => now,
  );
  const [a, b] = await Promise.all([coalescer.refresh('r1'), coalescer.refresh('r1')]);
  assert.equal(calls, 1);
  assert.deepEqual(a, b);
  now = 20_000;
  await coalescer.refresh('r1');
  assert.equal(calls, 2);
});

test('a failing rotation resolves to null instead of throwing', async () => {
  const coalescer = new RefreshCoalescer(async () => {
    throw new Error('network');
  });
  assert.equal(await coalescer.refresh('r1'), null);
});

test('validates credit adjustments', () => {
  const requestId = '0b6c1f0e-6f53-4a7e-9d8f-1f2a3b4c5d6e';
  assert.deepEqual(parseAdjustment({ amount: ' -5 ', reason: ' Chargeback ', requestId }), {
    amount: -5,
    reason: 'Chargeback',
    requestId,
  });
  for (const amount of ['0', '1.5', 'abc', '20000', '']) {
    assert.ok('error' in parseAdjustment({ amount, reason: 'Goodwill', requestId }), amount);
  }
  assert.ok('error' in parseAdjustment({ amount: '5', reason: 'x', requestId }));
  assert.ok('error' in parseAdjustment({ amount: '5', reason: 'Goodwill', requestId: 'nope' }));
  assert.equal(signed(3), '+3');
  assert.equal(signed(-3), '-3');
});

test('API URL and cookie security come from the environment', () => {
  assert.equal(apiUrl({ API_URL: 'https://api.yuz.app/' }), 'https://api.yuz.app');
  assert.throws(() => apiUrl({}));
  assert.throws(() => apiUrl({ API_URL: 'ftp://x' }));
  assert.equal(secureCookies({}), true);
  assert.equal(secureCookies({ ADMIN_INSECURE_COOKIES: 'true' }), false);
});
