import {
  localIsoToUtcMillis,
  utcMillisToLocalIso,
} from "../../application/services/local-date-time";
import type { SolarDayMilestones, SolarPhaseKind } from "../../domain";
import { calculateSolarPosition } from "./solar-position";

/**
 * Elevation thresholds, in apparent degrees.
 *
 * calculateSolarPosition already applies atmospheric refraction, so these are
 * apparent positions of the sun's centre. Sunrise is conventionally the moment
 * the upper limb touches the horizon, which puts the centre one solar radius
 * (about 16 arcminutes) below it.
 */
const ELEVATION = {
  astronomical: -18,
  nautical: -12,
  civil: -6,
  goldenEdge: -4,
  horizon: -0.267,
  goldenTop: 6,
} as const;

/** Coarse scan step. Fine enough to bracket every crossing at any latitude. */
const SCAN_STEP_MINUTES = 2;
const BISECTION_STEPS = 40;
const MINUTE_MS = 60_000;

interface DayContext {
  startMs: number;
  endMs: number;
  latitude: number;
  longitude: number;
  timezoneId: string;
}

export function calculateSolarDayMilestones(input: {
  latitude: number;
  longitude: number;
  timezoneId: string;
  targetDateIso: string;
}): SolarDayMilestones {
  const startMs = localIsoToUtcMillis(`${input.targetDateIso}T00:00:00`, input.timezoneId);
  const context: DayContext = {
    startMs,
    // A calendar day is not always 24 hours. DST shifts land inside this range.
    endMs: startMs + 26 * 60 * MINUTE_MS,
    latitude: input.latitude,
    longitude: input.longitude,
    timezoneId: input.timezoneId,
  };

  const extremes = findElevationExtremes(context);
  const solarNoonMs = refineSolarNoon(context, extremes.maxAtMs);

  /*
   * Anchor every search to solar noon rather than to midnight: dawn events are
   * the crossings before it, dusk events the crossings after. Scanning the
   * clock day from midnight finds the *previous* night's dusk at high
   * latitudes, where evening twilight runs past midnight.
   */
  const dawn = (target: number) =>
    findCrossing(context, target, "rising", context.startMs, solarNoonMs);
  const dusk = (target: number) =>
    findCrossing(
      context,
      target,
      "setting",
      solarNoonMs,
      solarNoonMs + 18 * 60 * MINUTE_MS,
    );

  const sunriseMs = dawn(ELEVATION.horizon);
  const sunsetMs = dusk(ELEVATION.horizon);

  return {
    astronomicalDawnIso: toIso(context, dawn(ELEVATION.astronomical)),
    nauticalDawnIso: toIso(context, dawn(ELEVATION.nautical)),
    civilDawnIso: toIso(context, dawn(ELEVATION.civil)),
    goldenHourStartIso: toIso(context, dawn(ELEVATION.goldenEdge)),
    sunriseIso: toIso(context, sunriseMs),
    goldenHourEndIso: toIso(context, dawn(ELEVATION.goldenTop)),
    solarNoonIso: utcMillisToLocalIso(solarNoonMs, context.timezoneId),
    goldenHourPmStartIso: toIso(context, dusk(ELEVATION.goldenTop)),
    sunsetIso: toIso(context, sunsetMs),
    goldenHourPmEndIso: toIso(context, dusk(ELEVATION.goldenEdge)),
    civilDuskIso: toIso(context, dusk(ELEVATION.civil)),
    nauticalDuskIso: toIso(context, dusk(ELEVATION.nautical)),
    astronomicalDuskIso: toIso(context, dusk(ELEVATION.astronomical)),
    daylightMinutes:
      sunriseMs === null || sunsetMs === null
        ? null
        : Math.round((sunsetMs - sunriseMs) / MINUTE_MS),
    maxElevationDegrees: round2(extremes.maxElevation),
    minElevationDegrees: round2(extremes.minElevation),
  };
}

