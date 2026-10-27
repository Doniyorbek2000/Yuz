// Deterministic synthetic test images and pixel statistics.

export const SKIN_LIGHT = [0.86, 0.64, 0.52];
export const SKIN_DARK = [0.55, 0.38, 0.29];
export const NON_SKIN_BLUE = [0.18, 0.34, 0.78];

function createRandom(seed) {
  let state = seed >>> 0;
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

function gaussian(random) {
  const u = Math.max(random(), 1e-9);
  const v = random();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}

export function createImage(width, height, pixelAt) {
  const data = new Uint8Array(width * height * 4);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const [r, g, b] = pixelAt(x, y);
      const offset = (y * width + x) * 4;
      data[offset] = Math.round(Math.min(Math.max(r, 0), 1) * 255);
      data[offset + 1] = Math.round(Math.min(Math.max(g, 0), 1) * 255);
      data[offset + 2] = Math.round(Math.min(Math.max(b, 0), 1) * 255);
      data[offset + 3] = 255;
    }
  }
  return { width, height, data };
}

/** Flat colour with additive Gaussian noise (blemish-like mid-amplitude). */
export function noisyPatch(width, height, base, sigma, seed) {
  const random = createRandom(seed);
  return createImage(width, height, () => {
    const n = gaussian(random) * sigma;
    return [base[0] + n, base[1] + n * 0.9, base[2] + n * 0.8];
  });
}

/** Flat colour with a fine, low-amplitude checker texture (pore-like). */
export function finelyTexturedPatch(width, height, base, amplitude) {
  return createImage(width, height, (x, y) => {
    const n = ((x + y) % 2 === 0 ? 1 : -1) * amplitude;
    return [base[0] + n, base[1] + n, base[2] + n];
  });
}

/** Two skin tones split by a horizontal edge, both with mild noise. */
export function skinEdge(width, height, seed) {
  const random = createRandom(seed);
  return createImage(width, height, (_x, y) => {
    const base = y < height / 2 ? SKIN_DARK : SKIN_LIGHT;
    const n = gaussian(random) * 0.01;
    return [base[0] + n, base[1] + n, base[2] + n];
  });
}

export function luma(image, x, y) {
  const o = (y * image.width + x) * 4;
  return (0.299 * image.data[o] + 0.587 * image.data[o + 1] + 0.114 * image.data[o + 2]) / 255;
}

/** Luma statistics over an inner region (ignores borders affected by clamping). */
export function lumaStats(image, margin = 12) {
  let sum = 0;
  let sumSquares = 0;
  let count = 0;
  for (let y = margin; y < image.height - margin; y += 1) {
    for (let x = margin; x < image.width - margin; x += 1) {
      const value = luma(image, x, y);
      sum += value;
      sumSquares += value * value;
      count += 1;
    }
  }
  const mean = sum / count;
  return { mean, variance: sumSquares / count - mean * mean };
}

export function maxChannelDifference(a, b) {
  let max = 0;
  for (let i = 0; i < a.data.length; i += 1) {
    if (i % 4 === 3) continue;
    max = Math.max(max, Math.abs(a.data[i] - b.data[i]));
  }
  return max;
}

export function solid(width, height, value) {
  return createImage(width, height, () => [value, value, value]);
}
