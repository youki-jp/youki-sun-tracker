import type { SkyGradientEngine as SkyGradientEnginePort } from "../../application/ports/sky-gradient-engine";
import type {
  NormalizedSkyObservation,
  SkyGradientOutput,
} from "../../domain/sky-gradient";

const STOP_POSITIONS = [0, 0.16, 0.32, 0.46, 0.6, 0.72, 0.83, 0.93, 1] as const;
const RAMP_POSITIONS = [0, 0.28, 0.55, 0.78, 1] as const;
const BULGE_AMP = 0.086;
const BULGE_HUE = 6;

const RENDERER_DEFAULTS = {
  cloudTotalPct: 0,
  cloudLowPct: 0,
  cloudMidPct: 0,
  cloudHighPct: 0,
  visibilityMeters: 24_000,
  relativeHumidityPct: 60,
  precipitationMillimeters: 0,
  aerosolOpticalDepth: 0.08,
  dustUgM3: 0,
  pm25UgM3: 0,
} as const;

export class SkyGradientEngine implements SkyGradientEnginePort {
  generate(input: NormalizedSkyObservation): SkyGradientOutput {
    // Defaults are intentionally applied here, at the renderer boundary. The
    // application service keeps missing provider values and availability data.
    const s = normalizeRendererInput(input);
    const elevation = s.elevationDegrees;
    const dayF = smoothstep(-8, 10, elevation);
    const highSun = smoothstep(10, 60, elevation);
    const glowF = Math.exp(-Math.pow((elevation + 1) / 8, 2));

    const cloudTotal = clamp01(s.cloudTotalPct / 100);
    const cloudLow = clamp01(s.cloudLowPct / 100);
    const cloudMid = clamp01(s.cloudMidPct / 100);
    const cloudHigh = clamp01(s.cloudHighPct / 100);

    const aerosolWarm = clamp01(
      clamp01((s.aerosolOpticalDepth - 0.04) / 0.42) +
        0.5 * clamp01(s.dustUgM3 / 45) +
        0.3 * clamp01(s.pm25UgM3 / 60),
    );
    const haze = clamp01(
      0.55 * clamp01((s.relativeHumidityPct - 68) / 30) +
        0.45 * (1 - clamp01(s.visibilityMeters / 22_000)),
    );
    const wet = clamp01(s.precipitationMillimeters / 1.5);
    const blocked = clamp01((cloudLow - 0.3) / 0.6);
    const highCatch = bell(cloudHigh, 0.15, 0.6);
    const overcastF = clamp01(0.78 * cloudTotal + 0.3 * cloudLow - 0.08 * cloudHigh);
    const lowSunTint = Math.exp(-Math.pow((elevation + 1) / 11, 2));

    const topL = clamp(
      0.335 + 0.3 * overcastF + 0.22 * cloudHigh + 0.16 * dayF - 0.07 * highSun,
      0.14,
      0.9,
    );
    const clearChroma =
      (0.045 + 0.055 * dayF * dayF) * (1 - 0.45 * aerosolWarm);
    const topC = clamp(
      lerp(clearChroma, 0.03, clamp01(cloudTotal * 1.05)) - 0.014 * haze,
      0.01,
      0.14,
    );
    const topH = 250 + (54 * overcastF + 12 * aerosolWarm) * lowSunTint;

    const warmVigour = clamp01(
      glowF * (1 - 0.6 * blocked) * (1 - 0.42 * haze) * (1 - 0.8 * wet),
    );
    const botL = clamp(
      0.51 +
        0.26 * glowF +
        0.12 * dayF +
        0.11 * cloudTotal +
        0.09 * cloudHigh -
        0.06 * overcastF * lowSunTint -
        0.08 * haze -
        0.1 * wet,
      0.3,
      0.94,
    );
    const botC = clamp(
      (0.052 + 0.108 * warmVigour) * (1 - 0.3 * haze),
      0.015,
      0.165,
    );
    const botH = 90 - 8 * glowF - 16 * aerosolWarm;
    const spread = clamp01(0.3 + 0.45 * aerosolWarm + 0.35 * cloudTotal + 0.25 * haze);
    const warmStart = clamp01(0.66 - 0.66 * glowF * spread);
    const coolRamp = 0.68 - 0.48 * overcastF + 0.14 * highSun;
    const warmPresence = clamp01(glowF * 1.15);
    const pink = clamp01(
      (0.52 * aerosolWarm + 0.52 * highCatch) *
        glowF *
        (1 - 0.75 * blocked) *
        (1 - 0.5 * wet),
    );

    const colourAt = (y: number): [number, number, number] => {
      const t =
        (warmStart >= 1
          ? 0
          : smoothstep(0, 1, clamp01((y - warmStart) / (1 - warmStart)))) *
        warmPresence;
      const hazeCeiling = 0.35 + 0.58 * dayF + 0.25 * overcastF + 0.3 * glowF;
      const coolHorizonL = clamp(
        Math.max(
          topL,
          Math.min(topL + coolRamp * (1 - 0.55 * overcastF), hazeCeiling),
        ),
        0.16,
        0.93,
      );
      const coolL = lerp(topL, coolHorizonL, y);
      const coolC = topC * (1 - (0.45 + 0.28 * highSun) * y);
      const coolH = topH - 10 * y;
      const coolRad = (coolH * Math.PI) / 180;
      const botRad = (botH * Math.PI) / 180;
      let a = lerp(coolC * Math.cos(coolRad), botC * Math.cos(botRad), t);
      let b = lerp(coolC * Math.sin(coolRad), botC * Math.sin(botRad), t);
      const bulge = pink * BULGE_AMP * Math.pow(Math.sin(Math.PI * t), 1.4);
      a += bulge * Math.cos((BULGE_HUE * Math.PI) / 180);
      b += bulge * Math.sin((BULGE_HUE * Math.PI) / 180);
      return [
        lerp(coolL, botL, t),
        Math.hypot(a, b),
        (Math.atan2(b, a) * 180) / Math.PI,
      ];
    };

    const stops = STOP_POSITIONS.map((position) => {
      const [lightness, chroma, hue] = colourAt(position);
      return { hex: oklchToHex(lightness, chroma, hue), position };
    });

    const cloudBands = [
      addBand(cloudHigh, 0.16, 0.13, colourAt),
      addBand(cloudMid, 0.38, 0.15, colourAt),
      addBand(cloudLow, 0.62, 0.17, colourAt),
    ].filter((band): band is NonNullable<typeof band> => band !== null);

    return {
      stops,
      ramp: RAMP_POSITIONS.map((position) => {
        const [lightness, chroma, hue] = colourAt(position);
        return oklchToHex(lightness, chroma, hue);
      }),
      glow: {
        centerX: 0.5,
        centerY: 0.89,
        radius: round3(0.3 + 0.12 * glowF),
        intensity: round3(clamp01(warmVigour * (1 - 0.5 * cloudTotal))),
      },
      cloudBands,
    };
  }
}

