import type { AirQualityProvider } from "../../application/ports/air-quality-provider";
import type { AirQualitySample } from "../../domain";

export class DevelopmentAirQualityProvider implements AirQualityProvider {
  async listAirQualitySamples(input: {
    range: { startsAtIso: string; endsAtIso: string };
  }): Promise<AirQualitySample[]> {
    return buildHourlySamples(input.range, (timeIso) => ({
      timeIso,
      aerosolOpticalDepth: 0.22,
      particulateMatter2_5UgM3: 12,
      particulateMatter10UgM3: 21,
      dustUgM3: 8,
      ozoneUgM3: 72,
    }));
  }
}

function buildHourlySamples<T>(
  range: { startsAtIso: string; endsAtIso: string },
  buildSample: (timeIso: string) => T,
): T[] {
  const samples: T[] = [];
  const cursor = new Date(range.startsAtIso);
  const end = Date.parse(range.endsAtIso);

  cursor.setUTCMinutes(0, 0, 0);

  while (cursor.getTime() <= end) {
    samples.push(buildSample(cursor.toISOString()));
    cursor.setUTCHours(cursor.getUTCHours() + 1);
  }

  return samples;
}
