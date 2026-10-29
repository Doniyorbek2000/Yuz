'use server';

import { revalidatePath } from 'next/cache';

import { api, ApiError } from '@/lib/api';
import { parseAdjustment } from '@/lib/format';

export interface AdjustState {
  ok?: string;
  error?: string;
  /** Submitted values, re-filled after an error. */
  amount?: string;
  reason?: string;
}

export async function adjustCredits(userId: string, _previous: AdjustState, form: FormData): Promise<AdjustState> {
  const amount = String(form.get('amount') ?? '');
  const reason = String(form.get('reason') ?? '');
  const parsed = parseAdjustment({ amount, reason, requestId: form.get('requestId') });
  if ('error' in parsed) return { error: parsed.error, amount, reason };
  try {
    const result = await api<{ balance: number; applied: boolean }>(
      `/v1/admin/users/${encodeURIComponent(userId)}/credits`,
      { method: 'POST', body: parsed },
    );
    revalidatePath(`/users/${userId}`);
    return {
      ok: result.applied
        ? `Applied. New balance: ${result.balance}.`
        : `Already applied earlier. Balance: ${result.balance}.`,
    };
  } catch (error) {
    if (error instanceof ApiError) {
      return {
        error: error.code === 'insufficient_credits' ? 'The balance cannot go below zero.' : error.message,
        amount,
        reason,
      };
    }
    throw error;
  }
}
