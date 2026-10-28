import { randomUUID } from 'node:crypto';

import { forwardRef, HttpStatus, Inject, Injectable, Logger } from '@nestjs/common';
import type { Queue } from 'bullmq';

import { ApiError, consentRequired, notFound } from '../common/errors';
import { ENV, type Env } from '../config/env';
import { ConsentService } from '../consent/consent.service';
import { CreditsService } from '../credits/credits.service';
import type { AiJob, AiJobType, Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AI_QUEUE, type AiQueuePayload } from '../queue/queue.module';
import { StorageService } from '../storage/storage.service';
import { AI_JOB_COSTS, detectImageType } from './pricing';

/** What the app sees (storage keys stay internal). */
export interface AiJobView {
  id: string;
  type: AiJobType;
  status: AiJob['status'];
  cost: number;
  error: string | null;
  createdAt: Date;
  startedAt: Date | null;
  finishedAt: Date | null;
  hasResult: boolean;
}

export const toView = (job: AiJob): AiJobView => ({
  id: job.id,
  type: job.type,
  status: job.status,
  cost: job.cost,
  error: job.error,
  createdAt: job.createdAt,
  startedAt: job.startedAt,
  finishedAt: job.finishedAt,
  hasResult: job.status === 'SUCCEEDED' && job.resultKey !== null,
});

const refundKey = (jobId: string) => `refund:${jobId}`;

