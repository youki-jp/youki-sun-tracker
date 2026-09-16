import type {
  IsoDateTimeString,
  SkyEventKind,
  TimeRange,
  TwilightPhase,
} from "./shared";

export interface TwilightBoundaries {
  civilStartsAtIso: IsoDateTimeString;
  civilEndsAtIso: IsoDateTimeString;
  nauticalStartsAtIso: IsoDateTimeString;
  nauticalEndsAtIso: IsoDateTimeString;
  astronomicalStartsAtIso: IsoDateTimeString;
  astronomicalEndsAtIso: IsoDateTimeString;
}

export interface SolarEventWindow {
  kind: SkyEventKind;
  eventTimeIso: IsoDateTimeString;
  scoringWindow: TimeRange;
  twilight: TwilightBoundaries;
}

export interface SolarSample {
  timeIso: IsoDateTimeString;
  elevationDegrees: number;
  azimuthDegrees: number;
  twilightPhase: TwilightPhase;
}

export type SolarPhaseKind =
  | "night"
  | "nauticalDawn"
  | "civilDawn"
  | "blueHourAm"
  | "goldenHourAm"
  | "day"
  | "goldenHourPm"
  | "blueHourPm"
  | "civilDusk"
  | "nauticalDusk";

/**
 * Named moments across one local day, derived from real solar elevation
 * crossings. Any of them may be null inside the polar circles, where the sun
 * can stay above or below a threshold for the whole day.
 */
export interface SolarDayMilestones {
  astronomicalDawnIso: IsoDateTimeString | null;
  nauticalDawnIso: IsoDateTimeString | null;
  civilDawnIso: IsoDateTimeString | null;
  goldenHourStartIso: IsoDateTimeString | null;
  sunriseIso: IsoDateTimeString | null;
  goldenHourEndIso: IsoDateTimeString | null;
  solarNoonIso: IsoDateTimeString;
  goldenHourPmStartIso: IsoDateTimeString | null;
  sunsetIso: IsoDateTimeString | null;
  goldenHourPmEndIso: IsoDateTimeString | null;
  civilDuskIso: IsoDateTimeString | null;
  nauticalDuskIso: IsoDateTimeString | null;
  astronomicalDuskIso: IsoDateTimeString | null;
  daylightMinutes: number | null;
  maxElevationDegrees: number;
  minElevationDegrees: number;
}

/** One moment on the day timeline, before weather is attached. */
export interface SolarDaySample {
  timeIso: IsoDateTimeString;
  elevationDegrees: number;
  azimuthDegrees: number;
  isRising: boolean;
  phase: SolarPhaseKind;
}