export { SkyGradientEngine as OklchSkyGradientEngine };

type RendererInput = {
  elevationDegrees: number;
  cloudTotalPct: number;
  cloudLowPct: number;
  cloudMidPct: number;
  cloudHighPct: number;
  visibilityMeters: number;
  relativeHumidityPct: number;
  precipitationMillimeters: number;
  aerosolOpticalDepth: number;
  dustUgM3: number;
  pm25UgM3: number;
};

function normalizeRendererInput(input: NormalizedSkyObservation): RendererInput {
  return {
    elevationDegrees: clampFinite(input.elevationDegrees, -90, 90, 0),
    cloudTotalPct: numberOrDefault(input.cloudTotalPct, RENDERER_DEFAULTS.cloudTotalPct, 0, 100),
    cloudLowPct: numberOrDefault(input.cloudLowPct, RENDERER_DEFAULTS.cloudLowPct, 0, 100),
    cloudMidPct: numberOrDefault(input.cloudMidPct, RENDERER_DEFAULTS.cloudMidPct, 0, 100),
    cloudHighPct: numberOrDefault(input.cloudHighPct, RENDERER_DEFAULTS.cloudHighPct, 0, 100),
    visibilityMeters: numberOrDefault(input.visibilityMeters, RENDERER_DEFAULTS.visibilityMeters, 0, 100_000),
    relativeHumidityPct: numberOrDefault(input.relativeHumidityPct, RENDERER_DEFAULTS.relativeHumidityPct, 0, 100),
    precipitationMillimeters: numberOrDefault(input.precipitationMillimeters, RENDERER_DEFAULTS.precipitationMillimeters, 0, 100),
    aerosolOpticalDepth: numberOrDefault(input.aerosolOpticalDepth, RENDERER_DEFAULTS.aerosolOpticalDepth, 0, 2),
    dustUgM3: numberOrDefault(input.dustUgM3, RENDERER_DEFAULTS.dustUgM3, 0, 1_000),
    pm25UgM3: numberOrDefault(input.pm25UgM3, RENDERER_DEFAULTS.pm25UgM3, 0, 1_000),
  };
}

