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

The frontend is a local visual prototype that mirrors the Youki mock:

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

The screen currently reads from `PrototypeDay.sampleDays`. `ServerViewModel` can call the backend root URL, but `ContentView` does not use it and does not yet decode sky-color predictions.

## What Is Not Connected Yet

- CoreLocation is not wired into the current SwiftUI screen.
- The iOS app does not call `POST /api/v1/sky-color/predictions`.
- Backend JSON is not mapped into `PrototypeDay` or a production forecast view model.
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

Air-quality fields:

- `aerosol_optical_depth`
- `pm2_5`
- `pm10`
- `dust`
- `ozone`

The rationale for each input is documented in [`docs/sky-color-prediction.md`](sky-color-prediction.md).

## Recommended Next Milestones

1. Add a Swift API client and Codable response types for the nested predictions endpoint.
2. Add a location service that owns CoreLocation permissions and current coordinates.
3. Introduce a frontend forecast view model that maps API predictions into presentation models.
4. Replace sample-day timing, score, and palette values with backend data while retaining preview fixtures.
5. Improve solar geometry with a timezone-safe astronomical calculation and real elevation/azimuth samples.
6. Add deterministic backend tests for request validation, feature alignment, and heuristic scoring.
7. Add integration tests with fixture responses for Open-Meteo failures and incomplete data.

## Important Decision

The backend should remain the source of truth for solar geometry, external data aggregation, and sky-color scoring. The iOS app should own permissions, presentation, local UI state, and user interaction, not duplicate prediction logic.
