import { randomBytes } from 'node:crypto';

// Test configuration: local Postgres/Redis (CI provides them as services).
// Secrets are random per run, so none are committed.
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL ??= 'postgresql://yuz:yuz_dev_only@localhost:5432/yuz_test';
process.env.REDIS_URL ??= 'redis://localhost:6379/15';
process.env.JWT_SECRET ??= randomBytes(32).toString('hex');
process.env.WORKER_TOKEN ??= randomBytes(32).toString('hex');
process.env.STORAGE_DIR ??= `/tmp/yuz-api-test-storage-${process.pid}`;
process.env.WELCOME_CREDITS ??= '3';
process.env.AUTH_RATE_LIMIT_PER_MINUTE ??= '1000';
