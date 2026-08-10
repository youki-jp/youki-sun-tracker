import type { LocationInput, TimeRange, AirQualitySample } from "../../domain";

export interface AirQualityProvider {
  listAirQualitySamples(input: {
    location: LocationInput;
    timezoneId: string;
    range: TimeRange;
  }): Promise<AirQualitySample[]>;
}
