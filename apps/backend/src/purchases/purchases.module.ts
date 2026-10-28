import { Module } from '@nestjs/common';

import { CreditsModule } from '../credits/credits.module';
import { PurchasesController } from './purchases.controller';
import { PurchasesService } from './purchases.service';
import { STORE_VERIFIERS, UnconfiguredVerifier } from './store-verifier';

@Module({
  imports: [CreditsModule],
  controllers: [PurchasesController],
  providers: [
    PurchasesService,
    {
      provide: STORE_VERIFIERS,
      useFactory: () => [new UnconfiguredVerifier('APP_STORE'), new UnconfiguredVerifier('GOOGLE_PLAY')],
    },
  ],
})
export class PurchasesModule {}
