import { ExternalServiceError } from "../../application/errors";

const LOCAL_TIMESTAMP_PATTERN = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/;

/** Normalize Open-Meteo wall-clock values without assigning or converting a timezone. */
export function normalizeOpenMeteoLocalTimestamp(value: string): string {
  const match = typeof value === "string" ? LOCAL_TIMESTAMP_PATTERN.exec(value) : null;
  if (!match) {
    throw new ExternalServiceError("Open-Meteo returned an invalid local timestamp.");
  }

  const [, yearText, monthText, dayText, hourText, minuteText, secondText] = match;
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const hour = Number(hourText);
  const minute = Number(minuteText);
  const second = secondText === undefined ? 0 : Number(secondText);
  const leapYear = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const daysInMonth = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  if (
    month < 1 || month > 12 || day < 1 || day > daysInMonth[month - 1]! ||
    hour > 23 || minute > 59 || second > 59
  ) {
    throw new ExternalServiceError("Open-Meteo returned an invalid local timestamp.");
  }

  return secondText === undefined ? `${value}:00` : value;
}
