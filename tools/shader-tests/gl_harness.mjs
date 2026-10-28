// Headless WebGL2 harness that executes the production GLSL ES 3.00 shaders
// from the Android engine in Chromium (SwiftShader) and returns pixel data.
// The same source files are loaded by the Android renderer at runtime, so a
// passing test here validates the shader maths that ships on device.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { chromium } from 'playwright';

const here = path.dirname(fileURLToPath(import.meta.url));
export const shaderDir = path.resolve(
  here,
  '../../packages/yuz_beauty_engine/android/src/main/assets/yuz_beauty_engine/shaders',
);

export function loadShader(name) {
  return readFileSync(path.join(shaderDir, name), 'utf8');
}

// Executed inside the browser page.
function pageRuntime() {
  const canvas = document.createElement('canvas');
  const gl = canvas.getContext('webgl2', { preserveDrawingBuffer: true });
  if (!gl) throw new Error('WebGL2 unavailable');

  const quad = new Float32Array([
    -1, -1, 0, 0,
    1, -1, 1, 0,
    -1, 1, 0, 1,
    1, 1, 1, 1,
  ]);
  const vbo = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
  gl.bufferData(gl.ARRAY_BUFFER, quad, gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 16, 0);
  gl.enableVertexAttribArray(1);
  gl.vertexAttribPointer(1, 2, gl.FLOAT, false, 16, 8);

  const programs = new Map();

  function compile(type, source) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      throw new Error(`compile failed: ${gl.getShaderInfoLog(shader)}`);
    }
    return shader;
  }

  window.__compileProgram = (name, vertexSource, fragmentSource) => {
    const program = gl.createProgram();
    gl.attachShader(program, compile(gl.VERTEX_SHADER, vertexSource));
    gl.attachShader(program, compile(gl.FRAGMENT_SHADER, fragmentSource));
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      throw new Error(`link failed: ${gl.getProgramInfoLog(program)}`);
    }
    programs.set(name, program);
    return true;
  };

  const textures = new Map();

  function createTexture(width, height, data) {
    const texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    return texture;
  }

  window.__uploadTexture = (name, width, height, bytes) => {
    textures.set(name, { texture: createTexture(width, height, new Uint8Array(bytes)), width, height });
    return true;
  };

  // pass = { program, inputs: {uniformName: textureName}, uniforms: {...},
  //          output | outputs: [names], width, height, blendMax, clear }
  window.__runPass = (pass) => {
    const program = programs.get(pass.program);
    gl.useProgram(program);
    const outputNames = pass.outputs ?? [pass.output];
    const fbo = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
    outputNames.forEach((name, index) => {
      let target = textures.get(name);
      if (!target || target.width !== pass.width || target.height !== pass.height) {
        target = { texture: createTexture(pass.width, pass.height, null), width: pass.width, height: pass.height };
        textures.set(name, target);
      }
      gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0 + index, gl.TEXTURE_2D, target.texture, 0);
    });
    gl.drawBuffers(outputNames.map((_, index) => gl.COLOR_ATTACHMENT0 + index));
    gl.viewport(0, 0, pass.width, pass.height);
    if (pass.clear) {
      gl.clearColor(...pass.clear);
      gl.clear(gl.COLOR_BUFFER_BIT);
    }
    if (pass.blendMax) {
      gl.enable(gl.BLEND);
      gl.blendEquation(gl.MAX);
    } else {
      gl.disable(gl.BLEND);
    }

    let unit = 0;
    for (const [uniformName, textureName] of Object.entries(pass.inputs ?? {})) {
      gl.activeTexture(gl.TEXTURE0 + unit);
      gl.bindTexture(gl.TEXTURE_2D, textures.get(textureName).texture);
      gl.uniform1i(gl.getUniformLocation(program, uniformName), unit);
      unit += 1;
    }
    const identity = new Float32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
    gl.uniformMatrix4fv(gl.getUniformLocation(program, 'uTexMatrix'), false, identity);
    for (const [uniformName, value] of Object.entries(pass.uniforms ?? {})) {
      const location = gl.getUniformLocation(program, uniformName);
      if (location === null) throw new Error(`missing uniform ${uniformName}`);
      if (typeof value === 'number') gl.uniform1f(location, value);
      else if (value.vec2Array) gl.uniform2fv(location, new Float32Array(value.vec2Array));
      else if (value.vec4Array) gl.uniform4fv(location, new Float32Array(value.vec4Array));
      else if (value.length === 2) gl.uniform2f(location, value[0], value[1]);
      else if (value.length === 3) gl.uniform3f(location, value[0], value[1], value[2]);
      else if (value.length === 4) gl.uniform4f(location, value[0], value[1], value[2], value[3]);
      else throw new Error(`unsupported uniform ${uniformName}`);
    }
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    gl.disable(gl.BLEND);
    gl.deleteFramebuffer(fbo);
    const error = gl.getError();
    if (error !== gl.NO_ERROR) throw new Error(`GL error ${error}`);
    return true;
  };

  window.__readTexture = (name) => {
    const target = textures.get(name);
    const fbo = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, target.texture, 0);
    const out = new Uint8Array(target.width * target.height * 4);
    gl.readPixels(0, 0, target.width, target.height, gl.RGBA, gl.UNSIGNED_BYTE, out);
    gl.deleteFramebuffer(fbo);
    return Array.from(out);
  };
}

export class GlHarness {
  static async launch() {
    const browser = await chromium.launch({
      args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
    });
    const page = await browser.newPage();
    await page.setContent('<!doctype html><html><body></body></html>');
    await page.evaluate(`(${pageRuntime.toString()})()`);
    return new GlHarness(browser, page);
  }

  constructor(browser, page) {
    this.browser = browser;
    this.page = page;
  }

  compile(name, vertexFile, fragmentFile) {
    return this.page.evaluate(
      ([n, v, f]) => window.__compileProgram(n, v, f),
      [name, loadShader(vertexFile), loadShader(fragmentFile)],
    );
  }

  upload(name, image) {
    return this.page.evaluate(
      ([n, w, h, bytes]) => window.__uploadTexture(n, w, h, bytes),
      [name, image.width, image.height, Array.from(image.data)],
    );
  }

  run(pass) {
    return this.page.evaluate((p) => window.__runPass(p), pass);
  }

  async read(name, width, height) {
    const data = await this.page.evaluate((n) => window.__readTexture(n), name);
    return { width, height, data: Uint8Array.from(data) };
  }

  close() {
    return this.browser.close();
  }
}
