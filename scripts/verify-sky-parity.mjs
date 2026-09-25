// bun scripts/verify-sky-parity.mjs /path/to/reference/gradient.html [timeline.json]
// Uses an explicitly supplied, inspected reference. No downloads or dependency install.
import { readFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const referencePath = process.argv[2];
if (!referencePath) throw new Error('Usage: bun scripts/verify-sky-parity.mjs gradient.html [timeline.json]');
const html = readFileSync(referencePath, 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
const wiring = script?.indexOf('const el = function');
if (!script || wiring < 0) throw new Error('Expected the reviewed gradient.html reference layout');
const context = vm.createContext({});
vm.runInContext(script.slice(0, wiring), context, { timeout: 2000 });
const fixture = vm.runInContext('buildFixture()', context);
const base = {
  elevationDegrees: -1, azimuthDegrees: 90,
  cloudTotalPct: 38, cloudLowPct: 9, cloudMidPct: 15, cloudHighPct: 48,
  visibilityMeters: 24140, relativeHumidityPct: 72, precipitationMillimeters: 0,
  aerosolOpticalDepth: 0.18, dustUgM3: 1.2, pm25UgM3: 9.1,
};
const regimes = [
  ['twilight', {}],
  ['clear sunrise', { cloudTotalPct: 0, cloudLowPct: 0, cloudMidPct: 0, cloudHighPct: 0 }],
  ['cloud bell below range', { cloudHighPct: 5 }],
  ['cloud bell above range', { cloudHighPct: 95 }],
  ['overcast midday', { elevationDegrees: 28, cloudTotalPct: 100, cloudLowPct: 90, cloudHighPct: 100 }],
  ['clear noon', { elevationDegrees: 60, cloudTotalPct: 3, cloudHighPct: 0 }],
  ['rain', { precipitationMillimeters: 2, visibilityMeters: 3500, relativeHumidityPct: 98 }],
  ['haze', { aerosolOpticalDepth: 0.5, dustUgM3: 30, pm25UgM3: 40, visibilityMeters: 8000 }],
  ['night', { elevationDegrees: -25 }],
];
const samples = regimes.map(([, values]) => ({ ...base, ...values }));
const clean = ({ stops, ramp, glow, cloudBands }) => JSON.parse(JSON.stringify({ stops, ramp, glow, cloudBands }));
context.samples = samples;
const expectedSamples = vm.runInContext('samples.map(generateSky)', context).map(clean);

const buildDirectory = mkdtempSync(join(tmpdir(), 'youki-sky-parity-'));
const executable = join(buildDirectory, 'sky-parity');
const frontend = join(root, 'frontend/YoukiApp');
const compile = spawnSync('/usr/bin/xcrun', [
  'swiftc', '-module-cache-path', join(buildDirectory, 'module-cache'),
  join(frontend, 'SkyGradient.swift'), join(frontend, 'SkyDayTimelineAPI.swift'),
  join(root, 'scripts/sky-parity-main.swift'), '-o', executable,
], { encoding: 'utf8', env: { ...process.env, DEVELOPER_DIR: '/Applications/Xcode.app/Contents/Developer' } });
if (compile.status !== 0) throw new Error(compile.stderr || compile.stdout);

const timelines = [['reference fixture', fixture]];
if (process.argv[3]) timelines.push(['live backend', JSON.parse(readFileSync(process.argv[3], 'utf8'))]);
let passed = 0;
for (const [name, timeline] of timelines) {
  // The reference intentionally samples at whole minutes; use the same minute
  // in Swift even when the backend's milestone has nonzero seconds.
  const times = ['00:00', '05:16', '05:30', '12:00', '17:45', '23:59'].map(t => `${timeline.targetDateIso}T${t}:00`);
  for (const key of ['civilDawnIso', 'sunriseIso', 'solarNoonIso', 'sunsetIso']) {
    if (timeline.milestones[key]) times.push(timeline.milestones[key].slice(0, 16) + ':00');
  }
  context.timeline = timeline;
  context.times = times;
  vm.runInContext(`globalThis.state = {
    solar: timeline.solar.map(flattenSolar).sort((a,b) => a.minutes-b.minutes),
    weather: timeline.weather.map(flattenWeather).sort((a,b) => a.minutes-b.minutes),
    air: timeline.airQuality.map(flattenAir).sort((a,b) => a.minutes-b.minutes)
  }`, context);
  const expectedTimeline = vm.runInContext('times.map(t => generateSky(sampleAt(isoToMinutes(t))))', context).map(clean);
  const result = spawnSync(executable, [], {
    input: JSON.stringify({ samples, timeline, times }), encoding: 'utf8',
  });
  if (result.status !== 0) throw new Error(result.stderr || 'Swift runner failed');
  const outputs = JSON.parse(result.stdout);
  const expected = [...expectedSamples, ...expectedTimeline];
  const labels = [...regimes.map(([label]) => label), ...times];
  outputs.forEach((output, index) => {
    assert.deepStrictEqual(output, expected[index], `${name}: ${labels[index]}`);
    passed++;
  });
  assert.equal(outputs.length, expected.length);
  console.log(`PASS ${name}: ${expected.length} exact appearance comparisons`);
}
console.log(`PASS ${passed} comparisons: nine stops, ramp, glow, and cloud geometry`);
console.log(`Reference SHA-256: ${createHash('sha256').update(html).digest('hex')}`);
