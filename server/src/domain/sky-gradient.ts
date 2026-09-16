import type { SolarPhaseKind } from "./solar";

export type SkyGradientNumericField =
  | "cloudTotalPct"
  | "cloudLowPct"
  | "cloudMidPct"
  | "cloudHighPct"
  | "visibilityMeters"
  | "relativeHumidityPct"
  | "precipitationMillimeters"
  | "aerosolOpticalDepth"
  | "dustUgM3"
  | "pm25UgM3";

export interface SkyGradientAvailabilityGroup {
  rowCount: number;
  clamped: boolean;
  fields: Record<SkyGradientNumericField, boolean>;
}

export interface SkyGradientAvailability {
  solar: boolean;
  weather: SkyGradientAvailabilityGroup;
  airQuality: SkyGradientAvailabilityGroup;
}

/** One timeline moment after grid joining, before renderer defaults are used. */
export interface NormalizedSkyObservation {
  timeIso: string;
  elevationDegrees: number;
  azimuthDegrees: number;
  isRising: boolean;
  phase: SolarPhaseKind;
  cloudTotalPct: number | null;
  cloudLowPct: number | null;
  cloudMidPct: number | null;
  cloudHighPct: number | null;
  visibilityMeters: number | null;
  relativeHumidityPct: number | null;
  precipitationMillimeters: number | null;
  aerosolOpticalDepth: number | null;
  dustUgM3: number | null;
  pm25UgM3: number | null;
  availability: SkyGradientAvailability;
}

export interface SkyGradientStop {
  hex: string;
  position: number;
}

export interface SkyGradientGlow {
  centerX: number;
  centerY: number;
  radius: number;
  intensity: number;
}

export interface SkyGradientCloudBand {
  y: number;
  height: number;
  hex: string;
  opacity: number;
  blur: number;
}

export interface SkyGradientOutput {
  /** Always nine stops at the fixed positions used by the SwiftUI renderer. */
  stops: SkyGradientStop[];
  /** Five representative colors sampled across the same vertical sky. */
  ramp: string[];
  glow: SkyGradientGlow;
  cloudBands: SkyGradientCloudBand[];
}
