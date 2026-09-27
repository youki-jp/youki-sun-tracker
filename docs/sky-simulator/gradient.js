/* Youki Oklch reference generator.
 * Source: reviewed youki-prototype/gradient.html, also ported in
 * server/src/infrastructure/engines/sky-gradient-engine.ts.
 * Kept independent of the atmosphere experiment; parity checked by script.
 */
(function (root) {
"use strict";
function clamp(v, lo, hi) { return Math.min(Math.max(v, lo), hi); }
function clamp01(v) { return clamp(v, 0, 1); }
function lerp(a, b, t) { return a + (b - a) * t; }

function smoothstep(edge0, edge1, x) {
  const t = clamp01((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}

/* 1 inside [lo,hi], falling off smoothly outside it. */
function bell(v, lo, hi) {
  if (v >= lo && v <= hi) return 1;
  const span = (hi - lo) || 1;
  const d = v < lo ? lo - v : v - hi;
  return clamp01(1 - d / span);
}

/* ===========================================================================
   2. COLOUR: OKLCH -> sRGB
   ---------------------------------------------------------------------------
   We build colour in Oklch because interpolating a blue-to-gold ramp in sRGB
   runs through muddy grey midpoints. Everything is flattened to sRGB hex
   before it leaves this file: iOS 17 has no MeshGradient, no Color.mix, and
   no gradient colour-space control, so Swift must receive plain sRGB stops.
   Port these three functions as-is if the Swift side ever needs to generate
   colour itself.
   =========================================================================== */

function oklabToLinearSrgb(L, a, b) {
  const l_ = L + 0.3963377774 * a + 0.2158037573 * b;
  const m_ = L - 0.1055613458 * a - 0.0638541728 * b;
  const s_ = L - 0.0894841775 * a - 1.2914855480 * b;
  const l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_;
  return [
     4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
  ];
}

function linearToGamma(c) {
  return c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
}

/*
 * Oklch to hex, reducing chroma until the colour fits in sRGB. Clipping RGB
 * channels directly shifts hue badly on saturated warm tones, which is exactly
 * where these gradients live.
 */
function oklchToHex(L, C, H) {
  const lightness = clamp(L, 0, 1);
  const hueRad = (H * Math.PI) / 180;
  let chroma = Math.max(C, 0);
  let rgb = null;

  for (let i = 0; i < 28; i++) {
    rgb = oklabToLinearSrgb(
      lightness,
      chroma * Math.cos(hueRad),
      chroma * Math.sin(hueRad)
    );
    if (rgb[0] >= -0.0005 && rgb[0] <= 1.0005 &&
        rgb[1] >= -0.0005 && rgb[1] <= 1.0005 &&
        rgb[2] >= -0.0005 && rgb[2] <= 1.0005) break;
    chroma *= 0.94;
  }

  return '#' + rgb.map(function (channel) {
    const v = Math.round(clamp01(linearToGamma(clamp01(channel))) * 255);
    return v.toString(16).padStart(2, '0');
  }).join('');
}

/* Shortest-path hue interpolation, so blue-to-gold never detours via green. */
function mixOklch(a, b, t) {
  let dh = ((b[2] - a[2]) % 360 + 540) % 360 - 180;
  return [lerp(a[0], b[0], t), lerp(a[1], b[1], t), a[2] + dh * t];
}

/* ===========================================================================
   3. THE GENERATOR
   ---------------------------------------------------------------------------
   generateSky() is the deliverable. It is pure: no DOM, no fetch, no clock,
   no CSS-only tricks. Given one flattened atmospheric sample it returns a
   plain object of sRGB stops and fractional geometry. Port it to Swift as
   written.

   Two rules the Swift side depends on:
     - STOP_POSITIONS is fixed and never varies. SwiftUI only morphs between
       gradients smoothly when the stop count is stable; a changing count
       cross-fades instead. Colours move, positions do not.
     - All geometry is a fraction of sky height, never a point value. The sky
       is 266pt collapsed and full-screen expanded, so absolute offsets land
       in the wrong place in one of the two states.
   =========================================================================== */

/* Stop positions taken from the approved vivid sky in index.html:52. */
const STOP_POSITIONS = [0, 0.16, 0.32, 0.46, 0.60, 0.72, 0.83, 0.93, 1];

/* Amplitude and hue of the magenta detour. See BULGE note in colourAt. */
const BULGE_AMP = 0.086;
const BULGE_HUE = 6;

function generateSky(s) {
  const elevation = s.elevationDegrees;

  /* --- how much daylight, how much horizon glow --------------------------- */

  /* Full day well above the horizon, night below civil twilight. */
  const dayF = smoothstep(-8, 10, elevation);

  /* Above about ten degrees dayF is saturated, so without this the whole middle
     of the day renders as one frozen frame. A high sun deepens the zenith and
     brightens the horizon haze. */
  const highSun = smoothstep(10, 60, elevation);

  /* The warm band peaks a shade below the horizon and fades either side.
     This is the single strongest driver of what a sunrise looks like. */
  const glowF = Math.exp(-Math.pow((elevation + 1.0) / 8.0, 2));

  /* --- atmospheric modifiers ---------------------------------------------- */

  const cloudTotal = clamp01(s.cloudTotalPct / 100);
  const cloudLow   = clamp01(s.cloudLowPct / 100);
  const cloudMid   = clamp01(s.cloudMidPct / 100);
  const cloudHigh  = clamp01(s.cloudHighPct / 100);

  /* Mie scattering off aerosol deepens orange into red. Dust pushes amber,
     fine particulates add a little of both. */
  const aerosolWarm = clamp01(
    clamp01((s.aerosolOpticalDepth - 0.04) / 0.42) +
    0.5 * clamp01(s.dustUgM3 / 45) +
    0.3 * clamp01(s.pm25UgM3 / 60)
  );

  /* Humid air and poor visibility both wash colour toward pastel. */
  const haze = clamp01(
    0.55 * clamp01((s.relativeHumidityPct - 68) / 30) +
    0.45 * (1 - clamp01(s.visibilityMeters / 22000))
  );
  const wet = clamp01(s.precipitationMillimeters / 1.5);

  /* Low cloud sits between you and the sun and blocks the horizon light.
     High cloud is the opposite: it catches light from below and is what makes
     a sky spectacular. */
  const blocked   = clamp01((cloudLow - 0.30) / 0.60);
  const highCatch = bell(cloudHigh, 0.15, 0.60);

  /* Cloud scatters light down into the upper sky. An overcast twilight is a
     pale grey-mauve; a clear one is a deep saturated blue. This runs opposite
     to the intuition that cloud means "darker". */
  const overcastF = clamp01(0.78 * cloudTotal + 0.30 * cloudLow - 0.08 * cloudHigh);

  /* The mauve cast of an overcast sky is a LOW SUN effect: reddened light
     scattering through cloud. At midday there is no reddened light to scatter,
     and a real overcast sky is a near-neutral grey-blue. Measured from a
     Yokohama window at 21 degrees: hue 252, not the 289 this used to produce. */
  const lowSunTint = Math.exp(-Math.pow((elevation + 1) / 11, 2));

  /* --- cool anchor: top of frame ------------------------------------------ */

  const topL = clamp(
    0.335 + 0.30 * overcastF + 0.22 * cloudHigh + 0.16 * dayF - 0.07 * highSun,
    0.14, 0.90
  );
  /* A clear midday zenith is far more saturated than any twilight; an overcast
     one is desaturated at every sun angle. Interpolating between those two ends
     by cloud cover matches both a measured overcast afternoon (chroma 0.034)
     and the approved twilight gradients. */
  /* Aerosol whitens a daytime sky: more scattering particles means more
     multiply-scattered white light mixed into the blue. Without this term the
     model returned the same chromaticity for a pristine and a hazy midday,
     which the Preetham oracle disagrees with by a wide margin. */
  const clearChroma = (0.045 + 0.055 * dayF * dayF) * (1 - 0.45 * aerosolWarm);
  const topC = clamp(
    lerp(clearChroma, 0.030, clamp01(cloudTotal * 1.05)) - 0.014 * haze,
    0.010, 0.14
  );
  const topH = 250 + (54 * overcastF + 12 * aerosolWarm) * lowSunTint;

  /* --- warm anchor: horizon ----------------------------------------------- */

  /* How strongly the horizon actually glows, after everything in the way. */
  const warmVigour = clamp01(
    glowF * (1 - 0.60 * blocked) * (1 - 0.42 * haze) * (1 - 0.80 * wet)
  );

  /* Cloud is what makes a horizon pale and bright; clean air burns a deeper,
     more saturated orange. Keeping clear skies darker here also keeps their
     chroma inside sRGB, which is where the richest colour lives. Haze, heavy
     overcast and rain all pull it back down. */
  const botL = clamp(
    0.510 + 0.26 * glowF + 0.12 * dayF + 0.11 * cloudTotal + 0.09 * cloudHigh
      - 0.06 * overcastF * lowSunTint - 0.08 * haze - 0.10 * wet,
    0.30, 0.94
  );
  const botC = clamp((0.052 + 0.108 * warmVigour) * (1 - 0.30 * haze), 0.015, 0.165);
  const botH = 90 - 8 * glowF - 16 * aerosolWarm;

  /* How much of the sky the warmth climbs into, and how far the colour path
     detours through magenta on its way from blue to gold. */
  /* Scattering is what spreads the glow up the sky. In clean air the warmth
     stays pinned near the horizon and the blue holds most of the frame; haze,
     cloud and aerosol push it much higher. */
  const spread = clamp01(0.30 + 0.45 * aerosolWarm + 0.35 * cloudTotal + 0.25 * haze);
  const warmStart = clamp01(0.66 - 0.66 * glowF * spread);
  const coolRamp = 0.68 - 0.48 * overcastF + 0.14 * highSun;

  /* How much the warm anchor applies at all. Without this the horizon stays
     gold at midday, when it should be pale haze: the warm colour of a horizon
     is made by a low sun, not by being at the bottom of the frame. */
  const warmPresence = clamp01(glowF * 1.15);
  const pink = clamp01(
    (0.52 * aerosolWarm + 0.52 * highCatch) *
    glowF * (1 - 0.75 * blocked) * (1 - 0.5 * wet)
  );

  function colourAt(y) {
    const t = (warmStart >= 1 ? 0 :
      smoothstep(0, 1, clamp01((y - warmStart) / (1 - warmStart)))) * warmPresence;

    /* The cool zone has its own ramp. Looking lower means looking through more
       atmosphere, so the blue lightens and desaturates toward the horizon well
       before any warmth arrives. A clear sky ramps hard from deep zenith blue;
       an overcast one is nearly uniform grey. */
    /* The cool ramp ends at a haze lightness of its own. Tying it to the warm
       anchor made an overcast midday sky get DARKER toward the horizon, which
       is backwards: a longer path through haze scatters MORE light, so the
       horizon is the brightest part of an overcast sky. Measured strip rises
       0.842 to 0.872 from top of frame to horizon. */
    /* The haze ceiling has to scale with the scene. A clear humid twilight was
       running the cool ramp up past its own warm anchor, so the gradient dipped
       in lightness near the bottom. */
    const hazeCeiling = 0.35 + 0.58 * dayF + 0.25 * overcastF + 0.30 * glowF;

    /* Never below the zenith: a sky that darkens toward the horizon is wrong at
       every sun angle, and at night the ceiling alone would produce one. */
    const coolHorizonL = clamp(
      Math.max(topL, Math.min(topL + coolRamp * (1 - 0.55 * overcastF), hazeCeiling)),
      0.16, 0.93
    );
    const coolL = lerp(topL, coolHorizonL, y);
    const coolC = topC * (1 - (0.45 + 0.28 * highSun) * y);
    const coolH = topH - 10 * y;

    /* Interpolate in rectangular Oklab, not polar Oklch. Rectangular passes
       through low chroma near the midpoint, which is exactly what a clean sky
       does: deep blue desaturates to almost grey, then resaturates into gold.
       Polar would hold chroma and swing the hue through green. */
    const coolRad = (coolH * Math.PI) / 180;
    const botRad = (botH * Math.PI) / 180;
    let a = lerp(coolC * Math.cos(coolRad), botC * Math.cos(botRad), t);
    let b = lerp(coolC * Math.sin(coolRad), botC * Math.sin(botRad), t);

    /* BULGE: aerosol and cloud scatter red light into the middle of the sky,
       bending the path through pink rather than through grey. This one term is
       the whole difference between a clean blue-to-gold dawn and a vivid one
       with a magenta band. Peaks mid-path and vanishes at both anchors. */
    const bulge = pink * BULGE_AMP * Math.pow(Math.sin(Math.PI * t), 1.4);
    a += bulge * Math.cos((BULGE_HUE * Math.PI) / 180);
    b += bulge * Math.sin((BULGE_HUE * Math.PI) / 180);

    return [
      lerp(coolL, botL, t),
      Math.hypot(a, b),
      (Math.atan2(b, a) * 180) / Math.PI,
    ];
  }

  /* --- emit ---------------------------------------------------------------- */

  const stops = STOP_POSITIONS.map(function (position) {
    const c = colourAt(position);
    return { hex: oklchToHex(c[0], c[1], c[2]), position: position };
  });

  /* Cloud bands sit at the altitude their layer actually occupies: high cloud
     near the top of frame, low cloud down by the horizon. Colour is derived
     from the sky behind them so they stay in key as conditions change. */
  const cloudBands = [];
  function addBand(cover, y, height) {
    if (cover < 0.14) return;
    const c = colourAt(y);
    cloudBands.push({
      y: y,
      height: height,
      /* Cloud reads as a soft darker mass of the sky behind it, not a stripe.
         Blur is a fraction of sky height so it survives both frame sizes. */
      hex: oklchToHex(c[0] * 0.74, c[1] * 0.6, c[2]),
      opacity: Math.round((0.10 + 0.30 * cover) * 100) / 100,
      blur: 0.055,
    });
  }
  addBand(cloudHigh, 0.16, 0.13);
  addBand(cloudMid, 0.38, 0.15);
  addBand(cloudLow, 0.62, 0.17);

  return {
    stops: stops,
    ramp: [0, 0.28, 0.55, 0.78, 1].map(function (position) {
      const c = colourAt(position);
      return oklchToHex(c[0], c[1], c[2]);
    }),
    glow: {
      centerX: 0.5,
      centerY: 0.89,
      radius: Math.round((0.30 + 0.12 * glowF) * 1000) / 1000,
      intensity: Math.round(
        clamp01(warmVigour * (1 - 0.50 * cloudTotal)) * 1000
      ) / 1000,
    },
    cloudBands: cloudBands,
    debug: {
      elevationDegrees: Math.round(elevation * 100) / 100,
      dayF: round3(dayF), glowF: round3(glowF), haze: round3(haze),
      wet: round3(wet), overcastF: round3(overcastF), blocked: round3(blocked),
      highCatch: round3(highCatch), aerosolWarm: round3(aerosolWarm),
      warmVigour: round3(warmVigour), warmStart: round3(warmStart),
      pink: round3(pink),
      topOklch: [round3(topL), round3(topC), round3(topH)].join(' '),
      botOklch: [round3(botL), round3(botC), round3(botH)].join(' '),
    },
  };
}

function round3(v) { return Math.round(v * 1000) / 1000; }


root.YoukiGradient = { generateSky };
})(globalThis);
