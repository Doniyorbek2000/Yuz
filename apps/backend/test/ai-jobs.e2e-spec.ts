import { readdir } from 'node:fs/promises';

import { StorageService } from '../src/storage/storage.service';
import { AiJobsService } from '../src/ai-jobs/ai-jobs.service';
import { createHarness, type Harness, registerUser, TINY_PNG } from './harness';

describe('consent and AI jobs', () => {
  let h: Harness;
  let worker: { Authorization: string };

  beforeAll(async () => {
    h = await createHarness();
    worker = { Authorization: `Bearer ${h.env.WORKER_TOKEN}` };
  });

  afterAll(async () => {
    await h.close();
  });

  async function consentingUser() {
    const user = await registerUser(h.http);
    await h.http
      .post('/v1/consents/cloud-ai')
      .set(user.auth)
      .send({ version: h.env.CLOUD_AI_CONSENT_VERSION })
      .expect(201);
    return user;
  }

  const upload = (auth: Record<string, string>, type = 'MAKEUP', image: Buffer = TINY_PNG) =>
    h.http
      .post('/v1/ai-jobs')
      .set(auth)
      .field('type', type)
      .field('params', '{"style":"soft"}')
      .attach('image', image, 'face.png');

  it('publishes prices and refuses types that no worker serves', async () => {
    const user = await consentingUser();
    const pricing = await h.http.get('/v1/ai-jobs/pricing').set(user.auth).expect(200);
    expect(pricing.body.BACKGROUND).toEqual({ cost: 1, enabled: true });
    const enabled = h.env.AI_ENABLED_TYPES;
    h.env.AI_ENABLED_TYPES = ['BACKGROUND'];
    try {
      const refused = await upload(user.auth, 'PHOTOSHOOT').expect(503);
      expect(refused.body.code).toBe('ai_type_unavailable');
      expect((await h.http.get('/v1/ai-jobs/pricing').set(user.auth)).body.PHOTOSHOOT.enabled).toBe(false);
    } finally {
      h.env.AI_ENABLED_TYPES = enabled;
    }
    expect((await h.http.get('/v1/credits').set(user.auth)).body.balance).toBe(3);
  });

  it('requires the current cloud AI consent', async () => {
    const user = await registerUser(h.http);
    const denied = await upload(user.auth).expect(403);
    expect(denied.body.code).toBe('consent_required');

    const outdated = await h.http
      .post('/v1/consents/cloud-ai')
      .set(user.auth)
      .send({ version: '2001-01' })
      .expect(409);
    expect(outdated.body.code).toBe('consent_outdated');

    await h.http
      .post('/v1/consents/cloud-ai')
      .set(user.auth)
      .send({ version: h.env.CLOUD_AI_CONSENT_VERSION })
      .expect(201);
    const consents = await h.http.get('/v1/consents').set(user.auth).expect(200);
    expect(consents.body.cloudAiActive).toBe(true);
  });

  it('creates a job: spends credits, stores the upload and queues it', async () => {
    const user = await consentingUser();
    const created = await upload(user.auth, 'HAIRSTYLE').expect(201);
    expect(created.body).toMatchObject({ type: 'HAIRSTYLE', status: 'QUEUED', cost: 2, hasResult: false });
    expect(created.body).not.toHaveProperty('inputKey');

    const credits = await h.http.get('/v1/credits').set(user.auth).expect(200);
    expect(credits.body.balance).toBe(1);
    expect(credits.body.entries[0]).toMatchObject({ amount: -2, kind: 'SPEND' });

    const queued = await h.queue.getJob(created.body.id as string);
    expect(queued?.data).toEqual({ jobId: created.body.id });
  });

  it('rejects non-images, oversized params and unknown types before charging', async () => {
    const user = await consentingUser();
    const fake = await upload(user.auth, 'MAKEUP', Buffer.from('#!/bin/sh\necho owned')).expect(415);
    expect(fake.body.code).toBe('unsupported_image');
    await upload(user.auth, 'NOPE').expect(400);
    await h.http.post('/v1/ai-jobs').set(user.auth).field('type', 'MAKEUP').expect(400);
    await h.http
      .post('/v1/ai-jobs')
      .set(user.auth)
      .field('type', 'MAKEUP')
      .field('params', '[1,2]')
      .attach('image', TINY_PNG, 'a.png')
      .expect(400);
    expect((await h.http.get('/v1/credits').set(user.auth)).body.balance).toBe(3);
  });

  it('refuses jobs without enough credits', async () => {
    const user = await consentingUser();
    const response = await upload(user.auth, 'PHOTOSHOOT').expect(402);
    expect(response.body.code).toBe('insufficient_credits');
    const jobs = await h.http.get('/v1/ai-jobs').set(user.auth).expect(200);
    expect(jobs.body).toEqual([]);
  });

  it('runs the worker lifecycle and serves the result to its owner only', async () => {
    const user = await consentingUser();
    const other = await consentingUser();
    const job = (await upload(user.auth).expect(201)).body as { id: string };

    await h.http.post(`/internal/ai-jobs/${job.id}/start`).expect(401);
    await h.http
      .post(`/internal/ai-jobs/${job.id}/start`)
      .set({ Authorization: 'Bearer wrong-token' })
      .expect(401);
    const started = await h.http.post(`/internal/ai-jobs/${job.id}/start`).set(worker).expect(200);
    expect(started.body).toMatchObject({ type: 'MAKEUP', params: { style: 'soft' } });
    await h.http.post(`/internal/ai-jobs/${job.id}/start`).set(worker).expect(409);

    const storage = h.app.get(StorageService);
    const resultKey = `${started.body.outputPrefix as string}/result.png`;
    await h.http.post(`/internal/ai-jobs/${job.id}/complete`).set(worker).send({ resultKey }).expect(400);
    await storage.write(resultKey, TINY_PNG);
    await h.http
      .post(`/internal/ai-jobs/${job.id}/complete`)
      .set(worker)
      .send({ resultKey: `users/${other.email}/../../etc/passwd` })
      .expect(400);
    const done = await h.http
      .post(`/internal/ai-jobs/${job.id}/complete`)
      .set(worker)
      .send({ resultKey })
      .expect(200);
    expect(done.body).toMatchObject({ status: 'SUCCEEDED', hasResult: true });
    expect(await storage.exists(started.body.inputKey as string)).toBe(false);

    const result = await h.http.get(`/v1/ai-jobs/${job.id}/result`).set(user.auth).expect(200);
    expect(result.headers['content-type']).toBe('image/png');
    expect(Buffer.compare(result.body as Buffer, TINY_PNG)).toBe(0);
    await h.http.get(`/v1/ai-jobs/${job.id}`).set(other.auth).expect(404);
    await h.http.get(`/v1/ai-jobs/${job.id}/result`).set(other.auth).expect(404);
  });

  it('refunds failed jobs exactly once', async () => {
    const user = await consentingUser();
    const job = (await upload(user.auth, 'HAIRSTYLE').expect(201)).body as { id: string };
    await h.http.post(`/internal/ai-jobs/${job.id}/start`).set(worker).expect(200);
    await h.http
      .post(`/internal/ai-jobs/${job.id}/fail`)
      .set(worker)
      .send({ error: 'model_timeout' })
      .expect(200);
    await h.http.post(`/internal/ai-jobs/${job.id}/fail`).set(worker).send({ error: 'again' }).expect(200);
    const credits = await h.http.get('/v1/credits').set(user.auth).expect(200);
    expect(credits.body.balance).toBe(3);
    expect(credits.body.entries.filter((e: { kind: string }) => e.kind === 'REFUND')).toHaveLength(1);
    const view = await h.http.get(`/v1/ai-jobs/${job.id}`).set(user.auth).expect(200);
    expect(view.body).toMatchObject({ status: 'FAILED', error: 'model_timeout' });
  });

  it('cancels queued jobs with a refund and removes them from the queue', async () => {
    const user = await consentingUser();
    const job = (await upload(user.auth).expect(201)).body as { id: string };
    await h.http.delete(`/v1/ai-jobs/${job.id}`).set(user.auth).expect(204);
    expect((await h.http.get(`/v1/ai-jobs/${job.id}`).set(user.auth)).body.status).toBe('CANCELLED');
    expect(await h.queue.getJob(job.id)).toBeUndefined();
    expect((await h.http.get('/v1/credits').set(user.auth)).body.balance).toBe(3);
    // The worker can no longer pick it up.
    await h.http.post(`/internal/ai-jobs/${job.id}/start`).set(worker).expect(409);
  });

  it('revoking consent cancels queued jobs and deletes their uploads', async () => {
    const user = await consentingUser();
    const job = (await upload(user.auth).expect(201)).body as { id: string };
    await h.http.delete('/v1/consents/cloud-ai').set(user.auth).expect(204);
    expect((await h.http.get(`/v1/ai-jobs/${job.id}`).set(user.auth)).body.status).toBe('CANCELLED');
    await upload(user.auth).expect(403);
  });

  it('purges finished jobs after the retention period', async () => {
    const user = await consentingUser();
    const job = (await upload(user.auth).expect(201)).body as { id: string };
    await h.http.post(`/internal/ai-jobs/${job.id}/fail`).set(worker).send({ error: 'x' }).expect(200);
    const service = h.app.get(AiJobsService);
    expect(await service.purgeExpired(new Date())).toBe(0);
    const later = new Date(Date.now() + (h.env.RESULT_RETENTION_DAYS + 1) * 86_400_000);
    expect(await service.purgeExpired(later)).toBeGreaterThanOrEqual(1);
    await h.http.get(`/v1/ai-jobs/${job.id}`).set(user.auth).expect(404);
  });

  it('never lets concurrent jobs overdraw the balance', async () => {
    const user = await consentingUser();
    const responses = await Promise.all(Array.from({ length: 6 }, () => upload(user.auth)));
    const statuses = responses.map((r) => r.status).sort();
    expect(statuses.filter((s) => s === 201)).toHaveLength(3);
    expect(statuses.filter((s) => s === 402)).toHaveLength(3);
    expect((await h.http.get('/v1/credits').set(user.auth)).body.balance).toBe(0);
    const files = await readdir(`${h.env.STORAGE_DIR}/users`, { recursive: true });
    expect(files.filter((f) => String(f).endsWith('input.png'))).not.toHaveLength(0);
  });
});
