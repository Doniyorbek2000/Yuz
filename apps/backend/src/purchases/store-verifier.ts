import type { StorePlatform } from '../generated/prisma/client';

/** What a store confirms about a purchase. */
export interface VerifiedPurchase {
  transactionId: string;
  productId: string;
  /** Subscriptions only. */
  expiresAt?: Date;
}

export interface StoreVerifier {
  readonly platform: StorePlatform;
  /** false until store credentials are configured. */
  readonly configured: boolean;
  verify(productId: string, purchaseToken: string): Promise<VerifiedPurchase>;
}

export const STORE_VERIFIERS = Symbol('STORE_VERIFIERS');

export class StoreRejectedError extends Error {}

/**
 * Placeholder until App Store Server API / Google Play Developer API
 * credentials exist (they must be issued by the account owner). Never
 * approves anything.
 */
export class UnconfiguredVerifier implements StoreVerifier {
  readonly configured = false;

  constructor(readonly platform: StorePlatform) {}

  verify(): Promise<VerifiedPurchase> {
    return Promise.reject(new Error(`${this.platform} verification is not configured`));
  }
}
