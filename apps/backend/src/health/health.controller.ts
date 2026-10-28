import { Controller, Get, HttpStatus, Inject, Res } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import type { Queue } from 'bullmq';
import type { Response } from 'express';

import { Public } from '../common/decorators';
import { PrismaService } from '../prisma/prisma.service';
import { AI_QUEUE, type AiQueuePayload } from '../queue/queue.module';

@ApiTags('health')
@Public()
@SkipThrottle()
@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(AI_QUEUE) private readonly queue: Queue<AiQueuePayload>,
  ) {}

  /** 200 when the database and the queue answer; 503 otherwise (for load balancers). */
  @Get()
  async check(@Res() response: Response) {
    const [database, queue] = await Promise.all([
      this.prisma.$queryRaw`SELECT 1`.then(
        () => 'up' as const,
        () => 'down' as const,
      ),
      this.queue.count().then(
        () => 'up' as const,
        () => 'down' as const,
      ),
    ]);
    const ok = database === 'up' && queue === 'up';
    response
      .status(ok ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE)
      .json({ status: ok ? 'ok' : 'degraded', database, queue });
  }
}
