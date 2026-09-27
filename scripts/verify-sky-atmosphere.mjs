// bun scripts/verify-sky-atmosphere.mjs [--render-with /path/to/test/node_modules]
// Optional render dependencies: @napi-rs/canvas and jsdom. No downloads here.
import assert from 'node:assert/strict';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve, dirname, join } from 'node:path';
import { createRequire } from 'node:module';
import vm from 'node:vm';
import { SkyGradientEngine } from '../server/src/infrastructure/engines/sky-gradient-engine.ts';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = name => readFileSync(join(root, 'docs/sky-simulator', name), 'utf8');
const context = vm.createContext({});
vm.runInContext(source('gradient.js'), context);
vm.runInContext(source('atmosphere.js'), context);
const { generateScene, elevationAt } = context.YoukiAtmosphere;
const clean = x => JSON.parse(JSON.stringify(x));
const base = { elevationDegrees: 35, cloudTotalPct: 45, cloudLowPct: 20, cloudMidPct: 25, cloudHighPct: 50,
  visibilityMeters: 24000, relativeHumidityPct: 65, precipitationMillimeters: 0,
  aerosolOpticalDepth: .16, dustUgM3: 0, pm25UgM3: 0, directNormalWm2: 500,
  globalHorizontalWm2: 600, diffuseHorizontalWm2: 120 };
let comparisons = 0;
const reference = new SkyGradientEngine();
for (const elevation of [-25, -6, -3, -.267, 0, .267, 5, 35, 60]) {
  for (const cover of [0, 12, 50, 100]) {
    const observation = { ...base, elevationDegrees: elevation, cloudTotalPct: cover, cloudLowPct: cover };
    const scene = generateScene(observation);
    const expected = reference.generate(observation);
    for (const key of ['stops', 'ramp', 'glow', 'cloudBands']) assert.deepEqual(clean(scene.base[key]), clean(expected[key]));
    assert.equal(scene.base.stops.length, 9);
    for (const v of [scene.direct, scene.sun.opacity, scene.sun.limb, scene.horizonGlow, scene.haze]) assert.ok(Number.isFinite(v) && v >= 0 && v <= 1);
    comparisons++;
  }
}
const night = generateScene({ ...base, elevationDegrees: -20, directNormalWm2: 1000 });
assert.equal(night.direct, 0); assert.equal(night.horizonGlow, 0); assert.equal(night.daylight, 0);
const dawn = generateScene({ ...base, elevationDegrees: -3 });
assert.equal(dawn.direct, 0); assert.ok(dawn.horizonGlow > 0);
assert.equal(generateScene({ ...base, directNormalWm2: 0 }).direct, 0);
assert.equal(generateScene({ ...base, directNormalWm2: null }).quality, 'cloud-estimated');
const missing = { ...base, directNormalWm2: null, cloudTotalPct: null, cloudLowPct: null, cloudMidPct: null, cloudHighPct: null };
assert.equal(generateScene(missing).quality, 'unavailable'); assert.equal(generateScene(missing).direct, 0); assert.equal(generateScene(missing).layers.length, 0);
assert.equal(generateScene({ ...missing, cloudTotalPct: 70 }).layers[0].id, 'generic');
assert.equal(generateScene({ ...base, globalHorizontalWm2: 0 }).diffuse, null);
assert.equal(generateScene({ ...base, diffuseHorizontalWm2: 900 }).diffuse, null);
assert.equal(generateScene({ ...base, visibilityMeters: 100 }).direct, 0);
assert.equal(generateScene({ ...base, cloudLowPct: 100 }).direct, 0);
assert.equal(generateScene({ ...base, elevationDegrees: -.267 }).sun.limb, 0);
assert.equal(generateScene({ ...base, elevationDegrees: 0 }).sun.limb, .5);
assert.equal(generateScene({ ...base, elevationDegrees: .267 }).sun.limb, 1);
assert.ok(Math.abs(elevationAt(360) + .267) < 1e-9);
assert.ok(Math.abs(elevationAt(1080) + .267) < 1e-9);
let prior = 1;
for (const cloudLowPct of [0, 40, 80, 90, 95, 100]) {
  const direct = generateScene({ ...base, directNormalWm2: null, cloudLowPct }).direct;
  assert.ok(direct <= prior); prior = direct;
}
assert.deepEqual(clean(generateScene(base)), clean(generateScene(base)));
assert.deepEqual(clean(generateScene(base).base), clean(generateScene({ ...base, directNormalWm2: 0 }).base));
console.log(`PASS ${comparisons} exact gradient parity cases; geometry, missingness, monotonicity and finite-output invariants`);

