export type Role = 'USER' | 'ADMIN';
export type AiJobStatus = 'QUEUED' | 'RUNNING' | 'SUCCEEDED' | 'FAILED' | 'CANCELLED';
export type AiJobType = 'PHOTOSHOOT' | 'HAIRSTYLE' | 'MAKEUP' | 'BACKGROUND';

export const JOB_STATUSES: readonly AiJobStatus[] = ['QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED'];
export const JOB_TYPES: readonly AiJobType[] = ['PHOTOSHOOT', 'HAIRSTYLE', 'MAKEUP', 'BACKGROUND'];

export interface Stats {
  users: { total: number; last7Days: number };
  aiJobs: { last24Hours: number; byStatus: Partial<Record<AiJobStatus, number>> };
  credits30Days: Partial<Record<string, number>>;
  purchases: { total: number };
}

export interface UserSummary {
  id: string;
  email: string;
  displayName: string | null;
  role: Role;
  locale: string;
  creditBalance: number;
  premiumUntil: string | null;
  createdAt: string;
}

export interface CreditEntry {
  id: string;
  amount: number;
  kind: string;
  reference: string | null;
  createdAt: string;
}

export interface JobSummary {
  id: string;
  type: AiJobType;
  status: AiJobStatus;
  cost: number;
  error: string | null;
  createdAt: string;
  startedAt?: string | null;
  finishedAt: string | null;
  user?: { id: string; email: string };
}

export interface UserDetail extends UserSummary {
  credits: CreditEntry[];
  aiJobs: JobSummary[];
  consents: { id: string; kind: string; version: string; grantedAt: string; revokedAt: string | null }[];
}

export interface AuditEntry {
  id: string;
  actorId: string | null;
  action: string;
  targetId: string | null;
  details: Record<string, unknown>;
  createdAt: string;
}
