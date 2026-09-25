# iPhone live sky integration

Status: Live sky and fixed main-screen layout implemented; simulator UI suite needs follow-up
Updated: 2026-09-25

## Quick read

### What changed

Connected the iPhone forecast screen to the live day timeline and made its native
sky gradient use the same numeric colors, cloud bands, and glow as the HTML
reference. Users can load their device location or enter coordinates, start on
the live current-time sky, then choose one of six real solar milestones. The
main screen now fits without vertical scrolling, and the footer sun mark is also
used as the app icon. The timeline rows expand into the available panel height so
there is no large empty gap above the footer. While location or backend data is
loading, a theme-matched skeleton replaces sample forecast values; failures show
an explicit retry state instead of fabricated data.

### Why it matters

The screen now renders the sky for the current instant by default (with a local
clock that advances each minute), or a selected local milestone; the hero and
color ramp follow that sky sample. Live and partial-data states
remain visible when either API is unavailable.

### Current state

The iPhone 16 Pro simulator was used to inspect the themed loading skeleton and
has now returned to its normal live-backend launch. The latest normal iPhone 16 Pro run showed the current time and Now row together, with all
seven moments, score, ramp, sky, and footer visible without scrolling. Model
regression and HTML parity checks pass. Timeline rows now use the space down to
the footer rather than stopping at a fixed maximum height. The loading skeleton
was inspected in the simulator's UI-audit mode, then the app was restored to the
live backend. The full UI test suite still has simulator
interaction assertions to resolve; manual inspection confirmed current time and
sky selection, but did not retest changing to each milestone.

### Next step

Resolve the remaining simulator UI assertions and rerun the UI suite.

## Changed surface

| Area | Status | Details |
| --- | --- | --- |
| Design | Proposed/implemented | [Integration plan](../ios-live-sky-integration-plan.md) |
| iOS integration | Implemented | [ServerViewModel.swift](../../frontend/YoukiApp/ServerViewModel.swift), [SkyGradient.swift](../../frontend/YoukiApp/SkyGradient.swift), [SkyBackgroundView.swift](../../frontend/YoukiApp/SkyBackgroundView.swift), [ContentView.swift](../../frontend/YoukiApp/ContentView.swift) |
| Coordinates and forecast display | Implemented | [ForecastSheets.swift](../../frontend/YoukiApp/ForecastSheets.swift), [ForecastMapper.swift](../../frontend/YoukiApp/ForecastMapper.swift) |
| Branding and fixed main layout | Implemented | [AppIcon.appiconset](../../frontend/YoukiApp/Assets.xcassets/AppIcon.appiconset/Contents.json), [YoukiSun.imageset](../../frontend/YoukiApp/Assets.xcassets/YoukiSun.imageset/Contents.json), [ContentView.swift](../../frontend/YoukiApp/ContentView.swift), [ForecastComponents.swift](../../frontend/YoukiApp/ForecastComponents.swift) |
| Loading and failure states | Implemented | [ServerViewModel.swift](../../frontend/YoukiApp/ServerViewModel.swift), [ForecastComponents.swift](../../frontend/YoukiApp/ForecastComponents.swift), [ModelRegression.swift](../../frontend/YoukiApp/Tests/ModelRegression.swift) |
| Reference parity harness | Implemented | [verify-sky-parity.mjs](../../scripts/verify-sky-parity.mjs), [sky-parity-main.swift](../../scripts/sky-parity-main.swift) |
| Run instructions and regressions | Implemented | [iOS README](../../frontend/README.md), [ModelRegression.swift](../../frontend/YoukiApp/Tests/ModelRegression.swift), [YoukiAppUITests.swift](../../frontend/YoukiApp/YoukiAppUITests/YoukiAppUITests.swift) |

## Engineer details

### Design and decisions

- Kept the established day-timeline API and local Swift renderer (Option A).
- Matched the reference's timestamp precision, weather-grid interpolation,
  null-value defaults, bell curve, fixed nine stops, five-color ramp, cloud-band
  geometry, and glow geometry.
- Preserved separate success states for the score and timeline APIs and prevented
  older location requests from replacing newer selections.
- Device location remains the normal path. Manual coordinates provide a direct
  equivalent to the HTML preview input and are not saved.

### Contracts and flow

