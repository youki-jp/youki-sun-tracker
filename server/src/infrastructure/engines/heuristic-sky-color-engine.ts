import type { SkyColorEngine } from "../../application/ports/sky-color-engine";
import type {
  SkyColorEventContext,
  SkyColorLabel,
  SkyColorPrediction,
} from "../../domain";

interface ContextMetrics {
  totalCloud: number;
  lowCloud: number;
  highCloud: number;
  humidity: number;
  visibility: number;
  aerosol: number;
  precipitation: number;
  dust: number;
  pm2_5: number;
  dataCoverage: number;
  highCloudBonus: number;
  totalCloudBonus: number;
  aerosolBonus: number;
  dustBonus: number;
  lowCloudPenalty: number;
  humidityPenalty: number;
  visibilityPenalty: number;
  precipitationPenalty: number;
}

export class HeuristicSkyColorEngine implements SkyColorEngine {
  async predict(
    contexts: SkyColorEventContext[],
  ): Promise<SkyColorPrediction[]> {
    return contexts.map((context) => {
      const metrics = summarizeContext(context);
      const score = clamp(
        30 +
          metrics.highCloudBonus +
          metrics.totalCloudBonus +
          metrics.aerosolBonus +
          metrics.dustBonus -
          metrics.lowCloudPenalty -
          metrics.humidityPenalty -
          metrics.visibilityPenalty -
          metrics.precipitationPenalty,
        0,
        100,
      );
      const confidence = clamp(Math.round(metrics.dataCoverage * 100), 0, 100);
      const palette = buildPalette(context.window.kind, score, metrics);

      return {
        kind: context.window.kind,
        score,
        confidence,
        label: mapScoreToLabel(score),
        estimatedColorName: palette.primary.name,
        estimatedHex: palette.primary.hex,
        dominantColors: palette.secondary,
        reasons: buildReasons(metrics),
        window: context.window,
      };
    });
  }
}

function summarizeContext(context: SkyColorEventContext): ContextMetrics {
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
  const precipitation = averageNullable(
    context.features.map((feature) => feature.weather.precipitationMillimeters),
  );
  const dust = averageNullable(
    context.features.map((feature) => feature.airQuality.dustUgM3),
  );
  const pm2_5 = averageNullable(
    context.features.map(
      (feature) => feature.airQuality.particulateMatter2_5UgM3,
    ),
  );
  const dataCoverage = calculateDataCoverage(context);

  return {
    totalCloud,
    lowCloud,
    highCloud,
    humidity,
    visibility,
    aerosol,
    precipitation,
    dust,
    pm2_5,
    dataCoverage,
    highCloudBonus: idealRangeBonus(highCloud, 18, 58, 18),
    totalCloudBonus: idealRangeBonus(totalCloud, 25, 65, 12),
    aerosolBonus: idealRangeBonus(aerosol, 0.1, 0.35, 18),
    dustBonus: idealRangeBonus(dust, 5, 35, 8),
    lowCloudPenalty: highValuePenalty(lowCloud, 40, 24),
    humidityPenalty: highValuePenalty(humidity, 84, 8),
    visibilityPenalty: lowValuePenalty(visibility, 7_500, 12),
    precipitationPenalty: highValuePenalty(precipitation, 0.2, 16),
  };
}

function buildReasons(metrics: ContextMetrics): string[] {
  const reasons: string[] = [];

  if (metrics.highCloud >= 18 && metrics.highCloud <= 58) {
    reasons.push("High clouds are in a range that often catches warm horizon light.");
  }

  if (metrics.lowCloud >= 45) {
    reasons.push("Low cloud near the horizon may block direct sunrise or sunset color.");
  }

  if (metrics.aerosol >= 0.1 && metrics.aerosol <= 0.35) {
    reasons.push("Moderate aerosol levels can deepen orange and pink tones.");
  }

  if (metrics.dust >= 10) {
    reasons.push("Dust can push the sky toward warmer amber and red tones.");
  }

  if (metrics.visibility < 7_500) {
    reasons.push("Lower visibility may mute contrast and reduce color separation.");
  }

  if (metrics.precipitation > 0.2) {
    reasons.push("Ongoing precipitation usually reduces vivid horizon color.");
  }

  if (metrics.humidity >= 84) {
    reasons.push("High humidity may soften the scene into a more pastel glow.");
  }

  if (metrics.pm2_5 >= 20) {
    reasons.push("Fine particulates may intensify warm scattering but can also flatten clarity.");
  }

  if (reasons.length === 0) {
    reasons.push("Cloud and aerosol conditions look broadly balanced for a decent glow.");
  }

  return reasons;
}

function buildPalette(
  kind: "sunrise" | "sunset",
  score: number,
  metrics: ContextMetrics,
): {
  primary: { name: string; hex: string };
  secondary: string[];
} {
  if (score >= 80) {
    return kind === "sunrise"
      ? {
          primary: { name: "rose gold", hex: "#F5A26F" },
          secondary: ["soft coral", "apricot", "warm pink"],
        }
      : {
          primary: { name: "burnt orange", hex: "#E26D3D" },
          secondary: ["amber", "crimson", "magenta"],
        };
  }

  if (score >= 60) {
    return kind === "sunrise"
      ? {
          primary: { name: "peach", hex: "#F4B183" },
          secondary: ["gold", "blush pink", "light apricot"],
        }
      : {
          primary: { name: "golden orange", hex: "#F29F43" },
          secondary: ["peach", "pink", "warm gold"],
        };
  }

  if (score >= 40) {
    return metrics.humidity >= 84
      ? {
          primary: { name: "pastel pink", hex: "#E8B7C8" },
          secondary: ["soft lavender", "powder blue", "light gray"],
        }
      : {
          primary: { name: "warm gray", hex: "#C4B8AA" },
          secondary: ["soft blue", "light peach", "muted pink"],
        };
  }

  return {
    primary: { name: "muted blue-gray", hex: "#8C97A8" },
    secondary: ["gray", "soft slate", "cool beige"],
  };
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
  const totalValues = context.features.length * 12;
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
      feature.airQuality.dustUgM3,
      feature.airQuality.particulateMatter2_5UgM3,
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

  return (
    presentValues.reduce((sum, value) => sum + value, 0) / presentValues.length
  );
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
