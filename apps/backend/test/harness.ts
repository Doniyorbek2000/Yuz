import { rm } from 'node:fs/promises';

import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import type { Queue } from 'bullmq';
import request from 'supertest';
import type TestAgent from 'supertest/lib/agent';

import { AppModule } from '../src/app.module';
import { configureApp } from '../src/bootstrap';
import { ENV, type Env } from '../src/config/env';
import { PrismaService } from '../src/prisma/prisma.service';
import { STORE_VERIFIERS, type StoreVerifier } from '../src/purchases/store-verifier';
import { AI_QUEUE, type AiQueuePayload } from '../src/queue/queue.module';

export interface Harness {
  app: INestApplication;
  http: TestAgent;
  prisma: PrismaService;
  queue: Queue<AiQueuePayload>;
  env: Env;
  close(): Promise<void>;
}

/** Boots the real application (HTTP setup included) against the test services. */
export async function createHarness(options: { verifiers?: StoreVerifier[] } = {}): Promise<Harness> {
  const builder = Test.createTestingModule({ imports: [AppModule] });
  if (options.verifiers) builder.overrideProvider(STORE_VERIFIERS).useValue(options.verifiers);
  const moduleRef = await builder.compile();
  const app = moduleRef.createNestApplication();
  const env = app.get<Env>(ENV);
  configureApp(app, env);
  await app.init();
  const prisma = app.get(PrismaService);
  const queue = app.get<Queue<AiQueuePayload>>(AI_QUEUE);
  await resetState(prisma, queue, env);
  return {
    app,
    http: request(app.getHttpServer()),
    prisma,
    queue,
    env,
    close: async () => {
      await app.close();
    },
  };
}

export async function resetState(
  prisma: PrismaService,
  queue: Queue<AiQueuePayload>,
  env: Env,
): Promise<void> {
  await prisma.$executeRawUnsafe(
    'TRUNCATE TABLE audit_logs, purchases, ai_jobs, credit_entries, consents, refresh_tokens, users CASCADE',
  );
  await queue.obliterate({ force: true });
  await rm(env.STORAGE_DIR, { recursive: true, force: true });
}

let counter = 0;

/** Registers a fresh user and returns its tokens. */
export async function registerUser(http: TestAgent, overrides: Record<string, unknown> = {}) {
  counter += 1;
  const email = `user${counter}-${Date.now()}@example.com`;
  const password = 'correct horse battery';
  const response = await http
    .post('/v1/auth/register')
    .send({ email, password, ...overrides })
    .expect(201);
  const body = response.body as { accessToken: string; refreshToken: string };
  return { email, password, ...body, auth: { Authorization: `Bearer ${body.accessToken}` } };
}

/** A real 1x1 PNG. */
export const TINY_PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64',
);
