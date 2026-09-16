import type {
  LocationInput,
  ResolvedLocation,
  SkyColorEventContext,
  SkyColorFeatures,
  SkyDayTimelineRequest,
  SkyDayTimelineResponse,
  SolarDayMilestones,
  SolarDaySample,
  TwilightPhase,
  WeatherSample,
  AirQualitySample,
} from "../../domain";
import type { AirQualityProvider } from "../ports/air-quality-provider";
import type { SkyColorEngine } from "../ports/sky-color-engine";
import type { SolarProvider } from "../ports/solar-provider";
import type { TimezoneResolver } from "../ports/timezone-resolver";
import type { WeatherProvider } from "../ports/weather-provider";
import { findNearestSample } from "./align-sky-color-features";
import { getCurrentDateInTimezone } from "./local-date-time";

export class SkyDayTimelineService {
  constructor(
    private readonly timezoneResolver: TimezoneResolver,
    private readonly solarProvider: SolarProvider,
    private readonly weatherProvider: WeatherProvider,
    private readonly airQualityProvider: AirQualityProvider,
    private readonly skyColorEngine: SkyColorEngine,
  ) {}

  async execute(
    request: SkyDayTimelineRequest,
  ): Promise<SkyDayTimelineResponse> {
    const timezoneId = await this.timezoneResolver.resolveTimezone(
      request.location,
    );
    const targetDateIso =
      request.targetDateIso ?? getCurrentDateInTimezone(timezoneId);
    const location: ResolvedLocation = { ...request.location, timezoneId };

    const milestones = await this.solarProvider.getDayMilestones({
      location,
      timezoneId,
      targetDateIso,
    });

    // One range covering the whole local day. The providers already download a
    // full week of hourly rows and filter, so this is no more network work
    // than asking for a single 90-minute window.
    const dayRange = {
      startsAtIso: `${targetDateIso}T00:00:00`,
      endsAtIso: `${targetDateIso}T23:59:59`,
    };

    const [solarSamples, weatherSamples, airQualitySamples] = await Promise.all([
      this.solarProvider.listDaySamples({
        location,
        timezoneId,
        targetDateIso,
        milestones,
      }),
      this.weatherProvider.listWeatherSamples({
        location,
        timezoneId,
        range: dayRange,
      }),
      this.airQualityProvider.listAirQualitySamples({
        location,
        timezoneId,
        range: dayRange,
      }),
    ]);

    return {
      location,
      targetDateIso,
      generatedAtIso: new Date().toISOString(),
      milestones,
      solar: solarSamples,
      weather: weatherSamples,
      airQuality: airQualitySamples,
      summary: await this.buildSummary(
        location,
        milestones,
        solarSamples,
        weatherSamples,
        airQualitySamples,
      ),
    };
  }

  /**
   * Score the day's sunrise and sunset from samples already in hand, so the
   * timeline carries the same numbers the prediction endpoint would return
   * without paying for a second round of provider calls.
   */
  private async buildSummary(
    location: ResolvedLocation,
    milestones: SolarDayMilestones,
    solarSamples: SolarDaySample[],
    weatherSamples: WeatherSample[],
    airQualitySamples: AirQualitySample[],
  ): Promise<SkyDayTimelineResponse["summary"]> {
    const contexts: SkyColorEventContext[] = [];
    const kinds: Array<"sunrise" | "sunset"> = [];
    const join = { solarSamples, weatherSamples, airQualitySamples };

    const sunriseContext = buildContext(location, join, "sunrise", milestones);
    if (sunriseContext) {
      contexts.push(sunriseContext);
      kinds.push("sunrise");
    }

    const sunsetContext = buildContext(location, join, "sunset", milestones);
    if (sunsetContext) {
      contexts.push(sunsetContext);
      kinds.push("sunset");
    }

    if (contexts.length === 0) {
      return {
        sunriseLabel: null,
        sunriseScore: null,
        sunsetLabel: null,
        sunsetScore: null,
      };
    }

    const predictions = await this.skyColorEngine.predict(contexts);
    const sunriseIndex = kinds.indexOf("sunrise");
    const sunsetIndex = kinds.indexOf("sunset");

    return {
      sunriseLabel:
        sunriseIndex === -1 ? null : predictions[sunriseIndex].label,
      sunriseScore:
        sunriseIndex === -1 ? null : predictions[sunriseIndex].score,
      sunsetLabel: sunsetIndex === -1 ? null : predictions[sunsetIndex].label,
      sunsetScore: sunsetIndex === -1 ? null : predictions[sunsetIndex].score,
    };
  }
}

function buildContext(
  location: ResolvedLocation,
  join: {
    solarSamples: SolarDaySample[];
    weatherSamples: WeatherSample[];
    airQualitySamples: AirQualitySample[];
  },
  kind: "sunrise" | "sunset",
  milestones: SolarDayMilestones,
): SkyColorEventContext | null {
  const eventTimeIso =
    kind === "sunrise" ? milestones.sunriseIso : milestones.sunsetIso;

  if (eventTimeIso === null) {
    return null;
  }

  const startsAtIso =
    (kind === "sunrise"
      ? milestones.civilDawnIso
      : milestones.goldenHourPmStartIso) ?? eventTimeIso;
  const endsAtIso =
    (kind === "sunrise"
      ? milestones.goldenHourEndIso
      : milestones.civilDuskIso) ?? eventTimeIso;

  const features: SkyColorFeatures[] = join.solarSamples
    .filter(
      (sample) => sample.timeIso >= startsAtIso && sample.timeIso <= endsAtIso,
    )
    .map((sample) => ({
      solar: {
        timeIso: sample.timeIso,
        elevationDegrees: sample.elevationDegrees,
        azimuthDegrees: sample.azimuthDegrees,
        twilightPhase: mapElevationToTwilightPhase(sample.elevationDegrees),
      },
      weather: findNearestSample(sample.timeIso, join.weatherSamples),
      airQuality: findNearestSample(sample.timeIso, join.airQualitySamples),
    }));

  if (features.length === 0) {
    return null;
  }

  return {
    location,
    window: {
      kind,
      eventTimeIso,
      scoringWindow: { startsAtIso, endsAtIso },
      twilight: {
        civilStartsAtIso: milestones.civilDawnIso ?? eventTimeIso,
        civilEndsAtIso: milestones.civilDuskIso ?? eventTimeIso,
        nauticalStartsAtIso: milestones.nauticalDawnIso ?? eventTimeIso,
        nauticalEndsAtIso: milestones.nauticalDuskIso ?? eventTimeIso,
        astronomicalStartsAtIso:
          milestones.astronomicalDawnIso ?? eventTimeIso,
        astronomicalEndsAtIso: milestones.astronomicalDuskIso ?? eventTimeIso,
      },
    },
    features,
  };
}

function mapElevationToTwilightPhase(
  elevationDegrees: number,
): TwilightPhase {
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
