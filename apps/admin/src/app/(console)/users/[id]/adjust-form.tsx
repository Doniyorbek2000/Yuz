'use client';

import { useActionState } from 'react';

import { adjustCredits, type AdjustState } from './actions';

export function AdjustCreditsForm({ userId, requestId }: { userId: string; requestId: string }) {
  const [state, action, pending] = useActionState<AdjustState, FormData>(adjustCredits.bind(null, userId), {});
  return (
    <form className="inline" action={action}>
      {state.ok && <p className="message ok">{state.ok}</p>}
      {state.error && <p className="message error">{state.error}</p>}
      {/* A new id is rendered after each applied change; resubmitting the same form applies once. */}
      <input type="hidden" name="requestId" value={requestId} />
      <label>
        Amount (+/-)
        <input
          name="amount"
          inputMode="numeric"
          required
          pattern="-?[0-9]{1,5}"
          size={8}
          defaultValue={state.amount}
        />
      </label>
      <label>
        Reason (shown to the user)
        <input name="reason" required minLength={3} maxLength={200} size={36} defaultValue={state.reason} />
      </label>
      <button type="submit" disabled={pending}>
        {pending ? 'Applying…' : 'Apply'}
      </button>
    </form>
  );
}
