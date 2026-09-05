import { ValidationError } from "../../application/errors";
import type { SolarProvider } from "../../application/ports/solar-provider";
import {
  addMinutesToLocalIso,
  localIsoToUtcMillis,
  parseLocalIsoToMillis,
} from "../../application/services/local-date-time";
import type {
  SkyEventKind,
  SolarEventWindow,
  SolarSample,
  TwilightPhase,
} from "../../domain";
import { calculateSolarPosition } from "../solar/solar-position";
import type { OpenMeteoDailyForecastResponse } from "./open-meteo-types";
import { OpenMeteoClient } from "./open-meteo-client";

const SAMPLE_INTERVAL_MINUTES = 15;

export class OpenMeteoSolarProvider implements SolarProvider {
  constructor(private readonly client: OpenMeteoClient) {}

  async getSolarEventWindow(input: {
    location: { latitude: number; longitude: number; altitudeMeters: number | null };
    timezoneId: string;
    targetDateIso: string;
    kind: SkyEventKind;
  }): Promise<SolarEventWindow> {
    const response = await this.client.getJson<OpenMeteoDailyForecastResponse>(
      "/v1/forecast",
      {
        latitude: String(input.location.latitude),
        longitude: String(input.location.longitude),
        elevation:
          input.location.altitudeMeters === null
            ? "nan"
            : String(input.location.altitudeMeters),
        timezone: input.timezoneId,
        daily: "sunrise,sunset",
        forecast_days: "7",
      },
    );
    const dailyTimes = response.daily?.time ?? [];
    const dayIndex = dailyTimes.indexOf(input.targetDateIso);

    if (dayIndex === -1) {
      throw new ValidationError(
        "targetDateIso is outside the current Open-Meteo forecast window.",
      );
    }

    const eventTimeIso = getEventTimeIso(response, input.kind, dayIndex);

    return {
      kind: input.kind,
      eventTimeIso,
      scoringWindow: {
        startsAtIso: addMinutesToLocalIso(
          eventTimeIso,
          input.kind === "sunrise" ? -60 : -30,
        ),
        endsAtIso: addMinutesToLocalIso(
          eventTimeIso,
          input.kind === "sunrise" ? 30 : 75,
        ),
      },
      twilight: {
        civilStartsAtIso: addMinutesToLocalIso(eventTimeIso, -30),
        civilEndsAtIso: addMinutesToLocalIso(eventTimeIso, 30),
        nauticalStartsAtIso: addMinutesToLocalIso(eventTimeIso, -60),
        nauticalEndsAtIso: addMinutesToLocalIso(eventTimeIso, 60),
        astronomicalStartsAtIso: addMinutesToLocalIso(eventTimeIso, -90),
        astronomicalEndsAtIso: addMinutesToLocalIso(eventTimeIso, 90),
      },
    };
  }

  async listSolarSamples(input: {
    location: { latitude: number; longitude: number };
    timezoneId: string;
    kind: SkyEventKind;
    range: { startsAtIso: string; endsAtIso: string };
  }): Promise<SolarSample[]> {
    const samples: SolarSample[] = [];
    const startMs = parseLocalIsoToMillis(input.range.startsAtIso);
    const endMs = parseLocalIsoToMillis(input.range.endsAtIso);
    const cursor = new Date(startMs);

    while (cursor.getTime() <= endMs) {
      const timeIso = formatLocalSampleTime(cursor);
      const position = calculateSolarPosition({
        utcMillis: localIsoToUtcMillis(timeIso, input.timezoneId),
        latitude: input.location.latitude,
        longitude: input.location.longitude,
      });

      samples.push({
        timeIso,
        elevationDegrees: position.elevationDegrees,
        azimuthDegrees: position.azimuthDegrees,
        twilightPhase: mapElevationToTwilightPhase(position.elevationDegrees),
      });

      cursor.setMinutes(cursor.getMinutes() + SAMPLE_INTERVAL_MINUTES);
    }

    return samples;
  }
}

function getEventTimeIso(
  response: OpenMeteoDailyForecastResponse,
  kind: SkyEventKind,
  dayIndex: number,
): string {
  const values = kind === "sunrise" ? response.daily?.sunrise : response.daily?.sunset;
  const eventTime = values?.[dayIndex];

  if (!eventTime) {
    throw new ValidationError(`Open-Meteo did not return ${kind} for the target day.`);
  }

  return normalizeLocalIso(eventTime);
}

function mapElevationToTwilightPhase(elevationDegrees: number): TwilightPhase {
  if (elevationDegrees >= 0) {
    return "day";
  }

  if (elevationDegrees >= -6) {
    return "civil";
  }

  if (elevationDegrees >= -12) {
    return "nautical";
  }

  if (elevationDegrees >= -18) {
    return "astronomical";
  }

  return "night";
}

function normalizeLocalIso(value: string): string {
  return value.length === 16 ? `${value}:00` : value.replace("Z", "");
}

function formatLocalSampleTime(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  const hour = String(date.getHours()).padStart(2, "0");
  const minute = String(date.getMinutes()).padStart(2, "0");
  const second = String(date.getSeconds()).padStart(2, "0");

  return `${year}-${month}-${day}T${hour}:${minute}:${second}`;
}
