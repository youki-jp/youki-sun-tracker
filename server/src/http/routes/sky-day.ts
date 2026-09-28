import { Hono } from "hono";
import { ValidationError } from "../../application/errors";
import type { SkyDayTimelineService } from "../../application/services/sky-day-timeline-service";
import type { SkyDayTimelineRequest } from "../../domain";
import {
  isRecord,
  optionalDateString,
  parseLocation,
  readJsonBody,
} from "./request-validation";

export function createSkyDayRouter(service: SkyDayTimelineService) {
  const router = new Hono();

  router.post("/timeline", async (c) => {
    const request = parseTimelineRequest(await readJsonBody(c.req.raw));
    const response = await service.execute(request);

    return c.json(response, 200);
  });

  return router;
}

function parseTimelineRequest(payload: unknown): SkyDayTimelineRequest {
  if (!isRecord(payload)) {
    throw new ValidationError("Request body must be an object.");
  }
  return {
    location: parseLocation(payload.location),
    targetDateIso: optionalDateString(payload.targetDateIso, "targetDateIso"),
  };
}
