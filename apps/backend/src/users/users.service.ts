import { HttpStatus, Injectable } from '@nestjs/common';

import { AuthService } from '../auth/auth.service';
import { ApiError } from '../common/errors';
import { ConsentService } from '../consent/consent.service';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
    private readonly consents: ConsentService,
    private readonly storage: StorageService,
  ) {}

  async profile(userId: string) {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    const consent = await this.consents.activeCloudAi(userId);
    return {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      locale: user.locale,
      role: user.role,
      creditBalance: user.creditBalance,
      premiumUntil: user.premiumUntil,
      premiumActive: user.premiumUntil !== null && user.premiumUntil.getTime() > Date.now(),
      cloudAiConsent: { active: consent !== null, currentVersion: this.consents.currentVersion },
      createdAt: user.createdAt,
    };
  }

  async update(userId: string, changes: { displayName?: string; locale?: string }) {
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        ...(changes.displayName !== undefined ? { displayName: changes.displayName.trim() || null } : {}),
        ...(changes.locale !== undefined ? { locale: changes.locale } : {}),
      },
    });
    return this.profile(userId);
  }

  async export(userId: string) {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      include: {
        consents: true,
        credits: { orderBy: { createdAt: 'asc' } },
        aiJobs: { orderBy: { createdAt: 'asc' } },
        purchases: true,
      },
    });
    const { passwordHash: _hash, ...account } = user;
    return { exportedAt: new Date(), account };
  }

  /**
   * Deletes the account and every file of it. Purchases stay (anonymized by
   * the SET NULL relation) because stores and tax law require the record.
   */
  async delete(userId: string, password: string): Promise<void> {
    if (!(await this.auth.verifyPassword(userId, password))) {
      throw new ApiError(HttpStatus.FORBIDDEN, 'invalid_password', 'Password is incorrect');
    }
    await this.prisma.$transaction([
      this.prisma.auditLog.create({ data: { actorId: null, action: 'account.deleted', targetId: userId } }),
      this.prisma.user.delete({ where: { id: userId } }),
    ]);
    await this.storage.delete(StorageService.userPrefix(userId));
  }
}
