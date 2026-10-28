import { forwardRef, Inject, Logger, Module, OnApplicationShutdown, OnModuleInit } from '@nestjs/common';

import { ENV, type Env } from '../config/env';
import { ConsentModule } from '../consent/consent.module';
import { CreditsModule } from '../credits/credits.module';
import { AiJobsController, WorkerJobsController } from './ai-jobs.controller';
import { AiJobsService } from './ai-jobs.service';

const PURGE_INTERVAL_MS = 60 * 60 * 1000;

@Module({
  imports: [CreditsModule, forwardRef(() => ConsentModule)],
  controllers: [AiJobsController, WorkerJobsController],
  providers: [AiJobsService],
  exports: [AiJobsService],
})
export class AiJobsModule implements OnModuleInit, OnApplicationShutdown {
  private readonly logger = new Logger(AiJobsModule.name);
  private timer?: NodeJS.Timeout;

  constructor(
    private readonly jobs: AiJobsService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /** Hourly retention sweep (disabled in tests, which call purgeExpired directly). */
  onModuleInit(): void {
    if (this.env.NODE_ENV === 'test') return;
    this.timer = setInterval(() => {
      this.jobs.purgeExpired().then(
        (count) => count > 0 && this.logger.log(`Deleted ${count} expired AI jobs`),
        (error: unknown) => this.logger.error('Retention sweep failed', error as Error),
      );
    }, PURGE_INTERVAL_MS);
    this.timer.unref();
  }

  onApplicationShutdown(): void {
    if (this.timer) clearInterval(this.timer);
  }
}