The app sends the same validated coordinates to
`POST /api/v1/sky-color/predictions` and `POST /api/v1/sky-day/timeline`.
The default Now selection samples the current instant in the timeline timezone;
solar-milestone selections sample their respective timeline times. The resulting
appearance drives the hero and ramp, while the prediction API supplies score and
explanation. See the [plan](../ios-live-sky-integration-plan.md) and canonical
[timeline contract](../../server/src/domain/sky-day.ts).

### Delegated-agent outcomes

| Agent | Scope | Changed files | Verification | Assumptions or blockers |
| --- | --- | --- | --- | --- |
| First implementation worker | iOS app, model regressions, run instructions | SwiftUI/API client sources, UI tests, model regression runner, frontend README | Model runner and its simulator build checks passed; parent reran model runner and parity harness | Browser and SwiftUI blur rasterization can differ |
| Luna follow-up workers | UI test fixes | `YoukiAppUITests.swift`, `frontend/README.md` | `git diff --check` passed; final parent simulator rerun still failed two UI assertions | See verification and follow-ups |

### Verification

| Check | Result | Evidence |
| --- | --- | --- |
| `git diff --check` | Passed | Clean whitespace check after final edits |
| Model regression runner | Passed | Covers timestamp parsing, grid interpolation/defaults, timezone/day boundaries, coordinate bounds, polar milestones, event selection, partial API failures, and stale requests |
| Loading-state model regression | Passed | Fresh models begin loading without forecast fixtures; stale concurrent requests keep the data empty; partial API success remains explicit |
| `bun scripts/verify-sky-parity.mjs /tmp/youki-gradient-reference.html` | Passed | 19 exact appearance comparisons against the HTML fixture |
| Same harness with live Tokyo timeline | Passed | 19 more exact comparisons; all nine stops, ramp colors, glow, and cloud geometry matched |
| Backend health and Tokyo timeline | Passed | Health `ok`; response contained 116 solar and 24 hourly weather and air-quality samples |
| Xcode simulator build | Passed | App and UI test targets compiled for iPhone 16 Pro, iOS 18.6 |
| Updated iOS app build | Passed | `xcodebuild` generic iOS Simulator build completed successfully with the new icon asset and fixed layout |
| Fixed-layout simulator check | Passed | iPhone 16 Pro screen showed Now, all six solar moments, forecast score, color ramp, live sky, and footer simultaneously; no main-screen scroll view remains |
| Footer-gap follow-up | Passed | Timeline-row maximum removed and panel now extends to the footer overlay; rebuilt screenshot showed rows evenly filling the formerly empty area |
| Footer seam finish | Passed | Main screen retains its top rounding but uses square lower corners where it meets the footer; expanded sky remains unclipped |
| Loading skeleton visual check | Passed | Built-in `-uiAudit` mode showed themed score/time/ramp/seven-row skeletons and “Finding location” status without sample forecast values; normal launch then loaded live Tokyo data |
| App icon assets | Passed | Asset-catalog JSON valid; icon and reusable sun mark are 1024×1024 PNGs |
| UI test suite | Failed | `testMainControlsAndSheets` hit an AX scroll-to-visible failure on the off-screen full-screen control. `testManualCoordinatesAndLiveEventSelection` failed its daylight selected-time assertion after the tap. See `/tmp/youki-live-sky-uitests-final.xcresult`. |
| Manual simulator launch | Passed | iPhone 16 Pro displayed live Tokyo coordinates, “Live sky and forecast”, sunrise score 67, and the generated sky/ramp |

The downloaded reference used for parity is `/tmp/youki-gradient-reference.html`
(SHA-256 `87a50e9b4a921df7f22c718eb72195794bb1535cb098a3b2277acfcaf12081ec`).
The live timeline is a temporary file at `/tmp/youki-live-tokyo-timeline.json`.

### Risks and limitations

- Numeric generator parity is exact at the HTML's whole-minute resolution; native
  and browser blur/compositing can still render differently.
- The forecast remains heuristic and the app loads one day at a time.
- The live demo uses simulator-local networking. A physical iPhone needs a
  reachable LAN backend or HTTPS URL.

### Follow-ups

- Resolve the two UI test failures against a live run, then rerun
  `YoukiAppUITests` on iPhone 16 Pro.
- Verify a physical-device URL separately if that is part of the release target.

### Not implemented or unverified

- Automated UI verification of a successful event change remains unverified;
  the manual screenshot confirmed the app displays live sky data at sunrise.
- The app icon was validated in the asset catalog/build but its appearance on the
  simulator Home Screen was not separately inspected.
- Pixel-identical native/browser blur, physical-device networking, and production
  deployment were not verified.
