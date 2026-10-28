import { HttpStatus, Inject, Injectable } from '@nestjs/common';

import { ApiError } from '../common/errors';
import { ENV, type Env } from '../config/env';
import type { Consent } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ConsentService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  get currentVersion(): string {
    return this.env.CLOUD_AI_CONSENT_VERSION;
  }

  /** The active consent for the current text version, or null. */
  async activeCloudAi(userId: string): Promise<Consent | null> {
    return this.prisma.consent.findFirst({
      where: { userId, kind: 'CLOUD_AI', version: this.currentVersion, revokedAt: null },
      orderBy: { grantedAt: 'desc' },
    });
  }

  /** The app sends the version it displayed; an outdated text must be shown again. */
  async grantCloudAi(userId: string, version: string): Promise<Consent> {
    if (version !== this.currentVersion) {
      throw new ApiError(
        HttpStatus.CONFLICT,
        'consent_outdated',
        `Current consent version is ${this.currentVersion}`,
      );
    }
    return (
      (await this.activeCloudAi(userId)) ??
      this.prisma.consent.create({ data: { userId, kind: 'CLOUD_AI', version } })
    );
  }

  async revokeCloudAi(userId: string): Promise<number> {
    const result = await this.prisma.consent.updateMany({
      where: { userId, kind: 'CLOUD_AI', revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return result.count;
  }

  list(userId: string) {
    return this.prisma.consent.findMany({ where: { userId }, orderBy: { grantedAt: 'desc' } });
  }
}
