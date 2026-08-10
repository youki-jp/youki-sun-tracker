export type IsoDateString = string;
export type IsoDateTimeString = string;

export type SkyEventKind = "sunrise" | "sunset";

export type TwilightPhase =
  | "day"
  | "civil"
  | "nautical"
  | "astronomical"
  | "night";

export type SkyColorLabel = "muted" | "pastel" | "warm" | "vivid" | "dramatic";

export interface Coordinates {
  latitude: number;
  longitude: number;
}

export interface TimeRange {
  startsAtIso: IsoDateTimeString;
  endsAtIso: IsoDateTimeString;
}
