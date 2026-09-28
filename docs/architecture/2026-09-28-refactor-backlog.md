# Refactor and cleanup backlog

Status: Implemented (simulator UI inspection remains unverified)

Updated: 2026-09-28

Reviewed at: `13c9eea` (`develop`)

## Quick read

The app has working UI and clear domain boundaries, so this is a focused cleanup backlog rather than a rewrite. Fix forecast location and freshness state first: those paths can show data for the wrong place or keep an old score after a partial refresh. Then consolidate duplicated HTTP and provider parsing, and finally simplify the account view and preview-only settings. Each numbered task below is intended to be handed to one GPT-6 Luna agent with its own branch or worktree.

## Scope and assumptions

- Goal: preserve the current visual design and public API while reducing duplicated code, ambiguous state, and misleading controls.
- Non-goals: redesign the sky engine, add subscriptions, add saved locations, implement notifications, or change the forecast response contract.
- The existing 10 km location radius and 30-minute forecast freshness interval are product defaults for this pass. An agent should not change those numbers while refactoring.
- The branch was clean at review time. Recheck Git status before starting any task and preserve work added later.
- `docs/current-state.md` contains an older prototype snapshot. Source files and the newer auth documentation are the evidence for current behavior.

## Current flow and evidence

The SwiftUI root owns sheet, account, manual-coordinate, theme, and alarm state in [ContentView](../../frontend/YoukiApp/ContentView.swift#L4). [ServerViewModel](../../frontend/YoukiApp/ServerViewModel.swift#L9) obtains a one-shot device fix, calls the prediction and timeline endpoints, builds scenes, refreshes on a timer, and maps responses into `PrototypeDay`. The two clients independently build authenticated POST requests in [SkyColorAPI](../../frontend/YoukiApp/SkyColorAPI.swift#L94) and [SkyDayTimelineAPI](../../frontend/YoukiApp/SkyDayTimelineAPI.swift#L132). [AuthSession](../../frontend/YoukiApp/AuthSession.swift#L42) owns bearer-token refresh and Keychain persistence.

The backend validates forecast requests in two route files, then resolves timezone and obtains provider data in the [prediction](../../server/src/application/services/predict-sky-color-service.ts#L25) and [timeline](../../server/src/application/services/sky-day-timeline-service.ts#L29) services. [OpenMeteoClient](../../server/src/infrastructure/open-meteo/open-meteo-client.ts#L6) already caches exact upstream URLs and coalesces concurrent calls. The Swift sky generator is a deliberate port with a parity harness; its size alone is not a reason to rewrite it.

## Target ownership and invariants

| Component | Decision it owns | Contract to preserve |
| --- | --- | --- |
| iOS location coordinator | Whether a new fix reuses or replaces the displayed forecast | 10 km radius, manual-location choice, cancellation on sign-out |
| iOS forecast assembly | Whether sky and score are current for the same place and day | Partial success remains visible and labeled accurately |
| iOS HTTP transport | JSON request/response and server-error decoding | Existing paths, bodies, bearer auth, and user-facing errors |
| Backend HTTP boundary | Payload shape, numeric limits, and real date validity | Flat and nested endpoint compatibility; `ValidationError` responses |
| Open-Meteo adapters | Provider-specific local timestamp parsing | Never silently relabel UTC as local time; nullable fields stay nullable |
| SwiftUI screens | Presentation and navigation | Current theme, layout, and accessibility identifiers |

The target flow is: obtain a device fix when device location is selected, decide reuse against the displayed forecast's anchor, request both endpoint results when due, validate each result's place/day, then publish a scene and score with separate freshness. Existing Keychain sessions and server SQLite persistence are unaffected. Network cost should fall for same-area foreground visits; do not add polling or extra provider calls to achieve this. Backend validation failures remain client errors, and provider timestamp failures remain upstream errors.

## Handoff rules for Luna agents

1. Take one task ID. Read `AGENTS.md`, `CLAUDE.md`, `.codex/standards.md`, and the linked source before editing.
2. Keep changes inside the task's write scope. If a necessary change crosses another task's scope, stop that part and report the dependency.
3. Preserve existing accessibility identifiers, public HTTP request/response shapes, local-day behavior, and partial-success fallback unless the task explicitly changes them.
4. Report changed files, observed behavior, verification run, and anything still unverified. Do not claim a passing simulator or server check that was not run.

## Implementation queue

| ID | Priority | Outcome | Main write scope | Depends on |
| --- | --- | --- | --- | --- |
| L1 | High | Correct device-location reuse and request invalidation | `ServerViewModel.swift`, `LocationManager.swift`, focused model regressions | None |
| L2 | High | Make sky and score freshness explicit; share scene assembly | `ServerViewModel.swift`, focused model regressions | L1 |
| S1 | Medium | Share iOS forecast HTTP transport | `SkyColorAPI.swift`, `SkyDayTimelineAPI.swift`, one focused transport helper | None |
| B1 | Medium | Share backend request parsing and validate real calendar dates | `server/src/http/routes/`, focused route tests | None |
| B2 | Medium | Normalize Open-Meteo local timestamps in one place | `server/src/infrastructure/open-meteo/`, focused provider tests | None |
| U1 | Low | Separate account entry and management views without changing appearance | `AccountScreen.swift`, new focused Swift view files, Xcode project | None |
| U2 | Low | Make settings controls match implemented behavior | `ContentView.swift`, `ForecastSheets.swift`, UI checks | None |
| D1 | Low | Refresh the implementation snapshot and runnable checks | `docs/current-state.md`, `frontend/README.md`, `server/README.md` if present | After code tasks |

Implementation completed on 2026-09-28 and committed as `a088e52` on `chore/refactor-cleanup`; [PR #15](https://github.com/youki-jp/youki-sun-tracker/pull/15) is open. `frontend/README.md` already described the cache/freshness behavior and runnable checks accurately, so it did not need edits; `server/README.md` does not exist. The current-state snapshot was corrected and updated. See the [implementation summary](../artifacts/2026-09-28-refactor-cleanup.md) for source links and verification results.

### L1 - Device location and cache lifecycle

**Observed:** [loadForecast](../../frontend/YoukiApp/ServerViewModel.swift#L105) uses existing coordinates and calls `refreshIfNeeded` when a sky is loaded. [setForeground](../../frontend/YoukiApp/ServerViewModel.swift#L363) also only refreshes the existing coordinates. A user who travels while the app is backgrounded therefore gets a fresh forecast for the old coordinates until they explicitly choose device location again. [refreshIfNeeded](../../frontend/YoukiApp/ServerViewModel.swift#L368) updates the timeline but does not update `forecastCoordinates`, leaving the 10 km comparison anchored to the initial fetch. [showSample](../../frontend/YoukiApp/ServerViewModel.swift#L121) invalidates forecast requests but does not invalidate an in-flight location lookup. [LocationManager](../../frontend/YoukiApp/LocationManager.swift#L30) owns a concrete Core Location manager, which makes the device-fix path hard to exercise without a simulator.

**Implement:** Introduce an injectable location-fix seam. On an appropriate foreground/load path, acquire a new fix when device location is selected, then compare it with the coordinates associated with the displayed forecast. Keep the 10 km rule, the existing refresh interval, and manual-coordinate mode. Update the cache anchor when a refresh succeeds at new coordinates. Make logout/sample transitions invalidate pending location results and geocoding callbacks. Avoid duplicate simultaneous device lookups.

**Acceptance:** Same-area fixes reuse fresh sky/score without forecast HTTP calls; a move beyond 10 km fetches new coordinates; returning from background detects a move; a successful same-area refresh moves the anchor; a late location result cannot restore live data after sign-out. Use injected fixes and loaders for focused regressions. Keep a failed location lookup from erasing a valid displayed forecast.

### L2 - Forecast result assembly and freshness

**Observed:** Initial [fetch](../../frontend/YoukiApp/ServerViewModel.swift#L213) and [refreshIfNeeded](../../frontend/YoukiApp/ServerViewModel.swift#L368) each assemble scenes and filter predictions with separate logic. On refresh, a new timeline can be accepted while the score request fails; the old `predictions` and `hasLiveForecast` remain, `retrievedAt` advances, and `errorMessage` is cleared. The UI can then treat an older score as current.

**Implement:** Build one pure or narrowly scoped result-assembly path used by initial load and refresh. Track sky and score provenance/freshness separately, including response day and location. Preserve usable sky when the score fails, but mark the score unavailable or stale and show a concise partial-failure message. Preserve existing local-midnight and no-usable-milestone behavior.

**Acceptance:** For sky success/score failure, score success/sky failure, both success, and both failure, presentation flags and messages reflect the data actually shown. A refresh cannot attach a score for another local day or materially different location. Existing moment selection and stale-sky behavior remain intact. Add focused regressions at the view-model seam.

### S1 - iOS forecast HTTP transport

**Observed:** The [prediction client](../../frontend/YoukiApp/SkyColorAPI.swift#L94) and [timeline client](../../frontend/YoukiApp/SkyDayTimelineAPI.swift#L132) repeat JSON POST setup, authenticated send, HTTP status handling, and server-error decoding. They also define equivalent request-location structs.

**Implement:** Add one small transport helper for authenticated JSON POST and server-error decoding. Let each endpoint keep its own DTO, endpoint path, timeout if intentionally different, and success validation. Do not move request orchestration into a SwiftUI view.

**Acceptance:** Both clients still send the same JSON and bearer token. Their existing user-facing errors remain recognizable. Token refresh and 429 handling stay in `AuthSession`. A request/response fixture or injected URLSession seam covers success and server error. Add any new Swift source to `project.pbxproj`.

### B1 - Backend forecast input validation

**Observed:** [sky-color](../../server/src/http/routes/sky-color.ts#L31) and [sky-day](../../server/src/http/routes/sky-day.ts#L19) duplicate JSON parsing, numeric location validation, optional date parsing, and record checks. Their `targetDateIso` checks only the `YYYY-MM-DD` shape, so an impossible date passes the HTTP boundary and fails later. `isRecord` currently accepts arrays as objects.

**Implement:** Extract shared boundary helpers in `server/src/http/`. Validate calendar dates strictly, including leap years, and reject arrays where an object is required. Keep the flat `/estimate` and nested `/predictions` forms and the current field names. Return `ValidationError` for malformed inputs before provider work starts.

**Acceptance:** Both routes accept current valid payloads and reject non-finite/out-of-range coordinates, invalid or impossible dates, and array-shaped objects consistently. No public response DTO changes. Focused route tests cover the shared behavior.

### B2 - Provider timestamp normalization

**Observed:** The weather, air-quality, and solar adapters each contain a private `normalizeLocalIso` with the same implementation: append seconds or strip a trailing `Z` ([weather](../../server/src/infrastructure/open-meteo/open-meteo-weather-provider.ts#L71), [air quality](../../server/src/infrastructure/open-meteo/open-meteo-air-quality-provider.ts#L47), [solar](../../server/src/infrastructure/open-meteo/open-meteo-solar-provider.ts#L281)). Removing `Z` from a UTC timestamp would relabel it as local time without conversion.

**Implement:** Move normalization into one provider-local module. Accept the documented local timestamp shapes returned with an explicit Open-Meteo timezone. Reject malformed or offset-bearing timestamps as an external-provider error unless the agent can demonstrate and implement an actual timezone conversion. Keep nullable weather and air-quality values nullable.

**Acceptance:** All three adapters use the helper. Minute and second local strings normalize consistently; malformed and zone-bearing strings cannot silently change meaning. Provider fixtures cover the accepted shapes and a rejected `Z` case.

### U1 - Account view ownership

**Observed:** [AccountScreen](../../frontend/YoukiApp/AccountScreen.swift#L10) is about 560 lines and owns sign-up, sign-in, debug test accounts, signed-in management, deletion confirmation, and the visual cards. Button closures perform auth side effects alongside presentation state.

**Implement:** Keep `AccountScreen` as the mode and presentation coordinator. Extract signed-in management and entry/test-account visual sections into focused views. Keep auth actions in the coordinator or pass explicit action closures; avoid introducing a second source of auth truth. Preserve the current sunrise membership card, Free and Pro variants, and all accessibility identifiers.

**Acceptance:** No visual or navigation change in sign-up, sign-in, test login, Free management, or Pro management. Sign-out and deletion still reach their existing confirmation/error paths. The iOS simulator build passes; inspect at least one signed-in screen and one entry screen. Add new Swift files to the Xcode project.

### U2 - Preview-only settings semantics

**Observed:** The [Sunset alerts toggle](../../frontend/YoukiApp/ForecastSheets.swift#L164) binds only to an in-memory `@State` flag in [ContentView](../../frontend/YoukiApp/ContentView.swift#L11); no alert is scheduled. The [All settings row](../../frontend/YoukiApp/ForecastSheets.swift#L175) opens the locations sheet rather than a general settings page. These controls currently imply behavior the code does not provide.

**Implement:** Keep the current visual style while making those controls truthful. Replace the inert alert toggle with a noninteractive "Sunset alerts - Coming later" row. Rename "All settings" to "Locations" and make its subtitle describe the locations sheet it opens. Do not implement a notification service or a full settings redesign in this task.

**Acceptance:** Turning on a visible switch corresponds to real app behavior. Navigation labels match the screen they open. Current alarm and account controls still work; their accessibility identifiers remain stable where the control remains.

### D1 - Current-state documentation

**Observed:** [current-state.md](../current-state.md) was last written for the pre-auth prototype and contains older claims such as unconditional CORS, while [app.ts](../../server/src/app.ts#L14) enables CORS only when `CORS_ORIGINS` is configured. The snapshot also does not describe the newest account view and location cache behavior in one place.

**Implement:** Update the snapshot after the code tasks land. Label implemented, prototype, future, and unverified behavior separately. Link to canonical source and current auth docs. Keep run commands aligned with actual scripts and Xcode requirements.

**Acceptance:** A new contributor can tell which controls work, which are previews, how caching behaves, and how to build the server and simulator app without reading stale proposals. Do not claim Apple sign-in, AlarmKit on iOS 26, or production deployment has been verified unless new evidence exists.

## Ordering, risks, and alternatives

- Give L1 and L2 to the same agent sequentially, or wait for L1 to merge before assigning L2. They edit the same view model.
- S1, B1, B2, and U1 have mostly disjoint write scopes and can run in parallel worktrees. U2 overlaps `ContentView` and `ForecastSheets` but not U1.
- Keep the two forecast endpoints during this cleanup. The timeline summary contains scores but not every prediction detail the current UI uses; removing the prediction request would be a separate API/product change.
- Keep the sky gradient reference implementation and parity harness intact. Its length reflects the color model and interpolation contract, not obvious duplication.
- Account and entitlement changes are higher risk than view extraction. U1 should be a presentation refactor only; server auth semantics remain untouched.

## Verification plan

**Current evidence:** The audit was performed at commit `13c9eea`; implementation was completed in the current working tree on 2026-09-28. Backend focused tests, typecheck, and bundle build passed. The iOS simulator app build passed with the project entitlement path override and code signing disabled. Foundation regression cases were added but not run. CoreSimulator was unavailable, so no simulator screenshots were captured.

**Per-task checks:**

- iOS tasks: build the `YoukiApp` scheme for an iOS Simulator using the command in `CLAUDE.md`; run focused existing model/UI regressions when the task touches their behavior. For U1 and U2, inspect simulator screenshots in both light and dark themes where affected.
- Backend tasks: run `bun run typecheck` and focused `bun test` cases in `server/`; run the backend bundle command from `.codex/standards.md` when imports or module boundaries change.
- Before handoff: run `git diff --check` and report files changed and any checks blocked by the environment.

## Later decisions

- A persistent multi-location forecast cache, forecast storage across launches, seven-day orchestration, notifications, and payments are product work, not cleanup slices in this backlog.
- If the team wants to reduce forecast endpoint duplication, first decide what prediction detail should be added to the timeline response. Do not remove the prediction call based only on the timeline's current score summary.
