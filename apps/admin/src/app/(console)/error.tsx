'use client';

export default function ConsoleError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div>
      <h1>Something went wrong</h1>
      <p className="message error">{error.message || 'The request failed.'}</p>
      <button type="button" onClick={reset}>
        Try again
      </button>
    </div>
  );
}
