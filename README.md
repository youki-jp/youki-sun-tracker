# Youki Sun Tracker

Youki is a sunrise and sunset color forecast prototype. The repository contains a SwiftUI iOS client and a Bun + Hono TypeScript backend.

## Repository layout

- `server/` contains the HTTP API, application services, domain models, and Open-Meteo adapters.
- `frontend/` contains the SwiftUI prototype and its Xcode project.
- `docs/sky-color-prediction.md` describes the forecast architecture and data requirements.

## Backend

Start the development server:

```bash
cd server
bun install
bun run dev
```

The API is available at `http://localhost:3000`.

Health endpoints:

- `GET /api/v1/health`
- `GET /api/v1/health/live`
- `GET /api/v1/health/ready`

Sky color endpoints:

- `POST /api/v1/sky-color/estimate` accepts flat location fields.
- `POST /api/v1/sky-color/predictions` accepts a nested `location` object.

Example request:

```bash
curl -X POST http://localhost:3000/api/v1/sky-color/predictions \
  -H 'content-type: application/json' \
  -d '{"location":{"latitude":35.6762,"longitude":139.6503,"altitudeMeters":40},"requestedEvents":["sunrise","sunset"]}'
```

The service resolves the location timezone, calculates solar windows and samples, fetches weather and air quality from Open-Meteo, aligns the data, and applies the current heuristic sky color engine.

## iOS prototype

Open `frontend/YoukiApp/YoukiApp.xcodeproj` in Xcode and run the `YoukiApp` scheme on an iOS Simulator or connected device. The current screen is a local UI prototype with sample Tokyo forecast data. It includes the main forecast, expanded color analysis, forecast calendar, locations, paywall, and light/dark theme previews.

The SwiftUI source is organized by responsibility:

- `ContentView.swift` owns screen state and top-level composition.
- `ForecastComponents.swift` contains the main forecast components.
- `ForecastSheets.swift` contains modal sheet content.
- `PrototypeModels.swift` contains temporary sample data and presentation models.
- `SkyBackgroundView.swift` and `Color+Hex.swift` contain visual helpers.

## DigitalOcean App Platform

For a backend deployment, point the app's source directory to `server/`.

```text
Build command: bun run build
Run command: bun run start
```
