/* Pure scene decisions and a deterministic Canvas renderer for the HTML study.
 * Artistic heuristics, not a physical reconstruction or sun-visibility probability.
 * Kept separate from gradient.js so its reference colors remain unchanged. */
(function (root) {
  'use strict';
  const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
  const mix = (a, b, t) => a + (b - a) * t;
  const smooth = (a, b, x) => { const t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t); };
  const valid = x => typeof x === 'number' && Number.isFinite(x) && x >= 0;
  const value = (x, fallback) => valid(x) ? x : fallback;
  const rgb = hex => [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16));
  const blend = (a, b, t) => a.map((v, i) => mix(v, b[i], t));
  const rgba = (color, alpha) => `rgba(${color.map(Math.round).join(',')},${clamp(alpha)})`;
  const defaults = { cloudTotalPct: 0, cloudLowPct: 0, cloudMidPct: 0, cloudHighPct: 0,
    visibilityMeters: 24000, relativeHumidityPct: 60, precipitationMillimeters: 0,
    aerosolOpticalDepth: 0.08, dustUgM3: 0, pm25UgM3: 0 };

  function elevationAt(minutes) {
    // Intentionally synthetic: the demo's nominal sunrise/sunset remain 06/18.
    return 60 * Math.sin((minutes - 360) / 720 * Math.PI) - 0.267;
  }

  function generateScene(input) {
    const e = Number.isFinite(input.elevationDegrees) ? clamp(input.elevationDegrees, -90, 90) : -90;
    const normalized = { elevationDegrees: e, azimuthDegrees: 180 };
    for (const [key, fallback] of Object.entries(defaults)) normalized[key] = value(input[key], fallback);
    const base = root.YoukiGradient.generateSky(normalized);
    const low = valid(input.cloudLowPct) ? clamp(input.cloudLowPct / 100) : null;
    const mid = valid(input.cloudMidPct) ? clamp(input.cloudMidPct / 100) : null;
    const high = valid(input.cloudHighPct) ? clamp(input.cloudHighPct / 100) : null;
    const total = valid(input.cloudTotalPct) ? clamp(input.cloudTotalPct / 100) : null;
    const hasCloud = [low, mid, high, total].some(v => v !== null);
    const hasRadiation = valid(input.directNormalWm2);
    let transmission = 0;
    if ([low, mid, high].every(v => v !== null)) transmission = (1 - .9 * low) * (1 - .6 * mid) * (1 - .25 * high);
    else if (total !== null) transmission = Math.pow(1 - total, 1.5);
    else if (hasCloud) transmission = Math.min(.35, (1 - .9 * (low ?? 0)) * (1 - .6 * (mid ?? 0)) * (1 - .25 * (high ?? 0)));
    const visibilityCap = valid(input.visibilityMeters) ? smooth(200, 5000, input.visibilityMeters) : 1;
    const overcastCap = low === null ? 1 : 1 - smooth(.85, 1, low);
    const limb = smooth(-.267, .267, e);
    const direct = (e <= -.267 ? 0 : (hasRadiation ? smooth(20, 500, input.directNormalWm2) : transmission)) * visibilityCap * overcastCap;
    const diffuse = valid(input.globalHorizontalWm2) && input.globalHorizontalWm2 >= 20 && valid(input.diffuseHorizontalWm2)
      && input.diffuseHorizontalWm2 <= input.globalHorizontalWm2 + 1
      ? clamp(input.diffuseHorizontalWm2 / input.globalHorizontalWm2) : null;
    const warmth = Math.exp(-Math.pow((e + 1) / 10, 2)) * smooth(-6, -2, e);
    const daylight = smooth(-6, 8, e);
    const quality = hasRadiation ? 'radiation-supported' : hasCloud ? 'cloud-estimated' : 'unavailable';
    const layers = [
      { id: 'high', cover: high, opacity: .42, center: .26, spread: .28 },
      { id: 'mid', cover: mid, opacity: .72, center: .48, spread: .24 },
      { id: 'low', cover: low, opacity: .93, center: .63, spread: .32 }
    ].filter(layer => layer.cover !== null && layer.cover > 0);
    if (low === null && mid === null && high === null && total !== null && total > 0) {
      layers.push({ id: 'generic', cover: total, opacity: .8, center: .5, spread: .45 });
    }
    return { base, elevation: e, quality, direct, diffuse, warmth, daylight,
      sun: { x: .5, y: .86 - .72 * clamp(e / 90), radius: .025, limb,
        opacity: direct, softness: diffuse ?? clamp((high ?? total ?? 0) * .6 + (mid ?? 0) * .3) },
      horizonGlow: e <= -6 ? 0 : base.glow.intensity * smooth(-6, -4, e),
      haze: valid(input.visibilityMeters) ? (1 - smooth(200, 18000, input.visibilityMeters)) * .5 : 0,
      layers, seed: Number.isFinite(input.seed) ? input.seed >>> 0 : 42,
      missing: Object.keys(defaults).filter(key => !valid(input[key])),
      contradictions: [hasRadiation && input.directNormalWm2 > 100 && low !== null && low > .95 ? 'Direct radiation conflicts with dense low cloud.' : null,
        valid(input.diffuseHorizontalWm2) && valid(input.globalHorizontalWm2) && input.diffuseHorizontalWm2 > input.globalHorizontalWm2 + 1 ? 'Diffuse radiation exceeds global radiation.' : null].filter(Boolean) };
  }

  function colorAt(base, y) {
    const after = base.stops.findIndex(s => s.position >= y);
    if (after <= 0) return rgb(base.stops[after < 0 ? base.stops.length - 1 : 0].hex);
    const a = base.stops[after - 1], b = base.stops[after];
    return blend(rgb(a.hex), rgb(b.hex), (y - a.position) / (b.position - a.position));
  }

  // Fixed integer hash + smooth value noise: stable across browsers and sessions.
  function hash(x, y, seed) {
    let h = Math.imul(x, 374761393) + Math.imul(y, 668265263) + Math.imul(seed, 1442695041);
    h = Math.imul(h ^ (h >>> 13), 1274126177);
    return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
  }
  function noise(x, y, seed) {
    const ix = Math.floor(x), iy = Math.floor(y), tx = smooth(0, 1, x - ix), ty = smooth(0, 1, y - iy);
    return mix(mix(hash(ix, iy, seed), hash(ix + 1, iy, seed), tx), mix(hash(ix, iy + 1, seed), hash(ix + 1, iy + 1, seed), tx), ty);
  }
  function fbm(x, y, seed) {
    let sum = 0, amplitude = .53, frequency = 1;
    for (let i = 0; i < 5; i++) { sum += noise(x * frequency, y * frequency, seed + i * 7) * amplitude; amplitude *= .48; frequency *= 2.03; }
    return sum / 1.005;
  }

  function makeRenderer(createCanvas) {
    const width = 360, height = 480, maps = new Map();
    const surface = createCanvas(width, height), context = surface.getContext('2d');
    function field(id, seed) {
      const key = `${id}:${seed}`;
      if (maps.has(key)) return maps.get(key);
      const data = new Float32Array(width * height);
      const index = { high: 1, mid: 2, low: 3, generic: 4 }[id];
      for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
        const u = x / width, v = y / height;
        const warp = noise(u * 3, v * 4, seed + index) * .8;
        data[y * width + x] = fbm(u * (id === 'high' ? 3 : 5) + warp + 13, v * (id === 'high' ? 24 : 9) + warp + 5, seed + index * 97);
      }
      // Only one geometry family is retained; avoid unbounded growth if future UI changes seeds.
      if (maps.size >= 4) maps.clear();
      maps.set(key, data);
      return data;
    }
    function cloud(ctx, layer, scene, w, h) {
      const n = field(layer.id, scene.seed), pixels = context.createImageData(width, height);
      const cover = layer.cover, threshold = mix(.76, .16, cover);
      const deck = layer.id === 'low' || layer.id === 'generic' ? smooth(.78, 1, cover) : 0;
      for (let y = 0; y < height; y++) {
        const v = y / height;
        const envelope = Math.exp(-Math.pow((v - layer.center) / layer.spread, 4));
        const sky = colorAt(scene.base, v);
        const coolBody = blend(sky, [120, 133, 148], .35).map(c => c * mix(.54, .88, scene.daylight));
        const lit = blend([239, 241, 236], [250, 186, 135], scene.warmth * .82);
        for (let x = 0; x < width; x++) {
          const i = y * width + x, p = i * 4, density = smooth(threshold, threshold + .22, n[i]);
          const shape = Math.max(density * envelope, deck * (.68 + .3 * n[i]));
          const edge = clamp((n[i] - n[Math.max(0, y - 3) * width + x]) * 12 + .33);
          const illumination = scene.daylight * (.13 + scene.direct * .36) + scene.warmth * .30;
          const color = blend(coolBody, lit, clamp(edge * illumination));
          pixels.data[p] = color[0]; pixels.data[p + 1] = color[1]; pixels.data[p + 2] = color[2];
          pixels.data[p + 3] = 255 * clamp(shape * layer.opacity * smooth(0, .12, cover));
        }
      }
      context.putImageData(pixels, 0, 0);
      ctx.drawImage(surface, 0, 0, w, h);
    }
    function glow(ctx, x, y, radius, color, opacity, w, h) {
      if (opacity <= 0) return;
      const g = ctx.createRadialGradient(x, y, 0, x, y, radius);
      g.addColorStop(0, rgba(color, opacity)); g.addColorStop(.24, rgba(color, opacity * .48)); g.addColorStop(1, rgba(color, 0));
      ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
    }
    function draw(canvas, scene, options = {}) {
      const ctx = canvas.getContext('2d'), w = canvas.width, h = canvas.height;
      ctx.clearRect(0, 0, w, h);
      const gradient = ctx.createLinearGradient(0, 0, 0, h);
      scene.base.stops.forEach(s => gradient.addColorStop(s.position, s.hex));
      ctx.fillStyle = gradient; ctx.fillRect(0, 0, w, h);
      if (options.baseline) return;
      if (options.sun !== false) {
        glow(ctx, w * .5, h * .89, h * .58, [255, 196, 131], scene.horizonGlow * .50, w, h);
        const sun = scene.sun, sx = sun.x * w, sy = sun.y * h, radius = sun.radius * Math.min(w, h);
        if (sun.opacity > 0 && sun.limb > 0) {
          const color = blend([255, 253, 234], [255, 213, 149], scene.warmth * .62);
          glow(ctx, sx, sy, radius * (9 + sun.softness * 6), color, sun.opacity * sun.limb * .5, w, h);
          glow(ctx, sx, sy, radius * 2.3, color, sun.opacity * sun.limb * .45, w, h);
          ctx.save(); ctx.beginPath(); ctx.rect(0, 0, w, sy - radius + 2 * radius * sun.limb); ctx.clip();
          const disc = ctx.createRadialGradient(sx, sy, 0, sx, sy, radius * (1.05 + sun.softness * .25));
          disc.addColorStop(0, rgba(color, sun.opacity)); disc.addColorStop(.72, rgba(color, sun.opacity * .96)); disc.addColorStop(1, rgba(color, 0));
          ctx.fillStyle = disc; ctx.beginPath(); ctx.arc(sx, sy, radius * 1.4, 0, Math.PI * 2); ctx.fill(); ctx.restore();
        }
      }
      if (options.clouds !== false) scene.layers.forEach(layer => cloud(ctx, layer, scene, w, h));
      if (options.haze !== false && scene.haze > 0) {
        const veil = ctx.createLinearGradient(0, 0, 0, h);
        const tint = blend(colorAt(scene.base, .8), [214, 216, 210], scene.daylight * .6);
        veil.addColorStop(0, rgba(tint, scene.haze * .3)); veil.addColorStop(1, rgba(tint, scene.haze));
        ctx.fillStyle = veil; ctx.fillRect(0, 0, w, h);
      }
    }
    return { draw };
  }
  root.YoukiAtmosphere = { generateScene, makeRenderer, elevationAt, smooth, clamp };
})(globalThis);
