import Link from 'next/link';

import { api } from '@/lib/api';
import { formatDate } from '@/lib/format';
import type { AuditEntry } from '@/lib/types';

const PAGE = 50;

export default async function AuditPage({ searchParams }: { searchParams: Promise<{ before?: string }> }) {
  const { before } = await searchParams;
  const entries = await api<AuditEntry[]>(`/v1/admin/audit${before ? `?before=${encodeURIComponent(before)}` : ''}`);
  const last = entries.at(-1);
  return (
    <>
      <h1>Audit log</h1>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>When</th>
              <th>Action</th>
              <th>Actor</th>
              <th>Target</th>
              <th>Details</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((entry) => (
              <tr key={entry.id}>
                <td>{formatDate(entry.createdAt)}</td>
                <td>{entry.action}</td>
                <td>{entry.actorId ? <Link href={`/users/${entry.actorId}`}>{entry.actorId.slice(0, 8)}</Link> : 'system'}</td>
                <td>{entry.targetId ? <code>{entry.targetId.slice(0, 8)}</code> : '—'}</td>
                <td className="muted">
                  <code>{JSON.stringify(entry.details)}</code>
                </td>
              </tr>
            ))}
            {entries.length === 0 && (
              <tr>
                <td colSpan={5} className="muted">
                  Nothing recorded yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      {entries.length === PAGE && last && (
        <p className="pager">
          <Link href={`/audit?before=${encodeURIComponent(last.createdAt)}`}>Older entries →</Link>
        </p>
      )}
    </>
  );
}
