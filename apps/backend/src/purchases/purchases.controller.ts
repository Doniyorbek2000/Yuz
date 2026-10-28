import { Body, Controller, Get, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';

import { type AuthUser, CurrentUser } from '../common/decorators';
import type { StorePlatform } from '../generated/prisma/client';
import { PurchasesService } from './purchases.service';

const PLATFORMS: StorePlatform[] = ['APP_STORE', 'GOOGLE_PLAY'];

class VerifyPurchaseDto {
  @ApiProperty({ enum: PLATFORMS }) @IsIn(PLATFORMS) platform!: StorePlatform;

  @ApiProperty() @IsString() @MaxLength(100) productId!: string;

  /** App Store: signed transaction / transaction id; Google Play: purchase token. */
  @ApiProperty() @IsString() @MinLength(8) @MaxLength(10_000) purchaseToken!: string;
}

@ApiTags('purchases')
@ApiBearerAuth()
@Controller('v1')
export class PurchasesController {
  constructor(private readonly purchases: PurchasesService) {}

  @Get('products')
  products() {
    return this.purchases.products();
  }

  @Post('purchases/verify')
  @HttpCode(HttpStatus.OK)
  verify(@CurrentUser() user: AuthUser, @Body() dto: VerifyPurchaseDto) {
    return this.purchases.verify(user.id, dto.platform, dto.productId, dto.purchaseToken);
  }
}
