# Deployment readiness and request abuse review

Updated: 2026-10-07 (Asia/Tokyo)
Status: Review completed; remediation proposed, not implemented

## Quick read

The Droplet is running the latest `develop` commit, `1cbf3362fe45e0e0a4187e963d5ffe792eb488b3`. HTTPS readiness and SQLite readiness passed. The current deployment includes the weekly forecast and night palette changes; the earlier handover's statement that weekly work remains local is now stale.

The forecast and sky rendering code is implemented, but the color scorer remains a heuristic with no demonstrated accuracy calibration. Apple enrollment is necessary for TestFlight, and additional distribution configuration remains: correct the Release backend URL, configure signing/App Store Connect, and archive/upload the app. Real Apple sign-in needs its own credential configuration and live verification.

The backend has meaningful protections against unauthorized forecast use and excessive usage by individual accounts. It lacks configured protection before requests reach the app. The shared login throttle can deny service to all testers, and unauthenticated request floods still reach a small Droplet. Harden these areas before broad public testing.

Next step: add limits before authentication and isolate login throttling by caller/account, while retaining global capacity limits. Prepare the iOS Release backend configuration alongside Apple enrollment.

## Reviewed surfaces

Source links below are pinned to the reviewed commit because the local checkout is on the old `main` branch and does not contain these source files.

