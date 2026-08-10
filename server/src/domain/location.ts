import type { Coordinates } from "./shared";

export interface LocationInput extends Coordinates {
  altitudeMeters: number | null;
}

export interface ResolvedLocation extends LocationInput {
  timezoneId: string;
}
