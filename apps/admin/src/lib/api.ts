import 'server-only';

import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

import { apiUrl } from './config.ts';
import { ACCESS_COOKIE } from './session.ts';

export class ApiError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

async function errorFrom(response: Response): Promise<ApiError> {
  let code = `http_${response.status}`;
  let message = response.statusText || 'Request failed';
  try {
    const body = (await response.json()) as { code?: unknown; message?: unknown };
    if (typeof body.code === 'string') code = body.code;
    if (typeof body.message === 'string') message = body.message;
    else if (Array.isArray(body.message)) message = body.message.join('; ');
  } catch {
    // Not JSON (proxy error page).
  }
  return new ApiError(response.status, code, message);
}

/** Calls the API without a session (login, logout). */
export async function publicCall(path: string, body: unknown, accessToken?: string): Promise<Response> {
  return fetch(`${apiUrl()}${path}`, {
    method: body === undefined ? 'GET' : 'POST',
    headers: {
      Accept: 'application/json',
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
      ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
    cache: 'no-store',
  });
}

/** Calls the API as the signed-in admin. A rejected session goes back to login. */
export async function api<T>(path: string, init: { method?: 'GET' | 'POST'; body?: unknown } = {}): Promise<T> {
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  if (!token) redirect('/login');
  const response = await fetch(`${apiUrl()}${path}`, {
    method: init.method ?? 'GET',
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${token}`,
      ...(init.body === undefined ? {} : { 'Content-Type': 'application/json' }),
    },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
    cache: 'no-store',
  });
  if (response.status === 401) redirect('/login?expired=1');
  if (!response.ok) throw await errorFrom(response);
  return (await response.json()) as T;
}
