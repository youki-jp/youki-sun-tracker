# Persistent sign-in and verified account plan

Status: Proposed; current behavior audited, no auth code changed by this document.
Updated: 2026-09-28

## Quick read

Youki already has a Sign in with Apple button, server-side Apple identity verification, SQLite accounts, and Keychain-backed Youki sessions. It has **no Youki password**. The missing work is to distinguish a restored local session from a server-verified one, renew active sessions beyond the current 30-day idle limit without showing Apple sign-in again, handle Apple revocation, and make logout/reinstall behavior reliable. Keep server authorization authoritative; cached account details are only for presentation. Recommend a rolling 365-day *inactivity* limit, with no fixed lifetime for an actively used session, rather than a refresh token that never expires.

## Problem and scope

### Goals

- A user signs in once on a new install and stays signed in across ordinary app launches, updates, and frequent use without seeing the Apple UI again.
- The server accepts forecast requests only for an active account with a valid Youki session; Free/Pro comes from the server.
- Stored credentials and secrets remain protected. Logout, account deletion, Apple revocation, or an invalid session stop authenticated access.
- First launch after an app uninstall/reinstall starts signed out, even if iOS retained Keychain items.
- Offline startup preserves a useful cached presentation without claiming the server verified the user while offline.

### Non-goals and assumptions