if (!process.argv.includes('--render-with')) {
  console.log('Canvas/DOM checks not requested; use --render-with to enable.');
  process.exit(0);
}
const dependencyRoot = process.argv[process.argv.indexOf('--render-with') + 1];
assert.ok(dependencyRoot, 'Supply a node_modules directory after --render-with');
const requireTest = createRequire(join(resolve(dependencyRoot), '../package.json'));
const { createCanvas } = requireTest('@napi-rs/canvas');
const { JSDOM } = requireTest('jsdom');
const html = readFileSync(join(root, 'docs/sky-atmosphere-simulator.html'), 'utf8');
const dom = new JSDOM(html, { runScripts: 'outside-only', url: 'http://localhost/sky-atmosphere-simulator.html' });
const { window } = dom, doc = window.document;
const backing = new WeakMap();
function canvasFor(element) {
  if (!backing.has(element)) {
    const canvas = createCanvas(element.width, element.height), ctx = canvas.getContext('2d');
    const drawImage = ctx.drawImage.bind(ctx);
    ctx.drawImage = (image, ...args) => drawImage(image instanceof window.HTMLCanvasElement ? canvasFor(image) : image, ...args);
    backing.set(element, canvas);
  }
  const canvas = backing.get(element);
  if (canvas.width !== element.width) canvas.width = element.width;
  if (canvas.height !== element.height) canvas.height = element.height;
  return canvas;
}
window.HTMLCanvasElement.prototype.getContext = function () { return canvasFor(this).getContext('2d'); };
window.HTMLCanvasElement.prototype.toDataURL = function () { return canvasFor(this).toDataURL('image/png'); };
window.HTMLElement.prototype.getBoundingClientRect = () => ({ width: 360, height: 480 });
window.ResizeObserver = class { observe() {} };
let pending = [], intervals = [], downloads = [];
window.requestAnimationFrame = callback => { pending.push(callback); return pending.length; };
window.setInterval = callback => { intervals.push(callback); return intervals.length; };
window.clearInterval = () => { intervals = []; };
window.HTMLAnchorElement.prototype.click = function () { downloads.push(this.download); };
window.URL.createObjectURL = () => 'blob:test'; window.URL.revokeObjectURL = () => {};
for (const file of ['gradient.js', 'atmosphere.js', 'studio.js']) window.eval(source(file));
function flush() { const queue = pending; pending = []; queue.forEach(callback => callback()); }
function change(id, v, type = 'input') { doc.getElementById(id).value = v; doc.getElementById(id).dispatchEvent(new window.Event(type)); flush(); }
function model() { return JSON.parse(doc.getElementById('scene-json').textContent); }
flush();
assert.equal(doc.getElementById('clock').textContent, '17:40');
assert.equal(doc.querySelectorAll('[data-preset]').length, 8);
const outputDirectory = '/tmp/youki-sky-verification-output'; mkdirSync(outputDirectory, { recursive: true });
const contact = createCanvas(4 * 360, 2 * 535), contactContext = contact.getContext('2d');
contactContext.fillStyle = '#f5f2eb'; contactContext.fillRect(0, 0, contact.width, contact.height);
let index = 0, totalRenderMs = 0;
for (const button of doc.querySelectorAll('[data-preset]')) {
  const start = performance.now(); button.click(); flush(); totalRenderMs += performance.now() - start;
  const canvas = canvasFor(doc.getElementById('enhanced'));
  const x = (index % 4) * 360, y = Math.floor(index / 4) * 535;
  contactContext.drawImage(canvas, x, y + 35);
  contactContext.fillStyle = '#292d29'; contactContext.font = '16px sans-serif';
  contactContext.fillText(button.textContent, x + 14, y + 24);
  writeFileSync(join(outputDirectory, button.dataset.preset + '.png'), canvas.toBuffer('image/png'));
  index++;
}
writeFileSync(join(outputDirectory, 'contact-sheet.png'), contact.toBuffer('image/png'));
doc.querySelector('[data-preset="clear"]').click(); flush();
change('sunlight', 0); assert.equal(model().scene.direct, 0);
change('data-mode', 'clouds', 'change'); assert.equal(model().scene.quality, 'cloud-estimated'); assert.ok(doc.getElementById('sunlight').disabled);
change('data-mode', 'missing', 'change'); assert.equal(model().scene.quality, 'unavailable'); assert.equal(model().scene.layers.length, 0);
doc.getElementById('reset').click(); flush(); assert.equal(model().scene.quality, 'radiation-supported'); assert.equal(doc.getElementById('sunlight').disabled, false);
change('time', 349); assert.equal(model().scene.direct, 0); assert.ok(model().scene.horizonGlow > 0);
change('time', 1320); assert.equal(model().scene.horizonGlow, 0);
doc.getElementById('focus').click(); flush(); assert.ok(doc.getElementById('previews').classList.contains('focused'));
doc.getElementById('show-overlay').checked = true; doc.getElementById('show-overlay').dispatchEvent(new window.Event('change')); assert.equal(doc.querySelector('.mock-overlay').hidden, false);
for (const key of ['sun', 'clouds', 'haze']) { doc.getElementById('show-' + key).checked = false; doc.getElementById('show-' + key).dispatchEvent(new window.Event('change')); }
flush(); assert.deepEqual(model().visibleLayers, { sun: false, clouds: false, haze: false });
assert.deepEqual(canvasFor(doc.getElementById('baseline')).toBuffer('image/png'), canvasFor(doc.getElementById('enhanced')).toBuffer('image/png'));
doc.getElementById('play').click(); assert.equal(intervals.length, 1); const before = doc.getElementById('time').value; intervals[0](); flush(); assert.notEqual(doc.getElementById('time').value, before);
doc.getElementById('play').click(); assert.equal(intervals.length, 0);
doc.getElementById('save-image').click(); doc.getElementById('save-json').click(); assert.equal(downloads.length, 2); assert.ok(downloads[0].endsWith('.png')); assert.equal(downloads[1], 'youki-sky-scene.json');
console.log(`PASS Canvas render for 8 presets (${Math.round(totalRenderMs / 8)} ms mean, software raster; not a browser benchmark)`);
console.log('PASS DOM interactions: sliders, time, availability, reset, focus, overlay, layer equality, play/pause, export');
console.log(`Render artifacts: ${outputDirectory}`);
dom.window.close();
