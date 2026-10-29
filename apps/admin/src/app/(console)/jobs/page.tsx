import Link from 'next/link';

import { api } from '@/lib/api';
import { formatDate } from '@/lib/format';
import { JOB_STATUSES, JOB_TYPES, type JobSummary } from '@/lib/types';

const PAGE = 50;

export default async function JobsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; type?: string; before?: string }>;
}) {
  const params = await searchParams;
  const status = JOB_STATUSES.find((s) => s === params.status);
  const type = JOB_TYPES.find((t) => t === params.type);
  const query = new URLSearchParams();
  if (status) query.set('status', status);
  if (type) query.set('type', type);
  if (params.before) query.set('before', params.before);
  const jobs = await api<JobSummary[]>(`/v1/admin/ai-jobs?${query}`);
  const next = new URLSearchParams(query);
  const last = jobs.at(-1);
  if (last) next.set('before', last.createdAt);

  return (
    <>
      <h1>AI jobs</h1>
      <form className="inline">
        <label>
          Status
          <select name="status" defaultValue={status ?? ''}>
            <option value="">Any</option>
            {JOB_STATUSES.map((s) => (
              <option key={s}>{s}</option>
            ))}
          </select>
        </label>
        <label>
          Type
          <select name="type" defaultValue={type ?? ''}>
            <option value="">Any</option>
            {JOB_TYPES.map((t) => (
              <option key={t}>{t}</option>
            ))}
          </select>
        </label>
        <button type="submit">Filter</button>
      </form>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Created</th>
              <th>User</th>
              <th>Type</th>
              <th>Status</th>
              <th className="num">Cost</th>
              <th>Finished</th>
              <th>Error</th>
            </tr>
          </thead>
          <tbody>
            {jobs.map((job) => (
              <tr key={job.id}>
                <td>{formatDate(job.createdAt)}</td>
                <td>{job.user ? <Link href={`/users/${job.user.id}`}>{job.user.email}</Link> : '—'}</td>
                <td>{job.type}</td>
                <td>
                  <span className={`badge ${job.status}`}>{job.status}</span>
                </td>
                <td className="num">{job.cost}</td>
                <td>{formatDate(job.finishedAt)}</td>
                <td className="muted">{job.error ?? '—'}</td>
              </tr>
            ))}
            {jobs.length === 0 && (
              <tr>
                <td colSpan={7} className="muted">
                  No jobs match.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      {jobs.length === PAGE && (
        <p className="pager">
          <Link href={`/jobs?${next}`}>Older jobs →</Link>
        </p>
      )}
    </>
  );
}
