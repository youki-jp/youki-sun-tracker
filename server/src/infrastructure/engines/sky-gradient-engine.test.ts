import { describe, expect, it } from "bun:test";
import { SkyGradientEngine } from "./sky-gradient-engine";
import type { NormalizedSkyObservation } from "../../domain/sky-gradient";

const offsets = [0, 0.16, 0.32, 0.46, 0.6, 0.72, 0.83, 0.93, 1];

function observation(
  overrides: Partial<NormalizedSkyObservation> = {},
): NormalizedSkyObservation {
  return {
    timeIso: "2026-09-16T06:30:00",
    elevationDegrees: -0.5,
    azimuthDegrees: 90,
    isRising: true,
    phase: "goldenHourAm",
    cloudTotalPct: 4,
    cloudLowPct: 1,
    cloudMidPct: 1,
    cloudHighPct: 3,
    visibilityMeters: 32_000,
    relativeHumidityPct: 44,
    precipitationMillimeters: 0,
    aerosolOpticalDepth: 0.09,
    dustUgM3: 1,
    pm25UgM3: 5,
    availability: {
      solar: true,
      weather: { rowCount: 1, clamped: false, fields: fields(true) },
      airQuality: { rowCount: 1, clamped: false, fields: fields(true) },
    },
    ...overrides,
  };
}

function fields(value: boolean) {
  return {
    cloudTotalPct: value,
    cloudLowPct: value,
    cloudMidPct: value,
    cloudHighPct: value,
    visibilityMeters: value,
    relativeHumidityPct: value,
    precipitationMillimeters: value,
    aerosolOpticalDepth: value,
    dustUgM3: value,
    pm25UgM3: value,
  };
}

function expectValidOutput(output: ReturnType<SkyGradientEngine["generate"]>) {
  expect(output.stops).toHaveLength(9);
  expect(output.stops.map((stop) => stop.position)).toEqual(offsets);
  expect(output.ramp).toHaveLength(5);
  for (const hex of [...output.stops.map((stop) => stop.hex), ...output.ramp]) {
    expect(hex).toMatch(/^#[0-9a-f]{6}$/);
    expect([...hex.slice(1)].every((character) => /[0-9a-f]/.test(character))).toBe(true);
  }
  expect(Number.isFinite(output.glow.centerX)).toBe(true);
  expect(Number.isFinite(output.glow.centerY)).toBe(true);
  expect(Number.isFinite(output.glow.radius)).toBe(true);
  expect(Number.isFinite(output.glow.intensity)).toBe(true);
  for (const band of output.cloudBands) {
    expect(band.y).toBeGreaterThanOrEqual(0);
    expect(band.y + band.height).toBeLessThanOrEqual(1);
    expect(band.opacity).toBeGreaterThanOrEqual(0);
    expect(band.opacity).toBeLessThanOrEqual(1);
  }
}

describe("SkyGradientEngine", () => {
  it("emits stable nine-stop offsets, five ramp colors, and valid sRGB hex", () => {
    const output = new SkyGradientEngine().generate(observation());
    expectValidOutput(output);
  });

  it("produces distinct clear twilight, overcast, rainy, and hazy regimes", () => {
    const engine = new SkyGradientEngine();
    const clear = engine.generate(observation());
    const overcast = engine.generate(
      observation({ cloudTotalPct: 97, cloudLowPct: 82, cloudMidPct: 74, cloudHighPct: 12, relativeHumidityPct: 88, visibilityMeters: 12_000, aerosolOpticalDepth: 0.16 }),
    );
    const rainy = engine.generate(
      observation({ cloudTotalPct: 80, cloudLowPct: 70, cloudMidPct: 60, cloudHighPct: 50, precipitationMillimeters: 2 }),
    );
    const hazy = engine.generate(
      observation({ relativeHumidityPct: 95, visibilityMeters: 3_000, aerosolOpticalDepth: 0.45, dustUgM3: 45, pm25UgM3: 60 }),
    );

    for (const output of [clear, overcast, rainy, hazy]) expectValidOutput(output);
    expect(clear).not.toEqual(overcast);
    expect(clear).not.toEqual(rainy);
    expect(clear).not.toEqual(hazy);
    expect(clear.glow.intensity).toBeGreaterThan(overcast.glow.intensity);
    expect(clear.glow.intensity).toBeGreaterThan(rainy.glow.intensity);
  });

  it("uses renderer defaults only at the engine boundary for null inputs", () => {
    const engine = new SkyGradientEngine();
    const withNulls = engine.generate(
      observation({
        cloudTotalPct: null,
        cloudLowPct: null,
        cloudMidPct: null,
        cloudHighPct: null,
        visibilityMeters: null,
        relativeHumidityPct: null,
        precipitationMillimeters: null,
        aerosolOpticalDepth: null,
        dustUgM3: null,
        pm25UgM3: null,
      }),
    );
    const withDefaults = engine.generate(
      observation({
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
      }),
    );
    expect(withNulls).toEqual(withDefaults);
  });

  it("returns identical output for repeated identical input", () => {
    const engine = new SkyGradientEngine();
    const input = observation({ elevationDegrees: 18, cloudTotalPct: 55 });
    expect(engine.generate(input)).toEqual(engine.generate(input));
  });
});
