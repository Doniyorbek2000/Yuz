import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsEmail, IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export const SUPPORTED_LOCALES = ['uz', 'ru', 'en'] as const;

const normalizeEmail = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toLowerCase() : value;

export class RegisterDto {
  @ApiProperty() @Transform(normalizeEmail) @IsEmail() @MaxLength(254) email!: string;

  /** Length is what matters; no composition rules (NIST SP 800-63B). */
  @ApiProperty({ minLength: 10 }) @IsString() @MinLength(10) @MaxLength(128) password!: string;

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(60) displayName?: string;

  @ApiPropertyOptional({ enum: SUPPORTED_LOCALES }) @IsOptional() @IsIn(SUPPORTED_LOCALES) locale?: string;
}

export class LoginDto {
  @ApiProperty() @Transform(normalizeEmail) @IsEmail() @MaxLength(254) email!: string;

  @ApiProperty() @IsString() @MinLength(1) @MaxLength(128) password!: string;
}

export class RefreshDto {
  @ApiProperty() @IsString() @MinLength(20) @MaxLength(200) refreshToken!: string;
}

export interface TokenPair {
  accessToken: string;
  accessTokenExpiresIn: number;
  refreshToken: string;
}
