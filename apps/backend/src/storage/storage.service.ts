import { createReadStream, type ReadStream } from 'node:fs';
import { mkdir, rm, stat, writeFile } from 'node:fs/promises';
import { dirname, isAbsolute, relative, resolve } from 'node:path';

import { Inject, Injectable } from '@nestjs/common';

import { ENV, type Env } from '../config/env';

/**
 * Local-disk object storage shared with the AI worker (a mounted volume in
 * production). Keys are relative paths; anything resolving outside the root
 * is rejected, so user-controlled ids can never escape it.
 */
@Injectable()
export class StorageService {
  readonly root: string;

  constructor(@Inject(ENV) env: Env) {
    this.root = resolve(env.STORAGE_DIR);
  }

  pathFor(key: string): string {
    const full = resolve(this.root, key);
    const inside = relative(this.root, full);
    if (!key || inside.startsWith('..') || isAbsolute(inside) || inside === '') {
      throw new Error(`Storage key escapes the root: ${key}`);
    }
    return full;
  }

  async write(key: string, data: Buffer): Promise<void> {
    const path = this.pathFor(key);
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, data, { mode: 0o600 });
  }

  async exists(key: string): Promise<boolean> {
    try {
      return (await stat(this.pathFor(key))).isFile();
    } catch {
      return false;
    }
  }

  read(key: string): ReadStream {
    return createReadStream(this.pathFor(key));
  }

  async delete(key: string): Promise<void> {
    await rm(this.pathFor(key), { force: true, recursive: true });
  }

  static userPrefix(userId: string): string {
    return `users/${userId}`;
  }

  static jobPrefix(userId: string, jobId: string): string {
    return `users/${userId}/jobs/${jobId}`;
  }
}
