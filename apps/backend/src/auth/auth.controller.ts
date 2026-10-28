import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';

import { Public } from '../common/decorators';
import { AuthService } from './auth.service';
import { LoginDto, RefreshDto, RegisterDto, type TokenPair } from './dto';

/** Read per request so the validated setting applies without a restart in tests. */
const authLimit = (): number => Number(process.env.AUTH_RATE_LIMIT_PER_MINUTE ?? 10) || 10;

/** Credential endpoints are rate limited per client to slow down guessing. */
@ApiTags('auth')
@Public()
@Throttle({ default: { limit: authLimit, ttl: 60_000 } })
@Controller('v1/auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  register(@Body() dto: RegisterDto): Promise<TokenPair> {
    return this.auth.register(dto);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Body() dto: LoginDto): Promise<TokenPair> {
    return this.auth.login(dto);
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() dto: RefreshDto): Promise<TokenPair> {
    return this.auth.refresh(dto.refreshToken);
  }

  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  async logout(@Body() dto: RefreshDto): Promise<void> {
    await this.auth.logout(dto.refreshToken);
  }
}
