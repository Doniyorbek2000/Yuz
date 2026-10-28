import { Global, Inject, Module, OnApplicationShutdown } from '@nestjs/common';
import { Queue } from 'bullmq';

import { ENV, type Env } from '../config/env';

export const AI_QUEUE = Symbol('AI_QUEUE');
export const AI_QUEUE_NAME = 'yuz-ai-jobs';

/** Payload the worker receives; everything else is fetched from the internal API. */
export interface AiQueuePayload {
  jobId: string;
}

/** Parses redis://[user:password@]host:port[/db] for BullMQ. */
export function redisConnection(url: string) {
  const parsed = new URL(url);
  return {
    host: parsed.hostname,
    port: Number(parsed.port || 6379),
    username: parsed.username || undefined,
    password: parsed.password ? decodeURIComponent(parsed.password) : undefined,
    db: parsed.pathname.length > 1 ? Number(parsed.pathname.slice(1)) : 0,
    tls: parsed.protocol === 'rediss:' ? {} : undefined,
    maxRetriesPerRequest: null,
  };
}

@Global()
@Module({
  providers: [
    {
      provide: AI_QUEUE,
      inject: [ENV],
      useFactory: (env: Env) =>
        new Queue<AiQueuePayload>(AI_QUEUE_NAME, {
          connection: redisConnection(env.REDIS_URL),
          defaultJobOptions: { attempts: 1, removeOnComplete: 1000, removeOnFail: 1000 },
        }),
    },
  ],
  exports: [AI_QUEUE],
})
export class QueueModule implements OnApplicationShutdown {
  constructor(@Inject(AI_QUEUE) private readonly queue: Queue<AiQueuePayload>) {}

  async onApplicationShutdown(): Promise<void> {
    await this.queue.close();
  }
}
