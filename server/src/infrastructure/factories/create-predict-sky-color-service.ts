import { PredictSkyColorService } from "../../application/services/predict-sky-color-service";
import { DevelopmentAirQualityProvider } from "../dev/development-air-quality-provider";
import { DevelopmentSkyColorEngine } from "../dev/development-sky-color-engine";
import { DevelopmentSolarProvider } from "../dev/development-solar-provider";
import { DevelopmentTimezoneResolver } from "../dev/development-timezone-resolver";
import { DevelopmentWeatherProvider } from "../dev/development-weather-provider";

export function createPredictSkyColorService(): PredictSkyColorService {
  return new PredictSkyColorService(
    new DevelopmentTimezoneResolver(),
    new DevelopmentSolarProvider(),
    new DevelopmentWeatherProvider(),
    new DevelopmentAirQualityProvider(),
    new DevelopmentSkyColorEngine(),
  );
}
