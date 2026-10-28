import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

/** Opaque refresh token (256 bits) and the hash stored for it. */
export function newRefreshToken(): { token: string; hash: string } {
  const token = randomBytes(32).toString('base64url');
  return { token, hash: hashToken(token) };
}

export const hashToken = (token: string): string => createHash('sha256').update(token).digest('hex');

/** Constant-time comparison of two secrets of any length. */
export function secretsEqual(provided: string, expected: string): boolean {
  const a = createHash('sha256').update(provided).digest();
  const b = createHash('sha256').update(expected).digest();
  return timingSafeEqual(a, b);
}
