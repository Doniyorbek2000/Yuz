'use client';

import { useActionState } from 'react';

import { login, type LoginState } from '../session-actions';

export function LoginForm() {
  const [state, action, pending] = useActionState<LoginState, FormData>(login, {});
  return (
    <form action={action} className="login" style={{ margin: 0 }}>
      {state.error && (
        <p className="message error" role="alert">
          {state.error}
        </p>
      )}
      <label>
        Email
        <input name="email" type="email" autoComplete="username" required defaultValue={state.email} />
      </label>
      <label>
        Password
        <input name="password" type="password" autoComplete="current-password" required />
      </label>
      <button type="submit" disabled={pending}>
        {pending ? 'Signing in…' : 'Sign in'}
      </button>
    </form>
  );
}
