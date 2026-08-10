import type { SkyColorEngine } from "../../application/ports/sky-color-engine";
import type {
  SkyColorEventContext,
  SkyColorLabel,
  SkyColorPrediction,
} from "../../domain";

export class DevelopmentSkyColorEngine implements SkyColorEngine {
  async predict(
    contexts: SkyColorEventContext[],
  ): Promise<SkyColorPrediction[]> {
    return contexts.map((context) => {
      const metrics = summarizeContext(context);
      const score = clamp(
        25 +
          metrics.highCloudBonus +
          metrics.totalCloudBonus +
          metrics.aerosolBonus -
          metrics.lowCloudPenalty -
          metrics.humidityPenalty -
          metrics.visibilityPenalty,
        0,
        100,
      );
      const confidence = Math.round(metrics.dataCoverage * 100);

      return {
        kind: context.window.kind,
        score,
        confidence,
        label: mapScoreToLabel(score),
        dominantColors: buildDominantColors(score),
        reasons: buildReasons(metrics),
        window: context.window,
      };
    });
  }
}

function summarizeContext(context: SkyColorEventContext) {
  const totalCloud = averageNullable(
    context.features.map((feature) => feature.weather.cloudCover.totalPct),
  );
  const lowCloud = averageNullable(
    context.features.map((feature) => feature.weather.cloudCover.lowPct),
  );
  const highCloud = averageNullable(
    context.features.map((feature) => feature.weather.cloudCover.highPct),
  );
  const humidity = averageNullable(
    context.features.map((feature) => feature.weather.relativeHumidityPct),
  );
  const visibility = averageNullable(
    context.features.map((feature) => feature.weather.visibilityMeters),
  );
  const aerosol = averageNullable(
    context.features.map((feature) => feature.airQuality.aerosolOpticalDepth),
  );
  const dataCoverage = calculateDataCoverage(context);

  return {
    totalCloud,
    lowCloud,
    highCloud,
    humidity,
    visibility,
    aerosol,
    dataCoverage,
    highCloudBonus: idealRangeBonus(highCloud, 20, 55, 18),
    totalCloudBonus: idealRangeBonus(totalCloud, 25, 60, 14),
    aerosolBonus: idealRangeBonus(aerosol, 0.12, 0.35, 16),
    lowCloudPenalty: highValuePenalty(lowCloud, 35, 22),
    humidityPenalty: highValuePenalty(humidity, 82, 10),
    visibilityPenalty: lowValuePenalty(visibility, 6_000, 12),
  };
}

function buildReasons(metrics: ReturnType<typeof summarizeContext>): string[] {
  const reasons: string[] = [];

  if (metrics.highCloud >= 20 && metrics.highCloud <= 55) {
    reasons.push("High clouds may catch warm low-angle light.");
  }

  if (metrics.lowCloud >= 50) {
    reasons.push("Low clouds near the horizon may block direct color.");
  }

  if (metrics.aerosol >= 0.12 && metrics.aerosol <= 0.35) {
    reasons.push("Moderate aerosols may enhance warm sunrise and sunset tones.");
  }

  if (metrics.visibility < 6_000) {
    reasons.push("Reduced visibility may flatten contrast and clarity.");
  }

  if (metrics.humidity >= 82) {
    reasons.push("High humidity may soften the scene into pastel haze.");
  }

  if (reasons.length === 0) {
    reasons.push("This prediction is based on a temporary development heuristic.");
  }

  return reasons;
}

function buildDominantColors(score: number): string[] {
  if (score >= 80) {
    return ["amber", "orange", "magenta"];
  }

  if (score >= 60) {
    return ["peach", "gold", "pink"];
  }

  if (score >= 40) {
    return ["soft blue", "pastel pink", "warm gray"];
  }

  return ["gray-blue", "soft gray"];
}

function mapScoreToLabel(score: number): SkyColorLabel {
  if (score >= 80) {
    return "dramatic";
  }

  if (score >= 65) {
    return "vivid";
  }

  if (score >= 50) {
    return "warm";
  }

  if (score >= 35) {
    return "pastel";
  }

  return "muted";
}

function calculateDataCoverage(context: SkyColorEventContext): number {
  const totalValues = context.features.length * 10;
  const presentValues = context.features.reduce((sum, feature) => {
    const values = [
      feature.weather.cloudCover.totalPct,
      feature.weather.cloudCover.lowPct,
      feature.weather.cloudCover.midPct,
      feature.weather.cloudCover.highPct,
      feature.weather.visibilityMeters,
      feature.weather.relativeHumidityPct,
      feature.weather.dewPointCelsius,
      feature.weather.precipitationMillimeters,
      feature.airQuality.aerosolOpticalDepth,
      feature.airQuality.ozoneUgM3,
    ];

    return sum + values.filter((value) => value !== null).length;
  }, 0);

  return totalValues === 0 ? 0 : presentValues / totalValues;
}

function averageNullable(values: Array<number | null>): number {
  const presentValues = values.filter((value): value is number => value !== null);

  if (presentValues.length === 0) {
    return 0;
  }

  return presentValues.reduce((sum, value) => sum + value, 0) / presentValues.length;
}

function idealRangeBonus(
  value: number,
  min: number,
  max: number,
  fullBonus: number,
): number {
  if (value >= min && value <= max) {
    return fullBonus;
  }

  const midpoint = (min + max) / 2;
  const distance = Math.abs(value - midpoint);
  const range = max - min || 1;

  return clamp(fullBonus - (distance / range) * fullBonus, 0, fullBonus);
}

function highValuePenalty(
  value: number,
  threshold: number,
  maxPenalty: number,
): number {
  if (value <= threshold) {
    return 0;
  }

  return clamp(((value - threshold) / threshold) * maxPenalty, 0, maxPenalty);
}

function lowValuePenalty(
  value: number,
  threshold: number,
  maxPenalty: number,
): number {
  if (value >= threshold) {
    return 0;
  }

  return clamp(((threshold - value) / threshold) * maxPenalty, 0, maxPenalty);
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(Math.round(value), min), max);
}
