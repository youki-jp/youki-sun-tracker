import type { AirQualitySample } from "./air-quality";
import type { LocationInput, ResolvedLocation } from "./location";
import type { SolarEventWindow, SolarSample } from "./solar";
import type {
  IsoDateString,
  IsoDateTimeString,
  SkyColorLabel,
  SkyEventKind,
} from "./shared";
import type { WeatherSample } from "./weather";

export interface SkyColorFeatures {
  solar: SolarSample;
  weather: WeatherSample;
  airQuality: AirQualitySample;
}

export interface SkyColorEventContext {
  location: ResolvedLocation;
  window: SolarEventWindow;
  features: SkyColorFeatures[];
}

export interface SkyColorConditions {
  cloudCoverPct: number | null;
  highCloudPct: number | null;
  lowCloudPct: number | null;
  relativeHumidityPct: number | null;
  visibilityMeters: number | null;
  precipitationMillimeters: number | null;
  uvIndex: number | null;
}

export interface SkyColorPredictionRequest {
  location: LocationInput;
  targetDateIso: IsoDateString | null;
  requestedEvents: SkyEventKind[];
  /**
   * Return the per-timestep atmospheric samples alongside each prediction.
   * Clients that synthesise their own sky colour need these; the default stays
   * off so the standard response shape is unchanged.
   */
  includeFeatures: boolean;
}

export interface SkyColorPrediction {
  kind: SkyEventKind;
  score: number;
  confidence: number;
  label: SkyColorLabel;
  estimatedColorName: string;
  estimatedHex: string;
  dominantColors: string[];
  reasons: string[];
  conditions: SkyColorConditions;
  window: SolarEventWindow;
  /** Present only when the request set includeFeatures. */
  features?: SkyColorFeatures[];
}

export interface SkyColorApiResponse {
  location: ResolvedLocation;
  generatedAtIso: IsoDateTimeString;
  predictions: SkyColorPrediction[];
}
