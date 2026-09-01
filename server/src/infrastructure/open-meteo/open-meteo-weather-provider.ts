import { ExternalServiceError } from "../../application/errors";
import type { WeatherProvider } from "../../application/ports/weather-provider";
import { isLocalIsoWithinRange } from "../../application/services/local-date-time";
import type { WeatherSample } from "../../domain";
import type { OpenMeteoWeatherResponse } from "./open-meteo-types";
import { OpenMeteoClient } from "./open-meteo-client";

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
          "cloud_cover,cloud_cover_low,cloud_cover_mid,cloud_cover_high,visibility,relative_humidity_2m,dew_point_2m,precipitation",
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
        timeIso: normalizeLocalIso(timeIso),
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
      }))
      .filter((sample) => isLocalIsoWithinRange(sample.timeIso, input.range));
  }
}

function normalizeLocalIso(value: string): string {
  return value.length === 16 ? `${value}:00` : value.replace("Z", "");
}
