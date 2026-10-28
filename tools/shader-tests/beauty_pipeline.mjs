// Mirrors the pass sequence of BeautyRenderer.kt (Android) so the tests run
// the shipped shaders in the shipped order with the shipped constants.
import { createImage, solid } from './images.mjs';

// Keep in sync with BeautyRenderer.kt / MetalBeautyRenderer.swift.
export const RANGE_SIGMA = 0.10;
export const MASK_BLUR_ITERATIONS = 2;
export const LINER_BLUR_ITERATIONS = 1;
export const BASE_BLUR_ITERATIONS = 2;

export const ZERO_PARAMS = {
  uSkinSmoothing: 0,
  uTexturePreservation: 0,
  uSkinBrightening: 0,
  uSkinTone: 0,
  uBlemishReduction: 0,
  uShineReduction: 0,
  uGlow: 0,
  uEyeBrightening: 0,
  uTeethWhitening: 0,
  uDarkCircles: 0,
  uLipstick: 0,
  uBlush: 0,
  uEyebrows: 0,
  uEyeshadow: 0,
  uEyeliner: 0,
  uLipColor: [0.75, 0.1, 0.2],
  uBlushColor: [0.95, 0.45, 0.45],
  uBrowColor: [0.25, 0.17, 0.12],
  uShadowColor: [0.55, 0.35, 0.45],
  uLinerColor: [0.05, 0.04, 0.04],
  uSharpen: 0,
  uLutIntensity: 0,
};

export async function compileAll(harness) {
  await harness.compile('blur', 'fullscreen.vert', 'edge_preserving_blur.frag');
  await harness.compile('gauss', 'fullscreen.vert', 'gaussian_blur.frag');
  await harness.compile('mask', 'fullscreen.vert', 'face_mask.frag');
  await harness.compile('warp', 'fullscreen.vert', 'face_warp.frag');
  await harness.compile('composite', 'fullscreen.vert', 'beauty_composite.frag');
  await harness.upload('blank', solid(4, 4, 0));
}

export async function smooth(harness, input, width, height) {
  for (const [source, output, step] of [
    [input, 'smoothH', [1 / width, 0]],
    ['smoothH', 'smoothed', [0, 1 / height]],
  ]) {
    await harness.run({
      program: 'blur',
      inputs: { uInput: source },
      uniforms: { uTexelStep: step, uRangeSigma: RANGE_SIGMA },
      output,
      width,
      height,
    });
  }
  return 'smoothed';
}

/** Wide plain Gaussian at quarter resolution (2 separable iterations). */
export async function baseBlur(harness, input, width, height) {
  const w = Math.max(1, Math.floor(width / 4));
  const h = Math.max(1, Math.floor(height / 4));
  let source = input;
  for (let i = 0; i < BASE_BLUR_ITERATIONS; i += 1) {
    await harness.run({ program: 'gauss', inputs: { uInput: source }, uniforms: { uTexelStep: [1 / w, 0] }, output: 'baseTmp', width: w, height: h });
    await harness.run({ program: 'gauss', inputs: { uInput: 'baseTmp' }, uniforms: { uTexelStep: [0, 1 / h] }, output: 'baseBlur', width: w, height: h });
    source = 'baseBlur';
  }
  return 'baseBlur';
}

/** Plain Gaussian at half resolution (1 separable iteration) for sharpening. */
export async function detailBlur(harness, input, width, height) {
  const w = Math.max(1, Math.floor(width / 2));
  const h = Math.max(1, Math.floor(height / 2));
  await harness.run({ program: 'gauss', inputs: { uInput: input }, uniforms: { uTexelStep: [1 / w, 0] }, output: 'detailTmp', width: w, height: h });
  await harness.run({ program: 'gauss', inputs: { uInput: 'detailTmp' }, uniforms: { uTexelStep: [0, 1 / h] }, output: 'detailBlur', width: w, height: h });
  return 'detailBlur';
}

/**
 * Renders the composite. `options.masks` = true uses the masks produced by
 * renderFaceMask(); otherwise colour-only mode. `options.lut` names an
 * uploaded LUT texture.
 */
export async function renderBeauty(harness, image, params, options = {}) {
  const { width, height } = image;
  await harness.upload('original', image);
  await smooth(harness, 'original', width, height);
  await baseBlur(harness, 'original', width, height);
  await detailBlur(harness, 'original', width, height);
  const masks = options.masks ?? false;
  await harness.run({
    program: 'composite',
    inputs: {
      uOriginal: 'original',
      uSmoothed: 'smoothed',
      uBaseBlur: 'baseBlur',
      uDetailBlur: 'detailBlur',
      uMaskA: masks ? 'maskA' : 'blank',
      uMaskB: masks ? 'maskB' : 'blank',
      uMaskC: masks ? 'maskC' : 'blank',
      uLut: options.lut ?? 'blank',
    },
    uniforms: { ...ZERO_PARAMS, ...params, uFaceMaskEnabled: masks ? 1 : 0 },
    output: 'result',
    width,
    height,
  });
  return harness.read('result', width, height);
}

