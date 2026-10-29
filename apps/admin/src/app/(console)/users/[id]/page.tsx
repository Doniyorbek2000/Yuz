import { randomUUID } from 'node:crypto';

import Link from 'next/link';
import { notFound } from 'next/navigation';

import { api, ApiError } from '@/lib/api';
import { formatDate, signed } from '@/lib/format';
import type { UserDetail } from '@/lib/types';

import { AdjustCreditsForm } from './adjust-form';

async function load(id: string): Promise<UserDetail> {
  try {
    return await api<UserDetail>(`/v1/admin/users/${encodeURIComponent(id)}`);
  } catch (error) {
    if (error instanceof ApiError && (error.status === 404 || error.status === 400)) notFound();
    throw error;
  }
}

export default async function UserPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const user = await load(id);
  const consent = user.consents.find((c) => c.kind === 'CLOUD_AI' && !c.revokedAt);
  return (
    <>
      <p>
        <Link href="/users">← Users</Link>
      </p>
      <h1>{user.email}</h1>
      <dl className="facts">
        <dt>Name</dt>
        <dd>{user.displayName ?? '—'}</dd>
        <dt>Id</dt>
        <dd>
          <code>{user.id}</code>
        </dd>
        <dt>Role</dt>
        <dd>
          <span className={`badge ${user.role}`}>{user.role}</span>
        </dd>
        <dt>Language</dt>
        <dd>{user.locale}</dd>
        <dt>Credits</dt>
        <dd>{user.creditBalance}</dd>
        <dt>Premium until</dt>
        <dd>{formatDate(user.premiumUntil)}</dd>
        <dt>Cloud AI consent</dt>
        <dd>{consent ? `Granted ${formatDate(consent.grantedAt)} (v${consent.version})` : 'Not granted'}</dd>
        <dt>Joined</dt>
        <dd>{formatDate(user.createdAt)}</dd>
      </dl>

      <h2>Adjust credits</h2>
      <AdjustCreditsForm userId={user.id} requestId={randomUUID()} />

      <h2>Credit ledger (latest 20)</h2>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>When</th>
              <th>Kind</th>
              <th className="num">Amount</th>
              <th>Reference</th>
            </tr>
          </thead>
          <tbody>
            {user.credits.map((entry) => (
              <tr key={entry.id}>
                <td>{formatDate(entry.createdAt)}</td>
                <td>{entry.kind}</td>
                <td className="num">{signed(entry.amount)}</td>
                <td className="muted">{entry.reference ?? '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <h2>AI jobs (latest 20)</h2>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Created</th>
              <th>Type</th>
              <th>Status</th>
              <th className="num">Cost</th>
              <th>Error</th>
            </tr>
          </thead>
          <tbody>
            {user.aiJobs.map((job) => (
              <tr key={job.id}>
                <td>{formatDate(job.createdAt)}</td>
                <td>{job.type}</td>
                <td>
                  <span className={`badge ${job.status}`}>{job.status}</span>
                </td>
                <td className="num">{job.cost}</td>
                <td className="muted">{job.error ?? '—'}</td>
              </tr>
            ))}
            {user.aiJobs.length === 0 && (
              <tr>
                <td colSpan={5} className="muted">
                  No AI jobs.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
