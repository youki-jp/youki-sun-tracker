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

function parseLocalDateTime(value: string): Date {
  const normalized = value.trim().replace("Z", "");
  const match = normalized.match(
    /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/,
  );

  if (!match) {
    throw new ValidationError(`Invalid local datetime: ${value}`);
  }

  const [, year, month, day, hour, minute, second = "00"] = match;

  return new Date(
    Number(year),
    Number(month) - 1,
    Number(day),
    Number(hour),
    Number(minute),
    Number(second),
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
