import { Injectable } from '@nestjs/common';

import { insufficientCredits, isUniqueViolation } from '../common/errors';
import type { CreditKind, Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export interface CreditResult {
  balance: number;
  /** false when the idempotency key was already used (nothing changed). */
  applied: boolean;
}

type Tx = Prisma.TransactionClient;

/**
 * The credit ledger. Every change is one ledger row plus an atomic update of
 * the cached balance in the same transaction; a spend is a conditional
 * update, so concurrent requests can never drive the balance below zero.
 */
@Injectable()
export class CreditsService {
  constructor(private readonly prisma: PrismaService) {}

  async apply(
    userId: string,
    amount: number,
    kind: CreditKind,
    idempotencyKey: string,
    reference?: string,
    tx?: Tx,
  ): Promise<CreditResult> {
    if (!Number.isInteger(amount) || amount === 0) throw new Error(`Invalid credit amount ${amount}`);
    const run = (client: Tx) => this.applyIn(client, userId, amount, kind, idempotencyKey, reference);
    if (tx) return run(tx);
    try {
      return await this.prisma.$transaction(run);
    } catch (error) {
      // A concurrent request with the same key won the race.
      if (isUniqueViolation(error)) return { balance: await this.balance(userId), applied: false };
      throw error;
    }
  }

  async balance(userId: string): Promise<number> {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { creditBalance: true },
    });
    return user.creditBalance;
  }

  async history(userId: string, take = 50) {
    return this.prisma.creditEntry.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: Math.min(Math.max(take, 1), 200),
      select: { id: true, amount: true, kind: true, reference: true, createdAt: true },
    });
  }

  private async applyIn(
    tx: Tx,
    userId: string,
    amount: number,
    kind: CreditKind,
    idempotencyKey: string,
    reference?: string,
  ): Promise<CreditResult> {
    const existing = await tx.creditEntry.findUnique({
      where: { userId_idempotencyKey: { userId, idempotencyKey } },
    });
    if (existing) {
      const user = await tx.user.findUniqueOrThrow({
        where: { id: userId },
        select: { creditBalance: true },
      });
      return { balance: user.creditBalance, applied: false };
    }
    if (amount < 0) {
      const updated = await tx.user.updateMany({
        where: { id: userId, creditBalance: { gte: -amount } },
        data: { creditBalance: { increment: amount } },
      });
      if (updated.count === 0) {
        const user = await tx.user.findUniqueOrThrow({
          where: { id: userId },
          select: { creditBalance: true },
        });
        throw insufficientCredits(-amount, user.creditBalance);
      }
    } else {
      await tx.user.update({ where: { id: userId }, data: { creditBalance: { increment: amount } } });
    }
    await tx.creditEntry.create({ data: { userId, amount, kind, idempotencyKey, reference } });
    const user = await tx.user.findUniqueOrThrow({ where: { id: userId }, select: { creditBalance: true } });
    return { balance: user.creditBalance, applied: true };
  }
}
