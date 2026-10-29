import Link from 'next/link';

export default function NotFound() {
  return (
    <main className="login">
      <h1>Not found</h1>
      <p className="muted">This page or record does not exist.</p>
      <Link href="/">Back to overview</Link>
    </main>
  );
}