/** Which named phase a given elevation falls in, for labelling a sample. */
export function mapElevationToPhase(
  elevationDegrees: number,
  isRising: boolean,
): SolarPhaseKind {
  if (elevationDegrees >= ELEVATION.goldenTop) {
    return "day";
  }

  if (elevationDegrees >= ELEVATION.horizon) {
    return isRising ? "goldenHourAm" : "goldenHourPm";
  }

  if (elevationDegrees >= ELEVATION.goldenEdge) {
    return isRising ? "goldenHourAm" : "goldenHourPm";
  }

  if (elevationDegrees >= ELEVATION.civil) {
    return isRising ? "blueHourAm" : "blueHourPm";
  }

  if (elevationDegrees >= ELEVATION.nautical) {
    return isRising ? "civilDawn" : "civilDusk";
  }

  if (elevationDegrees >= ELEVATION.astronomical) {
    return isRising ? "nauticalDawn" : "nauticalDusk";
  }

  return "night";
}

export function elevationAt(
  context: { latitude: number; longitude: number },
  utcMillis: number,
): number {
  return calculateSolarPosition({
    utcMillis,
    latitude: context.latitude,
    longitude: context.longitude,
  }).elevationDegrees;
}

/**
 * Find when the sun crosses a given elevation, either on the way up or the way
 * down. Returns null when it never does: inside the polar circles the sun can
 * stay above or below a threshold for the whole day, and that is a normal
 * answer rather than an error.
 */
function findCrossing(
  context: DayContext,
  targetDegrees: number,
  direction: "rising" | "setting",
  fromMs: number,
  toMs: number,
): number | null {
  const stepMs = SCAN_STEP_MINUTES * MINUTE_MS;
  let previousMs = fromMs;
  let previousDelta = elevationAt(context, previousMs) - targetDegrees;

  for (let ms = fromMs + stepMs; ms <= toMs; ms += stepMs) {
    const delta = elevationAt(context, ms) - targetDegrees;
    const crossed =
      direction === "rising"
        ? previousDelta < 0 && delta >= 0
        : previousDelta > 0 && delta <= 0;

    if (crossed) {
      return bisect(context, targetDegrees, previousMs, ms);
    }

    previousMs = ms;
    previousDelta = delta;
  }

  return null;
}

function bisect(
  context: DayContext,
  targetDegrees: number,
  lowMs: number,
  highMs: number,
): number {
  let low = lowMs;
  let high = highMs;
  const lowDelta = elevationAt(context, low) - targetDegrees;

  for (let i = 0; i < BISECTION_STEPS; i++) {
    const mid = (low + high) / 2;
    const midDelta = elevationAt(context, mid) - targetDegrees;

    if (midDelta === 0) {
      return mid;
    }

    if (midDelta < 0 === lowDelta < 0) {
      low = mid;
    } else {
      high = mid;
    }
  }

  return (low + high) / 2;
}

function findElevationExtremes(context: DayContext): {
  maxElevation: number;
  minElevation: number;
  maxAtMs: number;
} {
  const stepMs = SCAN_STEP_MINUTES * MINUTE_MS;
  let maxElevation = -Infinity;
  let minElevation = Infinity;
  let maxAtMs = context.startMs;

  for (let ms = context.startMs; ms <= context.endMs; ms += stepMs) {
    const elevation = elevationAt(context, ms);

    if (elevation > maxElevation) {
      maxElevation = elevation;
      maxAtMs = ms;
    }

    if (elevation < minElevation) {
      minElevation = elevation;
    }
  }

  return { maxElevation, minElevation, maxAtMs };
}

/**
 * The coarse scan locates solar noon only to within its step. Elevation is
 * smooth and unimodal around the peak, so a ternary search refines it cheaply.
 */
function refineSolarNoon(context: DayContext, approximateMs: number): number {
  let low = approximateMs - SCAN_STEP_MINUTES * MINUTE_MS;
  let high = approximateMs + SCAN_STEP_MINUTES * MINUTE_MS;

  for (let i = 0; i < 60; i++) {
    const third = (high - low) / 3;
    const a = low + third;
    const b = high - third;

    if (elevationAt(context, a) < elevationAt(context, b)) {
      low = a;
    } else {
      high = b;
    }
  }

  return Math.round((low + high) / 2);
}

function toIso(context: DayContext, utcMillis: number | null): string | null {
  return utcMillis === null
    ? null
    : utcMillisToLocalIso(utcMillis, context.timezoneId);
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}
