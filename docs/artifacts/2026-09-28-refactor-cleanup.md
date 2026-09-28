# Refactor cleanup implementation

Status: Implemented (simulator UI inspection remains unverified)
Updated: 2026-09-28

## Quick read

Visual summary: [Open the HTML report](2026-09-28-refactor-cleanup.html).

### What changed

Implemented the location/freshness, HTTP transport, backend validation/timestamp, account view, and settings cleanup items from the [refactor backlog](../architecture/2026-09-28-refactor-backlog.md). Updated the current-state snapshot to match the code.

### Why it matters

Same-area foreground visits can reuse current forecasts, while changed locations and stale data trigger the existing forecast flow. Partial refreshes no longer present an old score as current, and backend input/provider parsing is less duplicated and more strict.

### Current state

Implemented and committed as `a088e52` on `chore/refactor-cleanup`; [PR #15](https://github.com/youki-jp/youki-sun-tracker/pull/15) is open. Backend checks and the iOS simulator-target build passed. No simulator UI screenshot was captured because CoreSimulator services were unavailable.

### Next step

Review the diff and run the app in Simulator when CoreSimulator is available.

## Changed surface

| Area | Status | Details |
| --- | --- | --- |
| iOS forecast state | Implemented | [ServerViewModel](../../frontend/YoukiApp/ServerViewModel.swift), [LocationManager](../../frontend/YoukiApp/LocationManager.swift), [model regressions](../../frontend/YoukiApp/Tests/ModelRegression.swift) |
| iOS API transport | Implemented | [SkyColorAPI](../../frontend/YoukiApp/SkyColorAPI.swift), [SkyDayTimelineAPI](../../frontend/YoukiApp/SkyDayTimelineAPI.swift) |
| Account and settings UI | Implemented | [AccountScreen](../../frontend/YoukiApp/AccountScreen.swift), [entry view](../../frontend/YoukiApp/AccountEntryView.swift), [management view](../../frontend/YoukiApp/AccountManagementView.swift), [ForecastSheets](../../frontend/YoukiApp/ForecastSheets.swift) |
| Backend request validation | Implemented | [shared validation](../../server/src/http/routes/request-validation.ts), [validation regressions](../../server/src/http/routes/request-validation.test.ts) |
| Provider timestamp normalization | Implemented | [local timestamp helper](../../server/src/infrastructure/open-meteo/local-timestamp.ts), [timestamp regressions](../../server/src/infrastructure/open-meteo/local-timestamp.test.ts) |
| Implementation snapshot | Implemented | [current state](../current-state.md), [backlog](../architecture/2026-09-28-refactor-backlog.md) |

## Engineer details

### Design and decisions

- The location reuse radius remains 10 km and the freshness interval remains 30 minutes. A successful refresh updates the coordinates used as the cache anchor.
- Sky and score results retain independent freshness. Forecast scores are matched to the displayed local day and location before presentation.
- Both forecast API clients use one authenticated JSON POST transport while retaining endpoint-specific request and response DTOs.
- Backend routes share parsing and validation. Calendar dates are checked as real dates, and arrays are not accepted as request objects.
- Open-Meteo wall-clock timestamps are normalized without stripping timezone markers or relabeling UTC values as local time.
- Account extraction preserves the existing views and actions. Sunset alerts now say “Coming later”; the existing Locations action is labeled accurately.

### Contracts and flow

The public forecast paths and request/response shapes are unchanged. In device-location mode the app gets a new fix on load and foreground return, compares it to the last successful forecast anchor, and uses cached results inside 10 km until the normal freshness/day refresh is due. Manual coordinates remain selected until device location is explicitly chosen.

### Delegated-agent outcomes

| Agent | Scope | Changed files | Verification | Assumptions or blockers |
| --- | --- | --- | --- | --- |
| Forecast state | L1/L2 | `ServerViewModel.swift`, `LocationManager.swift`, `ModelRegression.swift` | iOS build passed; regression cases added but not run | CoreSimulator unavailable for screenshots |
| iOS cleanup | S1/U1/U2 | `SkyColorAPI.swift`, `SkyDayTimelineAPI.swift`, account views, settings, Xcode project | iOS build passed; diff check passed | Simulator launch and screenshots unavailable |
| Backend cleanup | B1/B2 | route validators, Open-Meteo adapters, focused regression files | 13 focused cases, typecheck, bundle build, and diff check passed | None reported |

### Verification

| Check | Result | Evidence |
| --- | --- | --- |
| `cd server && bun run typecheck` | Passed | TypeScript completed with no errors |
| `cd server && bun build src/index.ts --target bun --outdir /tmp/youki-server-build` | Passed | Bun bundled 54 modules |
| iOS `xcodebuild` for generic iOS Simulator, with `CODE_SIGN_ENTITLEMENTS=YoukiApp.entitlements CODE_SIGNING_ALLOWED=NO` | Passed | `** BUILD SUCCEEDED **`; Xcode logged unavailable CoreSimulator service warnings |
| Backend focused regressions | Passed | Agent reported 13 cases/assertions passing |
| Swift `ModelRegression` executable | Not run | Regression cases were added; build verification was used, but no Swift regression executable was run |
| Simulator visual inspection | Not run | CoreSimulator services could not be reached |
| `git diff --check` | Passed | Clean during implementation handoff; rerun before commit |

### Risks and limitations

- The iOS app compiled for the simulator SDK, but runtime layout and sign-in flows were not visually inspected in Simulator.
- The current location cache is in-memory for the loaded forecast; persistent forecasts across launches remain out of scope.

### Follow-ups

- Inspect signed-in and account-entry screens in light and dark Simulator themes when CoreSimulator is available.
- Run the newly extended `ModelRegression.swift` executable in the normal macOS development environment.

### Not implemented or unverified

- No forecast persistence across launches, multi-location cache, new notification system, subscription flow, or seven-day client orchestration was added.
- Live Apple sign-in and production deployment remain unverified as documented in [auth implementation](../auth-implementation.md).