export async function renderWarp(harness, image, warps) {
  const { width, height } = image;
  await harness.upload('warpInput', image);
  const a = [];
  const b = [];
  for (let i = 0; i < 16; i += 1) {
    const warp = warps[i];
    a.push(...(warp ? [warp.cx, warp.cy, warp.radius, warp.kind] : [0, 0, 1, 0]));
    b.push(...(warp ? [warp.dx ?? 0, warp.dy ?? 0, warp.strength ?? 0, 0] : [0, 0, 0, 0]));
  }
  await harness.run({
    program: 'warp',
    inputs: { uInput: 'warpInput' },
    uniforms: {
      uWarpA: { vec4Array: a },
      uWarpB: { vec4Array: b },
      uWarpCount: warps.length,
      uAspect: width / height,
    },
    output: 'warped',
    width,
    height,
  });
  return harness.read('warped', width, height);
}

function circle(cx, cy, rx, ry, count) {
  return Array.from({ length: count }, (_, i) => {
    const angle = (i / count) * Math.PI * 2;
    return [cx + Math.cos(angle) * rx, cy + Math.sin(angle) * ry];
  });
}

/**
 * Synthetic face in GL uv space (v up) with the ring layout of
 * FaceMaskGeometry.kt: oval 36, eyes 16+16, brows 10+10, lips 20, mouth 20.
 */
export function syntheticFace() {
  const rings = {
    oval: circle(0.5, 0.5, 0.4, 0.45, 36),
    leftEye: circle(0.35, 0.6, 0.07, 0.03, 16),
    rightEye: circle(0.65, 0.6, 0.07, 0.03, 16),
    leftBrow: circle(0.35, 0.72, 0.08, 0.02, 10),
    rightBrow: circle(0.65, 0.72, 0.08, 0.02, 10),
    lips: circle(0.5, 0.28, 0.1, 0.045, 20),
    mouth: circle(0.5, 0.28, 0.07, 0.02, 20),
  };
  const points = [
    ...rings.oval, ...rings.leftEye, ...rings.rightEye, ...rings.leftBrow, ...rings.rightBrow,
    ...rings.lips, ...rings.mouth,
  ].flat();
  return {
    rings,
    uniforms: {
      uPoints: { vec4Array: points },
      uLeftEyeBox: [0.35, 0.6, 0.07, 0.03],
      uRightEyeBox: [0.65, 0.6, 0.07, 0.03],
      uMouthBox: [0.5, 0.28, 0.1, 0.045],
      uLeftCheek: [0.3, 0.42, 0.09, 0.07],
      uRightCheek: [0.7, 0.42, 0.09, 0.07],
      uFaceBounds: [0.05, 0.0, 0.95, 1.0],
      uVerticalSign: 1,
    },
  };
}

/** Renders one face into maskA/B/C (raw) and feathers them like the engine. */
export async function renderFaceMask(harness, face, width, height, { feather = true } = {}) {
  await harness.run({
    program: 'mask',
    uniforms: face.uniforms,
    outputs: ['maskA', 'maskB', 'maskC'],
    width,
    height,
    clear: [0, 0, 0, 0],
    blendMax: true,
  });
  const raw = {
    a: await harness.read('maskA', width, height),
    b: await harness.read('maskB', width, height),
    c: await harness.read('maskC', width, height),
  };
  if (feather) {
    for (const [name, iterations] of [['maskA', MASK_BLUR_ITERATIONS], ['maskB', MASK_BLUR_ITERATIONS], ['maskC', LINER_BLUR_ITERATIONS]]) {
      for (let i = 0; i < iterations; i += 1) {
        await harness.run({ program: 'gauss', inputs: { uInput: name }, uniforms: { uTexelStep: [1 / width, 0] }, output: 'maskTmp', width, height });
        await harness.run({ program: 'gauss', inputs: { uInput: 'maskTmp' }, uniforms: { uTexelStep: [0, 1 / height] }, output: name, width, height });
      }
    }
  }
  return raw;
}

/**
 * Builds a 512x512 lookup table with the same layout as the Dart generator
 * (ColorLut in yuz_beauty_engine): 8x8 tiles of 64x64, blue selects the
 * tile, red is x and green is y inside a tile, first data row = top.
 */
export function buildLut(transform) {
  return createImage(512, 512, (x, y) => {
    const tile = Math.floor(y / 64) * 8 + Math.floor(x / 64);
    const r = (x % 64) / 63;
    const g = (y % 64) / 63;
    const b = tile / 63;
    return transform([r, g, b]);
  });
}
