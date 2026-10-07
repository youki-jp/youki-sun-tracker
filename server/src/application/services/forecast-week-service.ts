import type { LocationInput } from "../../domain";
import { dateAfter, type ForecastAccess } from "./forecast-access";
import type { PredictSkyColorService } from "./predict-sky-color-service";
import type { SkyDayTimelineService } from "./sky-day-timeline-service";

export class ForecastWeekService {
  constructor(private readonly access: ForecastAccess,
    private readonly timelineService: SkyDayTimelineService,
    private readonly predictionService: PredictSkyColorService) {}

  async execute(location: LocationInput, tier: string) {
    const { timezoneId, today } = await this.access.resolve(location, null, tier);
    const days = [];
    // Sequential days keep cold provider work bounded and reuse the seven-day caches.
    for (let offset = 0; offset < 7; offset++) {
      const targetDateIso = dateAfter(today, offset);
      const forecastType = offset < 2 ? "forecast" : "outlook";
      if (tier !== "pro" && offset >= 2) {
        days.push({ targetDateIso, forecastType, locked: true, timeline: null, predictions: null, errors: [] });
        continue;
      }
      // Keep valid event times when only the color forecast fails (including polar events).
      const timeline = await this.timelineService.execute({ location, targetDateIso })
        .then(value => ({ value, error: null as string | null }))
        .catch(() => ({ value: null, error: "Timeline unavailable. Try refreshing." }));
      const predictions = await this.predictionService.execute({ location, targetDateIso,
        requestedEvents: ["sunrise", "sunset"], includeFeatures: false })
        .then(value => ({ value, error: null as string | null }))
        .catch(() => ({ value: null, error: "Sky quality forecast unavailable. Try refreshing." }));
      days.push({ targetDateIso, forecastType, locked: false,
        timeline: timeline.value, predictions: predictions.value,
        errors: [timeline.error, predictions.error].filter(Boolean) });
    }
    return { location: { ...location, timezoneId }, today,
      generatedAtIso: new Date().toISOString(), days };
  }
}
