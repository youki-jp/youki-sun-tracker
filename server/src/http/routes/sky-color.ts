import { Hono } from "hono";
import type { SkyColorPredictionRequest, SkyEventKind } from "../../domain";
import { ValidationError } from "../../application/errors";
import type { PredictSkyColorService } from "../../application/services/predict-sky-color-service";

export function createSkyColorRouter(service: PredictSkyColorService) {
  const router = new Hono();

  router.post("/estimate", async (c) => {
    const request = parseSkyColorRequest(await readJsonBody(c.req.raw), "flat");
    const response = await service.execute(request);

    return c.json(response, 200);
  });

  router.post("/predictions", async (c) => {
    const request = parseSkyColorRequest(
      await readJsonBody(c.req.raw),
      "nested",
    );
    const response = await service.execute(request);

    return c.json(response, 200);
  });

  return router;
}

type RequestShape = "flat" | "nested";

async function readJsonBody(request: Request): Promise<unknown> {
  return request.json().catch(() => {
    throw new ValidationError("Request body must be valid JSON.");
  });
}

function parseSkyColorRequest(
  payload: unknown,
  shape: RequestShape,
): SkyColorPredictionRequest {
  if (!isRecord(payload)) {
    throw new ValidationError("Request body must be an object.");
  }

  const locationPayload = shape === "flat" ? payload : payload.location;

  if (!isRecord(locationPayload)) {
    throw new ValidationError("location is required.");
  }

  const fieldPrefix = shape === "flat" ? "" : "location.";
  const latitude = requireNumber(
    locationPayload.latitude,
    `${fieldPrefix}latitude`,
  );
  const longitude = requireNumber(
    locationPayload.longitude,
    `${fieldPrefix}longitude`,
  );
  const altitudeMeters = optionalNumber(
    locationPayload.altitudeMeters,
    `${fieldPrefix}altitudeMeters`,
  );
  const targetDateIso = optionalDateString(
    payload.targetDateIso,
    "targetDateIso",
  );
  const requestedEvents = parseRequestedEvents(payload.requestedEvents);

  return {
    location: {
      latitude,
      longitude,
      altitudeMeters,
    },
    targetDateIso,
    requestedEvents,
  };
}

function parseRequestedEvents(value: unknown): SkyEventKind[] {
  if (value === undefined) {
    return ["sunrise", "sunset"];
  }

  if (!Array.isArray(value) || value.length === 0) {
    throw new ValidationError(
      "requestedEvents must be a non-empty array when provided.",
    );
  }

  const events = new Set<SkyEventKind>();
  value.forEach((item) => {
    if (item !== "sunrise" && item !== "sunset") {
      throw new ValidationError(
        "requestedEvents may only contain 'sunrise' and 'sunset'.",
      );
    }

    events.add(item);
  });

  return [...events];
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

function optionalDateString(
  value: unknown,
  fieldName: string,
): string | null {
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
