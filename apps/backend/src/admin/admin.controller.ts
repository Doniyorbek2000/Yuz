import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  NotEquals,
} from 'class-validator';

import { AI_JOB_TYPES } from '../ai-jobs/pricing';
import { type AuthUser, CurrentUser, Roles } from '../common/decorators';
import type { AiJobStatus, AiJobType } from '../generated/prisma/client';
import { AdminService, parseCursor } from './admin.service';

const JOB_STATUSES = ['QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED'] as const;

class AdjustCreditsDto {
  @ApiProperty({ minimum: -10_000, maximum: 10_000 })
  @Type(() => Number)
  @IsInt()
  @Min(-10_000)
  @Max(10_000)
  @NotEquals(0)
  amount!: number;

  /** Shown in the user's ledger and the audit log. */
  @ApiProperty() @IsString() @MinLength(3) @MaxLength(200) reason!: string;

  /** Client-generated; repeating it does not apply the change twice. */
  @ApiProperty() @IsUUID() requestId!: string;
}

class JobFilterDto {
  @ApiPropertyOptional({ enum: JOB_STATUSES }) @IsOptional() @IsIn(JOB_STATUSES) status?: AiJobStatus;

  @ApiPropertyOptional({ enum: AI_JOB_TYPES }) @IsOptional() @IsIn(AI_JOB_TYPES) type?: AiJobType;

  @ApiPropertyOptional() @IsOptional() @IsString() before?: string;
}

@ApiTags('admin')
@ApiBearerAuth()
@Roles('ADMIN')
@Controller('v1/admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('stats')
  stats() {
    return this.admin.stats();
  }

  @Get('users')
  users(@Query('q') query?: string, @Query('before') before?: string) {
    return this.admin.users(query?.slice(0, 100), parseCursor(before));
  }

  @Get('users/:id')
  user(@Param('id', ParseUUIDPipe) id: string) {
    return this.admin.user(id);
  }

  @Post('users/:id/credits')
  @HttpCode(HttpStatus.OK)
  adjustCredits(
    @CurrentUser() actor: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AdjustCreditsDto,
  ) {
    return this.admin.adjustCredits(actor.id, id, dto.amount, dto.reason.trim(), dto.requestId);
  }

  @Get('ai-jobs')
  jobs(@Query() filter: JobFilterDto) {
    return this.admin.jobs({ status: filter.status, type: filter.type, before: parseCursor(filter.before) });
  }

  @Get('audit')
  audit(@Query('before') before?: string) {
    return this.admin.audit(parseCursor(before));
  }
}
