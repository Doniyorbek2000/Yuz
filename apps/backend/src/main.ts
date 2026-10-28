import 'reflect-metadata';

import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';

import { AppModule } from './app.module';
import { configureApp } from './bootstrap';
import { ENV, type Env } from './config/env';

async function main(): Promise<void> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { bufferLogs: true });
  const env = app.get<Env>(ENV);
  // Behind one reverse proxy (TLS termination): client IPs for rate limiting.
  app.set('trust proxy', 1);
  app.useBodyParser('json', { limit: '256kb' });
  configureApp(app, env);
  await app.listen(env.PORT, '0.0.0.0');
  Logger.log(`Yuz API listening on ${env.PORT}`, 'Bootstrap');
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});
