import { HttpStatus, Injectable } from '@nestjs/common';

import { ApiError, notFound } from '../common/errors';
import { CreditsService } from '../credits/credits.service';
import type { AiJobStatus, AiJobType, Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const DAY = 86_400_000;
const PAGE = 50;

const userSummary = {
  id: true,
  email: true,
  displayName: true,
  role: true,
  locale: true,
  creditBalance: true,
  premiumUntil: true,
  createdAt: true,
} satisfies Prisma.UserSelect;

/** Read-mostly back office. Every change is written to the audit log. */
@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly credits: CreditsService,
  ) {}

  async stats(now = new Date()) {
    const weekAgo = new Date(now.getTime() - 7 * DAY);
    const dayAgo = new Date(now.getTime() - DAY);
    const monthAgo = new Date(now.getTime() - 30 * DAY);
    const [users, newUsers, jobsByStatus, jobsLastDay, creditsByKind, purchases] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { createdAt: { gte: weekAgo } } }),
      this.prisma.aiJob.groupBy({ by: ['status'], _count: { _all: true } }),
      this.prisma.aiJob.count({ where: { createdAt: { gte: dayAgo } } }),
      this.prisma.creditEntry.groupBy({
        by: ['kind'],
        where: { createdAt: { gte: monthAgo } },
        _sum: { amount: true },
      }),
      this.prisma.purchase.count(),
    ]);
    return {
      users: { total: users, last7Days: newUsers },
      aiJobs: {
        last24Hours: jobsLastDay,
        byStatus: Object.fromEntries(jobsByStatus.map((row) => [row.status, row._count._all])),
      },
      credits30Days: Object.fromEntries(creditsByKind.map((row) => [row.kind, row._sum.amount ?? 0])),
      purchases: { total: purchases },
    };
  }

  async users(query?: string, before?: Date) {
    const term = query?.trim();
    return this.prisma.user.findMany({
      where: {
        ...(term
          ? {
              OR: [
                { email: { contains: term.toLowerCase() } },
                { displayName: { contains: term, mode: 'insensitive' } },
                ...(isUuid(term) ? [{ id: term }] : []),
              ],
            }
          : {}),
        ...(before ? { createdAt: { lt: before } } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: PAGE,
      select: userSummary,
    });
  }

  async user(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        ...userSummary,
        credits: { orderBy: { createdAt: 'desc' }, take: 20 },
        aiJobs: {
          orderBy: { createdAt: 'desc' },
          take: 20,
          select: {
            id: true,
            type: true,
            status: true,
            cost: true,
            error: true,
            createdAt: true,
            finishedAt: true,
          },
        },
        consents: { orderBy: { grantedAt: 'desc' }, take: 5 },
      },
    });
    if (!user) throw notFound('User');
    return user;
  }

  /**
   * Manual credit correction (support goodwill, chargeback). [requestId]
   * makes a double-submitted form apply once.
   */
  async adjustCredits(actorId: string, userId: string, amount: number, reason: string, requestId: string) {
    if (!(await this.prisma.user.findUnique({ where: { id: userId }, select: { id: true } }))) {
      throw notFound('User');
    }
    return this.prisma.$transaction(async (tx) => {
      const result = await this.credits.apply(userId, amount, 'ADJUSTMENT', `admin:${requestId}`, reason, tx);
      if (result.applied) {
        await tx.auditLog.create({
          data: {
            actorId,
            action: 'credits.adjusted',
            targetId: userId,
            details: { amount, reason, requestId },
          },
        });
      }
      return result;
    });
  }

  async jobs(filter: { status?: AiJobStatus; type?: AiJobType; before?: Date }) {
    return this.prisma.aiJob.findMany({
      where: {
        ...(filter.status ? { status: filter.status } : {}),
        ...(filter.type ? { type: filter.type } : {}),
        ...(filter.before ? { createdAt: { lt: filter.before } } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: PAGE,
      select: {
        id: true,
        type: true,
        status: true,
        cost: true,
        error: true,
        createdAt: true,
        startedAt: true,
        finishedAt: true,
        user: { select: { id: true, email: true } },
      },
    });
  }

  async audit(before?: Date) {
    return this.prisma.auditLog.findMany({
      where: before ? { createdAt: { lt: before } } : {},
      orderBy: { createdAt: 'desc' },
      take: PAGE,
    });
  }
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const isUuid = (value: string) => UUID.test(value);

export function parseCursor(value?: string): Date | undefined {
  if (!value) return undefined;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new ApiError(HttpStatus.BAD_REQUEST, 'invalid_cursor', 'before must be an ISO date');
  }
  return date;
}
