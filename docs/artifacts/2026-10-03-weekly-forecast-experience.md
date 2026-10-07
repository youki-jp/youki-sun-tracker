# Sign-in entry and weekly forecast experience

Status: Implemented locally; not deployed
Updated: 2026-10-03

## Quick read

### What changed

Signed-out users now open a welcome/sign-in screen without a dismiss button. Forecasts show their date, passed events are dimmed, and a separate next-event line can show tomorrow's first light after sunset. Pro accounts have a real seven-day sunrise/sunset calendar; Free accounts have today/tomorrow and five locked outlook rows.

### Why it matters

Users can distinguish today's timeline, upcoming events, and longer-range estimates without accidentally mixing dates. Selecting a calendar day updates its sky, event scores, analysis, and times together.

### Current state

Implemented on `feat/weekly-forecast-experience`. Local Pro preview displayed seven real dated rows and a selected day-3 outlook. Backend type checking and bundling passed; Debug and Release simulator compilation passed. No test suites were added or run. Forecast accuracy remains dependent on existing provider data and the heuristic engine.

### Next step

Deploy the backend change before running this frontend against the Droplet; the current production backend does not yet have the weekly endpoint.

## Changed surface

| Area | Status | Details |
| --- | --- | --- |
| Entry and account dismissal | Implemented | [ContentView](../../frontend/YoukiApp/ContentView.swift), [AccountEntryView](../../frontend/YoukiApp/AccountEntryView.swift), [AccountManagementView](../../frontend/YoukiApp/AccountManagementView.swift) |
| Dated timeline and next event | Implemented | [ServerViewModel](../../frontend/YoukiApp/ServerViewModel.swift), [ForecastComponents](../../frontend/YoukiApp/ForecastComponents.swift) |
| Calendar and day selection | Implemented | [ForecastSheets](../../frontend/YoukiApp/ForecastSheets.swift), [timeline/weekly API models](../../frontend/YoukiApp/SkyDayTimelineAPI.swift), [ForecastMapper](../../frontend/YoukiApp/ForecastMapper.swift) |
| Weekly orchestration | Implemented | [ForecastWeekService](../../server/src/application/services/forecast-week-service.ts), [app routes](../../server/src/app.ts) |
| Server date authorization | Implemented | [ForecastAccess](../../server/src/application/services/forecast-access.ts), [prediction routes](../../server/src/http/routes/sky-color.ts), [timeline routes](../../server/src/http/routes/sky-day.ts) |
| Project handover | Updated | [Current state](../current-state.md), [project guide](../../CLAUDE.md), [README](../../README.md) |

## Engineer details

### Design and decisions

- Restore the existing session before choosing entry/forecast screens. Successful login opens the forecast; sign-out dismisses account/settings sheets and returns to sign-in. Development preview arguments retain their existing sample/fixture behavior.
- Keep all event rows on the displayed date. Dim passed events rather than moving individual rows to tomorrow. A separate next-event summary scans the available real milestones in chronological day order. Future dates omit the `Now` row.
- Show `Forecast` for today/tomorrow and `Outlook · Conditions may change` for offsets 2-6. The current engine's `confidence` is input completeness, so the UI calls it input coverage/data instead of a probability of accuracy. No arbitrary accuracy percentages or horizon penalties were invented.
- Preserve existing golden-hour alarm semantics (next upcoming event) and clarify the button as `Set next alarm` when browsing dates.
- Preserve the user's pre-existing changes to SkyGradient.swift and the Xcode project; no new Swift files or project edits were required.

### Contracts and flow

`POST /api/v1/sky-day/week` accepts nested `location`. Its response contains resolved location/timezone, timezone-local `today`, generation time, and exactly seven ordered rows. Each row includes `targetDateIso`, `forecastType`, `locked`, nullable `timeline`/`predictions`, and `errors`. Free rows 2-6 are locked with no forecast data. One existing forecast quota admission covers the bounded range. Sequential provider work reuses existing seven-day weather/solar/air-quality caches.

The existing single-date routes enforce the same limits through an authorization callback: Free offsets 0-1, Pro offsets 0-6. Dates are resolved in the requested location's timezone. Out-of-window dates return 400; Free requests beyond tomorrow return 403 `pro_required`.

The app validates ordered dates and response day/timezone/location matches, publishes calendar data independently of the selected presentation, and invalidates outstanding current-day requests on selection. Calendar state is cleared on location/account changes. Data refreshes after 30 minutes or a local-day change; failed automatic attempts have a five-minute backoff. Explicit refresh retries immediately. Failed calendar refreshes retain earlier rows with an explanation. The existing upstream weather and atmospheric cache remains 15 minutes.

### Delegated-agent outcomes

None; implementation was completed by the primary agent.

### Verification

| Check | Result | Evidence |
| --- | --- | --- |
| `bun run typecheck` | Passed | TypeScript compiled without diagnostics |
| `bun build src/index.ts --target bun --outdir /tmp/youki-weekly-server-build` | Passed | 57 bundled modules |
| Debug simulator build | Passed | `/tmp/youki-weekly-build.log`, `BUILD SUCCEEDED` |
| Release simulator build | Passed | `/tmp/youki-weekly-release.log`, `BUILD SUCCEEDED` |
| Manual layout review | Observed | Isolated iPhone 16 simulator and localhost backend, separate SQLite database. Welcome had no Done button; local login opened the forecast; after sunset the header showed tomorrow's first light; calendar displayed seven actual sunrise/sunset rows; selecting Oct 5 displayed that day's sky/time/score and Outlook label |
| Test suites | Not run | No tests requested; none added |

### Risks and limitations

- Detailed near-term forecasts are still estimates. The existing heuristic has no measured/calibrated accuracy; this work does not improve or validate its predictive skill.
- Atmospheric inputs can be missing later in the week. Existing input coverage decreases accordingly, and missing details are shown without substituting sample dates.
- Provider failures can leave individual days partially or fully unavailable. Partial errors are displayed; refresh offers a retry.
- The weekly endpoint is a larger bounded response than a single day. Cold requests can take longer; the client permits a 90-second request and displays loading state. Performance/load limits have not been measured.
- Payment remains a preview. Existing server-backed Pro test accounts provide access.

### Follow-ups

- Merge/deploy the new backend, then run the updated app with the Droplet BACKEND_URL.
- Future work: calibrate forecast skill against observed sunrise/sunset conditions rather than using data coverage as accuracy.

### Not implemented or unverified

- No production deployment of this change, new purchasing flow, weather model, or scientific accuracy calibration.
- No automated tests, Free lock UI walkthrough, midnight/DST runtime walkthrough, or physical-device layout review in this task.
