import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';

import { ENV, type Env } from '../config/env';
import { CreditsModule } from '../credits/credits.module';
import { AccessTokenGuard } from './auth.guard';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

@Module({
  imports: [
    CreditsModule,
    JwtModule.registerAsync({
      global: true,
      inject: [ENV],
      useFactory: (env: Env) => ({
        secret: env.JWT_SECRET,
        signOptions: { algorithm: 'HS256', issuer: 'yuz' },
        verifyOptions: { algorithms: ['HS256'], issuer: 'yuz' },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, { provide: APP_GUARD, useClass: AccessTokenGuard }],
  exports: [AuthService],
})
export class AuthModule {}
