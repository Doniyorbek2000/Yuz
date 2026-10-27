// Mirrors the pass sequence of BeautyRenderer.kt (Android) so the tests run
// the shipped shaders in the shipped order with the shipped constants.
import { solid } from './images.mjs';

// Keep in sync with BeautyRenderer.kt / BeautyShaders.swift.
export const RANGE_SIGMA = 0.10;
export const MASK_BLUR_ITERATIONS = 2;

export async function compileAll(harness) {
  await harness.compile('blur', 'fullscreen.vert', 'edge_preserving_blur.frag');
  await harness.compile('gauss', 'fullscreen.vert', 'gaussian_blur.frag');
  await harness.compile('mask', 'fullscreen.vert', 'face_mask.frag');
  await harness.compile('composite', 'fullscreen.vert', 'beauty_composite.frag');
}

export async function smooth(harness, input, width, height) {
  await harness.run({
    program: 'blur',
    inputs: { uInput: input },
    uniforms: { uTexelStep: [1 / width, 0], uRangeSigma: RANGE_SIGMA },
    output: 'smoothH',
    width,
    height,
  });
  await harness.run({
    program: 'blur',
    inputs: { uInput: 'smoothH' },
    uniforms: { uTexelStep: [0, 1 / height], uRangeSigma: RANGE_SIGMA },
    output: 'smoothed',
    width,
    height,
  });
  return 'smoothed';
}

export async function renderBeauty(harness, image, params, faceMaskTexture = null) {
  const { width, height } = image;
  await harness.upload('original', image);
  await smooth(harness, 'original', width, height);
  if (!faceMaskTexture) {
    await harness.upload('faceMask', solid(4, 4, 1));
  }
  await harness.run({
    program: 'composite',
    inputs: {
      uOriginal: 'original',
      uSmoothed: 'smoothed',
      uFaceMask: faceMaskTexture ?? 'faceMask',
    },
    uniforms: {
      uSkinSmoothing: params.skinSmoothing,
      uTexturePreservation: params.texturePreservation,
      uSkinBrightening: params.skinBrightening,
      uFaceMaskEnabled: faceMaskTexture ? 1 : 0,
    },
    output: 'result',
    width,
    height,
  });
  return harness.read('result', width, height);
}

/** Renders one face's polygons into 'faceMaskRaw' and feathers into 'faceMaskBlurred'. */
export async function renderFaceMask(harness, polygons, width, height) {
  await harness.run({
    program: 'mask',
    uniforms: {
      uFaceOval: { vec2Array: polygons.faceOval.flat() },
      uLeftEye: { vec2Array: polygons.leftEye.flat() },
      uRightEye: { vec2Array: polygons.rightEye.flat() },
      uLeftBrow: { vec2Array: polygons.leftBrow.flat() },
      uRightBrow: { vec2Array: polygons.rightBrow.flat() },
      uLips: { vec2Array: polygons.lips.flat() },
    },
    output: 'faceMaskRaw',
    width,
    height,
    clear: [0, 0, 0, 1],
    blendMax: true,
  });
  const raw = await harness.read('faceMaskRaw', width, height);
  let source = 'faceMaskRaw';
  for (let i = 0; i < MASK_BLUR_ITERATIONS; i += 1) {
    await harness.run({
      program: 'gauss',
      inputs: { uInput: source },
      uniforms: { uTexelStep: [1 / width, 0] },
      output: 'maskH',
      width,
      height,
    });
    await harness.run({
      program: 'gauss',
      inputs: { uInput: 'maskH' },
      uniforms: { uTexelStep: [0, 1 / height] },
      output: 'faceMaskBlurred',
      width,
      height,
    });
    source = 'faceMaskBlurred';
  }
  return raw;
}
