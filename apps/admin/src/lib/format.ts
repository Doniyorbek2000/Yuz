const dateTime = new Intl.DateTimeFormat('en-GB', {
  dateStyle: 'medium',
  timeStyle: 'short',
  timeZone: 'UTC',
});

/** UTC so every operator reads the same time. */
export function formatDate(value: string | null | undefined): string {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '—' : `${dateTime.format(date)} UTC`;
}

export function signed(amount: number): string {
  return amount > 0 ? `+${amount}` : String(amount);
}

/** Validates the credit adjustment form; returns an error message or the parsed values. */
export function parseAdjustment(form: {
  amount: unknown;
  reason: unknown;
  requestId: unknown;
}): { amount: number; reason: string; requestId: string } | { error: string } {
  const amountText = typeof form.amount === 'string' ? form.amount.trim() : '';
  if (!/^-?\d{1,5}$/.test(amountText)) return { error: 'Amount must be a whole number.' };
  const amount = Number(amountText);
  if (amount === 0 || Math.abs(amount) > 10_000) return { error: 'Amount must be between -10000 and 10000, not 0.' };
  const reason = typeof form.reason === 'string' ? form.reason.trim() : '';
  if (reason.length < 3 || reason.length > 200) return { error: 'Reason must be 3–200 characters.' };
  const requestId = typeof form.requestId === 'string' ? form.requestId : '';
  if (!/^[0-9a-f-]{36}$/i.test(requestId)) return { error: 'Reload the page and try again.' };
  return { amount, reason, requestId };
}
