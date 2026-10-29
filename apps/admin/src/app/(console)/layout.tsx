import Link from 'next/link';
import type { ReactNode } from 'react';

import { logout } from '../session-actions';

// Every console page reads live data with the operator's session.
export const dynamic = 'force-dynamic';

export default function ConsoleLayout({ children }: { children: ReactNode }) {
  return (
    <div className="shell">
      <nav className="nav" aria-label="Main">
        <span className="brand">Yuz Admin</span>
        <Link href="/">Overview</Link>
        <Link href="/users">Users</Link>
        <Link href="/jobs">AI jobs</Link>
        <Link href="/audit">Audit log</Link>
        <form action={logout}>
          <button className="secondary" type="submit">
            Sign out
          </button>
        </form>
      </nav>
      <main>{children}</main>
    </div>
  );
}
