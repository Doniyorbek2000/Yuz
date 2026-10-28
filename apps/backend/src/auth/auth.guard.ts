import { CanActivate, ExecutionContext, HttpStatus, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';

import { type AuthedRequest, IS_PUBLIC, ROLES } from '../common/decorators';
import { ApiError } from '../common/errors';
import type { Role } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import type { AccessClaims } from './auth.service';

/** Global guard: every route needs a valid access token unless marked @Public(). */
@Injectable()
export class AccessTokenGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const targets = [context.getHandler(), context.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, targets)) return true;
    const request = context.switchToHttp().getRequest<AuthedRequest>();
    const header = request.headers.authorization ?? '';
    const [scheme, token] = header.split(' ');
    if (scheme !== 'Bearer' || !token) {
      throw new ApiError(HttpStatus.UNAUTHORIZED, 'unauthorized', 'Missing access token');
    }
    let claims: AccessClaims;
    try {
      claims = await this.jwt.verifyAsync<AccessClaims>(token);
    } catch {
      throw new ApiError(HttpStatus.UNAUTHORIZED, 'unauthorized', 'Invalid or expired access token');
    }
    // The current row, not the token claims, decides: deleted accounts and
    // role changes take effect immediately instead of at token expiry.
    const user = await this.prisma.user.findUnique({
      where: { id: claims.sub },
      select: { id: true, role: true },
    });
    if (!user) throw new ApiError(HttpStatus.UNAUTHORIZED, 'unauthorized', 'Account no longer exists');
    request.user = user;
    const roles = this.reflector.getAllAndOverride<Role[] | undefined>(ROLES, targets);
    if (roles && !roles.includes(user.role)) {
      throw new ApiError(HttpStatus.FORBIDDEN, 'forbidden', 'Not allowed');
    }
    return true;
  }
}
