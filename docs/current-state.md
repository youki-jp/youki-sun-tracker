# Current Project State

Updated: 2026-09-16

## Product

Youki is a sunrise and sunset sky-color forecast experience. The product is currently a working prototype rather than a production-ready app.

The intended experience is:

1. The iOS app provides a user's latitude, longitude, and altitude.
2. The backend retrieves solar, weather, and atmospheric inputs.
3. A SkyColorEngine estimates the quality and palette of an upcoming sunrise or sunset.
4. A SkyGradientEngine synthesizes the continuous sky appearance from solar geometry and atmospheric inputs.
5. The iOS app explains the result with a score, color ramp, timing, and reasons.

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
- Solar elevation and azimuth are computed with the NOAA solar position algorithm, including atmospheric refraction near the horizon. Open-Meteo still supplies the daily sunrise and sunset times that anchor each window.
- Requests may set `includeFeatures` to receive the per-timestep solar, weather, and air-quality samples alongside each prediction.
- CORS is enabled on `/api/*` so browser clients on another origin can call the API.
- `POST /api/v1/sky-day/timeline` returns a whole local day: real solar-elevation milestones, adaptively spaced solar samples, and the hourly weather and air-quality grids. Milestones may be null at polar latitudes where the sun never reaches a given elevation.
- `SkyGradientService` interpolates the independent timeline grids into a normalized observation while preserving missing-field availability.
- The deterministic `SkyGradientEngine` ports the reference Oklch model, emits nine stable stops, a five-color ramp, glow geometry, and fractional cloud bands. Its tests cover interpolation, missing data, safe ranges, atmospheric regimes, and repeatability.
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

The screen also requests `POST /api/v1/sky-day/timeline`, interpolates solar/weather/air-quality rows locally, and renders a generated nine-stop sky with fractional cloud and glow geometry. A 60-second `TimelineView` refreshes the current appearance without putting network work in a view body.

## What Is Not Connected Yet

- Wake alarms, notifications, widgets, subscriptions, saved locations, and persistence are visual previews only.
- The calendar still displays the one live target day; it does not yet load a full seven-day set from the timeline endpoint.
- The iOS target has no standalone unit-test target for the Swift math; simulator app/UI-target builds remain the available verification seam.
- Weather and air-quality inputs remain hourly upstream. The gradient path interpolates them, while the semantic scoring path intentionally retains nearest-sample behavior.
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
  "requestedEvents": ["sunrise", "sunset"],
  "includeFeatures": false
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

### Optional features payload

When a request sets `includeFeatures: true`, each prediction gains a `features` array with one entry per 15-minute step of the scoring window (7 for sunrise, 8 for sunset):

```json
{
  "solar": {
    "timeIso": "2026-09-05T05:16:00",
    "elevationDegrees": -0.54,
    "azimuthDegrees": 80.82,
    "twilightPhase": "civil"
  },
  "weather": {
    "timeIso": "2026-09-05T05:00:00",
    "cloudCover": { "totalPct": 72, "lowPct": 49, "midPct": 0, "highPct": 72 },
    "visibilityMeters": 24140,
    "relativeHumidityPct": 88,
    "dewPointCelsius": 22.4,
    "precipitationMillimeters": 0
  },
  "airQuality": {
    "timeIso": "2026-09-05T05:00:00",
    "aerosolOpticalDepth": 0.13,
    "particulateMatter2_5UgM3": 8.4,
    "particulateMatter10UgM3": 12.1,
    "dustUgM3": 0.2,
    "ozoneUgM3": 63
  }
}
```

The key is omitted entirely when not requested, so existing consumers are unaffected.

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
3. Add integration tests with fixture responses for Open-Meteo failures and incomplete data.

## Important Decision

The backend remains the source of truth for solar geometry, external data aggregation, and semantic sky-color scoring. For the documented Option A gradient decision, the iOS app owns local grid interpolation, appearance generation, rendering, animation timing, fallback UI, and user interaction; it does not duplicate provider or solar-geometry logic.
