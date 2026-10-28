import { CanActivate, ExecutionContext, HttpStatus, Inject, Injectable } from '@nestjs/common';
import type { Request } from 'express';

import { secretsEqual } from '../auth/token.util';
import { ApiError } from '../common/errors';
import { ENV, type Env } from '../config/env';

@Injectable()
export class WorkerGuard implements CanActivate {
  constructor(@Inject(ENV) private readonly env: Env) {}

  canActivate(context: ExecutionContext): boolean {
    const header = context.switchToHttp().getRequest<Request>().headers.authorization ?? '';
    const [scheme, token] = header.split(' ');
    if (scheme === 'Bearer' && token && secretsEqual(token, this.env.WORKER_TOKEN)) return true;
    throw new ApiError(HttpStatus.UNAUTHORIZED, 'unauthorized', 'Invalid worker token');
  }
}
