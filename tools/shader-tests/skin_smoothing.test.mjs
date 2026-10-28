import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { GlHarness } from './gl_harness.mjs';
import { buildLut, compileAll, renderBeauty, renderFaceMask, syntheticFace } from './beauty_pipeline.mjs';
import {
  NON_SKIN_BLUE,
  SKIN_LIGHT,
  createImage,
  finelyTexturedPatch,
  luma,
  lumaStats,
  maxChannelDifference,
  noisyPatch,
  skinEdge,
} from './images.mjs';

const SIZE = 96;
const FULL_SMOOTH = { uSkinSmoothing: 1 };

describe('skin smoothing (GLSL ES 3.00, WebGL2/SwiftShader)', () => {
  let harness;

  before(async () => {
    harness = await GlHarness.launch();
    await compileAll(harness);
  });

  after(async () => {
    await harness?.close();
  });

  it('is an exact identity when every parameter is zero', async () => {
    const input = noisyPatch(SIZE, SIZE, SKIN_LIGHT, 0.05, 1);
    const output = await renderBeauty(harness, input, {});
    assert.ok(maxChannelDifference(input, output) <= 1, 'output deviates from input');
  });

  it('removes most noise variance from skin', async () => {
    const input = noisyPatch(SIZE, SIZE, SKIN_LIGHT, 0.04, 2);
    const output = await renderBeauty(harness, input, FULL_SMOOTH);
    const before = lumaStats(input);
    const afterStats = lumaStats(output);
    assert.ok(afterStats.variance < before.variance * 0.35, `variance ${afterStats.variance} vs ${before.variance}`);
    assert.ok(Math.abs(afterStats.mean - before.mean) < 0.01, 'mean skin tone shifted');
  });

  it('leaves non-skin colours untouched by every skin effect', async () => {
    const input = noisyPatch(SIZE, SIZE, NON_SKIN_BLUE, 0.04, 3);
    const output = await renderBeauty(harness, input, {
      uSkinSmoothing: 1,
      uSkinBrightening: 1,
      uSkinTone: 1,
      uBlemishReduction: 1,
      uShineReduction: 1,
      uGlow: 1,
    });
    assert.ok(maxChannelDifference(input, output) <= 2, 'non-skin pixels were modified');
  });

  it('preserves strong edges between skin regions', async () => {
    const input = skinEdge(SIZE, SIZE, 4);
    const output = await renderBeauty(harness, input, FULL_SMOOTH);
    const x = SIZE / 2;
    const edgeBefore = luma(input, x, SIZE / 2 + 2) - luma(input, x, SIZE / 2 - 3);
    const edgeAfter = luma(output, x, SIZE / 2 + 2) - luma(output, x, SIZE / 2 - 3);
    assert.ok(edgeAfter > edgeBefore * 0.9, `edge contrast ${edgeAfter} < 90% of ${edgeBefore}`);
  });

  it('texture preservation keeps fine pore-scale detail', async () => {
    const input = finelyTexturedPatch(SIZE, SIZE, SKIN_LIGHT, 0.012);
    const flattened = await renderBeauty(harness, input, FULL_SMOOTH);
    const preserved = await renderBeauty(harness, input, { uSkinSmoothing: 1, uTexturePreservation: 1 });
    const original = lumaStats(input).variance;
    assert.ok(lumaStats(flattened).variance < original * 0.5, 'smoothing did not flatten texture');
    assert.ok(lumaStats(preserved).variance > original * 0.6, 'texture not preserved');
  });

  it('brightening lifts skin luma within natural bounds', async () => {
    const input = noisyPatch(SIZE, SIZE, SKIN_LIGHT, 0.0, 5);
    const output = await renderBeauty(harness, input, { uSkinBrightening: 1 });
    const delta = lumaStats(output).mean - lumaStats(input).mean;
    assert.ok(delta > 0.03 && delta < 0.15, `brightening delta ${delta}`);
  });

  it('blemish reduction removes a dark spot even without smoothing', async () => {
    const spot = createImage(SIZE, SIZE, (x, y) => {
      const d = Math.hypot(x - SIZE / 2, y - SIZE / 2);
      const k = d < 3 ? 0.18 : 0;
      return [SKIN_LIGHT[0] - k, SKIN_LIGHT[1] - k, SKIN_LIGHT[2] - k];
    });
    const off = await renderBeauty(harness, spot, {});
    const on = await renderBeauty(harness, spot, { uBlemishReduction: 1 });
    const contrast = (img) => luma(img, 10, 10) - luma(img, SIZE / 2, SIZE / 2);
    assert.ok(contrast(on) < contrast(off) * 0.5, `spot contrast ${contrast(on)} vs ${contrast(off)}`);
  });

  it('skin tone evening reduces chroma variation (redness patches)', async () => {
    const patches = createImage(SIZE, SIZE, (x, y) =>
      ((Math.floor(x / 6) + Math.floor(y / 6)) % 2 === 0) ? [0.86, 0.60, 0.50] : [0.86, 0.66, 0.54]);
    const output = await renderBeauty(harness, patches, { uSkinTone: 1 });
    const chromaSpread = (img) => {
      let min = Infinity;
      let max = -Infinity;
      for (let y = 12; y < SIZE - 12; y += 1) {
        for (let x = 12; x < SIZE - 12; x += 1) {
          const o = (y * SIZE + x) * 4;
          const cr = 0.5 * img.data[o] - 0.418688 * img.data[o + 1] - 0.081312 * img.data[o + 2];
          min = Math.min(min, cr);
          max = Math.max(max, cr);
        }
      }
      return max - min;
    };
    assert.ok(chromaSpread(output) < chromaSpread(patches) * 0.6, 'chroma not evened');
  });

  it('shine reduction darkens skin highlights only', async () => {
    const shiny = noisyPatch(SIZE, SIZE, [0.98, 0.85, 0.78], 0.0, 7);
    const mid = noisyPatch(SIZE, SIZE, [0.7, 0.5, 0.42], 0.0, 7);
    const shinyDelta = lumaStats(shiny).mean - lumaStats(await renderBeauty(harness, shiny, { uShineReduction: 1 })).mean;
    const midDelta = lumaStats(mid).mean - lumaStats(await renderBeauty(harness, mid, { uShineReduction: 1 })).mean;
    assert.ok(shinyDelta > 0.05, `highlight not reduced (${shinyDelta})`);
    assert.ok(midDelta < 0.005, `mid-tones changed (${midDelta})`);
  });

  it('glow brightens skin', async () => {
    const input = noisyPatch(SIZE, SIZE, SKIN_LIGHT, 0.0, 8);
    const delta = lumaStats(await renderBeauty(harness, input, { uGlow: 1 })).mean - lumaStats(input).mean;
    assert.ok(delta > 0.03, `glow delta ${delta}`);
  });
});

