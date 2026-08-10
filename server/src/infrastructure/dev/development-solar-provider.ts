import type { SolarProvider } from "../../application/ports/solar-provider";
import type {
  SkyEventKind,
  SolarEventWindow,
  SolarSample,
  TwilightPhase,
} from "../../domain";

export class DevelopmentSolarProvider implements SolarProvider {
  async getSolarEventWindow(input: {
    targetDateIso: string;
    kind: SkyEventKind;
  }): Promise<SolarEventWindow> {
    const eventTimeIso = getEventTimeIso(input.targetDateIso, input.kind);
    const eventTimeMs = Date.parse(eventTimeIso);

    return {
      kind: input.kind,
      eventTimeIso,
      scoringWindow: {
        startsAtIso: new Date(
          eventTimeMs + getScoringWindowStartOffsetMs(input.kind),
        ).toISOString(),
        endsAtIso: new Date(
          eventTimeMs + getScoringWindowEndOffsetMs(input.kind),
        ).toISOString(),
      },
      twilight: {
        civilStartsAtIso: new Date(eventTimeMs - 30 * 60 * 1000).toISOString(),
        civilEndsAtIso: new Date(eventTimeMs + 30 * 60 * 1000).toISOString(),
        nauticalStartsAtIso: new Date(eventTimeMs - 60 * 60 * 1000).toISOString(),
        nauticalEndsAtIso: new Date(eventTimeMs + 60 * 60 * 1000).toISOString(),
        astronomicalStartsAtIso: new Date(
          eventTimeMs - 90 * 60 * 1000,
        ).toISOString(),
        astronomicalEndsAtIso: new Date(
          eventTimeMs + 90 * 60 * 1000,
        ).toISOString(),
      },
    };
  }

  async listSolarSamples(input: {
    kind: SkyEventKind;
    range: { startsAtIso: string; endsAtIso: string };
  }): Promise<SolarSample[]> {
    const samples: SolarSample[] = [];
    const cursor = new Date(input.range.startsAtIso);
    const end = Date.parse(input.range.endsAtIso);
    const totalDurationMs = end - cursor.getTime();

    while (cursor.getTime() <= end) {
      const elapsedRatio =
        totalDurationMs === 0
          ? 0
          : (cursor.getTime() - Date.parse(input.range.startsAtIso)) /
            totalDurationMs;
      const elevationDegrees =
        input.kind === "sunrise"
          ? -12 + elapsedRatio * 18
          : 6 - elapsedRatio * 18;

      samples.push({
        timeIso: cursor.toISOString(),
        elevationDegrees,
        azimuthDegrees: input.kind === "sunrise" ? 90 : 270,
        twilightPhase: mapElevationToTwilightPhase(elevationDegrees),
      });

      cursor.setUTCMinutes(cursor.getUTCMinutes() + 15);
    }

    return samples;
  }
}

function getEventTimeIso(targetDateIso: string, kind: SkyEventKind): string {
  return kind === "sunrise"
    ? `${targetDateIso}T06:00:00.000Z`
    : `${targetDateIso}T18:00:00.000Z`;
}

function getScoringWindowStartOffsetMs(kind: SkyEventKind): number {
  return kind === "sunrise" ? -60 * 60 * 1000 : -30 * 60 * 1000;
}

function getScoringWindowEndOffsetMs(kind: SkyEventKind): number {
  return kind === "sunrise" ? 30 * 60 * 1000 : 75 * 60 * 1000;
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
