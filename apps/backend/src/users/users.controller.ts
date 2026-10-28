import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

import { SUPPORTED_LOCALES } from '../auth/dto';
import { type AuthUser, CurrentUser } from '../common/decorators';
import { UsersService } from './users.service';

class UpdateProfileDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(60) displayName?: string;

  @ApiPropertyOptional({ enum: SUPPORTED_LOCALES }) @IsOptional() @IsIn(SUPPORTED_LOCALES) locale?: string;
}

class DeleteAccountDto {
  /** Re-authentication: a stolen access token alone cannot delete the account. */
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(128) password!: string;
}

@ApiTags('me')
@ApiBearerAuth()
@Controller('v1/me')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  profile(@CurrentUser() user: AuthUser) {
    return this.users.profile(user.id);
  }

  @Patch()
  update(@CurrentUser() user: AuthUser, @Body() dto: UpdateProfileDto) {
    return this.users.update(user.id, dto);
  }

  /** Everything stored about the user, as JSON (data portability). */
  @Get('export')
  export(@CurrentUser() user: AuthUser) {
    return this.users.export(user.id);
  }

  @Delete()
  @HttpCode(HttpStatus.NO_CONTENT)
  async delete(@CurrentUser() user: AuthUser, @Body() dto: DeleteAccountDto): Promise<void> {
    await this.users.delete(user.id, dto.password);
  }
}
