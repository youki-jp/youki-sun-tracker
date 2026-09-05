import { ExternalServiceError } from "../../application/errors";
import type { AirQualityProvider } from "../../application/ports/air-quality-provider";
import { isLocalIsoWithinRange } from "../../application/services/local-date-time";
import type { AirQualitySample } from "../../domain";
import type { OpenMeteoAirQualityResponse } from "./open-meteo-types";
import { OpenMeteoClient } from "./open-meteo-client";

export class OpenMeteoAirQualityProvider implements AirQualityProvider {
  constructor(private readonly client: OpenMeteoClient) {}

  async listAirQualitySamples(input: {
    location: { latitude: number; longitude: number; altitudeMeters: number | null };
    timezoneId: string;
    range: { startsAtIso: string; endsAtIso: string };
  }): Promise<AirQualitySample[]> {
    const response = await this.client.getJson<OpenMeteoAirQualityResponse>(
      "/v1/air-quality",
      {
        latitude: String(input.location.latitude),
        longitude: String(input.location.longitude),
        timezone: input.timezoneId,
        hourly: "aerosol_optical_depth,pm2_5,pm10,dust,ozone",
        forecast_days: "7",
      },
    );
    const hourly = response.hourly;

    if (!hourly?.time?.length) {
      throw new ExternalServiceError(
        "Open-Meteo did not return hourly air-quality data.",
      );
    }

    return hourly.time
      .map((timeIso, index) => ({
        timeIso: normalizeLocalIso(timeIso),
        aerosolOpticalDepth: hourly.aerosol_optical_depth?.[index] ?? null,
        particulateMatter2_5UgM3: hourly.pm2_5?.[index] ?? null,
        particulateMatter10UgM3: hourly.pm10?.[index] ?? null,
        dustUgM3: hourly.dust?.[index] ?? null,
        ozoneUgM3: hourly.ozone?.[index] ?? null,
      }))
      .filter((sample) => isLocalIsoWithinRange(sample.timeIso, input.range));
  }
}

function normalizeLocalIso(value: string): string {
  return value.length === 16 ? `${value}:00` : value.replace("Z", "");
}
