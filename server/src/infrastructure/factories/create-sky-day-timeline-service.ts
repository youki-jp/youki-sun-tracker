import { SkyDayTimelineService } from "../../application/services/sky-day-timeline-service";
import { HeuristicSkyColorEngine } from "../engines/heuristic-sky-color-engine";
import { OpenMeteoAirQualityProvider } from "../open-meteo/open-meteo-air-quality-provider";
import { OpenMeteoClient } from "../open-meteo/open-meteo-client";
import { OpenMeteoSolarProvider } from "../open-meteo/open-meteo-solar-provider";
import { OpenMeteoTimezoneResolver } from "../open-meteo/open-meteo-timezone-resolver";
import { OpenMeteoWeatherProvider } from "../open-meteo/open-meteo-weather-provider";

export function createSkyDayTimelineService(): SkyDayTimelineService {
  const weatherClient = new OpenMeteoClient("https://api.open-meteo.com");
  const airQualityClient = new OpenMeteoClient(
    "https://air-quality-api.open-meteo.com",
  );

  return new SkyDayTimelineService(
    new OpenMeteoTimezoneResolver(weatherClient),
    new OpenMeteoSolarProvider(weatherClient),
    new OpenMeteoWeatherProvider(weatherClient),
    new OpenMeteoAirQualityProvider(airQualityClient),
    new HeuristicSkyColorEngine(),
  );
}
