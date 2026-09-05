# Youki Project Guide

Read this file before making changes. It is the shortest reliable summary of the current project state for Claude and other coding agents.

## Current State

Youki is a sunrise and sunset sky-color forecast prototype with two parts:

- `frontend/` is an iOS 17+ SwiftUI visual prototype. The main screen still uses local Tokyo sample data and is not connected to the prediction API.
- `server/` is a Bun + Hono TypeScript backend. It calls Open-Meteo, normalizes solar, weather, and air-quality data, and returns heuristic sky-color predictions.

The UI prototype and backend are intentionally at different integration stages. Do not assume that changing a backend response will automatically change the iOS screen.

For a fuller snapshot, read [`docs/current-state.md`](docs/current-state.md). For agent-specific rules, read [`AGENTS.md`](AGENTS.md) and the files in [`.codex/`](.codex/).

## Source Map

### Backend

- `server/src/app.ts`: Hono app composition, routes, and error handling.
- `server/src/http/routes/`: HTTP parsing and health endpoints.
- `server/src/application/services/predict-sky-color-service.ts`: orchestration use case.
- `server/src/application/ports/`: provider and engine interfaces.
- `server/src/domain/`: location, solar, weather, air-quality, and prediction types.
- `server/src/infrastructure/open-meteo/`: Open-Meteo HTTP adapters.
- `server/src/infrastructure/engines/heuristic-sky-color-engine.ts`: current scoring and palette heuristic.
- `server/src/infrastructure/factories/create-predict-sky-color-service.ts`: production dependency wiring.

### iOS

- `frontend/YoukiApp/ContentView.swift`: screen state and top-level layout.
- `frontend/YoukiApp/ForecastComponents.swift`: forecast components and expanded analysis card.
- `frontend/YoukiApp/ForecastSheets.swift`: calendar, settings, locations, and paywall sheets.
- `frontend/YoukiApp/PrototypeModels.swift`: temporary UI models and sample data.
- `frontend/YoukiApp/SkyBackgroundView.swift`: generated sky background.
- `frontend/YoukiApp/ServerViewModel.swift` and `AppConfig.swift`: initial backend connection seam; not currently used by `ContentView`.

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

The response includes a resolved timezone, generation time, score, confidence, label, estimated color, dominant colors, reasons, solar event window, and twilight boundaries.

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

- The iOS app displays curated sample data; no Swift API client maps backend predictions into the UI yet.
- Solar event times come from Open-Meteo daily sunrise and sunset values. Elevation and azimuth within the window are computed locally with the NOAA solar position algorithm in `server/src/infrastructure/solar/solar-position.ts`.
- Weather and air quality are hourly and aligned by nearest sample, so atmospheric values are effectively constant across the 15-minute solar timesteps. Clients that need smooth variation must interpolate.
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
