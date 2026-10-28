import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsString, MaxLength } from 'class-validator';

import { AiJobsService } from '../ai-jobs/ai-jobs.service';
import { type AuthUser, CurrentUser } from '../common/decorators';
import { ConsentService } from './consent.service';

class GrantConsentDto {
  @ApiProperty() @IsString() @MaxLength(32) version!: string;
}

@ApiTags('consent')
@ApiBearerAuth()
@Controller('v1/consents')
export class ConsentController {
  constructor(
    private readonly consents: ConsentService,
    private readonly jobs: AiJobsService,
  ) {}

  @Get()
  async list(@CurrentUser() user: AuthUser) {
    const [items, active] = await Promise.all([
      this.consents.list(user.id),
      this.consents.activeCloudAi(user.id),
    ]);
    return { currentVersion: this.consents.currentVersion, cloudAiActive: active !== null, items };
  }

  @Post('cloud-ai')
  grant(@CurrentUser() user: AuthUser, @Body() dto: GrantConsentDto) {
    return this.consents.grantCloudAi(user.id, dto.version);
  }

  /** Revoking also cancels (and refunds) queued jobs and deletes their uploads. */
  @Delete('cloud-ai')
  @HttpCode(HttpStatus.NO_CONTENT)
  async revoke(@CurrentUser() user: AuthUser): Promise<void> {
    await this.consents.revokeCloudAi(user.id);
    await this.jobs.cancelQueuedForUser(user.id);
  }
}
