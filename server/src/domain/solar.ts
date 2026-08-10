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
