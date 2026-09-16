import { Hono } from "hono";
import { ValidationError } from "../../application/errors";
import type { SkyDayTimelineService } from "../../application/services/sky-day-timeline-service";
import type { SkyDayTimelineRequest } from "../../domain";

export function createSkyDayRouter(service: SkyDayTimelineService) {
  const router = new Hono();

  router.post("/timeline", async (c) => {
    const request = parseTimelineRequest(await readJsonBody(c.req.raw));
    const response = await service.execute(request);

    return c.json(response, 200);
  });

  return router;
}

async function readJsonBody(request: Request): Promise<unknown> {
  return request.json().catch(() => {
    throw new ValidationError("Request body must be valid JSON.");
  });
}

function parseTimelineRequest(payload: unknown): SkyDayTimelineRequest {
  if (!isRecord(payload)) {
    throw new ValidationError("Request body must be an object.");
  }

  const locationPayload = payload.location;

  if (!isRecord(locationPayload)) {
    throw new ValidationError("location is required.");
  }

  return {
    location: {
      latitude: requireNumber(locationPayload.latitude, "location.latitude"),
      longitude: requireNumber(locationPayload.longitude, "location.longitude"),
      altitudeMeters: optionalNumber(
        locationPayload.altitudeMeters,
        "location.altitudeMeters",
      ),
    },
    targetDateIso: optionalDateString(payload.targetDateIso, "targetDateIso"),
  };
}

function requireNumber(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || Number.isNaN(value)) {
    throw new ValidationError(`${fieldName} must be a number.`);
  }

  return value;
}

function optionalNumber(value: unknown, fieldName: string): number | null {
  if (value === undefined || value === null) {
    return null;
  }

  return requireNumber(value, fieldName);
}

function optionalDateString(value: unknown, fieldName: string): string | null {
  if (value === undefined || value === null) {
    return null;
  }

  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new ValidationError(`${fieldName} must be a YYYY-MM-DD string.`);
  }

  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
