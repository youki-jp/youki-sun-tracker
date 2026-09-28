import { ExternalServiceError } from "../../application/errors";
import type { WeatherProvider } from "../../application/ports/weather-provider";
import { isLocalIsoWithinRange } from "../../application/services/local-date-time";
import type { WeatherSample } from "../../domain";
import type { OpenMeteoWeatherResponse } from "./open-meteo-types";
import { OpenMeteoClient } from "./open-meteo-client";
import { normalizeOpenMeteoLocalTimestamp } from "./local-timestamp";

export class OpenMeteoWeatherProvider implements WeatherProvider {
  constructor(private readonly client: OpenMeteoClient) {}

  async listWeatherSamples(input: {
    location: { latitude: number; longitude: number; altitudeMeters: number | null };
    timezoneId: string;
    range: { startsAtIso: string; endsAtIso: string };
  }): Promise<WeatherSample[]> {
    const response = await this.client.getJson<OpenMeteoWeatherResponse>(
      "/v1/forecast",
      {
        latitude: String(input.location.latitude),
        longitude: String(input.location.longitude),
        elevation:
          input.location.altitudeMeters === null
            ? "nan"
            : String(input.location.altitudeMeters),
        timezone: input.timezoneId,
        hourly:
          "cloud_cover,cloud_cover_low,cloud_cover_mid,cloud_cover_high,visibility,relative_humidity_2m,dew_point_2m,precipitation,uv_index,direct_normal_irradiance_instant,shortwave_radiation_instant,diffuse_radiation_instant",
        forecast_days: "7",
      },
    );
    const hourly = response.hourly;

    if (!hourly?.time?.length) {
      throw new ExternalServiceError(
        "Open-Meteo did not return hourly weather data.",
      );
    }

    return hourly.time
      .map((timeIso, index) => ({
        timeIso: normalizeOpenMeteoLocalTimestamp(timeIso),
        cloudCover: {
          totalPct: hourly.cloud_cover?.[index] ?? null,
          lowPct: hourly.cloud_cover_low?.[index] ?? null,
          midPct: hourly.cloud_cover_mid?.[index] ?? null,
          highPct: hourly.cloud_cover_high?.[index] ?? null,
        },
        visibilityMeters: hourly.visibility?.[index] ?? null,
        relativeHumidityPct: hourly.relative_humidity_2m?.[index] ?? null,
        dewPointCelsius: hourly.dew_point_2m?.[index] ?? null,
        precipitationMillimeters: hourly.precipitation?.[index] ?? null,
        uvIndex: hourly.uv_index?.[index] ?? null,
        solarRadiation: {
          sampling: "instant" as const,
          directNormalWm2: radiationAt(hourly.direct_normal_irradiance_instant, response.hourly_units?.direct_normal_irradiance_instant, index),
          globalHorizontalWm2: radiationAt(hourly.shortwave_radiation_instant, response.hourly_units?.shortwave_radiation_instant, index),
          diffuseHorizontalWm2: radiationAt(hourly.diffuse_radiation_instant, response.hourly_units?.diffuse_radiation_instant, index),
        },
      }))
      .filter((sample) => isLocalIsoWithinRange(sample.timeIso, input.range));
  }
}

function radiationAt(values: Array<number | null> | undefined, unit: string | undefined, index: number): number | null {
  const value: unknown = values?.[index];
  // Open-Meteo reports instantaneous radiation in watts per square metre.
  if (unit !== "W/m²" && unit !== "W/m2") return null;
  return typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : null;
}
