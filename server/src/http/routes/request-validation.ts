import { ValidationError } from "../../application/errors";
import type { LocationInput } from "../../domain";

export async function readJsonBody(request: Request): Promise<unknown> {
  return request.json().catch(() => {
    throw new ValidationError("Request body must be valid JSON.");
  });
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function parseLocation(value: unknown, fieldPrefix = "location."): LocationInput {
  if (!isRecord(value)) {
    throw new ValidationError("location is required.");
  }

  const latitude = requireNumber(value.latitude, `${fieldPrefix}latitude`);
  const longitude = requireNumber(value.longitude, `${fieldPrefix}longitude`);
  const altitudeMeters = optionalNumber(value.altitudeMeters, `${fieldPrefix}altitudeMeters`);
  if (
    latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180 ||
    (altitudeMeters !== null && (altitudeMeters < -500 || altitudeMeters > 9000))
  ) {
    throw new ValidationError("location is outside the supported range.");
  }
  return { latitude, longitude, altitudeMeters };
}

export function optionalDateString(value: unknown, fieldName: string): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string" || !isRealCalendarDate(value)) {
    throw new ValidationError(`${fieldName} must be a valid YYYY-MM-DD date.`);
  }
  return value;
}

export function requireNumber(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new ValidationError(`${fieldName} must be a number.`);
  }
  return value;
}

export function optionalNumber(value: unknown, fieldName: string): number | null {
  return value === undefined || value === null ? null : requireNumber(value, fieldName);
}

function isRealCalendarDate(value: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return false;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (month < 1 || month > 12 || day < 1) return false;
  const leapYear = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const daysInMonth = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return day <= daysInMonth[month - 1]!;
}
