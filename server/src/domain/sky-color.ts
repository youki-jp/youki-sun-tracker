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

export interface SkyColorPredictionRequest {
  location: LocationInput;
  targetDateIso: IsoDateString | null;
  requestedEvents: SkyEventKind[];
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
  window: SolarEventWindow;
}

export interface SkyColorApiResponse {
  location: ResolvedLocation;
  generatedAtIso: IsoDateTimeString;
  predictions: SkyColorPrediction[];
}
