# Youki Sun Tracker

Youki is a sunrise and sunset color forecast prototype. The repository contains a SwiftUI iOS client and a Bun + Hono TypeScript backend.

## Repository layout

- `server/` contains the HTTP API, application services, domain models, and Open-Meteo adapters.
- `frontend/` contains the SwiftUI prototype and its Xcode project.
- `docs/sky-color-prediction.md` describes the forecast architecture and data requirements.
- `docs/current-state.md` records what is implemented, mocked, and planned.
- `CLAUDE.md`, `AGENTS.md`, and `.codex/` contain project guidance for coding agents.

## Backend

Start the development server:

```bash
cd server
bun install
bun run migrate
bun run dev
```

The server uses a local SQLite database at `server/data/youki.sqlite` by default. `bun run migrate` applies versioned Drizzle migrations. To use another file, set `SQLITE_PATH`; production requires an absolute path on persistent storage. For local testing without Apple credentials, run `YOOKI_TEST_USER_PASSWORD=admin bun run dev:test-users` instead of `bun run dev`. For Apple sign-in, startup requires `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, and `APPLE_TOKEN_ENCRYPTION_KEY`. See the [account implementation guide](docs/auth-implementation.md).

To generate a migration after editing the Drizzle schema, run `bun run migration:generate` and review its SQL. Use `bun run backup -- /absolute/path/to/backup.sqlite` to create and verify a consistent local backup.

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
  -H 'authorization: Bearer <youki-access-token>' \
  -d '{"location":{"latitude":35.6762,"longitude":139.6503,"altitudeMeters":40},"requestedEvents":["sunrise","sunset"]}'
```

The forecast routes require a Youki session. The service resolves the location timezone, calculates solar windows and samples, fetches weather and air quality from Open-Meteo, aligns the data, and applies the current heuristic sky color engine.

## iOS prototype

Open `frontend/YoukiApp/YoukiApp.xcodeproj` in Xcode and run the `YoukiApp` scheme on an iOS Simulator or connected device. The current screen is a local UI prototype with sample Tokyo forecast data. It includes the main forecast, expanded color analysis, forecast calendar, locations, paywall, and light/dark theme previews.

The SwiftUI app now has Sign in with Apple and a server-backed Free/Pro account state. Signed-out users can view a sample forecast; payment is not available. The SwiftUI source is organized by responsibility:

- `ContentView.swift` owns screen state and top-level composition.
- `ForecastComponents.swift` contains the main forecast components.
- `ForecastSheets.swift` contains modal sheet content.
- `PrototypeModels.swift` contains temporary sample data and presentation models.
- `SkyBackgroundView.swift` and `Color+Hex.swift` contain visual helpers.
- `AuthSession.swift` manages sign-in, Keychain storage, and authenticated API requests.

## Deployment

The server deploys to a single DigitalOcean Droplet on pushes to `develop`, using Docker Compose, persistent SQLite storage, and Caddy HTTPS. `AUTH_MODE=temporary` supports the existing Free/Pro test accounts without any Apple credentials. Follow the [Droplet deployment guide](server/deploy/README.md) for setup and GitHub secrets. Deployment and off-Droplet backups still need live verification. The iOS release URL still points to the App Platform hostname until that cutover.
