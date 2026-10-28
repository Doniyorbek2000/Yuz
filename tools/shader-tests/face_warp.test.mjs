import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { GlHarness } from './gl_harness.mjs';
import { compileAll, renderWarp } from './beauty_pipeline.mjs';
import { createImage, maxChannelDifference } from './images.mjs';

const SIZE = 128;

/** Black frame with a white disc of radius r at (cx, cy) in uv space (v up). */
function disc(cx, cy, r) {
  return createImage(SIZE, SIZE, (x, y) => {
    const u = (x + 0.5) / SIZE;
    const v = (y + 0.5) / SIZE;
    return Math.hypot(u - cx, v - cy) < r ? [1, 1, 1] : [0, 0, 0];
  });
}

function whiteArea(image) {
  let count = 0;
  for (let i = 0; i < image.data.length; i += 4) if (image.data[i] > 127) count += 1;
  return count;
}

function centroidX(image) {
  let sum = 0;
  let count = 0;
  for (let y = 0; y < image.height; y += 1) {
    for (let x = 0; x < image.width; x += 1) {
      if (image.data[(y * image.width + x) * 4] > 127) {
        sum += x;
        count += 1;
      }
    }
  }
  return sum / count / image.width;
}

describe('face reshape warp (GLSL ES 3.00)', () => {
  let harness;

  before(async () => {
    harness = await GlHarness.launch();
    await compileAll(harness);
  });

  after(async () => {
    await harness?.close();
  });

  it('no warps is an exact identity', async () => {
    const input = disc(0.5, 0.5, 0.1);
    const output = await renderWarp(harness, input, []);
    assert.equal(maxChannelDifference(input, output), 0);
  });

  it('zero-strength warps are an identity', async () => {
    const input = disc(0.5, 0.5, 0.1);
    const output = await renderWarp(harness, input, [
      { cx: 0.5, cy: 0.5, radius: 0.3, kind: 0, strength: 0 },
      { cx: 0.5, cy: 0.5, radius: 0.3, kind: 1, dx: 0, dy: 0 },
    ]);
    assert.ok(maxChannelDifference(input, output) <= 1);
  });

  it('bulge enlarges a feature (eye enlargement)', async () => {
    const input = disc(0.5, 0.5, 0.08);
    const output = await renderWarp(harness, input, [{ cx: 0.5, cy: 0.5, radius: 0.3, kind: 0, strength: 0.25 }]);
    const ratio = whiteArea(output) / whiteArea(input);
    assert.ok(ratio > 1.4 && ratio < 2.2, `area ratio ${ratio}`);
  });

  it('translate moves content in the offset direction (face slimming)', async () => {
    const input = disc(0.3, 0.5, 0.06);
    const output = await renderWarp(harness, input, [{ cx: 0.3, cy: 0.5, radius: 0.25, kind: 1, dx: 0.05, dy: 0 }]);
    const shift = centroidX(output) - centroidX(input);
    assert.ok(shift > 0.035 && shift < 0.06, `shift ${shift}`);
  });

  it('warps do not affect pixels outside their radius', async () => {
    const input = createImage(SIZE, SIZE, (x, y) => [x / SIZE, y / SIZE, 0.5]);
    const output = await renderWarp(harness, input, [{ cx: 0.5, cy: 0.5, radius: 0.1, kind: 0, strength: 0.3 }]);
    const corner = (img) => img.data.subarray(0, 4 * 10);
    assert.deepEqual(Array.from(corner(output)), Array.from(corner(input)));
  });
});
