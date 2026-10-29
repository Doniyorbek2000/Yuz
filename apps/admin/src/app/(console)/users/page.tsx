import Link from 'next/link';

import { api } from '@/lib/api';
import { formatDate } from '@/lib/format';
import type { UserSummary } from '@/lib/types';

const PAGE = 50;

export default async function UsersPage({ searchParams }: { searchParams: Promise<{ q?: string; before?: string }> }) {
  const { q = '', before } = await searchParams;
  const query = new URLSearchParams();
  if (q) query.set('q', q);
  if (before) query.set('before', before);
  const users = await api<UserSummary[]>(`/v1/admin/users?${query}`);
  const last = users.at(-1);
  const next = new URLSearchParams(q ? { q } : {});
  if (last) next.set('before', last.createdAt);

  return (
    <>
      <h1>Users</h1>
      <form className="inline" role="search">
        <label>
          Email, name or id
          <input name="q" defaultValue={q} maxLength={100} placeholder="dilnoza@example.com" />
        </label>
        <button type="submit">Search</button>
      </form>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Email</th>
              <th>Name</th>
              <th>Role</th>
              <th className="num">Credits</th>
              <th>Premium until</th>
              <th>Joined</th>
            </tr>
          </thead>
          <tbody>
            {users.map((user) => (
              <tr key={user.id}>
                <td>
                  <Link href={`/users/${user.id}`}>{user.email}</Link>
                </td>
                <td>{user.displayName ?? <span className="muted">—</span>}</td>
                <td>
                  <span className={`badge ${user.role}`}>{user.role}</span>
                </td>
                <td className="num">{user.creditBalance}</td>
                <td>{formatDate(user.premiumUntil)}</td>
                <td>{formatDate(user.createdAt)}</td>
              </tr>
            ))}
            {users.length === 0 && (
              <tr>
                <td colSpan={6} className="muted">
                  No users found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      {users.length === PAGE && (
        <p className="pager">
          <Link href={`/users?${next}`}>Older users →</Link>
        </p>
      )}
    </>
  );
}
