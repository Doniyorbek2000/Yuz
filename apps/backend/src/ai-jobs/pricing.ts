import type { AiJobType } from '../generated/prisma/client';

/** Credits per job; shown to the user before they confirm. */
export const AI_JOB_COSTS: Record<AiJobType, number> = {
  PHOTOSHOOT: 4,
  HAIRSTYLE: 2,
  MAKEUP: 1,
  BACKGROUND: 1,
};

export const AI_JOB_TYPES = Object.keys(AI_JOB_COSTS) as AiJobType[];

/** Accepted uploads, detected from magic bytes (never from the client's claim). */
export function detectImageType(data: Buffer): 'jpg' | 'png' | 'webp' | 'heic' | null {
  if (data.length >= 3 && data[0] === 0xff && data[1] === 0xd8 && data[2] === 0xff) return 'jpg';
  if (
    data.length >= 8 &&
    data.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  ) {
    return 'png';
  }
  if (
    data.length >= 12 &&
    data.toString('ascii', 0, 4) === 'RIFF' &&
    data.toString('ascii', 8, 12) === 'WEBP'
  ) {
    return 'webp';
  }
  if (data.length >= 12 && data.toString('ascii', 4, 8) === 'ftyp') {
    const brand = data.toString('ascii', 8, 12);
    if (['heic', 'heix', 'hevc', 'mif1', 'msf1'].includes(brand)) return 'heic';
  }
  return null;
}
