# Current Project State

Updated: 2026-09-05

## Product

Youki is a sunrise and sunset sky-color forecast experience. The product is currently a working prototype rather than a production-ready app.

The intended experience is:

1. The iOS app provides a user's latitude, longitude, and altitude.
2. The backend retrieves solar, weather, and atmospheric inputs.
3. A SkyColorEngine estimates the quality and palette of an upcoming sunrise or sunset.
4. The iOS app explains the result with a score, color ramp, timing, and reasons.

## What Works Today

### TypeScript backend

The backend is a Bun + Hono service with these layers:

```text
HTTP routes
  -> PredictSkyColorService
      -> application ports
          -> Open-Meteo adapters
          -> HeuristicSkyColorEngine
      -> domain response
```

Implemented behavior:

- Location input accepts latitude, longitude, and optional altitude.
- The timezone is resolved from Open-Meteo using `timezone=auto`.
- Daily sunrise and sunset times are fetched for a seven-day window.
- A scoring window is built around each event.
- Weather fields are fetched from the Open-Meteo Forecast API.
- Air-quality fields are fetched from the Open-Meteo Air Quality API.
- Solar, weather, and air-quality samples are aligned by nearest local timestamp.
- The heuristic engine returns a score, confidence, label, estimated color, dominant colors, reasons, and event window.
- Health, liveness, and readiness endpoints are available.
- A Dockerfile exists for a Bun production container.

### SwiftUI frontend

The frontend mirrors the Youki mock and can now load the current forecast from the backend:

- Dark and light themes
- Sunrise score and summary
- Sky gradient background
- Predicted color ramp
- Sunrise and sunset event timeline
- Expanded color-analysis card
- Forecast calendar sheet
- Locations sheet
- Settings sheet
- Paywall preview

The screen starts with `PrototypeDay.sampleDays` as a fallback, requests the user's current location, calls `POST /api/v1/sky-color/predictions`, and maps the live response into the existing presentation model. Live score, color palette, confidence, reasons, event times, cloud cover, and UV values are displayed when the request succeeds.

## What Is Not Connected Yet

- The live iOS response currently represents one target day. The calendar does not yet load a full seven-day set from the backend.
- Wake alarms, notifications, widgets, subscriptions, saved locations, and persistence are visual previews only.
- Solar elevation and azimuth are currently approximated in the Open-Meteo solar adapter.
- There are no automated backend or Swift unit tests in the repository.
- There is no CI workflow or production deployment configuration beyond the Dockerfile and DigitalOcean notes.

## Backend API

### Request shapes

Nested endpoint:

```json
{
  "location": {
    "latitude": 35.6762,
    "longitude": 139.6503,
    "altitudeMeters": 40
  },
  "targetDateIso": "2026-09-05",
  "requestedEvents": ["sunrise", "sunset"]
}
```

Flat endpoint:

```json
{
  "latitude": 35.6762,
  "longitude": 139.6503,
  "altitudeMeters": 40,
  "targetDateIso": "2026-09-05",
  "requestedEvents": ["sunrise"]
}
```

### Response shape

The response is based on `server/src/domain/sky-color.ts`:

```json
{
  "location": {
    "latitude": 35.6762,
    "longitude": 139.6503,
    "altitudeMeters": 40,
    "timezoneId": "Asia/Tokyo"
  },
  "generatedAtIso": "2026-09-05T00:00:00.000Z",
  "predictions": [
    {
      "kind": "sunrise",
      "score": 64,
      "confidence": 100,
      "label": "warm",
      "estimatedColorName": "peach",
      "estimatedHex": "#F4B183",
      "dominantColors": ["gold", "blush pink", "light apricot"],
      "reasons": ["Moderate aerosol levels can deepen orange and pink tones."],
      "window": {
        "kind": "sunrise",
        "eventTimeIso": "2026-09-05T05:13:00",
        "scoringWindow": {
          "startsAtIso": "2026-09-05T04:13:00",
          "endsAtIso": "2026-09-05T05:43:00"
        },
        "twilight": {}
      }
    }
  ]
}
```

The exact response should be treated as the TypeScript domain contract, not this abbreviated example.

## Data Inputs

Weather fields:

- `cloud_cover`
- `cloud_cover_low`
- `cloud_cover_mid`
- `cloud_cover_high`
- `visibility`
- `relative_humidity_2m`
- `dew_point_2m`
- `precipitation`
- `uv_index`

Air-quality fields:

- `aerosol_optical_depth`
- `pm2_5`
- `pm10`
- `dust`
- `ozone`

The prediction response also includes averaged forecast conditions for the scoring window so the iOS client can show cloud cover and UV values without reimplementing the backend's provider logic.

The rationale for each input is documented in [`docs/sky-color-prediction.md`](sky-color-prediction.md).

## Recommended Next Milestones

1. Load a full seven-day forecast set without making an expensive one-request-per-event call from the client.
2. Replace the remaining preview-only location, alarm, notification, widget, subscription, and persistence flows.
3. Improve solar geometry with a timezone-safe astronomical calculation and real elevation/azimuth samples.
4. Add deterministic backend tests for request validation, feature alignment, and heuristic scoring.
5. Add integration tests with fixture responses for Open-Meteo failures and incomplete data.

## Important Decision

The backend should remain the source of truth for solar geometry, external data aggregation, and sky-color scoring. The iOS app should own permissions, presentation, local UI state, and user interaction, not duplicate prediction logic.
