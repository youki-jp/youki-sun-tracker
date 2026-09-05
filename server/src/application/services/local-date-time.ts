import { ValidationError } from "../errors";

export function getCurrentDateInTimezone(timezoneId: string): string {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezoneId,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const parts = formatter.formatToParts(new Date());
  const year = parts.find((part) => part.type === "year")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  const day = parts.find((part) => part.type === "day")?.value;

  if (!year || !month || !day) {
    throw new ValidationError("Unable to determine the current date.");
  }

  return `${year}-${month}-${day}`;
}

export function addMinutesToLocalIso(
  localIso: string,
  minutes: number,
): string {
  const date = parseLocalDateTime(localIso);

  date.setMinutes(date.getMinutes() + minutes);

  return formatLocalDateTime(date);
}

export function isLocalIsoWithinRange(
  value: string,
  range: { startsAtIso: string; endsAtIso: string },
): boolean {
  const timestamp = parseLocalIsoToMillis(value);

  return (
    timestamp >= parseLocalIsoToMillis(range.startsAtIso) &&
    timestamp <= parseLocalIsoToMillis(range.endsAtIso)
  );
}

export function parseLocalIsoToMillis(value: string): number {
  return parseLocalDateTime(value).getTime();
}

/**
 * Resolve a wall-clock time in a named zone to a real UTC instant.
 *
 * Every timeIso in this service is a naive local string with no offset, which
 * is fine for ordering and comparison but useless for astronomy. Anything that
 * needs a true instant must go through here.
 */
export function localIsoToUtcMillis(
  value: string,
  timezoneId: string,
): number {
  const parts = parseLocalDateTimeParts(value);
  const wallClockAsUtc = Date.UTC(
    parts.year,
    parts.month - 1,
    parts.day,
    parts.hour,
    parts.minute,
    parts.second,
  );

  // The offset depends on the instant we are trying to find, so guess with the
  // wall-clock reading, then refine once. Two passes settle DST transitions.
  const firstGuess = getTimezoneOffsetMillis(timezoneId, wallClockAsUtc);
  const offset = getTimezoneOffsetMillis(
    timezoneId,
    wallClockAsUtc - firstGuess,
  );

  return wallClockAsUtc - offset;
}

function getTimezoneOffsetMillis(
  timezoneId: string,
  utcMillis: number,
): number {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezoneId,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  const parts = formatter.formatToParts(new Date(utcMillis));
  const read = (type: string): number => {
    const value = parts.find((part) => part.type === type)?.value;

    if (value === undefined) {
      throw new ValidationError(`Unable to resolve timezone: ${timezoneId}`);
    }

    return Number(value);
  };

  const asUtc = Date.UTC(
    read("year"),
    read("month") - 1,
    read("day"),
    read("hour"),
    read("minute"),
    read("second"),
  );

  return asUtc - utcMillis;
}

interface LocalDateTimeParts {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
}

function parseLocalDateTimeParts(value: string): LocalDateTimeParts {
  const normalized = value.trim().replace("Z", "");
  const match = normalized.match(
    /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/,
  );

  if (!match) {
    throw new ValidationError(`Invalid local datetime: ${value}`);
  }

  const [, year, month, day, hour, minute, second = "00"] = match;

  return {
    year: Number(year),
    month: Number(month),
    day: Number(day),
    hour: Number(hour),
    minute: Number(minute),
    second: Number(second),
  };
}

function parseLocalDateTime(value: string): Date {
  const parts = parseLocalDateTimeParts(value);

  return new Date(
    parts.year,
    parts.month - 1,
    parts.day,
    parts.hour,
    parts.minute,
    parts.second,
    0,
  );
}

function formatLocalDateTime(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  const hour = String(date.getHours()).padStart(2, "0");
  const minute = String(date.getMinutes()).padStart(2, "0");
  const second = String(date.getSeconds()).padStart(2, "0");

  return `${year}-${month}-${day}T${hour}:${minute}:${second}`;
}
