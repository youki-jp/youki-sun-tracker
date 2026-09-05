import { ValidationError } from "../../application/errors";
import type { SolarProvider } from "../../application/ports/solar-provider";
import {
  addMinutesToLocalIso,
  localIsoToUtcMillis,
  parseLocalIsoToMillis,
  utcMillisToLocalIso,
} from "../../application/services/local-date-time";
import type {
  SkyEventKind,
  SolarDayMilestones,
  SolarDaySample,
  SolarEventWindow,
  SolarSample,
  TwilightPhase,
} from "../../domain";
import {
  calculateSolarDayMilestones,
  mapElevationToPhase,
} from "../solar/solar-events";
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

  async getDayMilestones(input: {
    location: { latitude: number; longitude: number };
    timezoneId: string;
    targetDateIso: string;
  }): Promise<SolarDayMilestones> {
    return calculateSolarDayMilestones({
      latitude: input.location.latitude,
      longitude: input.location.longitude,
      timezoneId: input.timezoneId,
      targetDateIso: input.targetDateIso,
    });
  }

  /**
   * Walk a whole local day, spacing samples by how fast the sky is actually
   * changing. Near the horizon the sun moves through the elevations that drive
   * colour in minutes; at midday almost nothing happens for hours. Sampling
   * uniformly would either miss the interesting part or waste most of the
   * payload on a static blue sky.
   *
   * This is local astronomy only. The weather and air-quality rows for the
   * whole day are already fetched and discarded by the existing providers, so
   * covering a full day costs no additional network calls.
   */
  async listDaySamples(input: {
    location: { latitude: number; longitude: number };
    timezoneId: string;
    targetDateIso: string;
    milestones: SolarDayMilestones;
  }): Promise<SolarDaySample[]> {
    const { latitude, longitude } = input.location;
    const startMs = localIsoToUtcMillis(
      `${input.targetDateIso}T00:00:00`,
      input.timezoneId,
    );
    const endMs =
      localIsoToUtcMillis(
        `${nextDateIso(input.targetDateIso)}T00:00:00`,
        input.timezoneId,
      ) - 1;

    const timestamps = new Set<number>();

    for (let ms = startMs; ms <= endMs; ) {
      timestamps.add(ms);
      const elevation = calculateSolarPosition({
        utcMillis: ms,
        latitude,
        longitude,
      }).elevationDegrees;
      const nextElevation = calculateSolarPosition({
        utcMillis: ms + 60_000,
        latitude,
        longitude,
      }).elevationDegrees;
      ms += stepMinutesFor(elevation, nextElevation - elevation) * 60_000;
    }

    // Pin the named moments exactly, so scrubbing to a milestone shows the
    // sky at that milestone rather than at the nearest grid point.
    milestoneIsoValues(input.milestones).forEach((iso) => {
      timestamps.add(localIsoToUtcMillis(iso, input.timezoneId));
    });

    return [...timestamps]
      .filter((ms) => ms >= startMs && ms <= endMs)
      .sort((a, b) => a - b)
      .map((ms) => {
        const position = calculateSolarPosition({
          utcMillis: ms,
          latitude,
          longitude,
        });
        const isRising =
          calculateSolarPosition({
            utcMillis: ms + 60_000,
            latitude,
            longitude,
          }).elevationDegrees > position.elevationDegrees;

        return {
          timeIso: utcMillisToLocalIso(ms, input.timezoneId),
          elevationDegrees: round2(position.elevationDegrees),
          azimuthDegrees: round2(position.azimuthDegrees),
          isRising,
          phase: mapElevationToPhase(position.elevationDegrees, isRising),
        };
      });
  }
}

/**
 * Space samples by how far the sun will actually move, not by where it is.
 *
 * Keying off elevation alone breaks at high latitude: near the poles the sun
 * can sit within a few degrees of the horizon all day, which makes every hour
 * look like golden hour and explodes the sample count for a sky that is barely
 * changing. Dividing a target elevation delta by the current rate of change
 * gives dense samples exactly where the sky moves quickly and sparse ones
 * where it does not, at any latitude.
 */
function stepMinutesFor(
  elevationDegrees: number,
  degreesPerMinute: number,
): number {
  const absolute = Math.abs(elevationDegrees);
  const targetDelta = absolute <= 8 ? 0.5 : absolute <= 18 ? 1.5 : 4;
  const rate = Math.max(Math.abs(degreesPerMinute), 1e-4);

  return Math.min(Math.max(targetDelta / rate, 4), 60);
}

function milestoneIsoValues(milestones: SolarDayMilestones): string[] {
  return Object.entries(milestones)
    .filter(([key]) => key.endsWith("Iso"))
    .map(([, value]) => value)
    .filter((value): value is string => typeof value === "string");
}

function nextDateIso(dateIso: string): string {
  const date = new Date(`${dateIso}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + 1);
  return date.toISOString().slice(0, 10);
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
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