describe('face regions and makeup', () => {
  let harness;
  const face = syntheticFace();
  const W = 128;

  before(async () => {
    harness = await GlHarness.launch();
    await compileAll(harness);
  });

  after(async () => {
    await harness?.close();
  });

  const sample = (image, u, v, channel = 0) =>
    image.data[(Math.floor(v * image.height) * image.width + Math.floor(u * image.width)) * 4 + channel] / 255;

  it('mask A marks skin, eyes, teeth and under-eye in the right places', async () => {
    const { a } = await renderFaceMask(harness, face, W, W, { feather: false });
    assert.equal(sample(a, 0.5, 0.45, 0), 1, 'cheek/nose is skin');
    assert.equal(sample(a, 0.35, 0.6, 0), 0, 'eye is not skin');
    assert.equal(sample(a, 0.35, 0.72, 0), 0, 'brow is not skin');
    assert.equal(sample(a, 0.5, 0.28, 0), 0, 'mouth is not skin');
    assert.equal(sample(a, 0.03, 0.03, 0), 0, 'outside the face');
    assert.equal(sample(a, 0.35, 0.6, 1), 1, 'eye channel inside the eye');
    assert.equal(sample(a, 0.5, 0.45, 1), 0, 'eye channel off the eye');
    assert.equal(sample(a, 0.5, 0.28, 2), 1, 'teeth channel inside the mouth');
    assert.equal(sample(a, 0.5, 0.33, 2), 0, 'teeth channel off the mouth');
    assert.equal(sample(a, 0.35, 0.53, 3), 1, 'under-eye below the eye');
    assert.equal(sample(a, 0.35, 0.67, 3), 0, 'under-eye not above the eye');
  });

  it('mask B/C mark lips, blush, brows, eyeshadow and eyeliner', async () => {
    const { b, c } = await renderFaceMask(harness, face, W, W, { feather: false });
    assert.equal(sample(b, 0.5, 0.31, 0), 1, 'upper lip');
    assert.equal(sample(b, 0.5, 0.28, 0), 0, 'mouth opening is not lips');
    assert.ok(sample(b, 0.3, 0.42, 1) > 0.9, 'blush at cheek centre');
    assert.equal(sample(b, 0.5, 0.42, 1), 0, 'no blush on the nose');
    assert.equal(sample(b, 0.35, 0.72, 2), 1, 'brow');
    assert.equal(sample(b, 0.35, 0.655, 3), 1, 'eyeshadow above the eye');
    assert.equal(sample(b, 0.35, 0.55, 3), 0, 'no eyeshadow below the eye');
    assert.equal(sample(c, 0.35, 0.633, 0), 1, 'eyeliner on the upper lid');
    assert.equal(sample(c, 0.35, 0.6, 0), 0, 'no eyeliner inside the eye');
    assert.equal(sample(c, 0.35, 0.567, 0), 0, 'no eyeliner on the lower lid');
  });

  it('each makeup and detail effect changes only its own region', async () => {
    await renderFaceMask(harness, face, W, W);
    const base = createImage(W, W, () => [0.82, 0.62, 0.52]);
    const off = await renderBeauty(harness, base, {}, { masks: true });
    assert.ok(maxChannelDifference(base, off) <= 1, 'masks alone changed the image');

    const regions = {
      uLipstick: [0.5, 0.31],
      uBlush: [0.3, 0.42],
      uEyebrows: [0.35, 0.72],
      uEyeshadow: [0.35, 0.66],
      uEyeliner: [0.35, 0.633],
      uEyeBrightening: [0.35, 0.6],
      uTeethWhitening: [0.5, 0.28],
      uDarkCircles: [0.35, 0.53],
    };
    const elsewhere = [0.5, 0.9];
    for (const [uniform, [u, v]] of Object.entries(regions)) {
      const out = await renderBeauty(harness, base, { [uniform]: 1 }, { masks: true });
      const changed = Math.abs(sample(out, u, v, 0) - sample(base, u, v, 0)) +
        Math.abs(sample(out, u, v, 1) - sample(base, u, v, 1)) +
        Math.abs(sample(out, u, v, 2) - sample(base, u, v, 2));
      const leaked = Math.abs(sample(out, ...elsewhere, 0) - sample(base, ...elsewhere, 0));
      assert.ok(changed > 0.03, `${uniform} had no visible effect (${changed})`);
      assert.ok(leaked < 0.005, `${uniform} leaked outside its region (${leaked})`);
    }
  });

  it('lipstick takes the hue of the chosen colour', async () => {
    await renderFaceMask(harness, face, W, W);
    const base = createImage(W, W, () => [0.75, 0.5, 0.45]);
    const out = await renderBeauty(harness, base, { uLipstick: 1, uLipColor: [0.8, 0.05, 0.25] }, { masks: true });
    const r = sample(out, 0.5, 0.31, 0);
    const g = sample(out, 0.5, 0.31, 1);
    assert.ok(r - g > sample(base, 0.5, 0.31, 0) - sample(base, 0.5, 0.31, 1) + 0.1, 'lips are not redder');
  });
});

