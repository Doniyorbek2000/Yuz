'use server';

import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

import { publicCall } from '@/lib/api';
import { secureCookies } from '@/lib/config';
import { REFRESH_COOKIE, SESSION_COOKIES, sessionCookies, isTokenPair } from '@/lib/session';

export interface LoginState {
  error?: string;
  /** Re-filled after a failed attempt (React resets the form after an action). */
  email?: string;
}

export async function login(_previous: LoginState, form: FormData): Promise<LoginState> {
  const email = String(form.get('email') ?? '').trim();
  const password = String(form.get('password') ?? '');
  const failed = (error: string): LoginState => ({ error, email });
  if (!email || !password) return failed('Enter email and password.');

  let response: Response;
  try {
    response = await publicCall('/v1/auth/login', { email, password });
  } catch {
    return failed('The API cannot be reached.');
  }
  if (response.status === 401) return failed('Email or password is incorrect.');
  if (response.status === 429) return failed('Too many attempts. Wait a minute.');
  const pair: unknown = await response.json().catch(() => null);
  if (!response.ok || !isTokenPair(pair)) return failed('Sign-in failed. Try again.');

  const me = await publicCall('/v1/me', undefined, pair.accessToken);
  const profile = (await me.json().catch(() => null)) as { role?: string } | null;
  if (!me.ok || profile?.role !== 'ADMIN') {
    // Do not leave a session behind for a non-admin account.
    await publicCall('/v1/auth/logout', { refreshToken: pair.refreshToken }).catch(() => undefined);
    return failed('This account is not an administrator.');
  }

  const jar = await cookies();
  for (const cookie of sessionCookies(pair, secureCookies())) jar.set(cookie.name, cookie.value, cookie.options);
  redirect('/');
}

export async function logout(): Promise<void> {
  const jar = await cookies();
  const refreshToken = jar.get(REFRESH_COOKIE)?.value;
  if (refreshToken) await publicCall('/v1/auth/logout', { refreshToken }).catch(() => undefined);
  for (const name of SESSION_COOKIES) jar.delete(name);
  redirect('/login');
}
