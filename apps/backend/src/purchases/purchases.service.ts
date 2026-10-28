import { HttpStatus, Inject, Injectable } from '@nestjs/common';

import { ApiError, isUniqueViolation } from '../common/errors';
import { CreditsService } from '../credits/credits.service';
import type { Purchase, StorePlatform } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { productById, PRODUCTS } from './catalog';
import { StoreRejectedError, STORE_VERIFIERS, type StoreVerifier } from './store-verifier';

export interface PurchaseOutcome {
  purchase: Purchase;
  balance: number;
  /** true when this store transaction had already been granted. */
  alreadyApplied: boolean;
}

@Injectable()
export class PurchasesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly credits: CreditsService,
    @Inject(STORE_VERIFIERS) private readonly verifiers: StoreVerifier[],
  ) {}

  products() {
    return PRODUCTS.map((product) => ({
      ...product,
      platforms: this.verifiers.filter((v) => v.configured).map((v) => v.platform),
    }));
  }

  /**
   * Verifies a store purchase server-side and grants it once per store
   * transaction (retries and replays return the existing grant).
   */
  async verify(
    userId: string,
    platform: StorePlatform,
    productId: string,
    purchaseToken: string,
  ): Promise<PurchaseOutcome> {
    const product = productById(productId);
    if (!product)
      throw new ApiError(HttpStatus.BAD_REQUEST, 'unknown_product', `Unknown product ${productId}`);
    const verifier = this.verifiers.find((v) => v.platform === platform);
    if (!verifier?.configured) {
      throw new ApiError(
        HttpStatus.SERVICE_UNAVAILABLE,
        'store_verification_unavailable',
        'Purchases are not enabled yet',
      );
    }
    let verified;
    try {
      verified = await verifier.verify(productId, purchaseToken);
    } catch (error) {
      if (error instanceof StoreRejectedError) {
        throw new ApiError(HttpStatus.PAYMENT_REQUIRED, 'purchase_invalid', error.message);
      }
      throw new ApiError(
        HttpStatus.BAD_GATEWAY,
        'store_unreachable',
        'The store could not confirm the purchase',
      );
    }
    if (verified.productId !== productId) {
      throw new ApiError(
        HttpStatus.PAYMENT_REQUIRED,
        'purchase_invalid',
        'Product does not match the purchase',
      );
    }
    const existing = await this.prisma.purchase.findUnique({
      where: { transactionId: verified.transactionId },
    });
    if (existing) {
      if (existing.userId !== userId) {
        throw new ApiError(
          HttpStatus.CONFLICT,
          'purchase_claimed',
          'This purchase belongs to another account',
        );
      }
      return { purchase: existing, balance: await this.credits.balance(userId), alreadyApplied: true };
    }
    try {
      const purchase = await this.prisma.$transaction(async (tx) => {
        const created = await tx.purchase.create({
          data: {
            userId,
            platform,
            productId,
            transactionId: verified.transactionId,
            creditsGranted: product.credits ?? 0,
            premiumUntil: verified.expiresAt ?? null,
          },
        });
        if (product.credits) {
          await this.credits.apply(
            userId,
            product.credits,
            'PURCHASE',
            `purchase:${verified.transactionId}`,
            created.id,
            tx,
          );
        }
        if (product.kind === 'premium') {
          const until = verified.expiresAt ?? new Date(Date.now() + (product.premiumDays ?? 31) * 86_400_000);
          await tx.user.update({ where: { id: userId }, data: { premiumUntil: until } });
        }
        return created;
      });
      return { purchase, balance: await this.credits.balance(userId), alreadyApplied: false };
    } catch (error) {
      if (isUniqueViolation(error)) return this.verify(userId, platform, productId, purchaseToken);
      throw error;
    }
  }
}