- No email/password login or payment SDK. If password login is added later, passwords must be **salted, slow-hashed** (for example Argon2id), not reversibly encrypted. [OWASP password storage guidance](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- No new identity provider or separate auth service. One Bun/Hono server and one SQLite database remain the owner of accounts and sessions.
- The 365-day idle limit is a recommended security policy. Regular use renews it indefinitely; a year without opening the app, revoked Apple authorization, lost Keychain data, account suspension, or account deletion can still require sign-in. “Forever” cannot be guaranteed safely.
- The app has not yet completed a real-device Apple sign-in against a hosted server. Existing local test sessions do not require a production data migration.

## Current state and direct answers

| Question | Implemented now | Gap |
| --- | --- | --- |
| Is a password encrypted in SQLite? | There is no Youki password. Apple handles the user's Apple ID password. The server stores Apple's revocable refresh token using AES-256-GCM ciphertext; Youki's random access/refresh tokens are stored as SHA-256 hashes. See [token manager](../../server/src/infrastructure/auth/apple-token-manager.ts), [auth service](../../server/src/infrastructure/auth/auth-service.ts), and [schema](../../server/src/infrastructure/auth/sqlite-schema.ts). | The SQLite file itself is not application-encrypted; its file mode is restricted. Protect host disk, backups, and the separate encryption key. |
| Are login details hard-coded? | The reviewed server reads `APPLE_*` secrets from runtime environment variables in [index.ts](../../server/src/index.ts); the iOS app uses [Keychain](../../frontend/YoukiApp/AuthSession.swift). No Apple password or private key is present in the reviewed source. | Confirm deployment secrets are configured outside Git. The release API URL in [AppConfig](../../frontend/YoukiApp/AppConfig.swift) is hard-coded, but it is an address, not a credential. |
| Is there auth UI? | The [account sheet](../../frontend/YoukiApp/ForecastSheets.swift) has a native Sign in with Apple button, Free/Pro label, sign-out, and account deletion. Signed-out users see a sample and a sign-in entry point. | No explicit restoring/offline/reauthentication state; the sheet can show a sign-in state before a slow challenge response. |
| Is the user verified? | [AppleIdentityVerifier](../../server/src/infrastructure/auth/apple-identity.ts) checks Apple JWT signature, issuer, audience, expiry, and nonce. The server exchanges the authorization code, verifies the returned token has the same Apple subject, then creates or finds the SQLite user. `/api/v1/me` requires an active bearer session. | The client sets `isAuthenticated = true` immediately when it reads cached Keychain tokens, before `/me` confirms them. Apple credential revocation is not checked at launch or handled server-side. “Verified” here means valid Apple identity and active Youki session, not a separate email-verification badge. |
| Will the user be prompted every launch? | [AuthSession](../../frontend/YoukiApp/AuthSession.swift) restores tokens from Keychain and silently refreshes after a 401; the [root view](../../frontend/YoukiApp/ContentView.swift) calls `/me` on launch and foreground. Ordinary relaunches should not prompt. | The server's [refresh expiry](../../server/src/infrastructure/auth/sqlite-auth-store.ts) is 30 days after the last refresh. The client does not persist the access-token expiry, ignores Keychain write failures, and has no recovery if a refresh succeeds on the server but its response is lost. |

The account tier cached on the phone is a display hint; the server reads entitlements for authorization. The weather/Open-Meteo cache is separate from login persistence. Apple documents [checking credential state](https://developer.apple.com/documentation/authenticationservices/implementing-user-authentication-with-sign-in-with-apple) and [server-to-server account-change notifications](https://developer.apple.com/documentation/signinwithapple/processing-changes-for-sign-in-with-apple-accounts). Do not rely on a native revocation notification alone.

## Target architecture

### Ownership and flow

| Component | Responsibility | Likely files |
| --- | --- | --- |
| Apple AuthenticationServices | Interactive first sign-in and credential-state query for the stored Apple user identifier. | [AuthSession.swift](../../frontend/YoukiApp/AuthSession.swift), [ForecastSheets.swift](../../frontend/YoukiApp/ForecastSheets.swift) |
| iOS session coordinator | Persist tokens in Keychain, track local versus verified state, perform one silent refresh at a time, and update UI. | [AuthSession.swift](../../frontend/YoukiApp/AuthSession.swift), [ContentView.swift](../../frontend/YoukiApp/ContentView.swift) |
| Bun/Hono auth service | Verify Apple once at sign-in; issue, rotate, revoke, and validate Youki sessions; return authoritative account state. | [auth-service.ts](../../server/src/infrastructure/auth/auth-service.ts), [app.ts](../../server/src/app.ts) |
| SQLite + Drizzle | Store Apple subject, encrypted Apple refresh token, entitlement, session hashes, revocation, and activity timestamps. | [schema](../../server/src/infrastructure/auth/sqlite-schema.ts), [store](../../server/src/infrastructure/auth/sqlite-auth-store.ts), [migrations](../../server/drizzle/) |

1. **New install:** no valid local installation marker or session. Show sample forecast and the Apple button. After Apple authorization, the server verifies the token/code and returns a Youki session and Free/Pro account. Save the session and Apple `credential.user` in Keychain before presenting authenticated state.
2. **Relaunch:** load Keychain into `restoring`, show the cached account and existing sample forecast without a sign-in flash, and silently validate `/me`. If the access token is expired or near expiry, refresh first; then publish `authenticated` after `/me` succeeds.
3. **Normal API call:** attach access token. On one 401, single-flight refresh, save the new pair, and retry once. The server checks the hash and current account status on each protected request. 403 for a suspended/deleted account becomes `reauthRequired`/account unavailable, not a silently cached signed-in state.
4. **Offline launch:** keep tokens and cached account as `offlineRestored`, show an offline/stale indication, and retry when connectivity returns. Do not grant live forecasts or Pro features based only on the cached tier.
5. **Revocation or logout:** clear local credentials and cached account; revoke the server session when reachable. Account deletion additionally revokes Apple's token and cascades SQLite records. Apple's `.revoked` or `.notFound` credential state should remove the local session; a query failure should be treated as unknown/offline, not revocation. Treat `.transferred` as a distinct migration case. [Apple credential states](https://developer.apple.com/documentation/authenticationservices/asauthorizationappleidprovider/credentialstate)

### Session contract and persistence

- Keep the existing `{ accessToken, refreshToken, expiresIn, account }` response shape for compatibility. The client records `accessExpiresAt` from receipt time, with a 60-second early-refresh margin. Add an Apple user identifier and storage version to the Keychain record; never put the Apple password, Apple private key, or token-encryption key in the app bundle.
- Keep 15-minute access tokens. Change refresh expiry to **365 days after the most recent successful refresh** and continue rotating the refresh token on each refresh. No absolute session lifetime is needed for an active user. Keep token hashes and `revoked_at` server-side. Add `last_seen_at`/throttled `last_active_at` updates for real active-user counts; do not count a Keychain restore as a verified visit.
- Make refresh retry-safe: send a random `requestId` with `/auth/refresh`, persist it before the request, and allow the server to return the *same* encrypted rotation result for the same old refresh token and request ID for a short window (for example 60 seconds). Add a dedicated `SESSION_REPLAY_ENCRYPTION_KEY` runtime secret for this temporary ciphertext; never store the rotated raw token in SQLite. Purge replay records afterward. This closes the lost-response gap without allowing an old token to create a second session. Reuse the request ID after process restart until the new pair is safely written to Keychain.
- Replace Keychain delete-then-add with add-on-first-write and `SecItemUpdate` thereafter. Check OSStatus; if persistence fails, do not claim the session will survive restart. Retain the current `ThisDeviceOnly` accessibility or choose a more restrictive unlocked-only class after testing background needs. [Apple Keychain accessibility](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility)
- Keep a small installation marker in app-container storage. If it is absent at launch, remove any old Youki Keychain session before creating the marker. This handles iOS versions where Keychain data survives uninstall; Apple does not guarantee uninstall behavior as a stable contract. [Apple Developer Technical Support discussion](https://developer.apple.com/forums/thread/36442)
- The SQLite file is not globally encrypted by this plan. Keep its restrictive permissions, use encrypted off-machine backups, and provision `APPLE_PRIVATE_KEY` plus `APPLE_TOKEN_ENCRYPTION_KEY` as deployment secrets. Restore of an encrypted Apple refresh token requires preserving the encryption key separately from the database backup.

### Client state and failure semantics

Use one observable session state: `signedOut`, `restoring(cachedAccount)`, `authenticated(serverAccount)`, `offlineRestored(cachedAccount)`, and `reauthRequired(reason)`. Derive UI properties from this state rather than toggling `isAuthenticated` from Keychain existence. `/me` 200 establishes verified app state; a valid refresh followed by `/me` also does. A network/5xx failure preserves tokens and shows offline state. Invalid refresh, explicit logout, Apple revocation, or server account denial clears or blocks the session. A 429 keeps credentials and observes `Retry-After`.

The server cannot detect that an app was uninstalled, so uninstall can clear the *local* login on reinstall but cannot immediately revoke a server session. The idle expiry bounds that residual session. A lost device, server-side suspension, or account deletion can revoke earlier.

## Ordered implementation slices

| Order | Slice and files | Acceptance criteria |
| --- | --- | --- |
| 1 | Session policy and Drizzle migration: [schema](../../server/src/infrastructure/auth/sqlite-schema.ts), [store](../../server/src/infrastructure/auth/sqlite-auth-store.ts), [auth service](../../server/src/infrastructure/auth/auth-service.ts). | Active refreshes extend a 365-day idle window; expired/revoked/suspended sessions cannot refresh. Tests cover time boundaries and replay. Existing undeployed test sessions may be reset; if any real sessions exist, migrate only unexpired ones. |
| 2 | Retry-safe refresh: [HTTP routes](../../server/src/app.ts), store/schema, and tests. | A duplicate refresh with the same request ID returns the original result briefly; different request IDs or expired grace fail. No plaintext token is stored in SQLite; replay ciphertext expires and is pruned. |
| 3 | Client session coordinator: [AuthSession.swift](../../frontend/YoukiApp/AuthSession.swift), small Keychain/clock/network seams for tests. | Relaunch silently restores and verifies; access tokens refresh before expiry; parallel calls share one refresh; failed network does not erase credentials; Keychain write failure is surfaced. |
| 4 | Apple credential and uninstall handling: AuthSession, App entry point, and any new Swift file added to the [Xcode project](../../frontend/YoukiApp/YoukiApp.xcodeproj/project.pbxproj). | Store Apple `credential.user`; check credential state on launch/foreground; revoke/notFound signs out, unknown/offline does not. Reinstall starts signed out even if Keychain retained data. |
| 5 | UI and account behavior: [account sheet](../../frontend/YoukiApp/ForecastSheets.swift), [root view](../../frontend/YoukiApp/ContentView.swift), [forecast view model](../../frontend/YoukiApp/ServerViewModel.swift). | No sign-in flash on relaunch; signed-out sample remains; restoring/offline state is legible; suspended/expired accounts get one clear reauth path; Free/Pro reflects `/me`. |
| 6 | Revocation and release checks: server Apple notification route or documented provider configuration, auth tests, UI tests, operational docs. | Signed Apple account-change messages revoke local sessions; a real device passes sign-in, cold relaunch, idle refresh, logout, deletion, and Apple revocation checks. Do not treat a notification endpoint as implemented until its signature validation and delivery are exercised. |

## Decisions, risks, and rollout

- **Use Sign in with Apple only.** Adding a Youki password would create a new recovery, hashing, breach, and abuse surface without helping session persistence.
- **Keep a bounded, sliding refresh expiry.** This gives an Instagram-like experience for active users while limiting an abandoned or stolen token. A truly nonexpiring bearer token is rejected. Unexpected prompts remain possible after long inactivity or legitimate revocation.
- **Use the server as the verifier.** A cached account or Apple credential state alone does not authorize forecasts or prove a paid tier. `/me` and protected routes use the current SQLite account/session state.
- **Roll out locally first.** The current SQLite build cannot be deployed to App Platform without durable storage. Do not change the release URL or enforce this new policy in the hosted app until the Droplet cutover, backups, and real-device Apple test are complete. [Hosting boundary](../auth-implementation.md)
- **Protect sign-out semantics.** If offline, remove the active session from the UI immediately and keep the old refresh token only in a separate Keychain pending-revocation item. Retry server revocation when connectivity returns, then erase that item; show that remote revocation is pending. If the app is deleted before reconnecting, the server cannot know, so the idle timeout is the backstop.
- **Keep secrets external.** Verify CI and Droplet configuration inject Apple private/encryption keys securely; rotate keys with a migration plan. Do not log tokens, authorization codes, or Apple identity assertions.

## Verification plan

- Automated Bun/SQLite: Apple identity rejection, active/suspended lookup, 365-day sliding boundary, refresh replay/idempotency, logout, deletion cascade, and no authorization from a cached tier. Run `cd server && bun test && bun run typecheck && bun build src/index.ts --target bun --outdir /tmp/youki-server-build`.
- iOS tests with injected Keychain and HTTP transport: cold start with valid/expired tokens, parallel requests, lost refresh response, offline startup/reconnect, Keychain save error, Apple revoked/notFound/unknown/transferred states, logout, and reinstall marker. Build the `YoukiApp` simulator scheme and run UI checks for signed-out, restoring, and authenticated account sheets.
- Real-device integration: use a configured Apple Developer account and HTTPS test backend. Verify first login creates one SQLite user, relaunch does not show Apple UI, refresh and `/me` succeed, `/me` rejects revoked sessions, and sign-out/deletion clear client plus server state. Test a device restart and app reinstall separately.
- Operational: confirm SQLite backup/restore retains accounts and sessions, Apple encryption key is restored separately, and logs/metrics report refresh failures, invalid-session rates, Apple revocations, and active users without exposing token values.
- Current evidence: the prior local SQLite work passed 22 Bun tests and a readiness/auth smoke check. This document only audits source and proposes changes; none of the new persistent-session behavior is implemented or verified yet.

## Open questions

- Does “delete the app” mean only that reinstall should require sign-in, or should the server also remove account data? iOS cannot reliably notify the server at uninstall; this plan assumes the former. Use the explicit in-app **Delete account** action for data deletion.
- Choose the final inactivity window before release. This plan uses 365 days; changing it is a server policy choice, not an iOS UI change.
