import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import type { Response } from 'express';
import { memoryStorage } from 'multer';

import { type AuthUser, CurrentUser, Public } from '../common/decorators';
import { ApiError } from '../common/errors';
import type { AiJobType, Prisma } from '../generated/prisma/client';
import { StorageService } from '../storage/storage.service';
import { AiJobsService, toView } from './ai-jobs.service';
import { AI_JOB_TYPES } from './pricing';
import { WorkerGuard } from './worker.guard';

/** Hard cap for the multipart parser; the service enforces the configured limit. */
const UPLOAD_HARD_LIMIT = 50 * 1024 * 1024;

class CreateJobDto {
  @ApiProperty({ enum: AI_JOB_TYPES }) @IsIn(AI_JOB_TYPES) type!: AiJobType;

  /** JSON object with style options (validated by the worker). */
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(4000) params?: string;
}

class CompleteJobDto {
  @ApiProperty() @IsString() @MaxLength(500) resultKey!: string;
}

class FailJobDto {
  @ApiProperty() @IsString() @MaxLength(500) error!: string;
}

function parseParams(raw: string | undefined): Prisma.InputJsonObject {
  if (!raw) return {};
  try {
    const value: unknown = JSON.parse(raw);
    if (typeof value === 'object' && value !== null && !Array.isArray(value)) return value;
  } catch {
    // fall through
  }
  throw new ApiError(HttpStatus.BAD_REQUEST, 'invalid_params', 'params must be a JSON object');
}

@ApiTags('ai-jobs')
@ApiBearerAuth()
@Controller('v1/ai-jobs')
export class AiJobsController {
  constructor(
    private readonly jobs: AiJobsService,
    private readonly storage: StorageService,
  ) {}

  @Get('pricing')
  pricing() {
    return this.jobs.pricing();
  }

  @Post()
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('image', { storage: memoryStorage(), limits: { fileSize: UPLOAD_HARD_LIMIT, files: 1 } }),
  )
  create(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateJobDto,
    @UploadedFile() image?: Express.Multer.File,
  ) {
    if (!image) throw new ApiError(HttpStatus.BAD_REQUEST, 'image_required', 'Attach the photo as "image"');
    return this.jobs.create(user.id, dto.type, image.buffer, parseParams(dto.params));
  }

  @Get()
  list(@CurrentUser() user: AuthUser, @Query('before') before?: string) {
    if (before && Number.isNaN(Date.parse(before))) {
      throw new ApiError(HttpStatus.BAD_REQUEST, 'invalid_cursor', 'before must be an ISO date');
    }
    return this.jobs.list(user.id, 30, before);
  }

  @Get(':id')
  async get(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return toView(await this.jobs.get(user.id, id));
  }

  @Get(':id/result')
  async result(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Res() response: Response,
  ) {
    const job = await this.jobs.get(user.id, id);
    if (job.status !== 'SUCCEEDED' || !job.resultKey || !(await this.storage.exists(job.resultKey))) {
      throw new ApiError(HttpStatus.NOT_FOUND, 'result_unavailable', 'No result for this job');
    }
    const type = job.resultKey.endsWith('.png') ? 'image/png' : 'image/jpeg';
    response.setHeader('Content-Type', type);
    response.setHeader('Cache-Control', 'private, no-store');
    this.storage.read(job.resultKey).pipe(response);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string): Promise<void> {
    await this.jobs.remove(user.id, id);
  }
}

/** Called only by the AI worker (shared secret, not user tokens). */
@ApiTags('internal')
@Public()
@UseGuards(WorkerGuard)
@Controller('internal/ai-jobs')
export class WorkerJobsController {
  constructor(private readonly jobs: AiJobsService) {}

  @Post(':id/start')
  @HttpCode(HttpStatus.OK)
  start(@Param('id', ParseUUIDPipe) id: string) {
    return this.jobs.start(id);
  }

  @Post(':id/complete')
  @HttpCode(HttpStatus.OK)
  complete(@Param('id', ParseUUIDPipe) id: string, @Body() dto: CompleteJobDto) {
    return this.jobs.complete(id, dto.resultKey);
  }

  @Post(':id/fail')
  @HttpCode(HttpStatus.OK)
  fail(@Param('id', ParseUUIDPipe) id: string, @Body() dto: FailJobDto) {
    return this.jobs.fail(id, dto.error);
  }
}
