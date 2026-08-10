import type { IsoDateTimeString } from "./shared";

export interface AirQualitySample {
  timeIso: IsoDateTimeString;
  aerosolOpticalDepth: number | null;
  particulateMatter2_5UgM3: number | null;
  particulateMatter10UgM3: number | null;
  dustUgM3: number | null;
  ozoneUgM3: number | null;
}
