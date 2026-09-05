# Project References

## Canonical Repository Files

### Product and architecture

- [`docs/current-state.md`](../docs/current-state.md): what is implemented, what is still mocked, known gaps, and next milestones.
- [`docs/sky-color-prediction.md`](../docs/sky-color-prediction.md): original product architecture, input rationale, and proposed data model.
- [`README.md`](../README.md): setup and high-level repository overview.

### Backend source of truth

- [`server/src/domain/`](../server/src/domain/): domain contracts.
- [`server/src/application/services/predict-sky-color-service.ts`](../server/src/application/services/predict-sky-color-service.ts): prediction orchestration.
- [`server/src/application/services/align-sky-color-features.ts`](../server/src/application/services/align-sky-color-features.ts): nearest-time sample alignment.
- [`server/src/http/routes/sky-color.ts`](../server/src/http/routes/sky-color.ts): request shapes and validation.
- [`server/src/infrastructure/engines/heuristic-sky-color-engine.ts`](../server/src/infrastructure/engines/heuristic-sky-color-engine.ts): current scoring behavior.
- [`server/src/infrastructure/open-meteo/`](../server/src/infrastructure/open-meteo/): external API adapters.
- [`server/src/infrastructure/factories/create-predict-sky-color-service.ts`](../server/src/infrastructure/factories/create-predict-sky-color-service.ts): runtime dependency graph.

### iOS source of truth

- [`frontend/YoukiApp/ContentView.swift`](../frontend/YoukiApp/ContentView.swift): screen state and root layout.
- [`frontend/YoukiApp/ForecastComponents.swift`](../frontend/YoukiApp/ForecastComponents.swift): forecast UI sections.
- [`frontend/YoukiApp/ForecastSheets.swift`](../frontend/YoukiApp/ForecastSheets.swift): modal screens.
- [`frontend/YoukiApp/PrototypeModels.swift`](../frontend/YoukiApp/PrototypeModels.swift): temporary sample forecast data.
- [`frontend/YoukiApp/AppConfig.swift`](../frontend/YoukiApp/AppConfig.swift): `BACKEND_URL` configuration seam.
- [`frontend/YoukiApp/ServerViewModel.swift`](../frontend/YoukiApp/ServerViewModel.swift): initial generic server request seam.

## Commands

### Backend development

```bash
cd server
bun install
bun run dev
```

### Backend bundle check

```bash
cd server
bun build src/index.ts --target bun --outdir /tmp/youki-server-build
```

### iOS build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project frontend/YoukiApp/YoukiApp.xcodeproj \
  -scheme YoukiApp \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/youki-derived \
  build
```

### API smoke tests

```bash
curl http://localhost:3000/api/v1/health

curl -X POST http://localhost:3000/api/v1/sky-color/predictions \
  -H 'content-type: application/json' \
  -d '{"location":{"latitude":35.6762,"longitude":139.6503,"altitudeMeters":40},"requestedEvents":["sunrise","sunset"]}'
```

## External References

- [Open-Meteo Forecast API](https://open-meteo.com/en/docs): weather forecast fields and daily sunrise/sunset values.
- [Open-Meteo Air Quality API](https://open-meteo.com/en/docs/air-quality-api): aerosol, particulate matter, dust, and ozone fields.
- [SwiftUI documentation](https://developer.apple.com/documentation/swiftui): iOS presentation and layout framework.
- [Core Location documentation](https://developer.apple.com/documentation/corelocation): future location acquisition and authorization.
- [Hono documentation](https://hono.dev/docs/): backend HTTP framework.

## Contract Notes

- Use `POST /api/v1/sky-color/predictions` for the canonical nested request shape.
- Use `POST /api/v1/sky-color/estimate` only when a flat request is specifically useful.
- Use the TypeScript domain interfaces as the backend contract. The SwiftUI prototype models are presentation fixtures, not API DTOs.
