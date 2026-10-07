# Temporary Droplet authentication without Apple credentials

Status: Deployed and observed working on 2026-10-03
Updated: 2026-10-07

## Quick read

### What changed

The server can run with `AUTH_MODE=temporary` and a private `YOOKI_TEST_USER_PASSWORD`, without any Apple credentials. The existing four Free/Pro test accounts use SQLite sessions, refresh tokens, quotas, and account deletion. The iOS sign-in screen discovers this mode and shows the test-account password form.

### Why it matters

Droplet deployment and hosted testing can proceed before Apple Developer credentials are available.

### Current state

Implemented and checked locally on `feat/temporary-droplet-auth`. Production-mode startup with no `APPLE_*` settings and authenticated session flows passed. The Docker build context is corrected. PR #19 was merged into `develop` as `ec8b48e`. Its first workflow built the Docker image and migrated SQLite, then exited before seeding/startup. The follow-up disables Docker Compose interactive input so the remote script reaches startup and readiness.

The follow-up PR #20 was merged as `5a61ab9`. [Run 37120575640](https://github.com/youki-jp/youki-sun-tracker/actions/runs/37120575640) completed migrations, seeding, API/Caddy startup, and database readiness. HTTPS health/auth-config and user-confirmed iOS login worked at `https://206.189.178.229.sslip.io`. This evidence is from October 3; see the [current handover](../handover.md) for connection details and newer local work.

### Next step

Use the [handover](../handover.md) to connect to `deploy@206.189.178.229` and distinguish the deployed temporary-auth version from the local weekly UX changes.

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
| Corrected Droplet deployment | Passed on October 3 | Run `37120575640` reached seed, container startup, and readiness |
| Public HTTPS and hosted login | Observed on October 3 | Health/config requests succeeded; user confirmed iOS login |

### Risks and limitations

- All four test accounts share the password. Their sessions and quotas belong to the selected account, so testers selecting the same account share its data and quotas.
- Seeding preserves account IDs but recreates deleted test accounts on a later deployment. This is test-account behavior, not public signup.
- Temporary mode disables new Apple sign-ins. Existing Apple-account deletion requiring token revocation needs Apple mode and valid credentials.
- The iOS Release default still points to App Platform; hosted development used `BACKEND_URL=https://206.189.178.229.sslip.io`. Set this explicitly for subsequent hosted runs.
- Pre-existing changes in `SkyGradient.swift` and the Xcode project file were present before this work and were not edited by this task.

### Follow-ups

- Configure the iOS Release default before distribution and schedule off-Droplet backups.
- Deploy the newer local weekly UX when approved; see the [handover](../handover.md).
- Switch to Apple mode when valid Apple credentials are available.

### Not implemented or unverified

- Scheduled off-Droplet backups, restore drills, physical-device verification, and live Apple sign-in.
- Current uptime has not been rechecked on October 7; deployment, TLS, and login evidence is from October 3.
- Public email/password signup, password recovery, and payment integration.

## Deployment follow-up

Docker Compose `run` keeps stdin open by default ([Docker reference](https://docs.docker.com/reference/cli/docker/compose/run/)). Both CI one-off commands now use `-T --interactive=false` and `/dev/null` input. This prevents them from consuming the SSH heredoc. The workflow prints an explicit commit confirmation only after database readiness succeeds.
