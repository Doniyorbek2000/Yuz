import { api } from '@/lib/api';
import { JOB_STATUSES, type Stats } from '@/lib/types';

export default async function OverviewPage() {
  const stats = await api<Stats>('/v1/admin/stats');
  const credit = (kind: string) => stats.credits30Days[kind] ?? 0;
  const cards: [string, number][] = [
    ['Users', stats.users.total],
    ['New users (7 days)', stats.users.last7Days],
    ['AI jobs (24 h)', stats.aiJobs.last24Hours],
    ['Store purchases', stats.purchases.total],
  ];
  return (
    <>
      <h1>Overview</h1>
      <div className="cards">
        {cards.map(([label, value]) => (
          <div className="card" key={label}>
            <div className="label">{label}</div>
            <div className="value">{value}</div>
          </div>
        ))}
      </div>

      <h2>AI jobs by status</h2>
      <div className="cards">
        {JOB_STATUSES.map((status) => (
          <div className="card" key={status}>
            <div className="label">
              <span className={`badge ${status}`}>{status}</span>
            </div>
            <div className="value">{stats.aiJobs.byStatus[status] ?? 0}</div>
          </div>
        ))}
      </div>

      <h2>Credits, last 30 days</h2>
      <div className="cards">
        {[
          ['Welcome grants', credit('WELCOME')],
          ['Purchased', credit('PURCHASE')],
          ['Spent on AI', -credit('SPEND')],
          ['Refunded', credit('REFUND')],
          ['Manual adjustments', credit('ADJUSTMENT')],
        ].map(([label, value]) => (
          <div className="card" key={label}>
            <div className="label">{label}</div>
            <div className="value">{value}</div>
          </div>
        ))}
      </div>
    </>
  );
}