function numberOrDefault(
  value: number | null,
  fallback: number,
  lo: number,
  hi: number,
): number {
  return clampFinite(value, lo, hi, fallback);
}

function clampFinite(value: number | null, lo: number, hi: number, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value)
    ? clamp(value, lo, hi)
    : fallback;
}

function clamp(value: number, lo: number, hi: number): number {
  return Math.min(Math.max(value, lo), hi);
}

function clamp01(value: number): number {
  return clamp(value, 0, 1);
}

function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

function smoothstep(edge0: number, edge1: number, value: number): number {
  const t = clamp01((value - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}

function bell(value: number, lo: number, hi: number): number {
  if (value >= lo && value <= hi) return 1;
  const span = hi - lo || 1;
  const distance = value < lo ? lo - value : value - hi;
  return clamp01(1 - distance / span);
}

function oklabToLinearSrgb(L: number, a: number, b: number): [number, number, number] {
  const l_ = L + 0.3963377774 * a + 0.2158037573 * b;
  const m_ = L - 0.1055613458 * a - 0.0638541728 * b;
  const s_ = L - 0.0894841775 * a - 1.291485548 * b;
  const l = l_ * l_ * l_;
  const m = m_ * m_ * m_;
  const s = s_ * s_ * s_;
  return [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
  ];
}

function linearToGamma(value: number): number {
  return value <= 0.0031308
    ? 12.92 * value
    : 1.055 * Math.pow(value, 1 / 2.4) - 0.055;
}

function oklchToHex(L: number, C: number, H: number): string {
  const lightness = clamp(L, 0, 1);
  const hueRad = (H * Math.PI) / 180;
  let chroma = Math.max(C, 0);
  let rgb: [number, number, number] = [0, 0, 0];

  for (let index = 0; index < 28; index += 1) {
    rgb = oklabToLinearSrgb(
      lightness,
      chroma * Math.cos(hueRad),
      chroma * Math.sin(hueRad),
    );
    if (rgb.every((channel) => channel >= -0.0005 && channel <= 1.0005)) break;
    chroma *= 0.94;
  }

  return `#${rgb
    .map((channel) => {
      const value = Math.round(clamp01(linearToGamma(clamp01(channel))) * 255);
      return value.toString(16).padStart(2, "0");
    })
    .join("")}`;
}

function addBand(
  cover: number,
  y: number,
  height: number,
  colourAt: (y: number) => [number, number, number],
) {
  if (cover < 0.14) return null;
  const [lightness, chroma, hue] = colourAt(y);
  return {
    y,
    height,
    hex: oklchToHex(lightness * 0.74, chroma * 0.6, hue),
    opacity: round2(0.1 + 0.3 * cover),
    blur: 0.055,
  };
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

function round3(value: number): number {
  return Math.round(value * 1_000) / 1_000;
}
