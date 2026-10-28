import { randomUUID } from 'node:crypto';

import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as argon2 from 'argon2';

import { ApiError, isUniqueViolation } from '../common/errors';
import { ENV, type Env } from '../config/env';
import { CreditsService } from '../credits/credits.service';
import type { Role, User } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import type { LoginDto, RegisterDto, TokenPair } from './dto';
import { hashToken, newRefreshToken } from './token.util';

export interface AccessClaims {
  sub: string;
  role: Role;
}

const invalidCredentials = () =>
  new ApiError(HttpStatus.UNAUTHORIZED, 'invalid_credentials', 'Email or password is incorrect');

const invalidRefresh = () => new ApiError(HttpStatus.UNAUTHORIZED, 'invalid_refresh_token', 'Sign in again');

@Injectable()
export class AuthService {
  /** Verified when the email is unknown, so both paths take the same time. */
  private readonly dummyHash = argon2.hash('yuz-timing-equalizer');

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly credits: CreditsService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  async register(dto: RegisterDto): Promise<TokenPair> {
    const passwordHash = await argon2.hash(dto.password, { type: argon2.argon2id });
    let user: User;
    try {
      // Account and welcome credits are created together or not at all.
      user = await this.prisma.$transaction(async (tx) => {
        const created = await tx.user.create({
          data: {
            email: dto.email,
            passwordHash,
            displayName: dto.displayName?.trim() || null,
            locale: dto.locale ?? 'uz',
          },
        });
        if (this.env.WELCOME_CREDITS > 0) {
          await this.credits.apply(created.id, this.env.WELCOME_CREDITS, 'WELCOME', 'welcome', undefined, tx);
        }
        return created;
      });
    } catch (error) {
      if (isUniqueViolation(error)) {
        throw new ApiError(HttpStatus.CONFLICT, 'email_taken', 'An account with this email already exists');
      }
      throw error;
    }
    return this.issueTokens(user, randomUUID());
  }

  async login(dto: LoginDto): Promise<TokenPair> {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user) {
      await argon2.verify(await this.dummyHash, dto.password);
      throw invalidCredentials();
    }
    if (!(await argon2.verify(user.passwordHash, dto.password))) throw invalidCredentials();
    return this.issueTokens(user, randomUUID());
  }

  /**
   * Rotates the refresh token. Presenting an already rotated token means
   * it leaked: the whole family (every device session from that login) is
   * revoked.
   */
  async refresh(token: string): Promise<TokenPair> {
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: hashToken(token) },
      include: { user: true },
    });
    if (!stored) throw invalidRefresh();
    if (stored.revokedAt || stored.replacedAt) {
      await this.revokeFamily(stored.familyId);
      throw invalidRefresh();
    }
    if (stored.expiresAt.getTime() <= Date.now()) throw invalidRefresh();
    const rotated = await this.prisma.refreshToken.updateMany({
      where: { id: stored.id, replacedAt: null, revokedAt: null },
      data: { replacedAt: new Date() },
    });
    // A concurrent refresh already used this token: treat as reuse.
    if (rotated.count === 0) {
      await this.revokeFamily(stored.familyId);
      throw invalidRefresh();
    }
    return this.issueTokens(stored.user, stored.familyId);
  }

  async logout(token: string): Promise<void> {
    const stored = await this.prisma.refreshToken.findUnique({ where: { tokenHash: hashToken(token) } });
    if (stored) await this.revokeFamily(stored.familyId);
  }

  async verifyPassword(userId: string, password: string): Promise<boolean> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    return user !== null && argon2.verify(user.passwordHash, password);
  }

  private async revokeFamily(familyId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { familyId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private async issueTokens(user: User, familyId: string): Promise<TokenPair> {
    const claims: AccessClaims = { sub: user.id, role: user.role };
    const accessToken = await this.jwt.signAsync(claims, { expiresIn: this.env.ACCESS_TOKEN_TTL_SECONDS });
    const refresh = newRefreshToken();
    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        familyId,
        tokenHash: refresh.hash,
        expiresAt: new Date(Date.now() + this.env.REFRESH_TOKEN_TTL_DAYS * 86_400_000),
      },
    });
    return {
      accessToken,
      accessTokenExpiresIn: this.env.ACCESS_TOKEN_TTL_SECONDS,
      refreshToken: refresh.token,
    };
  }
}
