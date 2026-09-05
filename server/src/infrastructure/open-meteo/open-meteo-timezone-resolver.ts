import { ExternalServiceError } from "../../application/errors";
import type { TimezoneResolver } from "../../application/ports/timezone-resolver";
import type { LocationInput } from "../../domain";
import type { OpenMeteoDailyForecastResponse } from "./open-meteo-types";
import { OpenMeteoClient } from "./open-meteo-client";

export class OpenMeteoTimezoneResolver implements TimezoneResolver {
  constructor(private readonly client: OpenMeteoClient) {}

  async resolveTimezone(location: LocationInput): Promise<string> {
    const response = await this.client.getJson<OpenMeteoDailyForecastResponse>(
      "/v1/forecast",
      {
        latitude: String(location.latitude),
        longitude: String(location.longitude),
        timezone: "auto",
        daily: "sunrise",
        forecast_days: "1",
      },
    );

    if (!response.timezone) {
      throw new ExternalServiceError(
        "Open-Meteo did not return a timezone for the requested coordinates.",
      );
    }

    return response.timezone;
  }
}
