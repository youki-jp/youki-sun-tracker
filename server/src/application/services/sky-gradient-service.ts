import type {
  AirQualitySample,
  SkyDayTimelineResponse,
  SolarDaySample,
  WeatherSample,
} from "../../domain";
import type {
  NormalizedSkyObservation,
  SkyGradientAvailability,
  SkyGradientAvailabilityGroup,
  SkyGradientNumericField,
  SkyGradientOutput,
} from "../../domain/sky-gradient";
import type { SkyGradientEngine } from "../ports/sky-gradient-engine";

type TimelineGrids = Pick<
  SkyDayTimelineResponse,
  "solar" | "weather" | "airQuality"
>;

export interface SkyGradientRequest {
  timeline: TimelineGrids;
  atIso: string;
}

export interface SkyGradientResult {
  observation: NormalizedSkyObservation;
  availability: SkyGradientAvailability;
  output: SkyGradientOutput;
}

/**
 * Joins one local wall-clock moment to the independent timeline grids.
 * Numeric values are interpolated between bracketing rows and clamped at the
 * ends. Missing values stay null; renderer defaults belong in the engine.
 */
export function normalizeSkyObservation(
  request: SkyGradientRequest,
): { observation: NormalizedSkyObservation; availability: SkyGradientAvailability } {
  const atMillis = localIsoToComparableMillis(request.atIso);
  const solar = interpolateSolar(request.timeline.solar, atMillis);
  if (!solar) {
    throw new Error("Cannot generate a sky gradient without solar samples");
  }

  const weather = interpolateWeather(request.timeline.weather, atMillis);
  const airQuality = interpolateAirQuality(
    request.timeline.airQuality,
    atMillis,
  );
  const availability: SkyGradientAvailability = {
    solar: true,
    weather: weather.availability,
    airQuality: airQuality.availability,
  };

  const observation: NormalizedSkyObservation = {
    timeIso: request.atIso,
    elevationDegrees: solar.elevationDegrees,
    azimuthDegrees: solar.azimuthDegrees,
    isRising: solar.isRising,
    phase: solar.phase,
    ...weather.values,
    ...airQuality.values,
    availability,
  };

  return { observation, availability };
}

export class SkyGradientService {
  constructor(private readonly engine: SkyGradientEngine) {}

  execute(request: SkyGradientRequest): SkyGradientResult {
    const normalized = normalizeSkyObservation(request);
    return {
      ...normalized,
      output: this.engine.generate(normalized.observation),
    };
  }
}

interface TimedRow {
  timeIso: string;
}

interface InterpolatedWeather {
  values: Pick<
    NormalizedSkyObservation,
    | "cloudTotalPct"
    | "cloudLowPct"
    | "cloudMidPct"
    | "cloudHighPct"
    | "visibilityMeters"
    | "relativeHumidityPct"
    | "precipitationMillimeters"
  >;
  availability: SkyGradientAvailabilityGroup;
}

interface InterpolatedAirQuality {
  values: Pick<
    NormalizedSkyObservation,
    "aerosolOpticalDepth" | "dustUgM3" | "pm25UgM3"
  >;
  availability: SkyGradientAvailabilityGroup;
}

function interpolateSolar(
  rows: SolarDaySample[],
  targetMillis: number,
): SolarDaySample | null {
  const sorted = sortRows(rows);
  if (sorted.length === 0) return null;
  const bracket = bracketRows(sorted, targetMillis);
  if (!bracket.after) return bracket.before;
  if (!bracket.before) return bracket.after;

  const t = interpolationFraction(bracket.before, bracket.after, targetMillis);
  return {
    timeIso: sorted[0].timeIso,
    elevationDegrees: lerp(
      bracket.before.elevationDegrees,
      bracket.after.elevationDegrees,
      t,
    ),
    azimuthDegrees: lerp(
      bracket.before.azimuthDegrees,
      bracket.after.azimuthDegrees,
      t,
    ),
    isRising: t < 0.5 ? bracket.before.isRising : bracket.after.isRising,
    phase: t < 0.5 ? bracket.before.phase : bracket.after.phase,
  };
}

function interpolateWeather(
  rows: WeatherSample[],
  targetMillis: number,
): InterpolatedWeather {
  const sorted = sortRows(rows);
  const fields: Record<SkyGradientNumericField, boolean> = emptyFieldMap();
  for (const row of sorted) {
    markField(fields, "cloudTotalPct", row.cloudCover.totalPct);
    markField(fields, "cloudLowPct", row.cloudCover.lowPct);
    markField(fields, "cloudMidPct", row.cloudCover.midPct);
    markField(fields, "cloudHighPct", row.cloudCover.highPct);
    markField(fields, "visibilityMeters", row.visibilityMeters);
    markField(fields, "relativeHumidityPct", row.relativeHumidityPct);
    markField(fields, "precipitationMillimeters", row.precipitationMillimeters);
  }

  return {
    values: {
      cloudTotalPct: clampNullable(
        interpolateNullableField(sorted, targetMillis, (row) => row.cloudCover.totalPct),
        0,
        100,
      ),
      cloudLowPct: clampNullable(
        interpolateNullableField(sorted, targetMillis, (row) => row.cloudCover.lowPct),
        0,
        100,
      ),
      cloudMidPct: clampNullable(
        interpolateNullableField(sorted, targetMillis, (row) => row.cloudCover.midPct),
        0,
        100,
      ),
      cloudHighPct: clampNullable(
        interpolateNullableField(sorted, targetMillis, (row) => row.cloudCover.highPct),
        0,
        100,
      ),
      visibilityMeters: clampNullable(
        interpolateNullableField(sorted, targetMillis, (row) => row.visibilityMeters),
        0,
        100_000,
      ),
      relativeHumidityPct: clampNullable(
        interpolateNullableField(sorted, targetMillis, (row) => row.relativeHumidityPct),
        0,
        100,
      ),
      precipitationMillimeters: clampNullable(
        interpolateNullableField(sorted, targetMillis, (row) => row.precipitationMillimeters),
        0,
        100,
      ),
    },
    availability: {
      rowCount: sorted.length,
      clamped: isOutsideRange(sorted, targetMillis),
      fields,
    },
  };
}