| Area | Evidence | State |
| --- | --- | --- |
| Deployment | [Successful run 37605505423](https://github.com/youki-jp/youki-sun-tracker/actions/runs/37605505423), remote `git rev-parse HEAD` | Latest `develop` SHA confirmed on Droplet; working tree clean |
| Route guards | [app.ts](https://github.com/youki-jp/youki-sun-tracker/blob/1cbf3362fe45e0e0a4187e963d5ffe792eb488b3/server/src/app.ts) | Authenticated forecasts; body, account, auth, and concurrency limits |
| Persistent quota/session storage | [sqlite-auth-store.ts](https://github.com/youki-jp/youki-sun-tracker/blob/1cbf3362fe45e0e0a4187e963d5ffe792eb488b3/server/src/infrastructure/auth/sqlite-auth-store.ts), [auth-service.ts](https://github.com/youki-jp/youki-sun-tracker/blob/1cbf3362fe45e0e0a4187e963d5ffe792eb488b3/server/src/infrastructure/auth/auth-service.ts) | Account quotas in SQLite; opaque sessions and refresh rotation |
| Proxy and network | [Caddyfile](https://github.com/youki-jp/youki-sun-tracker/blob/1cbf3362fe45e0e0a4187e963d5ffe792eb488b3/server/deploy/Caddyfile), [compose.yaml](https://github.com/youki-jp/youki-sun-tracker/blob/1cbf3362fe45e0e0a4187e963d5ffe792eb488b3/server/deploy/compose.yaml) | Active Caddy configuration read; API bound to loopback |
| Upstream resource controls | [open-meteo-client.ts](https://github.com/youki-jp/youki-sun-tracker/blob/1cbf3362fe45e0e0a4187e963d5ffe792eb488b3/server/src/infrastructure/open-meteo/open-meteo-client.ts) | Cache, identical-request coalescing, deadlines, bounded concurrency/queue |
| iOS configuration | [AppConfig.swift](https://github.com/youki-jp/youki-sun-tracker/blob/1cbf3362fe45e0e0a4187e963d5ffe792eb488b3/frontend/YoukiApp/AppConfig.swift) | Release still defaults to legacy App Platform URL |
| Review artifact | This file | Only new documentation; no application or deployment changes |

## TestFlight readiness

1. Enroll in the Apple Developer Program. Account enrollment/status was not inspected in this review.
2. Make the distributed Release build use `https://206.189.178.229.sslip.io`, or the intended production domain, through configuration included in the app. The current default is `https://youki-server-2idly.ondigitalocean.app`. Xcode Run environment overrides are not a durable configuration for TestFlight installations.
3. Configure the correct signing team, register/confirm the bundle identifier and capabilities, and create the App Store Connect app record. The project already contains a team ID and bundle identifier; that does not establish that distribution signing is ready.
4. Archive a signed device Release build and upload it, complete required beta information and compliance declarations, and configure testers. External testing can require TestFlight App Review. [Apple distribution guidance](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases), [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).
5. If the beta should use real Apple accounts, configure the five required `APPLE_*` values, enable the capability for the app, switch `AUTH_MODE` from `temporary` to `apple`, and verify login, refresh, logout, and account deletion with live Apple credentials. This authentication cutover is separate from TestFlight distribution; invited testers can otherwise use temporary login.

Live `/api/v1/auth/config` currently returns `appleSignInEnabled: false` and `testLoginEnabled: true`. Remote container environment confirms `AUTH_MODE=temporary`, `NODE_ENV=production`. Temporary mode provides four seeded accounts sharing one private password, not public registration or individual tester identities. Production startup requires that password to be 24-128 characters; password entropy and secrecy were not audited.

StoreKit/payment verification and forecast accuracy calibration are outside this readiness check and are not established as complete. They are not prerequisites to distributing a beta that does not exercise purchases.

## Existing protection

| Control | Current behavior | Verification |
| --- | --- | --- |
| Forecast authentication | All four forecast POST routes require an active bearer session | All four rejected unauthenticated requests with `401` live |
| Account endpoints | `GET /api/v1/me` and `DELETE /api/v1/me` authenticate the caller; deletion additionally requires recent sign-in | GET returned `401` live; deletion inspected in source only |
| Free quotas | 20 forecast requests/minute; 300/day | Source verified; not exhausted on production |
| Pro quotas | 60 forecast requests/minute; 1,500/day | Source verified; not exhausted on production |
| Quota ownership | Account ID, shared across routes and sessions; atomic SQLite transaction; fixed UTC minute/day windows | Source verified; refresh/new sessions do not reset quotas |
| Forecast concurrency | At most eight requests executing downstream forecast work per app process | Source verified |
| Auth service | 600 requests/minute and 16 concurrent requests across `/api/v1/auth/*` per process | Source verified; counters reset on process restart |
| Temporary login | 30 attempts/minute total for the server | Source verified; counts unsuccessful attempts as well |
| Body limits | Forecast 8 KiB; auth and Bun HTTP server 12 KiB | 8,207-byte forecast body returned `413` live; other thresholds source verified |
| Input limits | Finite numeric coordinates, latitude/longitude/altitude bounds, valid dates, server-owned Free/Pro date horizons | Source verified |
| Upstream calls | Five-second fetch deadline; 16 concurrent calls; at most 32 queued waiters with one-second wait deadline | Source verified |
| Upstream cache | Maximum 256 entries, 15-minute forecast TTL / one-hour timezone TTL; identical in-flight URLs share work | Source verified; process-local |
| Session credentials | Random 32-byte opaque tokens, hashes stored in DB, 15-minute access expiry, rotating refresh tokens | Source verified |
| Network | HTTPS through Caddy; API published only on `127.0.0.1:3000` | Live HTTPS and remote Docker/`ss` observations |

Quota failures return `429` with `Retry-After`; forecast capacity exhaustion returns `503`. Quota admission occurs before forecast capacity and payload validation, so rejected downstream work can still consume an account's allowance. These are implementation details, not live load-test results.

## Findings and proposed follow-ups

### High priority: requests reach the Droplet before throttling

The active Caddyfile contains only `reverse_proxy api:3000`. There is no configured edge rate limiter, bot filter, or managed DDoS proxy in that configuration. Forecast account quotas operate after requests reach Bun and after token authentication. Invalid or missing credentials are rejected, but repeated requests still consume connection, HTTP parsing, and sometimes database work. Root/health and `/me` do not have an application request-rate limiter.

Proposed: add trusted-client-IP rate and connection limits before authentication, covering public routes and invalid-token traffic as well as forecasts. If using an external edge service, prevent direct origin access from bypassing it and trust forwarding headers only from the configured proxy. Retain app/account limits. Network firewall settings alone do not establish HTTP abuse protection. [OWASP denial-of-service guidance](https://cheatsheetseries.owasp.org/cheatsheets/Denial_of_Service_Cheat_Sheet.html).

### High priority: one caller can consume the shared login allowance

The 30-attempt temporary-login counter is global, with no per-IP or per-account isolation. Based on source, a caller making unsuccessful attempts can consume that allowance and cause other testers' login attempts to receive `429` for the rest of the minute. The broader 600-request auth limit is also global and includes public auth configuration requests. This availability failure mode was not deliberately triggered against production.

Proposed: use layered per-caller and account-aware controls plus a global emergency cap. Account-only throttling also needs care to avoid allowing targeted account lockout. Disable shared temporary login when moving to real user identities. Testers sharing an account also share forecast quotas and account-level actions; these accounts do not provide individual isolation.

### Medium priority: quotas count requests rather than total forecast work

The weekly endpoint admits one quota unit and processes up to seven days for Pro, sequentially. Cache keys contain exact request coordinates and other upstream parameters. Varying coordinates can bypass cache reuse and cause more upstream work, within the user's request allowance. Concurrency guards bound simultaneous work but do not impose a global daily upstream budget across all accounts.

Proposed: measure upstream work, enforce a global upstream budget and per-account work/concurrency policy, and evaluate location bucketing without materially reducing forecast quality. Retain the bounded weekly range, cache, and coalescing controls. Real Apple sign-in establishes identity; a valid user can still automate requests.

### Medium priority: limited host resources and observability

The host reports 458 MiB RAM and no swap. Neither API nor Caddy container has an explicit memory, CPU, or PID limit (`memory=0`, `nano_cpus=0`, PID limit unset). Source logging records unexpected error names/request IDs, and the active Caddyfile has no access-log directive. No abuse dashboard, alert configuration, or historical capacity metrics were inspected.

Proposed: monitor memory, latency, upstream calls, `401`/`429`/`503` rates, and login failures; add redacted request logging and actionable alerts. Determine suitable container limits and Droplet sizing from measured load. No safe operating traffic level is claimed by this review.

### Before Apple authentication cutover: bound signing-key refresh

`AppleIdentityVerifier` refetches Apple signing keys when a submitted token's key ID is unknown. There is no shared refresh promise or unknown-key refresh cooldown. This path is disabled in the current temporary deployment.

Proposed: coalesce key refresh and apply a cooldown/negative cache before enabling live Apple sign-in. Preserve signature, issuer, audience, expiry, and nonce validation.

## Verification evidence and boundaries

- GitHub read-only branch query: latest `develop` SHA matched the reviewed snapshot.
- GitHub deployment run `37605505423`: completed successfully on October 7 at 10:09 UTC.
- Read-only SSH: deployed checkout SHA matched; `git status --short` empty; API/Caddy running; loopback binding, nonsecret auth mode, memory, listeners, active proxy config, and container resource settings inspected.
- Eight low-volume HTTPS requests: readiness `200`, auth config `200`, all four forecast routes without credentials `401`, `/me` without credentials `401`, oversized timeline body `413`.
- Initial sandboxed network attempts could not resolve/reach hosts; the approved network checks then succeeded. Initial failures were not treated as service downtime.
- Host firewall inspection via `sudo -n ufw status verbose` could not run because sudo required a password. DigitalOcean Cloud Firewall rules were not inspected. SSH listening on all interfaces does not by itself prove unrestricted external SSH access.
- No production credentials retrieved, no authenticated forecasts requested, no sessions/accounts changed, no deployment/configuration edits, no brute force or saturation checks, and no automated test suite run.
- Live rate-limit saturation, authenticated forecast correctness, real Apple login, signed device archive/TestFlight upload, purchase validation, backup/restore readiness, and predictive accuracy remain unverified.
- No sub-agents were used.

TestFlight controls who receives the app; it does not make the public backend inaccessible to other callers. Current controls provide an appropriate foundation for a small invited beta, with the availability gaps above addressed before wider exposure.
