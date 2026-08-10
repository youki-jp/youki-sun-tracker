import type { LocationInput, TimeRange, WeatherSample } from "../../domain";

export interface WeatherProvider {
  listWeatherSamples(input: {
    location: LocationInput;
    timezoneId: string;
    range: TimeRange;
  }): Promise<WeatherSample[]>;
}