function interpolateAirQuality(
  rows: AirQualitySample[],
  targetMillis: number,
): InterpolatedAirQuality {
  const sorted = sortRows(rows);
  const fields: Record<SkyGradientNumericField, boolean> = emptyFieldMap();
  for (const row of sorted) {
    markField(fields, "aerosolOpticalDepth", row.aerosolOpticalDepth);
    markField(fields, "dustUgM3", row.dustUgM3);
    markField(fields, "pm25UgM3", row.particulateMatter2_5UgM3);
  }

  return {
    values: {
      aerosolOpticalDepth: clampNullable(
        interpolateNullableField(sorted, targetMillis, (row) => row.aerosolOpticalDepth),
        0,
        2,
      ),
      dustUgM3: clampNullable(
        interpolateNullableField(sorted, targetMillis, (row) => row.dustUgM3),
        0,
        1_000,
      ),
      pm25UgM3: clampNullable(
        interpolateNullableField(sorted, targetMillis, (row) => row.particulateMatter2_5UgM3),
        0,
        1_000,
      ),
    },
    availability: {
      rowCount: sorted.length,
      clamped: isOutsideRange(sorted, targetMillis),
      fields,
    },
  };
}

function interpolateNullableField<T extends TimedRow>(
  rows: T[],
  targetMillis: number,
  read: (row: T) => number | null,
): number | null {
  if (rows.length === 0) return null;
  const bracket = bracketRows(rows, targetMillis);
  const before = bracket.before ?? bracket.after;
  const after = bracket.after ?? bracket.before;
  if (!before || !after) return null;

  const beforeValue = finiteOrNull(read(before));
  const afterValue = finiteOrNull(read(after));
  if (before === after) return beforeValue ?? afterValue;
  if (beforeValue === null) return afterValue;
  if (afterValue === null) return beforeValue;
  return lerp(
    beforeValue,
    afterValue,
    interpolationFraction(before, after, targetMillis),
  );
}

function bracketRows<T extends TimedRow>(
  rows: T[],
  targetMillis: number,
): { before: T | null; after: T | null } {
  if (rows.length === 0) return { before: null, after: null };
  if (targetMillis <= localIsoToComparableMillis(rows[0].timeIso)) {
    return { before: rows[0], after: null };
  }
  const last = rows[rows.length - 1];
  if (targetMillis >= localIsoToComparableMillis(last.timeIso)) {
    return { before: last, after: null };
  }

  for (let index = 0; index < rows.length - 1; index += 1) {
    const before = rows[index];
    const after = rows[index + 1];
    const beforeMillis = localIsoToComparableMillis(before.timeIso);
    const afterMillis = localIsoToComparableMillis(after.timeIso);
    if (targetMillis >= beforeMillis && targetMillis <= afterMillis) {
      return { before, after };
    }
  }

  return { before: last, after: null };
}

function interpolationFraction(
  before: TimedRow,
  after: TimedRow,
  targetMillis: number,
): number {
  const span =
    localIsoToComparableMillis(after.timeIso) -
    localIsoToComparableMillis(before.timeIso);
  return span === 0
    ? 0
    : (targetMillis - localIsoToComparableMillis(before.timeIso)) / span;
}

function sortRows<T extends TimedRow>(rows: T[]): T[] {
  return [...rows].sort(
    (a, b) =>
      localIsoToComparableMillis(a.timeIso) -
      localIsoToComparableMillis(b.timeIso),
  );
}

function isOutsideRange(rows: TimedRow[], targetMillis: number): boolean {
  if (rows.length === 0) return false;
  return (
    targetMillis < localIsoToComparableMillis(rows[0].timeIso) ||
    targetMillis > localIsoToComparableMillis(rows[rows.length - 1].timeIso)
  );
}

function emptyFieldMap(): Record<SkyGradientNumericField, boolean> {
  return {
    cloudTotalPct: false,
    cloudLowPct: false,
    cloudMidPct: false,
    cloudHighPct: false,
    visibilityMeters: false,
    relativeHumidityPct: false,
    precipitationMillimeters: false,
    aerosolOpticalDepth: false,
    dustUgM3: false,
    pm25UgM3: false,
  };
}

function markField(
  fields: Record<SkyGradientNumericField, boolean>,
  field: SkyGradientNumericField,
  value: number | null,
): void {
  if (finiteOrNull(value) !== null) fields[field] = true;
}

function finiteOrNull(value: number | null | undefined): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function clampNullable(value: number | null, lo: number, hi: number): number | null {
  return value === null ? null : Math.min(Math.max(value, lo), hi);
}

function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

function localIsoToComparableMillis(value: string): number {
  const match = value.trim().match(
    /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/,
  );
  if (!match) throw new Error(`Invalid local datetime: ${value}`);
  const [, year, month, day, hour, minute, second = "00"] = match;
  const millis = Date.UTC(
    Number(year),
    Number(month) - 1,
    Number(day),
    Number(hour),
    Number(minute),
    Number(second),
  );
  if (!Number.isFinite(millis)) throw new Error(`Invalid local datetime: ${value}`);
  return millis;
}
