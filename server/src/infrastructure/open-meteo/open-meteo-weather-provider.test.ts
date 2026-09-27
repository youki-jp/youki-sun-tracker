import { describe, expect, test } from "bun:test";
import { OpenMeteoWeatherProvider } from "./open-meteo-weather-provider";
import type { OpenMeteoClient } from "./open-meteo-client";

const range = { startsAtIso: "2026-09-25T00:00:00", endsAtIso: "2026-09-25T23:59:59" };
const input = { location: { latitude: 35, longitude: 139, altitudeMeters: null }, timezoneId: "Asia/Tokyo", range };

function provider(payload: unknown, request: Record<string, string> = {}) {
  return new OpenMeteoWeatherProvider({
    getJson: async (_path: string, params: Record<string, string>) => {
      Object.assign(request, params);
      return payload;
    },
  } as unknown as OpenMeteoClient);
}

describe("OpenMeteoWeatherProvider radiation extension", () => {
  test("requests the three instant fields and keeps valid zero", async () => {
    const request: Record<string, string> = {};
    const rows = await provider({
      hourly_units: {
        direct_normal_irradiance_instant: "W/m²",
        shortwave_radiation_instant: "W/m²",
        diffuse_radiation_instant: "W/m²",
      },
      hourly: {
        time: ["2026-09-25T12:00"], cloud_cover: [35],
        direct_normal_irradiance_instant: [0], shortwave_radiation_instant: [450],
        diffuse_radiation_instant: [120],
      },
    }, request).listWeatherSamples(input);
    expect(request.hourly).toContain("direct_normal_irradiance_instant");
    expect(request.hourly).toContain("shortwave_radiation_instant");
    expect(request.hourly).toContain("diffuse_radiation_instant");
    expect(rows[0]?.cloudCover.totalPct).toBe(35);
    expect(rows[0]?.solarRadiation).toEqual({
      sampling: "instant", directNormalWm2: 0, globalHorizontalWm2: 450,
      diffuseHorizontalWm2: 120,
    });
  });

  test("keeps weather usable when radiation is missing, malformed, or has the wrong unit", async () => {
    const rows = await provider({
      hourly_units: {
        direct_normal_irradiance_instant: "kW/m²",
        shortwave_radiation_instant: "W/m²",
        diffuse_radiation_instant: "W/m²",
      },
      hourly: {
        time: ["2026-09-25T01:00", "2026-09-25T02:00"],
        cloud_cover: [50, 65], direct_normal_irradiance_instant: [500, 300],
        shortwave_radiation_instant: [-2, Number.NaN], diffuse_radiation_instant: [null],
      },
    }).listWeatherSamples(input);
    expect(rows.map(row => row.cloudCover.totalPct)).toEqual([50, 65]);
    expect(rows.every(row => row.solarRadiation?.directNormalWm2 === null)).toBe(true);
    expect(rows.every(row => row.solarRadiation?.globalHorizontalWm2 === null)).toBe(true);
    expect(rows.every(row => row.solarRadiation?.diffuseHorizontalWm2 === null)).toBe(true);
  });
});
