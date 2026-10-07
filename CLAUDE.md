# Youki Project Guide

Read this file before making changes. It is the shortest reliable summary of the current project state for Claude and other coding agents.

## Deployment handover: read before connecting

The current Droplet backend is `https://206.189.178.229.sslip.io`.
Connect with `ssh deploy@206.189.178.229`; the repository is `/opt/youki`.
Read [`docs/handover.md`](docs/handover.md) for env paths, CI/CD evidence,
local versus deployed changes, and simulator configuration. The iOS Release
source default still contains the legacy App Platform URL, so explicitly set
`BACKEND_URL` to the Droplet for hosted runs.

## Current State

Youki is a sunrise and sunset sky-color forecast prototype with two parts:

- `frontend/` is an iOS 17+ SwiftUI app. The main screen requests the current device location and loads the current forecast from the prediction API, with local Tokyo sample data as a fallback.
- `server/` is a Bun + Hono TypeScript backend. It calls Open-Meteo, normalizes solar, weather, and air-quality data, and returns heuristic sky-color predictions.

The 2026-09-28 auth implementation adds native Sign in with Apple, Youki-owned SQLite sessions and Free/Pro entitlements, authenticated forecast routes, and quotas. Drizzle manages the SQLite schema and migrations. It is implemented and tested locally but not deployed or verified with live Apple credentials. Read [`docs/auth-implementation.md`](docs/auth-implementation.md) before changing or deploying account code. The 2026-10-03 temporary deployment mode uses `AUTH_MODE=temporary` and `YOOKI_TEST_USER_PASSWORD` without Apple credentials, preserves backend sessions/quotas, and disables Apple login. See [`server/deploy/README.md`](server/deploy/README.md); the earlier temporary-auth deployment completed successfully (run `37120575640`), with user-confirmed app login. The subsequent weekly forecast UX changes remain local.

The UI prototype and backend are intentionally at different integration stages. Do not assume that changing a backend response will automatically change the iOS screen.

For a fuller snapshot, read [`docs/current-state.md`](docs/current-state.md). For agent-specific rules, read [`AGENTS.md`](AGENTS.md) and the files in [`.codex/`](.codex/).

The live sky gradient is implemented as Option A from [`docs/sky-gradient-implementation-plan.md`](docs/sky-gradient-implementation-plan.md): Bun/Hono serves the normalized day timeline, while SwiftUI interpolates the local moment and renders the deterministic nine-stop appearance. The reference and known calibration gaps are documented in [`docs/sky-gradient-implementation.md`](docs/sky-gradient-implementation.md).

## Source Map

### Backend

- `server/src/app.ts`: Hono app composition, routes, and error handling.
- `server/src/http/routes/`: HTTP parsing and health endpoints.
- `server/src/application/services/predict-sky-color-service.ts`: orchestration use case.
- `server/src/application/services/forecast-week-service.ts`: bounded weekly orchestration with per-day partial failure support.
- `server/src/application/services/forecast-access.ts`: timezone-local Free/Pro date limits.
- `server/src/application/services/sky-gradient-service.ts`: normalized timeline-grid join and gradient orchestration.
- `server/src/application/ports/`: provider and engine interfaces.
- `server/src/domain/`: location, solar, weather, air-quality, prediction, and gradient types.
- `server/src/infrastructure/open-meteo/`: Open-Meteo HTTP adapters.
- `server/src/infrastructure/engines/heuristic-sky-color-engine.ts`: current scoring and palette heuristic.
- `server/src/infrastructure/engines/sky-gradient-engine.ts`: deterministic Oklch sky-gradient engine.
- `server/src/infrastructure/factories/create-predict-sky-color-service.ts`: production dependency wiring.

### iOS

- `frontend/YoukiApp/ContentView.swift`: screen state and top-level layout.
- `frontend/YoukiApp/ForecastComponents.swift`: forecast components and expanded analysis card.
- `frontend/YoukiApp/ForecastSheets.swift`: calendar, settings, locations, and paywall sheets.
- `frontend/YoukiApp/PrototypeModels.swift`: temporary UI models and sample data.
- `frontend/YoukiApp/SkyBackgroundView.swift`: generated sky background.
- `frontend/YoukiApp/ServerViewModel.swift`: location and forecast loading state used by `ContentView`.
- `frontend/YoukiApp/SkyColorAPI.swift`: request/response DTOs and the backend HTTP client.
- `frontend/YoukiApp/LocationManager.swift`: one-shot Core Location authorization and location retrieval.
- `frontend/YoukiApp/ForecastMapper.swift`: maps backend predictions into the existing visual presentation model.
- `frontend/YoukiApp/SkyDayTimelineAPI.swift`: timeline DTOs and Bun/Hono client.
- `frontend/YoukiApp/SkyGradient.swift`: local timeline interpolation and reference generator port.
- `frontend/YoukiApp/AppConfig.swift`: backend URL configuration seam.

