import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import { type AuthUser, CurrentUser } from '../common/decorators';
import { CreditsService } from './credits.service';

@ApiTags('credits')
@ApiBearerAuth()
@Controller('v1/credits')
export class CreditsController {
  constructor(private readonly credits: CreditsService) {}

  @Get()
  async overview(@CurrentUser() user: AuthUser) {
    const [balance, entries] = await Promise.all([
      this.credits.balance(user.id),
      this.credits.history(user.id),
    ]);
    return { balance, entries };
  }
}