@Injectable()
export class AiJobsService {
  private readonly logger = new Logger(AiJobsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly credits: CreditsService,
    @Inject(forwardRef(() => ConsentService)) private readonly consents: ConsentService,
    private readonly storage: StorageService,
    @Inject(AI_QUEUE) private readonly queue: Queue<AiQueuePayload>,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /**
   * Creates a job: consent check, upload validation, credit spend and row in
   * one transaction, then the queue. Any failure after the spend refunds it.
   */
  async create(
    userId: string,
    type: AiJobType,
    image: Buffer,
    params: Prisma.InputJsonObject,
  ): Promise<AiJobView> {
    const consent = await this.consents.activeCloudAi(userId);
    if (!consent) throw consentRequired();
    if (image.length > this.env.MAX_UPLOAD_MB * 1024 * 1024) {
      throw new ApiError(
        HttpStatus.PAYLOAD_TOO_LARGE,
        'image_too_large',
        `Images are limited to ${this.env.MAX_UPLOAD_MB} MB`,
      );
    }
    const extension = detectImageType(image);
    if (!extension) {
      throw new ApiError(
        HttpStatus.UNSUPPORTED_MEDIA_TYPE,
        'unsupported_image',
        'Upload a JPEG, PNG, WebP or HEIC photo',
      );
    }
    const cost = AI_JOB_COSTS[type];
    const id = randomUUID();
    const inputKey = `${StorageService.jobPrefix(userId, id)}/input.${extension}`;
    await this.storage.write(inputKey, image);
    let job: AiJob;
    try {
      job = await this.prisma.$transaction(async (tx) => {
        await this.credits.apply(userId, -cost, 'SPEND', `job:${id}`, id, tx);
        return tx.aiJob.create({ data: { id, userId, type, inputKey, params, cost, consentId: consent.id } });
      });
    } catch (error) {
      await this.storage.delete(StorageService.jobPrefix(userId, id));
      throw error;
    }
    try {
      await this.queue.add(type, { jobId: id }, { jobId: id });
    } catch (error) {
      this.logger.error(`Queueing job ${id} failed`, error as Error);
      return toView(await this.finishFailed(job, 'queue_unavailable'));
    }
    return toView(job);
  }

  async list(userId: string, take = 30, before?: string): Promise<AiJobView[]> {
    const jobs = await this.prisma.aiJob.findMany({
      where: { userId, ...(before ? { createdAt: { lt: new Date(before) } } : {}) },
      orderBy: { createdAt: 'desc' },
      take: Math.min(Math.max(take, 1), 100),
    });
    return jobs.map(toView);
  }

  async get(userId: string, id: string): Promise<AiJob> {
    const job = await this.prisma.aiJob.findFirst({ where: { id, userId } });
    if (!job) throw notFound('Job');
    return job;
  }

  /** Cancels a queued job (refunded) or deletes a finished one with its files. */
  async remove(userId: string, id: string): Promise<void> {
    const job = await this.get(userId, id);
    if (job.status === 'RUNNING') {
      throw new ApiError(
        HttpStatus.CONFLICT,
        'job_running',
        'The job is being processed; try again when it finishes',
      );
    }
    if (job.status === 'QUEUED') {
      await this.cancel(job);
      return;
    }
    await this.storage.delete(StorageService.jobPrefix(userId, id));
    await this.prisma.aiJob.delete({ where: { id } });
  }

  async cancelQueuedForUser(userId: string): Promise<number> {
    const queued = await this.prisma.aiJob.findMany({ where: { userId, status: 'QUEUED' } });
    for (const job of queued) await this.cancel(job);
    return queued.length;
  }

  // region Worker API

  /** QUEUED -> RUNNING; the worker receives what it needs to process the job. */
  async start(id: string) {
    const updated = await this.prisma.aiJob.updateMany({
      where: { id, status: 'QUEUED' },
      data: { status: 'RUNNING', startedAt: new Date() },
    });
    const job = await this.prisma.aiJob.findUnique({ where: { id } });
    if (!job) throw notFound('Job');
    if (updated.count === 0) {
      throw new ApiError(HttpStatus.CONFLICT, 'job_not_queued', `Job is ${job.status.toLowerCase()}`);
    }
    return {
      id: job.id,
      type: job.type,
      params: job.params,
      inputKey: job.inputKey,
      outputPrefix: StorageService.jobPrefix(job.userId, job.id),
    };
  }

  /** RUNNING -> SUCCEEDED. The original upload is deleted as soon as it is no longer needed. */
  async complete(id: string, resultKey: string): Promise<AiJobView> {
    const job = await this.prisma.aiJob.findUnique({ where: { id } });
    if (!job) throw notFound('Job');
    if (
      !resultKey.startsWith(`${StorageService.jobPrefix(job.userId, job.id)}/`) ||
      resultKey === job.inputKey
    ) {
      throw new ApiError(
        HttpStatus.BAD_REQUEST,
        'invalid_result_key',
        'Result must be stored in the job directory',
      );
    }
    if (!(await this.storage.exists(resultKey))) {
      throw new ApiError(HttpStatus.BAD_REQUEST, 'result_missing', 'Result file not found');
    }
    const updated = await this.prisma.aiJob.updateMany({
      where: { id, status: 'RUNNING' },
      data: { status: 'SUCCEEDED', resultKey, finishedAt: new Date() },
    });
    if (updated.count === 0)
      throw new ApiError(HttpStatus.CONFLICT, 'job_not_running', `Job is ${job.status.toLowerCase()}`);
    await this.storage.delete(job.inputKey);
    return toView(await this.prisma.aiJob.findUniqueOrThrow({ where: { id } }));
  }

  /** Any non-final state -> FAILED, with a refund (idempotent). */
  async fail(id: string, reason: string): Promise<AiJobView> {
    const job = await this.prisma.aiJob.findUnique({ where: { id } });
    if (!job) throw notFound('Job');
    if (job.status === 'SUCCEEDED' || job.status === 'CANCELLED') {
      throw new ApiError(HttpStatus.CONFLICT, 'job_final', `Job is ${job.status.toLowerCase()}`);
    }
    return toView(await this.finishFailed(job, reason.slice(0, 500)));
  }

  // endregion

  /** Deletes results older than the retention period (privacy by default). */
  async purgeExpired(now = new Date()): Promise<number> {
    const cutoff = new Date(now.getTime() - this.env.RESULT_RETENTION_DAYS * 86_400_000);
    const expired = await this.prisma.aiJob.findMany({
      where: { finishedAt: { lt: cutoff }, status: { in: ['SUCCEEDED', 'FAILED', 'CANCELLED'] } },
      select: { id: true, userId: true },
      take: 500,
    });
    for (const job of expired) {
      await this.storage.delete(StorageService.jobPrefix(job.userId, job.id));
    }
    if (expired.length > 0)
      await this.prisma.aiJob.deleteMany({ where: { id: { in: expired.map((j) => j.id) } } });
    return expired.length;
  }

  private async cancel(job: AiJob): Promise<void> {
    const updated = await this.prisma.aiJob.updateMany({
      where: { id: job.id, status: 'QUEUED' },
      data: { status: 'CANCELLED', finishedAt: new Date() },
    });
    if (updated.count === 0) return;
    await this.queue
      .remove(job.id)
      .catch((error: unknown) => this.logger.warn(`Queue removal of ${job.id} failed: ${String(error)}`));
    await this.credits.apply(job.userId, job.cost, 'REFUND', refundKey(job.id), job.id);
    await this.storage.delete(job.inputKey);
  }

  private async finishFailed(job: AiJob, reason: string): Promise<AiJob> {
    await this.prisma.aiJob.updateMany({
      where: { id: job.id, status: { in: ['QUEUED', 'RUNNING'] } },
      data: { status: 'FAILED', error: reason, finishedAt: new Date() },
    });
    await this.credits.apply(job.userId, job.cost, 'REFUND', refundKey(job.id), job.id);
    await this.storage.delete(job.inputKey);
    return this.prisma.aiJob.findUniqueOrThrow({ where: { id: job.id } });
  }
}
