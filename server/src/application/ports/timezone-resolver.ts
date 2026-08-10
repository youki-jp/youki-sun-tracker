import type { LocationInput } from "../../domain";

export interface TimezoneResolver {
  resolveTimezone(location: LocationInput): Promise<string>;
}
