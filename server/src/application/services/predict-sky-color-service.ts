import type {
  LocationInput,
  ResolvedLocation,
  SkyColorApiResponse,
  SkyColorEventContext,
  SkyColorPredictionRequest,
} from "../../domain";
import type { AirQualityProvider } from "../ports/air-quality-provider";
import type { SkyColorEngine } from "../ports/sky-color-engine";
import type { SolarProvider } from "../ports/solar-provider";
import type { TimezoneResolver } from "../ports/timezone-resolver";
import type { WeatherProvider } from "../ports/weather-provider";
import { alignSkyColorFeatures } from "./align-sky-color-features";

export class PredictSkyColorService {
  constructor(
    private readonly timezoneResolver: TimezoneResolver,
    private readonly solarProvider: SolarProvider,
    private readonly weatherProvider: WeatherProvider,
    private readonly airQualityProvider: AirQualityProvider,
    private readonly skyColorEngine: SkyColorEngine,
  ) {}

  async execute(
    request: SkyColorPredictionRequest,
  ): Promise<SkyColorApiResponse> {
    const timezoneId = await this.timezoneResolver.resolveTimezone(
      request.location,
    );
    const targetDateIso = request.targetDateIso ?? getCurrentUtcDateIso();
    const location = buildResolvedLocation(request.location, timezoneId);
    const contexts = await Promise.all(
      request.requestedEvents.map((kind) =>
        this.buildEventContext({
          location,
          targetDateIso,
          kind,
        }),
      ),
    );

    const predictions = await this.skyColorEngine.predict(contexts);

    return {
      location,
      generatedAtIso: new Date().toISOString(),
      predictions,
    };
  }

  private async buildEventContext(input: {
    location: ResolvedLocation;
    targetDateIso: string;
    kind: "sunrise" | "sunset";
  }): Promise<SkyColorEventContext> {
    const { location, targetDateIso, kind } = input;
    const window = await this.solarProvider.getSolarEventWindow({
      location,
      timezoneId: location.timezoneId,
      targetDateIso,
      kind,
    });

    const [solarSamples, weatherSamples, airQualitySamples] = await Promise.all(
      [
        this.solarProvider.listSolarSamples({
          location,
          timezoneId: location.timezoneId,
          kind,
          range: window.scoringWindow,
        }),
        this.weatherProvider.listWeatherSamples({
          location,
          timezoneId: location.timezoneId,
          range: window.scoringWindow,
        }),
        this.airQualityProvider.listAirQualitySamples({
          location,
          timezoneId: location.timezoneId,
          range: window.scoringWindow,
        }),
      ],
    );

    return {
      location,
      window,
      features: alignSkyColorFeatures({
        solarSamples,
        weatherSamples,
        airQualitySamples,
      }),
    };
  }
}

function buildResolvedLocation(
  location: LocationInput,
  timezoneId: string,
): ResolvedLocation {
  return {
    ...location,
    timezoneId,
  };
}

function getCurrentUtcDateIso(): string {
  return new Date().toISOString().slice(0, 10);
}
