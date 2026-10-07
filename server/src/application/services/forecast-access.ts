import { AppError, ValidationError } from "../errors";
import type { LocationInput } from "../../domain";
import type { TimezoneResolver } from "../ports/timezone-resolver";
import { getCurrentDateInTimezone } from "./local-date-time";

export function dateAfter(day: string, offset: number): string {
  const date = new Date(`${day}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + offset);
  return date.toISOString().slice(0, 10);
}

/** Date limits are resolved in the forecast location, never the phone's zone. */
export class ForecastAccess {
  constructor(private readonly timezoneResolver: TimezoneResolver) {}

  async resolve(location: LocationInput, requested: string | null, tier: string) {
    const timezoneId = await this.timezoneResolver.resolveTimezone(location);
    const today = getCurrentDateInTimezone(timezoneId);
    const targetDateIso = requested ?? today;
    if (targetDateIso < today || targetDateIso > dateAfter(today, 6)) {
      throw new ValidationError("Choose a date from today through the next six days.");
    }
    if (tier !== "pro" && targetDateIso > dateAfter(today, 1)) {
      throw new AppError("Pro includes the seven-day outlook. Free includes today and tomorrow.", "pro_required", 403);
    }
    return { timezoneId, today, targetDateIso };
  }
}
