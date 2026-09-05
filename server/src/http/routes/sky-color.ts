import { Hono } from "hono";
import type { SkyColorPredictionRequest, SkyEventKind } from "../../domain";
import { ValidationError } from "../../application/errors";
import type { PredictSkyColorService } from "../../application/services/predict-sky-color-service";

export function createSkyColorRouter(service: PredictSkyColorService) {
  const router = new Hono();

  router.post("/estimate", async (c) => {
    const payload = await c.req.json().catch(() => {
      throw new ValidationError("Request body must be valid JSON.");
    });
    const request = parseEstimateRequest(payload);
    const response = await service.execute(request);

    return c.json(response, 200);
  });

  router.post("/predictions", async (c) => {
    const payload = await c.req.json().catch(() => {
      throw new ValidationError("Request body must be valid JSON.");
    });
    const request = parsePredictionRequest(payload);
    const response = await service.execute(request);

    return c.json(response, 200);
  });

  return router;
}

function parseEstimateRequest(payload: unknown): SkyColorPredictionRequest {
  if (!isRecord(payload)) {
    throw new ValidationError("Request body must be an object.");
  }

  const latitude = requireNumber(payload.latitude, "latitude");
  const longitude = requireNumber(payload.longitude, "longitude");
  const altitudeMeters = optionalNumber(payload.altitudeMeters, "altitudeMeters");
  const targetDateIso = optionalDateString(payload.targetDateIso, "targetDateIso");
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

function parsePredictionRequest(payload: unknown): SkyColorPredictionRequest {
  if (!isRecord(payload)) {
    throw new ValidationError("Request body must be an object.");
  }

  const locationPayload = payload.location;

  if (!isRecord(locationPayload)) {
    throw new ValidationError("location is required.");
  }

  const latitude = requireNumber(locationPayload.latitude, "location.latitude");
  const longitude = requireNumber(
    locationPayload.longitude,
    "location.longitude",
  );
  const altitudeMeters = optionalNumber(
    locationPayload.altitudeMeters,
    "location.altitudeMeters",
  );
  const targetDateIso = optionalDateString(payload.targetDateIso, "targetDateIso");
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

  const allowedValues = new Set<SkyEventKind>(["sunrise", "sunset"]);
  const events = value.map((item) => {
    if (item !== "sunrise" && item !== "sunset") {
      throw new ValidationError(
        "requestedEvents may only contain 'sunrise' and 'sunset'.",
      );
    }

    return item;
  });

  return events.filter((event, index) => {
    if (!allowedValues.has(event)) {
      return false;
    }

    return events.indexOf(event) === index;
  });
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
