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
}
