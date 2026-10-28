import { CreditsService } from '../src/credits/credits.service';
import type { StorePlatform } from '../src/generated/prisma/client';
import { StorageService } from '../src/storage/storage.service';
import {
  StoreRejectedError,
  type StoreVerifier,
  UnconfiguredVerifier,
  type VerifiedPurchase,
} from '../src/purchases/store-verifier';
import { createHarness, type Harness, registerUser, TINY_PNG } from './harness';

/** Test double: tokens are "<transactionId>:<productId>"; "bad:*" is rejected by the store. */
class FakeVerifier implements StoreVerifier {
  readonly configured = true;

  constructor(readonly platform: StorePlatform) {}

  verify(_productId: string, token: string): Promise<VerifiedPurchase> {
    const [transactionId, productId] = token.split(':');
    if (transactionId === 'bad') return Promise.reject(new StoreRejectedError('Receipt is not valid'));
    return Promise.resolve({
      transactionId: transactionId!,
      productId: productId!,
      expiresAt: productId === 'app.yuz.premium.month' ? new Date(Date.now() + 30 * 86_400_000) : undefined,
    });
  }
}

describe('credits, purchases and account', () => {
  let h: Harness;

  beforeAll(async () => {
    h = await createHarness({
      verifiers: [new FakeVerifier('APP_STORE'), new UnconfiguredVerifier('GOOGLE_PLAY')],
    });
  });

  afterAll(async () => {
    await h.close();
  });

  it('applies ledger changes idempotently', async () => {
    const user = await registerUser(h.http);
    const me = (await h.http.get('/v1/me').set(user.auth)).body as { id: string };
    const credits = h.app.get(CreditsService);
    const first = await credits.apply(me.id, 5, 'ADJUSTMENT', 'support-ticket-1');
    const replay = await credits.apply(me.id, 5, 'ADJUSTMENT', 'support-ticket-1');
    expect(first).toEqual({ balance: 8, applied: true });
    expect(replay).toEqual({ balance: 8, applied: false });

    const concurrent = await Promise.all(
      Array.from({ length: 5 }, () => credits.apply(me.id, 2, 'ADJUSTMENT', 'same-key')),
    );
    expect(concurrent.filter((r) => r.applied)).toHaveLength(1);
    expect(await credits.balance(me.id)).toBe(10);
  });

  it('lists products and grants a verified purchase once', async () => {
    const user = await registerUser(h.http);
    const products = await h.http.get('/v1/products').set(user.auth).expect(200);
    expect(products.body[0]).toMatchObject({ id: 'app.yuz.credits.10', platforms: ['APP_STORE'] });

    const body = {
      platform: 'APP_STORE',
      productId: 'app.yuz.credits.10',
      purchaseToken: 'tx-1001:app.yuz.credits.10',
    };
    const granted = await h.http.post('/v1/purchases/verify').set(user.auth).send(body).expect(200);
    expect(granted.body).toMatchObject({ balance: 13, alreadyApplied: false });
    const replay = await h.http.post('/v1/purchases/verify').set(user.auth).send(body).expect(200);
    expect(replay.body).toMatchObject({ balance: 13, alreadyApplied: true });

    const thief = await registerUser(h.http);
    const stolen = await h.http.post('/v1/purchases/verify').set(thief.auth).send(body).expect(409);
    expect(stolen.body.code).toBe('purchase_claimed');
  });

  it('rejects invalid, mismatched, unknown and unconfigured purchases', async () => {
    const user = await registerUser(h.http);
    const send = (body: Record<string, string>) =>
      h.http.post('/v1/purchases/verify').set(user.auth).send(body);
    expect(
      (
        await send({
          platform: 'APP_STORE',
          productId: 'app.yuz.credits.10',
          purchaseToken: 'bad:app.yuz.credits.10',
        }).expect(402)
      ).body.code,
    ).toBe('purchase_invalid');
    expect(
      (
        await send({
          platform: 'APP_STORE',
          productId: 'app.yuz.credits.100',
          purchaseToken: 'tx-7:app.yuz.credits.10',
        }).expect(402)
      ).body.code,
    ).toBe('purchase_invalid');
    expect(
      (
        await send({
          platform: 'APP_STORE',
          productId: 'app.yuz.free',
          purchaseToken: 'tx-8:app.yuz.free',
        }).expect(400)
      ).body.code,
    ).toBe('unknown_product');
    expect(
      (
        await send({
          platform: 'GOOGLE_PLAY',
          productId: 'app.yuz.credits.10',
          purchaseToken: 'tx-9:app.yuz.credits.10',
        }).expect(503)
      ).body.code,
    ).toBe('store_verification_unavailable');
    expect((await h.http.get('/v1/credits').set(user.auth)).body.balance).toBe(3);
  });

  it('activates premium from a subscription purchase', async () => {
    const user = await registerUser(h.http);
    await h.http
      .post('/v1/purchases/verify')
      .set(user.auth)
      .send({
        platform: 'APP_STORE',
        productId: 'app.yuz.premium.month',
        purchaseToken: 'tx-2001:app.yuz.premium.month',
      })
      .expect(200);
    const me = await h.http.get('/v1/me').set(user.auth).expect(200);
    expect(me.body.premiumActive).toBe(true);
  });

  it('updates the profile and exports the data without secrets', async () => {
    const user = await registerUser(h.http);
    const updated = await h.http
      .patch('/v1/me')
      .set(user.auth)
      .send({ displayName: 'Aziza', locale: 'en' })
      .expect(200);
    expect(updated.body).toMatchObject({ displayName: 'Aziza', locale: 'en' });
    await h.http.patch('/v1/me').set(user.auth).send({ email: 'evil@example.com' }).expect(400);

    const exported = await h.http.get('/v1/me/export').set(user.auth).expect(200);
    expect(exported.body.account.email).toBe(user.email);
    expect(JSON.stringify(exported.body)).not.toContain('passwordHash');
    expect(exported.body.account.credits).toHaveLength(1);
  });

  it('deletes the account after re-authentication and keeps purchases anonymized', async () => {
    const user = await registerUser(h.http);
    await h.http
      .post('/v1/consents/cloud-ai')
      .set(user.auth)
      .send({ version: h.env.CLOUD_AI_CONSENT_VERSION })
      .expect(201);
    const job = await h.http
      .post('/v1/ai-jobs')
      .set(user.auth)
      .field('type', 'MAKEUP')
      .attach('image', TINY_PNG, 'a.png')
      .expect(201);
    await h.http
      .post('/v1/purchases/verify')
      .set(user.auth)
      .send({
        platform: 'APP_STORE',
        productId: 'app.yuz.credits.30',
        purchaseToken: 'tx-3001:app.yuz.credits.30',
      })
      .expect(200);
    const me = (await h.http.get('/v1/me').set(user.auth)).body as { id: string };
    const storage = h.app.get(StorageService);
    const jobPrefix = StorageService.jobPrefix(me.id, job.body.id as string);
    expect(await storage.exists(`${jobPrefix}/input.png`)).toBe(true);

    const wrong = await h.http
      .delete('/v1/me')
      .set(user.auth)
      .send({ password: 'not my password' })
      .expect(403);
    expect(wrong.body.code).toBe('invalid_password');
    await h.http.delete('/v1/me').set(user.auth).send({ password: user.password }).expect(204);

    await h.http.get('/v1/me').set(user.auth).expect(401);
    await h.http.post('/v1/auth/refresh').send({ refreshToken: user.refreshToken }).expect(401);
    await h.http.post('/v1/auth/login').send({ email: user.email, password: user.password }).expect(401);
    expect(await storage.exists(`${jobPrefix}/input.png`)).toBe(false);

    const purchase = await h.prisma.purchase.findUniqueOrThrow({ where: { transactionId: 'tx-3001' } });
    expect(purchase.userId).toBeNull();
    expect(await h.prisma.aiJob.count({ where: { userId: me.id } })).toBe(0);
    const audit = await h.prisma.auditLog.findFirst({
      where: { action: 'account.deleted', targetId: me.id },
    });
    expect(audit).not.toBeNull();
  });
});
