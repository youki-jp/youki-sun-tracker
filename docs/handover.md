# Youki handover

Updated: 2026-10-07
Status: Droplet deployment and login observed working on 2026-10-03; weekly UX changes remain local

## Start here: current server

| Setting | Current value |
| --- | --- |
| Backend base URL / iOS `BACKEND_URL` | `https://206.189.178.229.sslip.io` |
| Droplet public IP / GitHub `DROPLET_HOST` | `206.189.178.229` |
| SSH user / GitHub `DROPLET_USER` | `deploy` |
| SSH command | `ssh deploy@206.189.178.229` |
| Reported Ubuntu hostname | `ubuntu-s-1vcpu-512mb-10gb-nyc1` |
| Repository on Droplet | `/opt/youki` |
| Deployed branch | `develop` |
| Domain in `/opt/youki/server/deploy/.env` | `API_DOMAIN=206.189.178.229.sslip.io` |
| Server secrets file | `/opt/youki/server/.env.production` |

Use this Droplet for the deployed backend. `https://youki-server-2idly.ondigitalocean.app` is the legacy App Platform address and is not the target for this deployment. SSH uses the public IP, not the HTTPS URL. This handover contains no SSH private key or server password; an agent needs an authorized SSH identity to connect. GitHub's private deployment key is not a local SSH identity.

These values were supplied and used successfully in this thread on October 3. They have not been rechecked against the live server on October 7.

## iOS backend selection

[AppConfig.swift](../frontend/YoukiApp/AppConfig.swift) reads `BACKEND_URL` from the app process environment. For the Droplet, set this in Xcode's **YoukiApp scheme > Run > Arguments > Environment Variables**:

```text
BACKEND_URL=https://206.189.178.229.sslip.io
```

The source defaults are still `http://localhost:3000` in Debug and the legacy App Platform address in Release. An environment override is therefore required for the Droplet. A `SIMCTL_CHILD_BACKEND_URL` override applies only to that simulator launch, not to future Xcode launches or distributed builds.

The separate **Youki UI Preview** simulator used the updated local server at `http://localhost:3001` with a separate preview database, because the new weekly API was not deployed. It was later switched from manually entered Suginami coordinates to **Use my location**, with the simulator's device location set to central Yokohama (`35.4437,139.6380`) and location permission enabled. This is simulated location; a physical iPhone uses Core Location for its actual position. The preview server's continued availability has not been rechecked.

## What was completed and deployed

- Temporary backend authentication works without Apple Developer credentials. The production file contains `AUTH_MODE=temporary` and a private `YOOKI_TEST_USER_PASSWORD`; no `APPLE_*` settings are required in this mode.
- Sessions, refresh tokens, account tiers, quotas, and SQLite persistence remain server-owned. Temporary auth exposes the existing four Free/Pro test accounts; it does not implement registration for public users or purchases.
- Pushes/merges to `develop` trigger [deploy-droplet.yml](../.github/workflows/deploy-droplet.yml). The workflow checks out the exact commit, builds the API, migrates SQLite, seeds temporary accounts, starts API/Caddy, and checks database readiness.
- Compose build context was fixed. Migration/seed runs now use `--interactive=false` and stdin from `/dev/null`, preventing Docker from consuming the remaining SSH deployment script.
- [PR 19](https://github.com/youki-jp/youki-sun-tracker/pull/19) and [PR 20](https://github.com/youki-jp/youki-sun-tracker/pull/20) were merged. The corrected [deployment run 37120575640](https://github.com/youki-jp/youki-sun-tracker/actions/runs/37120575640) reached seeding, container startup, and readiness for commit `5a61ab963a1f47eb0ba6042f6d3a25b5871c98f0`.
- HTTPS health/auth-config requests worked, and the user confirmed login from the local iOS app against the Droplet.

For configuration and operational commands, read the [deployment guide](../server/deploy/README.md). For implementation details, read [temporary auth](artifacts/2026-10-03-temporary-droplet-auth.md).

## What remains local

The working branch is `feat/weekly-forecast-experience`. As inspected on October 7, its implementation and documentation changes are uncommitted and have not been pushed, merged, or deployed in this thread.

- Welcome/sign-in entry; signed-out users no longer enter the main forecast.
- Dated timeline, dimmed past events, and next-event summary including tomorrow's first light.
- Seven-day Pro sunrise/sunset calendar; Free today/tomorrow with locked later rows.
- Server date limits, a weekly API, and selecting a day's sky/score/timeline together.
- Today/tomorrow labeled Forecast; days 3-7 labeled Outlook. Input completeness is displayed as coverage rather than a probability of accuracy.

See the [weekly UX artifact](artifacts/2026-10-03-weekly-forecast-experience.md) for source links, compilation evidence, preview observations, and limitations. Deploy the new backend before pointing the updated frontend's weekly calendar at production.

Pre-existing user edits in `frontend/YoukiApp/SkyGradient.swift` and `frontend/YoukiApp/YoukiApp.xcodeproj/project.pbxproj` must be preserved and kept distinct when reviewing or committing this work.

## Verification boundaries and follow-ups

- Last live deployment/login evidence: October 3, not a current uptime claim.
- Apple sign-in with real Developer credentials, payment verification, scheduled off-Droplet backups, and a hosted restore drill remain unverified or deferred.
- The weekly UX received backend type checking/bundling, Debug/Release simulator builds, and a local Pro calendar layout walkthrough. No automated tests were requested or run for that task.
- The Release backend default still needs an intentional cutover before distribution.
- No SSH connection was attempted or secrets retrieved during this handover update.

## Handover update record (October 7)

### Quick read

Connection information was missing from the earlier artifacts, and the temporary-auth artifact still described the pre-fix deployment. This handover now records the actual addresses and separates observed deployment history from newer local work. Other sessions should read this file before connecting.

### Changed guidance

| Surface | Change |
| --- | --- |
| [Agent entry](../AGENTS.md), [project guide](../CLAUDE.md), [references](../.codex/references.md), [README](../README.md) | Link to this handover and identify the current Droplet and legacy Release default |
| [Deployment guide](../server/deploy/README.md), [auth guide](auth-implementation.md), [current state](current-state.md) | Align connection details and deployed/local status |
| [Temporary-auth artifact](artifacts/2026-10-03-temporary-droplet-auth.md) | Record the corrected deployment and hosted login evidence |

### Verification and limits

`git diff --check` passed. Local handover links were checked and resolve. No tests, live server checks, SSH access, or secrets retrieval were performed for this documentation update. No agents were delegated work. Documentation changes remain local until committed/pushed; a separate checkout will not see them yet. The runtime defaults were documented, not changed.