## Backend Contract

Health endpoints:

- `GET /api/v1/health`
- `GET /api/v1/health/live`
- `GET /api/v1/health/ready`

Prediction endpoints:

- `POST /api/v1/sky-color/estimate` accepts flat `latitude`, `longitude`, and optional `altitudeMeters` fields.
- `POST /api/v1/sky-color/predictions` accepts those location fields inside `location`.

Both endpoints also accept optional `targetDateIso` (`YYYY-MM-DD`) and `requestedEvents` (`sunrise`, `sunset`). If events are omitted, both are requested.

They also accept optional `includeFeatures` (boolean, default `false`). When true, each prediction carries a `features` array holding the aligned solar, weather, and air-quality sample for every 15-minute step in the scoring window. This exists for clients that synthesise their own sky colour rather than using `estimatedHex`. The key is absent unless requested, so the default response shape is unchanged.

The response includes a resolved timezone, generation time, score, confidence, label, estimated color, dominant colors, reasons, averaged forecast conditions, optional aligned features, solar event window, and twilight boundaries.

### Day timeline

`POST /api/v1/sky-day/timeline` returns a whole local day rather than a single event window: every named milestone, solar positions across the day, and the hourly weather and air-quality grids.

Milestones are real solar elevation crossings (astronomical/nautical/civil dawn and dusk, golden hour bounds, sunrise, sunset, solar noon), not fixed minute offsets. Any of them can be `null` inside the polar circles, where the sun never reaches that elevation - callers must handle that rather than assume a time exists.

Solar samples are spaced by how fast the sun is moving, so twilight and golden hour are dense and midday is sparse. Weather and air quality stay on their own hourly grid instead of being copied onto every solar sample; clients join by timestamp and interpolate. A full day is about 22 KB, 3 KB gzipped.

This costs no extra network work: the Open-Meteo providers already fetch seven days of hourly data per request and filter it down, so a whole day was already being downloaded and discarded.

## Development Commands

Backend:

```bash
cd server
bun install
bun run dev
```

iOS:

```bash
open frontend/YoukiApp/YoukiApp.xcodeproj
```

Use the `YoukiApp` scheme with an iOS Simulator or connected iPhone. The project file manually lists Swift sources, so every new Swift file must be added to `frontend/YoukiApp/YoukiApp.xcodeproj/project.pbxproj`.

Useful verification commands:

```bash
cd server
bun build src/index.ts --target bun --outdir /tmp/youki-server-build

cd ..
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project frontend/YoukiApp/YoukiApp.xcodeproj \
  -scheme YoukiApp \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/youki-derived \
  build
```

## Important Limitations

- Signed-out users see sign-in. Signed-in users see today initially and can select a dated forecast from the backend weekly calendar; errors and unavailable fields are shown explicitly. Samples are development previews.
- `POST /api/v1/sky-day/week` returns seven dated rows with timeline/predictions and per-day errors. Free accounts receive today/tomorrow and locked outlook rows; Pro receives all seven. Single-day endpoints also enforce the horizon (Free 0-1, Pro 0-6) in the location timezone. Days 3-7 are outlooks, and the existing confidence number is displayed as input coverage rather than a probability of accuracy.
- Solar event times come from Open-Meteo daily sunrise and sunset values. Elevation and azimuth within the window are computed with the NOAA solar position algorithm in `server/src/infrastructure/solar/solar-position.ts`.
- The semantic sky-color scorer still uses nearest hourly weather and air-quality samples; the Swift sky-gradient path interpolates the bracketing rows locally.
- The backend does not expose a generated gradient snapshot endpoint by design; Option A keeps rendering and minute-level animation on the client.
- The backend captures all requested weather and air-quality fields, but the current heuristic uses only a subset directly. Mid-level cloud, dew point, PM10, and ozone are available for future refinement.
- Open-Meteo calls require network access. There is no local fixture or mock provider in the current implementation.
- The `server` package `build` script is still a placeholder. `bun build` is the practical bundling check until a formal build pipeline is introduced.

## Change Guidance

- Preserve the visual prototype while integrating data. Replace `PrototypeDay` through a view model or mapper rather than spreading API calls through SwiftUI views.
- Keep external API details in `server/src/infrastructure/` and keep orchestration in application services.
- Keep domain types independent of Hono and Open-Meteo response types.
- Treat nullable weather and atmospheric values as normal. Lower confidence when coverage is incomplete instead of failing unnecessarily.
- Do not add generated files, `.DS_Store`, Xcode user state, secrets, or local dependency folders to Git.
- Run the relevant backend and iOS verification commands after structural changes.
