# Temporary Droplet authentication without Apple credentials

Status: Implemented locally; deployment unverified
Updated: 2026-10-03

## Quick read

### What changed

The server can run with `AUTH_MODE=temporary` and a private `YOOKI_TEST_USER_PASSWORD`, without any Apple credentials. The existing four Free/Pro test accounts use SQLite sessions, refresh tokens, quotas, and account deletion. The iOS sign-in screen discovers this mode and shows the test-account password form.

### Why it matters

Droplet deployment and hosted testing can proceed before Apple Developer credentials are available.

### Current state

Implemented and checked locally on `feat/temporary-droplet-auth`. Production-mode startup with no `APPLE_*` settings and authenticated session flows passed. The Docker build context is corrected. No changes have been pushed or deployed.

### Next step

Replace the Droplet's placeholder env file using the [deployment guide](../../server/deploy/README.md), then merge these changes to `develop` and inspect the deployment run.

## Changed surface

| Area | Status | Details |
| --- | --- | --- |
| Auth mode and startup | Implemented | [Configuration](../../server/src/infrastructure/auth/auth-config.ts), [entry point](../../server/src/index.ts) |
| Auth routes and sessions | Implemented | [HTTP app](../../server/src/app.ts), [auth service](../../server/src/infrastructure/auth/auth-service.ts) |
| Test-account preparation | Implemented | [Seed command](../../server/scripts/seed-test-users.ts), [local helper](../../server/scripts/dev-test-users.ts) |
| iOS login | Implemented | [Session client](../../frontend/YoukiApp/AuthSession.swift), [entry view](../../frontend/YoukiApp/AccountEntryView.swift) |
| Droplet CI/CD | Implemented | [Workflow](../../.github/workflows/deploy-droplet.yml), [Compose](../../server/deploy/compose.yaml), [setup](../../server/deploy/README.md), [env template](../../server/deploy/.env.production.example) |

## Engineer details

### Design and decisions

- `AUTH_MODE=apple` remains the default. Temporary mode is explicit and never constructs Apple verification/token dependencies. The local helper now uses temporary mode instead of generating dummy Apple keys.
- Production temporary login requires a password of 24 to 128 characters. Generate it with `openssl rand -base64 32`. Credentials remain in the ignored Droplet env file.
- Apple challenge/sign-in routes are absent in temporary mode. All forecast routes retain authentication and account quotas. Existing Apple refresh-token revocation is not bypassed during deletion.
- Compose uses the server directory as its Docker build context, matching the Dockerfile. Env files and database files are excluded from that context.
- CI/CD migrates, seeds only in temporary mode, starts containers, then checks database readiness. SQLite stays in the existing named volume.

### Contracts and flow

`GET /api/v1/auth/config` reports `appleSignInEnabled` and `testLoginEnabled`. The updated iOS client uses this response to show temporary login even for an HTTPS server in Release builds. It falls back to the prior Apple flow when an older server returns 404 for this endpoint.

Temporary login uses the existing `POST /api/v1/auth/test-login` email/password contract, normal access and refresh tokens, and the existing four account emails. Login attempts are limited to 30 per minute across the server. No general account registration is added.

### Delegated-agent outcomes

None; implementation was completed by the primary agent.

### Verification

| Check | Result | Evidence |
| --- | --- | --- |
| `bun run typecheck` | Passed | No TypeScript errors |
| `bun build src/index.ts --target bun --outdir /tmp/youki-server-build` | Passed | 55 modules bundled |
| `bun test src/infrastructure/auth/auth.test.ts src/infrastructure/auth/sqlite-auth-store.test.ts` | Passed | 11 tests, 101 assertions |
| Temporary production HTTP smoke check | Passed | Fresh temporary SQLite database; no Apple env variables; repeated seed; readiness/config; Apple routes 404; forecasts reject missing tokens; Free/Pro login; refresh/replay; logout; deletion; login throttling |
| Weak production password startup | Passed | `admin` rejected before server startup |
| iOS Simulator Debug and Release builds | Passed | `xcodebuild` with generic iOS Simulator destination; temporary DerivedData; successful builds |
| `git diff --check` | Passed | No whitespace errors |

### Risks and limitations

- All four test accounts share the password. Their sessions and quotas belong to the selected account, so testers selecting the same account share its data and quotas.
- Seeding preserves account IDs but recreates deleted test accounts on a later deployment. This is test-account behavior, not public signup.
- Temporary mode disables new Apple sign-ins. Existing Apple-account deletion requiring token revocation needs Apple mode and valid credentials.
- The iOS Release URL still points to App Platform; the Droplet hostname must be configured before hosted app testing.
- Pre-existing changes in `SkyGradient.swift` and the Xcode project file were present before this work and were not edited by this task.

### Follow-ups

- Set the Droplet env file, merge to `develop`, and verify the workflow and public HTTPS readiness endpoint.
- Configure the iOS API hostname and off-Droplet backups.
- Switch to Apple mode when valid Apple credentials are available.

### Not implemented or unverified

- Live Docker image build: Docker is unavailable on this Mac.
- Live Droplet deployment, DNS, TLS, backups, and hosted iOS login.
- Simulator screenshots and physical-device verification.
- Public email/password signup, password recovery, and payment integration.
