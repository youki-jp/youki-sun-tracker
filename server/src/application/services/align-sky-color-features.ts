import type {
  AirQualitySample,
  SkyColorFeatures,
  SolarSample,
  WeatherSample,
} from "../../domain";

export function alignSkyColorFeatures(input: {
  solarSamples: SolarSample[];
  weatherSamples: WeatherSample[];
  airQualitySamples: AirQualitySample[];
}): SkyColorFeatures[] {
  const { solarSamples, weatherSamples, airQualitySamples } = input;

  return solarSamples.map((solar) => ({
    solar,
    weather: findNearestSample(solar.timeIso, weatherSamples),
    airQuality: findNearestSample(solar.timeIso, airQualitySamples),
  }));
}

function findNearestSample<T extends { timeIso: string }>(
  targetIso: string,
  samples: T[],
): T {
  if (samples.length === 0) {
    throw new Error("Cannot align features without samples");
  }

  const target = Date.parse(targetIso);
  let nearest = samples[0];
  let nearestDistance = Math.abs(Date.parse(samples[0].timeIso) - target);

  for (const sample of samples.slice(1)) {
    const distance = Math.abs(Date.parse(sample.timeIso) - target);

    if (distance < nearestDistance) {
      nearest = sample;
      nearestDistance = distance;
    }
  }

  return nearest;
}
