import { execFileSync } from 'node:child_process';

/** Applies migrations once before the suites (the schema is part of what is tested). */
export default function globalSetup(): void {
  process.env.DATABASE_URL ??= 'postgresql://yuz:yuz_dev_only@localhost:5432/yuz_test';
  execFileSync('npx', ['prisma', 'migrate', 'deploy'], { stdio: 'inherit', env: process.env });
}
