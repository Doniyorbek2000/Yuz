import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { GlHarness } from './gl_harness.mjs';
import { compileAll, renderBeauty, renderFaceMask } from './beauty_pipeline.mjs';
import {
  NON_SKIN_BLUE,
  SKIN_LIGHT,
  finelyTexturedPatch,
  luma,
  lumaStats,
  maxChannelDifference,
  noisyPatch,
  skinEdge,
} from './images.mjs';

const SIZE = 96;
const OFF = { skinSmoothing: 0, texturePreservation: 0, skinBrightening: 0 };
const FULL_SMOOTH = { skinSmoothing: 1, texturePreservation: 0, skinBrightening: 0 };

function circle(cx, cy, radius, count) {
  return Array.from({ length: count }, (_, i) => {
    const angle = (i / count) * Math.PI * 2;
    return [cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius];
  });
}

describe('beauty shaders (GLSL ES 3.00, WebGL2/SwiftShader)', () => {
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
    const output = await renderBeauty(harness, input, OFF);
    assert.ok(maxChannelDifference(input, output) <= 1, 'output deviates from input');
  });

  it('removes most noise variance from skin', async () => {
    const input = noisyPatch(SIZE, SIZE, SKIN_LIGHT, 0.04, 2);
    const output = await renderBeauty(harness, input, FULL_SMOOTH);
    const before = lumaStats(input);
    const afterStats = lumaStats(output);
    assert.ok(
      afterStats.variance < before.variance * 0.35,
      `variance ${afterStats.variance} not < 35% of ${before.variance}`,
    );
    assert.ok(Math.abs(afterStats.mean - before.mean) < 0.01, 'mean skin tone shifted');
  });

  it('leaves non-skin colours untouched', async () => {
    const input = noisyPatch(SIZE, SIZE, NON_SKIN_BLUE, 0.04, 3);
    const output = await renderBeauty(harness, input, {
      skinSmoothing: 1,
      texturePreservation: 0,
      skinBrightening: 1,
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
    const preserved = await renderBeauty(harness, input, {
      skinSmoothing: 1,
      texturePreservation: 1,
      skinBrightening: 0,
    });
    const original = lumaStats(input).variance;
    const flat = lumaStats(flattened).variance;
    const kept = lumaStats(preserved).variance;
    assert.ok(flat < original * 0.5, `smoothing did not flatten texture (${flat} vs ${original})`);
    assert.ok(kept > original * 0.6, `texture not preserved (${kept} vs ${original})`);
  });

  it('brightening lifts skin luma', async () => {
    const input = noisyPatch(SIZE, SIZE, SKIN_LIGHT, 0.0, 5);
    const output = await renderBeauty(harness, input, {
      skinSmoothing: 0,
      texturePreservation: 0,
      skinBrightening: 1,
    });
    const delta = lumaStats(output).mean - lumaStats(input).mean;
    assert.ok(delta > 0.03, `brightening too weak: ${delta}`);
    assert.ok(delta < 0.15, `brightening too strong: ${delta}`);
  });

  it('face mask covers the oval and excludes eyes, brows and lips', async () => {
    const polygons = {
      faceOval: circle(0.5, 0.5, 0.4, 36),
      leftEye: circle(0.35, 0.6, 0.06, 16),
      rightEye: circle(0.65, 0.6, 0.06, 16),
      leftBrow: circle(0.35, 0.75, 0.04, 10),
      rightBrow: circle(0.65, 0.75, 0.04, 10),
      lips: circle(0.5, 0.3, 0.07, 20),
    };
    const mask = await renderFaceMask(harness, polygons, 64, 64);
    const at = (u, v) => mask.data[(Math.floor(v * 64) * 64 + Math.floor(u * 64)) * 4] / 255;
    assert.equal(at(0.5, 0.45), 1, 'cheek/nose area must be skin');
    assert.equal(at(0.35, 0.6), 0, 'left eye must be excluded');
    assert.equal(at(0.65, 0.6), 0, 'right eye must be excluded');
    assert.equal(at(0.35, 0.75), 0, 'left brow must be excluded');
    assert.equal(at(0.5, 0.3), 0, 'lips must be excluded');
    assert.equal(at(0.05, 0.05), 0, 'outside the oval must be excluded');
  });

  it('face mask restricts smoothing to the face region', async () => {
    const polygons = {
      faceOval: [[0, 0], [0.5, 0], [0.5, 1], [0, 1], ...Array(32).fill([0, 1])],
      leftEye: Array(16).fill([2, 2]),
      rightEye: Array(16).fill([2, 2]),
      leftBrow: Array(10).fill([2, 2]),
      rightBrow: Array(10).fill([2, 2]),
      lips: Array(20).fill([2, 2]),
    };
    await renderFaceMask(harness, polygons, SIZE, SIZE);
    const input = noisyPatch(SIZE, SIZE, SKIN_LIGHT, 0.04, 6);
    const output = await renderBeauty(harness, input, FULL_SMOOTH, 'faceMaskBlurred');
    const half = (image, left) => {
      const crop = { width: SIZE / 2 - 16, height: SIZE - 16, data: new Uint8Array((SIZE / 2 - 16) * (SIZE - 16) * 4) };
      for (let y = 0; y < crop.height; y += 1) {
        for (let x = 0; x < crop.width; x += 1) {
          const sx = (left ? 4 : SIZE / 2 + 12) + x;
          const src = ((y + 8) * SIZE + sx) * 4;
          crop.data.set(image.data.subarray(src, src + 4), (y * crop.width + x) * 4);
        }
      }
      return crop;
    };
    const faceSide = lumaStats(half(output, true), 0).variance;
    const backgroundSide = lumaStats(half(output, false), 0).variance;
    const reference = lumaStats(half(input, false), 0).variance;
    assert.ok(faceSide < reference * 0.4, 'face side not smoothed');
    assert.ok(backgroundSide > reference * 0.95, 'background side was smoothed');
  });
});
