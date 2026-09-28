# Local Free and Pro test accounts

Status: Implemented locally
Updated: 2026-09-28

## Quick read

### What changed

Four local accounts are seeded into SQLite: two Pro and two Free. A Debug build connected to the localhost test server can sign in with them and receive ordinary Youki sessions.

### Why it matters

The account screen now demonstrates tier-specific controls: Free accounts can open the Pro information screen; Pro accounts see active membership and no upgrade button.

### Current state

Seeded and visually checked in the iPhone 16 Pro Simulator. The local test endpoint binds only to loopback and is disabled in production. Production Apple-created accounts still start Free.

### Next step

Use these accounts to finish the remaining Free and Pro feature access rules as the product entitlements are defined.

## Changed surface

| Area | Status | Details |
| --- | --- | --- |
| Test account records and sessions | Implemented | [local-test-users.ts](../../server/src/infrastructure/auth/local-test-users.ts), [auth-service.ts](../../server/src/infrastructure/auth/auth-service.ts) |
| Idempotent SQLite seed and local server command | Implemented | [seed-test-users.ts](../../server/scripts/seed-test-users.ts), [dev-test-users.ts](../../server/scripts/dev-test-users.ts) |
| Account tier controls | Implemented | [AccountScreen.swift](../../frontend/YoukiApp/AccountScreen.swift), [ForecastSheets.swift](../../frontend/YoukiApp/ForecastSheets.swift) |
| Setup and limitations | Documented | [auth-implementation.md](../auth-implementation.md) |

## Engineer details

### Design and decisions

| Email | Tier | Local test password |
| --- | --- | --- |
| `paid-tier1@example.com` | Pro | `admin` |
| `paid-tier2@example.com` | Pro | `admin` |
| `free-tier1@example.com` | Free | `admin` |
| `free-tier2@example.com` | Free | `admin` |

The password is supplied with `YOOKI_TEST_USER_PASSWORD` and stays in server memory; it is not written to SQLite or source control. The app only displays this login picker in Debug builds pointed at `localhost`. Enabling it makes the server bind to `127.0.0.1`. Production mode does not enable the route or seed users.

### Contracts and flow

`POST /api/v1/auth/test-login` checks the selected email and shared local password, then creates the same hashed access and refresh session used by Apple login. The response gets Free or Pro from the database entitlement row. The seed script can be run repeatedly without creating duplicates.

Run the documented local setup from `server/`:

```sh
YOOKI_TEST_USER_PASSWORD=admin bun run dev:test-users
```

Set `PORT` if 3000 is occupied. Point the Debug app at `http://localhost:<port>` through the Xcode scheme's `BACKEND_URL` environment value.

### Delegated-agent outcomes

None.

### Verification

| Check | Result | Evidence |
| --- | --- | --- |
| `bun run typecheck` | Passed | TypeScript completed without errors. |
| `bun test` | Passed | 23 tests passed, including idempotent seed, correct Free/Pro sessions, refresh, wrong password, and disabled-route checks. |
| `bun run dev:test-users` | Passed | Started on a local test port and returned HTTP 200 from readiness. |
| Test login smoke check | Passed | `paid-tier2@example.com` returned HTTP 200 with tier `pro`. |
| iOS Simulator build | Passed | Debug iOS app build completed successfully. |
| Manual tier UI check | Passed | Free account displayed “Explore Youki Pro”; Pro account displayed “Pro membership active” without an upgrade button. |
| `git diff --check` | Passed | No whitespace errors. |

### Risks and limitations

- `admin` is intentionally weak and only suitable for the isolated local test server. Do not enable the test route on a reachable host.
- The temporary Apple test keys only support rendering the Apple button; they cannot complete real Apple authorization.
- Payment checkout is not implemented. The Pro information screen is a placeholder.
- The live forecast calendar still returns one day; Pro tier currently affects account and quota state, not additional forecast data.

### Follow-ups

- Add production entitlements only through verified App Store transactions or a controlled admin workflow.
- Complete the remaining Free and Pro feature gates when those product differences are specified.

### Not implemented or unverified

- Real Apple sign-in and StoreKit purchase verification remain unverified.
