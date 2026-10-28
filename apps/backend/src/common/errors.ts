import { HttpException, HttpStatus } from '@nestjs/common';

/**
 * API errors carry a stable machine-readable `code` (the app localizes it)
 * next to a developer-facing message.
 */
export class ApiError extends HttpException {
  constructor(status: HttpStatus, code: string, message: string) {
    super({ statusCode: status, code, message }, status);
  }
}

export const insufficientCredits = (needed: number, balance: number) =>
  new ApiError(
    HttpStatus.PAYMENT_REQUIRED,
    'insufficient_credits',
    `Needs ${needed} credits, balance is ${balance}`,
  );

export const consentRequired = () =>
  new ApiError(HttpStatus.FORBIDDEN, 'consent_required', 'Cloud AI consent is required for this action');

export const notFound = (what: string) =>
  new ApiError(HttpStatus.NOT_FOUND, 'not_found', `${what} not found`);

/** Prisma unique-constraint violation. */
export const isUniqueViolation = (error: unknown): boolean =>
  typeof error === 'object' && error !== null && (error as { code?: unknown }).code === 'P2002';
