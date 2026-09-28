# User auth and request limits

Date: 2026-09-28
Status: Historical PostgreSQL-stage snapshot. The current storage implementation is SQLite; see [SQLite implementation summary](2026-09-28-sqlite-auth-local.md).

## Quick read

Youki now has a monolithic auth path in its Bun/Hono server and a native Sign in with Apple flow in the iOS client. Verified users get Youki-owned sessions and a server-side Free/Pro lifetime tier. All forecast routes require a session and share Postgres quotas; Open-Meteo work is bounded and cached. Payments remain deferred. Before release, provision Apple credentials and DigitalOcean Managed PostgreSQL, apply the migration, and complete real-device sign-in/deletion checks.

| Changed surface | Source |
| --- | --- |
| Auth endpoints, route guards and limits | [app.ts](../../server/src/app.ts), [auth service](../../server/src/infrastructure/auth/auth-service.ts) |
| Apple verification and token revocation | [identity verifier](../../server/src/infrastructure/auth/apple-identity.ts), [token manager](../../server/src/infrastructure/auth/apple-token-manager.ts) |
| Durable accounts, sessions and quotas | PostgreSQL implementation was replaced by the [SQLite store](../../server/src/infrastructure/auth/sqlite-auth-store.ts) and [Drizzle migration](../../server/drizzle/0000_lumpy_maestro.sql). |
| Native sign-in and account UI | [AuthSession.swift](../../frontend/YoukiApp/AuthSession.swift), [ForecastSheets.swift](../../frontend/YoukiApp/ForecastSheets.swift), [ContentView.swift](../../frontend/YoukiApp/ContentView.swift) |
| Deployment instructions and contract | [auth implementation](../auth-implementation.md), [README](../../README.md) |

## Engineer details

The client obtains an Apple authorization through `AuthenticationServices`, using a server-issued nonce. The server checks the Apple identity token and exchanges the one-use code for a revocable Apple refresh token. That token is encrypted in Postgres; Youki's own opaque access/refresh tokens are stored only as hashes on the server and in Keychain on the device. Access expires after 15 minutes; refresh rotates for a 30-day window. Account deletion requires a recently created session, revokes the Apple token, and cascades account-related records.

The `/api/v1/sky-color/{estimate,predictions}` and `/api/v1/sky-day/timeline` routes share 20/minute and 300/day Free quotas; Pro uses 60/minute and 1,500/day. Forecast concurrency is limited per server process, and Open-Meteo fetching has its own bounded pool, deadline, deduplication, and cache. The account routes have a process-level admission ceiling. For multi-instance rollout, the per-instance upstream ceiling still needs capacity tuning or a shared global budget. The old monthly/yearly trial UI is replaced by Free/Pro account status; there is no checkout or public Pro mutation route.

Verification observed: `bun test` passes (17 tests); `bun run typecheck` passes for production TypeScript; Bun bundles the server; iOS source type-checks; the model, scene and alarm-planner regression executables pass; a full unsigned iOS Simulator build and two signed-out account/UI tests succeeded; `git diff --check` passes. A live PostgreSQL migration, Apple account exchange/revocation, signed-device flow, and DigitalOcean edge behavior were not tested because this workspace has no service credentials or attached database. The old `sky-gradient-service.test.ts` has a pre-existing standalone TypeScript test-type error, so the build typecheck excludes test files while `bun test` executes them.

The [earlier architecture proposal](../auth-and-request-protection-design.md) and [HTML preview](../auth-experience-preview.html) remain context. The [current implementation guide](../auth-implementation.md) records the SQLite approach. No deployment, payment integration, or production secret changes were made in this historical stage.
