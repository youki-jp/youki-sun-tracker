# Codex Project Context

## Mission

Build Youki, an iOS experience that helps a user decide whether an upcoming sunrise or sunset is worth waking up for by predicting sky color quality and explaining the environmental causes.

## Current Architecture

```text
iOS SwiftUI prototype
  -> future Swift API client and CoreLocation integration
      -> TypeScript Bun/Hono API
          -> request validation
          -> PredictSkyColorService
              -> timezone resolver
              -> solar provider
              -> weather provider
              -> air-quality provider
              -> feature alignment
              -> SkyColorEngine
                  -> current heuristic implementation
          -> prediction response
```

The backend architecture is implemented. The iOS-to-backend integration is not.

## Backend Boundaries

### Domain

`server/src/domain/` contains framework-independent interfaces for:

- coordinates and resolved timezone
- local ISO dates and time ranges
- sunrise/sunset event kinds
- twilight phase
- solar event windows and samples
- weather samples and layered cloud cover
- air-quality samples
- sky-color contexts, requests, predictions, and API response

### Application

`server/src/application/` contains the use case and ports:

- `PredictSkyColorService` resolves timezone, chooses a date, requests event windows, fetches parallel samples, aligns them, and invokes the engine.
- Provider ports isolate the use case from Open-Meteo.
- `align-sky-color-features.ts` matches solar samples with nearest weather and air-quality samples.

### Infrastructure

`server/src/infrastructure/` contains:

- Open-Meteo HTTP client and response types
- timezone, weather, air-quality, and solar adapters
- `HeuristicSkyColorEngine`
- dependency factory wiring

### HTTP

`server/src/http/` owns Hono routes and transport validation. Keep request parsing at this boundary and do not pass Hono context objects into the application layer.

## Current Heuristic

The engine aggregates event-window samples and currently considers:

- total cloud cover
- low cloud cover
- high cloud cover
- visibility
- relative humidity
- precipitation
- aerosol optical depth
- dust
- PM2.5

It produces a score from 0 to 100, a label, a primary estimated color, secondary colors, confidence based on data coverage, and textual reasons. Mid cloud, dew point, PM10, and ozone are normalized but not yet used as direct score terms.

## Frontend Boundaries

The SwiftUI app is a presentation prototype. Keep temporary sample data in `PrototypeModels.swift` until the real data path is ready. Do not place network requests, CoreLocation permissions, or heuristic scoring directly inside view bodies.

The Xcode project uses explicit `PBXFileReference`, `PBXBuildFile`, group, and source-phase entries. A new Swift file is not compiled until it is added to the project file.

## Known Technical Risks

- `local-date-time.ts` parses local timestamps using the server process timezone. This needs a timezone-safe implementation before arbitrary user locations are treated as production-critical.
- `open-meteo-solar-provider.ts` currently uses daily Open-Meteo event times and simplified solar samples. It is not a complete solar-position calculator.
- External data coverage and Open-Meteo failures need deterministic fixture-based tests.
- The sample UI and backend response models use different presentation shapes and require an explicit mapper.
