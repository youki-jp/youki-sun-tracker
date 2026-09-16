import { describe, expect, it } from "bun:test";
import type { AirQualitySample, SolarDaySample, WeatherSample } from "../../domain";
import type {
  NormalizedSkyObservation,
  SkyGradientOutput,
} from "../../domain/sky-gradient";
import {
  SkyGradientService,
  normalizeSkyObservation,
} from "./sky-gradient-service";

const solar: SolarDaySample[] = [
  {
    timeIso: "2026-09-16T06:00:00",
    elevationDegrees: -4,
    azimuthDegrees: 80,
    isRising: true,
    phase: "civilDawn",
  },
  {
    timeIso: "2026-09-16T07:00:00",
    elevationDegrees: 5,
    azimuthDegrees: 95,
    isRising: true,
    phase: "goldenHourAm",
  },
];

const weather: WeatherSample[] = [
  weatherRow("2026-09-16T06:00:00", 10, 20, 30, 40, 10_000, 50, 0),
  weatherRow("2026-09-16T07:00:00", 50, 60, 70, 80, 20_000, 70, 1),
];

const airQuality: AirQualitySample[] = [
  {
    timeIso: "2026-09-16T06:00:00",
    aerosolOpticalDepth: 0.1,
    particulateMatter2_5UgM3: 10,
    particulateMatter10UgM3: 20,
    dustUgM3: 2,
    ozoneUgM3: 30,
  },
  {
    timeIso: "2026-09-16T07:00:00",
    aerosolOpticalDepth: 0.3,
    particulateMatter2_5UgM3: 30,
    particulateMatter10UgM3: 40,
    dustUgM3: 6,
    ozoneUgM3: 50,
  },
];

function weatherRow(
  timeIso: string,
  totalPct: number | null,
  lowPct: number | null,
  midPct: number | null,
  highPct: number | null,
  visibilityMeters: number | null,
  relativeHumidityPct: number | null,
  precipitationMillimeters: number | null,
): WeatherSample {
  return {
    timeIso,
    cloudCover: { totalPct, lowPct, midPct, highPct },
    visibilityMeters,
    relativeHumidityPct,
    dewPointCelsius: null,
    precipitationMillimeters,
    uvIndex: null,
  };
}

function timeline() {
  return { solar, weather, airQuality };
}

const fakeOutput: SkyGradientOutput = {
  stops: [],
  ramp: [],
  glow: { centerX: 0, centerY: 0, radius: 0, intensity: 0 },
  cloudBands: [],
};

describe("normalizeSkyObservation", () => {
  it("uses an exact hourly row without changing its numeric values", () => {
    const result = normalizeSkyObservation({
      timeline: timeline(),
      atIso: "2026-09-16T07:00:00",
    });

    expect(result.observation.cloudTotalPct).toBe(50);
    expect(result.observation.aerosolOpticalDepth).toBe(0.3);
    expect(result.observation.phase).toBe("goldenHourAm");
    expect(result.observation.isRising).toBe(true);
    expect(result.availability.weather.clamped).toBe(false);
  });

  it("linearly interpolates numeric weather and air values between rows", () => {
    const result = normalizeSkyObservation({
      timeline: timeline(),
      atIso: "2026-09-16T06:30:00",
    });

    expect(result.observation.elevationDegrees).toBe(0.5);
    expect(result.observation.cloudTotalPct).toBe(30);
    expect(result.observation.visibilityMeters).toBe(15_000);
    expect(result.observation.aerosolOpticalDepth).toBe(0.2);
    expect(result.observation.pm25UgM3).toBe(20);
    expect(result.observation.phase).toBe("goldenHourAm");
  });

  it("clamps before and after the available range and records it", () => {
    const before = normalizeSkyObservation({
      timeline: timeline(),
      atIso: "2026-09-16T05:00:00",
    });
    const after = normalizeSkyObservation({
      timeline: timeline(),
      atIso: "2026-09-16T08:00:00",
    });

    expect(before.observation.cloudTotalPct).toBe(10);
    expect(before.observation.aerosolOpticalDepth).toBe(0.1);
    expect(before.availability.weather.clamped).toBe(true);
    expect(after.observation.cloudTotalPct).toBe(50);
    expect(after.observation.aerosolOpticalDepth).toBe(0.3);
    expect(after.availability.airQuality.clamped).toBe(true);
  });

  it("keeps null values null and exposes field availability", () => {
    const result = normalizeSkyObservation({
      timeline: {
        solar,
        weather: [weatherRow("2026-09-16T06:00:00", null, null, null, null, null, null, null)],
        airQuality: [],
      },
      atIso: "2026-09-16T06:30:00",
    });

    expect(result.observation.cloudTotalPct).toBeNull();
    expect(result.observation.visibilityMeters).toBeNull();
    expect(result.observation.aerosolOpticalDepth).toBeNull();
    expect(result.availability.weather.fields.cloudTotalPct).toBe(false);
    expect(result.availability.airQuality.rowCount).toBe(0);
  });

  it("clamps normalized provider values to safe ranges without defaulting them", () => {
    const result = normalizeSkyObservation({
      timeline: {
        solar,
        weather: [weatherRow("2026-09-16T06:00:00", 125, -10, 50, 60, 250_000, 140, -2)],
        airQuality: [{
          timeIso: "2026-09-16T06:00:00",
          aerosolOpticalDepth: 3,
          particulateMatter2_5UgM3: 2_000,
          particulateMatter10UgM3: null,
          dustUgM3: -4,
          ozoneUgM3: null,
        }],
      },
      atIso: "2026-09-16T06:00:00",
    });

    expect(result.observation.cloudTotalPct).toBe(100);
    expect(result.observation.cloudLowPct).toBe(0);
    expect(result.observation.visibilityMeters).toBe(100_000);
    expect(result.observation.relativeHumidityPct).toBe(100);
    expect(result.observation.precipitationMillimeters).toBe(0);
    expect(result.observation.aerosolOpticalDepth).toBe(2);
    expect(result.observation.pm25UgM3).toBe(1_000);
    expect(result.observation.dustUgM3).toBe(0);
  });
});

describe("SkyGradientService", () => {
  it("passes the normalized observation to the engine and returns its output", () => {
    let received: NormalizedSkyObservation | null = null;
    const service = new SkyGradientService({
      generate(input) {
        received = input;
        return fakeOutput;
      },
    });

    const result = service.execute({ timeline: timeline(), atIso: "2026-09-16T06:30:00" });
    expect(result.output).toBe(fakeOutput);
    expect(received?.cloudTotalPct).toBe(30);
    expect(result.availability).toBe(result.observation.availability);
  });
});
