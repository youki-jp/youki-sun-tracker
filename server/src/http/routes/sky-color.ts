import { Hono } from "hono";
import type { SkyColorPredictionRequest, SkyEventKind } from "../../domain";
import { ValidationError } from "../../application/errors";
import {
  isRecord,
  optionalDateString,
  parseLocation,
  readJsonBody,
} from "./request-validation";
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

function parseSkyColorRequest(
  payload: unknown,
  shape: RequestShape,
): SkyColorPredictionRequest {
  if (!isRecord(payload)) {
    throw new ValidationError("Request body must be an object.");
  }

  const locationPayload = shape === "flat" ? payload : payload.location;

  const location = parseLocation(
    locationPayload,
    shape === "flat" ? "" : "location.",
  );
  const targetDateIso = optionalDateString(
    payload.targetDateIso,
    "targetDateIso",
  );
  const requestedEvents = parseRequestedEvents(payload.requestedEvents);
  const includeFeatures = optionalBoolean(
    payload.includeFeatures,
    "includeFeatures",
  );

  return {
    location,
    targetDateIso,
    requestedEvents,
    includeFeatures,
  };
}

function parseRequestedEvents(value: unknown): SkyEventKind[] {
  if (value === undefined) {
    return ["sunrise", "sunset"];
  }

  if (!Array.isArray(value) || value.length === 0) {
    // Keep one stable client error for invalid event-list shapes.
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

function optionalBoolean(value: unknown, fieldName: string): boolean {
  if (value === undefined || value === null) return false;
  if (typeof value !== "boolean") {
    throw new ValidationError(`${fieldName} must be a boolean.`);
  }
  return value;
}
