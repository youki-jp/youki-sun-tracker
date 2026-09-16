import type { AirQualitySample } from "./air-quality";
import type { LocationInput, ResolvedLocation } from "./location";
import type { SolarDayMilestones, SolarDaySample } from "./solar";
import type {
  IsoDateString,
  IsoDateTimeString,
  SkyColorLabel,
} from "./shared";
import type { WeatherSample } from "./weather";

export interface SkyDayTimelineRequest {
  location: LocationInput;
  targetDateIso: IsoDateString | null;
}

export interface SkyDayTimelineResponse {
  location: ResolvedLocation;
  targetDateIso: IsoDateString;
  generatedAtIso: IsoDateTimeString;
  milestones: SolarDayMilestones;
  /**
   * Solar positions across the whole local day, spaced by how fast the sun is
   * moving rather than uniformly: dense through twilight and golden hour,
   * sparse through the middle of the day where very little changes.
   */
  solar: SolarDaySample[];
  /**
   * Weather and air quality stay on their own hourly grid rather than being
   * copied onto every solar sample. The two resolutions are genuinely
   * different, and inlining them repeated the same hourly row dozens of times.
   * Clients join by timestamp, interpolating between the bracketing hours.
   */
  weather: WeatherSample[];
  airQuality: AirQualitySample[];
  /** Scored summary of the day's sunrise and sunset, for context. */
  summary: {
    sunriseLabel: SkyColorLabel | null;
    sunriseScore: number | null;
    sunsetLabel: SkyColorLabel | null;
    sunsetScore: number | null;
  };
}
