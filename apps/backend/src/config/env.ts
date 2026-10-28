import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  DATABASE_URL: z.string().min(1),
  REDIS_URL: z.string().min(1).default('redis://localhost:6379'),
  /** HS256 secret for access tokens. */
  JWT_SECRET: z.string().min(32, 'JWT_SECRET must be at least 32 characters'),
  ACCESS_TOKEN_TTL_SECONDS: z.coerce.number().int().min(60).max(86_400).default(900),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().min(1).max(365).default(30),
  /** Comma-separated allowed origins for browsers (the admin panel); empty = none. */
  CORS_ORIGINS: z.string().default(''),
  STORAGE_DIR: z.string().min(1).default('./storage'),
  /** Shared secret the AI worker presents on the internal API. */
  WORKER_TOKEN: z.string().min(32, 'WORKER_TOKEN must be at least 32 characters'),
  WELCOME_CREDITS: z.coerce.number().int().min(0).max(100).default(3),
  MAX_UPLOAD_MB: z.coerce.number().int().min(1).max(50).default(12),
  /** Version of the cloud AI consent text shown in the app. */
  CLOUD_AI_CONSENT_VERSION: z.string().min(1).default('2026-10'),
  /** Credential attempts (register/login/refresh) per client per minute. */
  AUTH_RATE_LIMIT_PER_MINUTE: z.coerce.number().int().min(1).max(10_000).default(10),
  /** Days results are kept before automatic deletion. */
  RESULT_RETENTION_DAYS: z.coerce.number().int().min(1).max(90).default(7),
});

export type Env = z.infer<typeof schema>;

export const ENV = Symbol('ENV');

/** Parses and validates configuration; fails fast with every problem listed. */
export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const result = schema.safeParse(source);
  if (!result.success) {
    const problems = result.error.issues
      .map((issue) => `${issue.path.join('.')}: ${issue.message}`)
      .join('; ');
    throw new Error(`Invalid configuration: ${problems}`);
  }
  return result.data;
}
