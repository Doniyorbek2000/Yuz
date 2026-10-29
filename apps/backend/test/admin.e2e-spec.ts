import { randomUUID } from 'node:crypto';

import { setRole } from '../src/cli/set-role';
import { createHarness, type Harness, registerUser } from './harness';

describe('admin', () => {
  let h: Harness;

  beforeAll(async () => {
    h = await createHarness();
  });

  afterAll(async () => {
    await h.close();
  });

  async function adminUser() {
    const admin = await registerUser(h.http, { displayName: 'Ops' });
    expect(await setRole(h.prisma, admin.email.toUpperCase(), 'ADMIN')).toBe(true);
    return admin;
  }

  it('is closed to regular users and anonymous callers', async () => {
    const user = await registerUser(h.http);
    await h.http.get('/v1/admin/stats').expect(401);
    const denied = await h.http.get('/v1/admin/stats').set(user.auth).expect(403);
    expect(denied.body.code).toBe('forbidden');
  });

  it('takes role changes into account without a new token', async () => {
    const admin = await adminUser();
    await h.http.get('/v1/admin/stats').set(admin.auth).expect(200);
    await setRole(h.prisma, admin.email, 'USER');
    await h.http.get('/v1/admin/stats').set(admin.auth).expect(403);
    const audit = await h.prisma.auditLog.findMany({ where: { action: 'role.changed' } });
    expect(audit.length).toBeGreaterThanOrEqual(2);
  });

  it('reports stats, searches users and shows one user', async () => {
    const admin = await adminUser();
    const user = await registerUser(h.http, { displayName: 'Zarina Q' });
    const stats = await h.http.get('/v1/admin/stats').set(admin.auth).expect(200);
    expect(stats.body.users.total).toBeGreaterThanOrEqual(2);
    expect(stats.body.credits30Days.WELCOME).toBeGreaterThanOrEqual(6);

    const byName = await h.http.get('/v1/admin/users').query({ q: 'zarina' }).set(admin.auth).expect(200);
    expect(byName.body).toHaveLength(1);
    expect(byName.body[0]).toMatchObject({ email: user.email, creditBalance: 3 });
    expect(byName.body[0]).not.toHaveProperty('passwordHash');

    const byEmail = await h.http
      .get('/v1/admin/users')
      .query({ q: user.email.toUpperCase() })
      .set(admin.auth)
      .expect(200);
    expect(byEmail.body.map((u: { email: string }) => u.email)).toEqual([user.email]);

    const detail = await h.http.get(`/v1/admin/users/${byName.body[0].id}`).set(admin.auth).expect(200);
    expect(detail.body.credits[0]).toMatchObject({ kind: 'WELCOME', amount: 3 });
    expect(detail.body).not.toHaveProperty('passwordHash');
    await h.http.get(`/v1/admin/users/${randomUUID()}`).set(admin.auth).expect(404);
    await h.http.get('/v1/admin/users').query({ before: 'yesterday' }).set(admin.auth).expect(400);
  });

  it('adjusts credits once per request id and audits it', async () => {
    const admin = await adminUser();
    const user = await registerUser(h.http);
    const { id } = (await h.prisma.user.findUniqueOrThrow({ where: { email: user.email } })) as {
      id: string;
    };
    const requestId = randomUUID();
    const body = { amount: 5, reason: 'Support goodwill', requestId };

    const first = await h.http.post(`/v1/admin/users/${id}/credits`).set(admin.auth).send(body).expect(200);
    expect(first.body).toEqual({ balance: 8, applied: true });
    const repeat = await h.http.post(`/v1/admin/users/${id}/credits`).set(admin.auth).send(body).expect(200);
    expect(repeat.body).toEqual({ balance: 8, applied: false });

    const overdraw = await h.http
      .post(`/v1/admin/users/${id}/credits`)
      .set(admin.auth)
      .send({ amount: -100, reason: 'Chargeback', requestId: randomUUID() })
      .expect(402);
    expect(overdraw.body.code).toBe('insufficient_credits');

    for (const invalid of [
      { ...body, amount: 0, requestId: randomUUID() },
      { ...body, amount: 1.5, requestId: randomUUID() },
      { ...body, reason: 'x', requestId: randomUUID() },
      { ...body, requestId: 'not-a-uuid' },
    ]) {
      await h.http.post(`/v1/admin/users/${id}/credits`).set(admin.auth).send(invalid).expect(400);
    }

    const ledger = await h.http.get('/v1/credits').set(user.auth).expect(200);
    expect(ledger.body.entries[0]).toMatchObject({
      amount: 5,
      kind: 'ADJUSTMENT',
      reference: 'Support goodwill',
    });
    const audit = await h.http.get('/v1/admin/audit').set(admin.auth).expect(200);
    const adjusted = audit.body.filter((entry: { action: string }) => entry.action === 'credits.adjusted');
    expect(adjusted).toHaveLength(1);
    expect(adjusted[0]).toMatchObject({ targetId: id, details: { amount: 5, requestId } });
  });

  it('lists AI jobs with filters', async () => {
    const admin = await adminUser();
    await h.http
      .get('/v1/admin/ai-jobs')
      .query({ status: 'FAILED', type: 'BACKGROUND' })
      .set(admin.auth)
      .expect(200);
    await h.http.get('/v1/admin/ai-jobs').query({ status: 'BROKEN' }).set(admin.auth).expect(400);
  });
});
