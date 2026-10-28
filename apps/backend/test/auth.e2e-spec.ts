import { createHarness, type Harness, registerUser } from './harness';

describe('auth', () => {
  let h: Harness;

  beforeAll(async () => {
    h = await createHarness();
  });

  afterAll(async () => {
    await h.close();
  });

  it('registers, grants welcome credits and serves the profile', async () => {
    const user = await registerUser(h.http, { displayName: '  Dilnoza  ', locale: 'ru' });
    expect(user.accessToken).toEqual(expect.any(String));
    const me = await h.http.get('/v1/me').set(user.auth).expect(200);
    expect(me.body).toMatchObject({
      email: user.email,
      displayName: 'Dilnoza',
      locale: 'ru',
      creditBalance: 3,
      role: 'USER',
    });
    expect(me.body).not.toHaveProperty('passwordHash');
  });

  it('normalizes emails and rejects duplicates', async () => {
    await h.http
      .post('/v1/auth/register')
      .send({ email: '  Mixed.Case@Example.com ', password: 'long enough password' })
      .expect(201);
    const duplicate = await h.http
      .post('/v1/auth/register')
      .send({ email: 'mixed.case@example.com', password: 'another long password' })
      .expect(409);
    expect(duplicate.body.code).toBe('email_taken');
    await h.http
      .post('/v1/auth/login')
      .send({ email: 'MIXED.case@example.com', password: 'long enough password' })
      .expect(200);
  });

  it('validates input strictly', async () => {
    await h.http
      .post('/v1/auth/register')
      .send({ email: 'not-an-email', password: 'long enough password' })
      .expect(400);
    await h.http.post('/v1/auth/register').send({ email: 'a@example.com', password: 'short' }).expect(400);
    await h.http
      .post('/v1/auth/register')
      .send({ email: 'b@example.com', password: 'long enough password', role: 'ADMIN' })
      .expect(400);
    await h.http
      .post('/v1/auth/register')
      .send({ email: 'c@example.com', password: 'long enough password', locale: 'de' })
      .expect(400);
  });

  it('gives one generic error for unknown email and wrong password', async () => {
    const user = await registerUser(h.http);
    const wrong = await h.http
      .post('/v1/auth/login')
      .send({ email: user.email, password: 'wrong password!' })
      .expect(401);
    const unknown = await h.http
      .post('/v1/auth/login')
      .send({ email: 'nobody@example.com', password: 'whatever pass' })
      .expect(401);
    expect(wrong.body.code).toBe('invalid_credentials');
    expect(unknown.body.code).toBe('invalid_credentials');
    expect(wrong.body.message).toBe(unknown.body.message);
  });

  it('protects routes and rejects forged tokens', async () => {
    await h.http.get('/v1/me').expect(401);
    await h.http.get('/v1/me').set('Authorization', 'Bearer not.a.jwt').expect(401);
    const user = await registerUser(h.http);
    const [header, payload] = user.accessToken.split('.');
    const forged = `${header}.${payload}.${Buffer.from('forged').toString('base64url')}`;
    await h.http.get('/v1/me').set('Authorization', `Bearer ${forged}`).expect(401);
  });

  it('rotates refresh tokens and revokes the family on reuse', async () => {
    const user = await registerUser(h.http);
    const first = await h.http.post('/v1/auth/refresh').send({ refreshToken: user.refreshToken }).expect(200);
    const rotated = first.body.refreshToken as string;
    expect(rotated).not.toBe(user.refreshToken);

    // Replaying the old token (stolen copy) revokes every token of that login.
    const replay = await h.http
      .post('/v1/auth/refresh')
      .send({ refreshToken: user.refreshToken })
      .expect(401);
    expect(replay.body.code).toBe('invalid_refresh_token');
    await h.http.post('/v1/auth/refresh').send({ refreshToken: rotated }).expect(401);
  });

  it('logout revokes the session', async () => {
    const user = await registerUser(h.http);
    await h.http.post('/v1/auth/logout').send({ refreshToken: user.refreshToken }).expect(204);
    await h.http.post('/v1/auth/refresh').send({ refreshToken: user.refreshToken }).expect(401);
  });

  it('rate limits credential attempts', async () => {
    const previous = process.env.AUTH_RATE_LIMIT_PER_MINUTE;
    process.env.AUTH_RATE_LIMIT_PER_MINUTE = '3';
    try {
      const statuses: number[] = [];
      for (let i = 0; i < 5; i++) {
        const response = await h.http
          .post('/v1/auth/login')
          .send({ email: 'x@example.com', password: 'wrong password' });
        statuses.push(response.status);
      }
      expect(statuses).toContain(429);
    } finally {
      process.env.AUTH_RATE_LIMIT_PER_MINUTE = previous;
    }
  });

  it('reports health', async () => {
    const health = await h.http.get('/health').expect(200);
    expect(health.body).toEqual({ status: 'ok', database: 'up', queue: 'up' });
  });
});
