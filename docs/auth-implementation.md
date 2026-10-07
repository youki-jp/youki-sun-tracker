# Youki account implementation

Status: Temporary auth with SQLite deployed and login observed on 2026-10-03; live Apple sign-in remains unverified.
Updated: 2026-10-07

The Bun/Hono server owns accounts, sessions, Free/Pro entitlements, and request quotas. The native iOS app uses Sign in with Apple and stores Youki session tokens in Keychain. Payment remains deferred. SQLite replaces the earlier PostgreSQL storage code; The Droplet deployment is recorded in the [handover](handover.md).

## What works in source

- The native app requests a server challenge, presents Sign in with Apple, and sends the Apple identity token and one-use authorization code. Both forecast clients share a rotating Youki session. The deployed client supported sample data while signed out; the newer local weekly UX enters through sign-in. See [AuthSession](../frontend/YoukiApp/AuthSession.swift) and [ContentView](../frontend/YoukiApp/ContentView.swift).
- The server verifies Apple's identity token and nonce, exchanges the code with Apple, encrypts Apple's refresh token, and issues opaque 15-minute access and rotating 30-day refresh tokens. Token hashes, accounts, and entitlements are stored in SQLite. See [auth service](../server/src/infrastructure/auth/auth-service.ts), [Apple verifier](../server/src/infrastructure/auth/apple-identity.ts), [Apple token manager](../server/src/infrastructure/auth/apple-token-manager.ts), and [SQLite store](../server/src/infrastructure/auth/sqlite-auth-store.ts).
- Forecast routes require a valid Youki bearer token and share atomic SQLite quotas. Free: 20/minute and 300/day; Pro: 60/minute and 1,500/day. In-process forecast concurrency is eight, with bounded Open-Meteo fetches. See [app composition](../server/src/app.ts).
- `GET /api/v1/me` returns the current account state. `DELETE /api/v1/me` requires a session created within ten minutes, revokes Apple's refresh token, and deletes related local records. All Apple-created users are Free. There is no public paid-tier mutation or checkout route.

## Local database workflow

From `server/`, run `bun install` and `bun run migrate`. This applies versioned [Drizzle migrations](../server/drizzle/) to `data/youki.sqlite` by default. The SQLite file, WAL files, and local secrets are ignored by Git. Set `SQLITE_PATH` to choose another file; production requires an absolute path. Startup refuses to create an unmigrated database.

Change the [Drizzle schema](../server/src/infrastructure/auth/sqlite-schema.ts), run `bun run migration:generate`, review the generated SQL, then run `bun run migrate`. Drizzle manages SQLite migrations; it does not automatically transfer data or translate migrations to PostgreSQL.

With `AUTH_MODE=apple` (the default), the server requires `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, and `APPLE_TOKEN_ENCRYPTION_KEY` (32 random bytes encoded as base64). Preserve the encryption key across restarts and backups; changing it without re-encrypting stored tokens breaks Apple revocation and account deletion.

## Local Free and Pro test accounts

From `server/`, run `YOOKI_TEST_USER_PASSWORD=admin bun run dev:test-users`. This applies migrations, idempotently seeds the four accounts below in the local SQLite database, and serves the test-login route on loopback only. Set `PORT` if 3000 is occupied. The helper selects `AUTH_MODE=temporary` and requires no Apple settings or generated Apple keys. The updated iOS client reads `/api/v1/auth/config` and shows the test-account form.

| Account | Tier | Local test password |
| --- | --- | --- |
| `paid-tier1@example.com` | Pro | `admin` |
| `paid-tier2@example.com` | Pro | `admin` |
| `free-tier1@example.com` | Free | `admin` |
| `free-tier2@example.com` | Free | `admin` |

The password is supplied through `YOOKI_TEST_USER_PASSWORD`, not stored in SQLite or committed to source. Production enables this endpoint only with explicit `AUTH_MODE=temporary` and a password of 24 to 128 characters. In `AUTH_MODE=apple`, production never enables test login. Test login issues the same rotating Youki session as Apple sign-in. The server returns the tier from SQLite entitlements; the account screen shows an upgrade information button only for Free accounts. Payment checkout remains unimplemented. The deployed server predates the local weekly calendar changes; see the [handover](handover.md).

Use `bun run backup -- /absolute/path/to/backup.sqlite` for a consistent SQLite `VACUUM INTO` snapshot. The script verifies `PRAGMA integrity_check` and refuses to overwrite an existing backup. For a hosted server, schedule these snapshots, copy them off the Droplet, retain multiple versions, and test restoration. No remote backup schedule is configured yet.

## Deployment boundary

Use the [Droplet deployment guide](../server/deploy/README.md) for persistent SQLite, HTTPS, and CI/CD. App Platform's ephemeral container filesystem is unsuitable for this SQLite build. The Droplet workflow migrates the database and seeds the four test accounts only when `AUTH_MODE=temporary`; it then starts the server and checks database readiness.

Temporary mode does not load any `APPLE_*` variables and does not register Apple challenge/sign-in routes. It retains backend-owned SQLite accounts, session rotation, entitlements, quotas, and account deletion. Test login has a server-wide limit of 30 attempts per minute. Existing Apple accounts cannot sign in in this mode, and deleting an existing Apple account requires switching back to Apple mode for revocation. This is a temporary shared-password testing setup, not registration for real users. Deleted test accounts are recreated by a later deployment's seed step.

The iOS sign-in view discovers temporary mode via `GET /api/v1/auth/config`, including for an HTTPS Droplet in Release builds. Use `BACKEND_URL=https://206.189.178.229.sslip.io` for the current Droplet. The Release default in [AppConfig](../frontend/YoukiApp/AppConfig.swift) still needs an intentional cutover. Temporary-auth deployment/login were observed working; backup scheduling and live Apple verification remain outstanding.

## Verification and remaining work

`bun test` passes 23 tests, including real SQLite migration, challenge replay, refresh rotation, entitlement lookup, local test-account login, account deletion cascade, quota behavior, HTTP auth routes, and backup restoration. `bun run typecheck` passes. A local SQLite migration and verified backup were exercised. The temporary-auth DigitalOcean cutover, persistent-volume setup, and initial app login were observed in this thread on October 3. Live Apple sign-in, durability across a hosted restart/restore drill, and scheduled backups remain unverified. App-wide request capacity and cache limits are per process, so this implementation targets one server instance. Account endpoints still need edge-level abuse protection before public launch. StoreKit payment verification remains future work.
