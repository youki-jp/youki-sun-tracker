import type { IsoDateTimeString } from "./shared";

export interface CloudCover {
  totalPct: number | null;
  lowPct: number | null;
  midPct: number | null;
  highPct: number | null;
}

export interface WeatherSample {
  timeIso: IsoDateTimeString;
  cloudCover: CloudCover;
  visibilityMeters: number | null;
  relativeHumidityPct: number | null;
  dewPointCelsius: number | null;
  precipitationMillimeters: number | null;
  uvIndex: number | null;
  solarRadiation?: {
    sampling: "instant";
    directNormalWm2: number | null;
    globalHorizontalWm2: number | null;
    diffuseHorizontalWm2: number | null;
  };
}
