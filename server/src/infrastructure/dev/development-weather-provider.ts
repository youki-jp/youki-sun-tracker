import type { WeatherProvider } from "../../application/ports/weather-provider";
import type { WeatherSample } from "../../domain";

export class DevelopmentWeatherProvider implements WeatherProvider {
  async listWeatherSamples(input: {
    range: { startsAtIso: string; endsAtIso: string };
  }): Promise<WeatherSample[]> {
    return buildHourlySamples(input.range, (timeIso) => ({
      timeIso,
      cloudCover: {
        totalPct: 42,
        lowPct: 18,
        midPct: 26,
        highPct: 38,
      },
      visibilityMeters: 14_000,
      relativeHumidityPct: 68,
      dewPointCelsius: 11,
      precipitationMillimeters: 0,
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