describe('colour lookup tables', () => {
  let harness;

  before(async () => {
    harness = await GlHarness.launch();
    await compileAll(harness);
  });

  after(async () => {
    await harness?.close();
  });

  it('identity LUT reproduces the input', async () => {
    await harness.upload('lut', buildLut((rgb) => rgb));
    const input = createImage(64, 64, (x, y) => [x / 63, y / 63, ((x + y) % 64) / 63]);
    const output = await renderBeauty(harness, input, { uLutIntensity: 1 }, { lut: 'lut' });
    assert.ok(maxChannelDifference(input, output) <= 3, `max diff ${maxChannelDifference(input, output)}`);
  });

  it('a monochrome LUT desaturates, scaled by intensity', async () => {
    await harness.upload('lut', buildLut(([r, g, b]) => {
      const y = 0.299 * r + 0.587 * g + 0.114 * b;
      return [y, y, y];
    }));
    const input = createImage(32, 32, () => [0.8, 0.3, 0.2]);
    const full = await renderBeauty(harness, input, { uLutIntensity: 1 }, { lut: 'lut' });
    const half = await renderBeauty(harness, input, { uLutIntensity: 0.5 }, { lut: 'lut' });
    const spread = (img) => img.data[0] - img.data[2];
    assert.ok(spread(full) <= 3, 'not grey at full intensity');
    assert.ok(Math.abs(spread(half) - spread(input) / 2) <= 4, 'intensity is not linear');
  });
});
