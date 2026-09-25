# iPhone live sky integration

Status: Implemented and displayed in iPhone simulator; UI automation follow-up remains
Updated: 2026-09-25

## Quick read

Complete the existing SwiftUI integration using the backend's whole-day timeline
and the HTML reference generator. Fix timestamp parsing and the Swift math port,
then drive the hero and color ramp from the same selected instant or solar milestone.
Keep the backend responsible for location-based atmospheric data and solar geometry.
Launch the finished app in an iPhone simulator against the Podman backend.

## Problem, scope, and assumptions

The user expects the iPhone sky to match the HTML preview for the same location,
day, and selected time. This request authorizes planning, delegated implementation,
and simulator verification together.

Goals:
- Load location-based predictions and a usable sky timeline on iPhone.
- Match the reference's nine stops, five ramp colors, glow, and cloud bands.
- Make first light, golden hour, sunrise, daylight, golden PM, and sunset select
  their real backend milestones, including nullable polar events.
- Default to a selectable Now moment sampled from the current instant in the
  timeline's timezone, refresh it every minute, and retain all six milestones.
- Show honest loading/live/partial/sample states and a retry path.
- Support Core Location and manual coordinates for reproducing HTML inputs.
- Prove color parity and display the live sky in the simulator.

Non-goals: new backend contracts, model recalibration, ML training, saved locations,
seven-day orchestration, subscriptions, deployment, and pixel-identical browser
rasterization. Simulator access uses localhost; a physical phone needs a reachable
backend URL (Mac LAN address or HTTPS deployment).

## Current-state evidence

Implemented:
- [Server timeline contract](../server/src/domain/sky-day.ts) returns local day,
  timezone, nullable milestones, independent solar/weather/air-quality grids.
- [iOS timeline client](../frontend/YoukiApp/SkyDayTimelineAPI.swift) and
  [prediction client](../frontend/YoukiApp/SkyColorAPI.swift) already exist.
- [Swift generator/sampler](../frontend/YoukiApp/SkyGradient.swift) is largely ported.
- [View model](../frontend/YoukiApp/ServerViewModel.swift) fetches both endpoints.

Defects found and fixed during implementation:
- `localMinutes` includes the colon in the hour substring (`Double("05:")`), so
  valid local timestamps cannot produce an appearance.
- Swift `bell` uses `max(high - low, 1)` whereas the HTML uses the nonzero span;
  the high-cloud interval is 0.45, changing pink intensity outside that interval.
- Timeline errors are swallowed; a fallback sky can be labelled live.
- [ContentView](../frontend/YoukiApp/ContentView.swift) samples now while the selected
  event defaults to sunrise; event clicks add preset tint overlays.
- [Components](../frontend/YoukiApp/ForecastComponents.swift) retain a ramp captured
  at fetch time and event times from prediction scoring windows.
- [Renderer](../frontend/YoukiApp/SkyBackgroundView.swift) uses ellipse clusters and
  a different glow palette than the HTML's single fractional bands and glow stops.

Reference: [gradient.html](https://github.com/youki-jp/youki-prototype/blob/main/gradient.html).
The adjacent local prototype checkout is older and lacks this file. The remote HTML
was retrieved on 2026-09-25 to `/tmp/youki-gradient-reference.html` for comparison.
No calibration constants should be invented or changed.

## Target flow and ownership

1. Core Location or validated manual coordinates supply the same location to both
   API requests. Altitude remains optional. No persistence is added.
2. The view model loads predictions and timeline, retaining independent success
   or failure states so a score failure does not suppress a valid sky.
3. The selected `SkyMoment` maps to the current instant (`Now`) or the HTML
   reference's milestone keys:
   first light = civil dawn; golden hour = golden-hour start; sunrise = sunrise;
   daylight = solar noon; golden PM = afternoon golden-hour start; sunset = sunset.
4. The sampler parses local wall-clock strings safely, brackets each grid, and
   interpolates numeric inputs. Missing atmospheric data remains a deliberate
   renderer fallback. Invalid timestamps do not masquerade as midnight.
5. The pure generator supplies one appearance to the hero and its five-color ramp.
   `Now` samples the current instant in the returned location timezone. Event
   selections use local milestone time, not the device timezone or now.
6. SwiftUI renders fixed stop positions and fractional cloud/glow geometry in both
   collapsed and expanded layouts. Remove preset event tinting of live output.

| Component | Responsibility | Contract |
| --- | --- | --- |
| API clients | Location/day requests and decoding | Existing POST endpoints unchanged |
| View model | Fetch state, source, selected event appearance, retries | No network calls in view bodies |
| Sampler/generator | Time interpolation and deterministic appearance | Nine stops; five ramp colors; nullable events |
| Content/components | Selection, status, synchronized colors and event labels | Existing visual hierarchy retained |
| Locations sheet | Device location or latitude/longitude input | Finite lat -90...90; lon -180...180 |

## State, failures, and operational concerns

- Initial loading may show a clearly labelled sample. Full success is live.
- Prediction-only success must identify the sky fallback; timeline-only success
  must keep the real sky and identify unavailable score details.
- Both failures show sample state and actionable retry/error information. Old data
  must not silently acquire a newly selected location or date label.
- Missing milestones display an unavailable time and cannot select a fabricated
  event. Default to `Now` when it falls within the returned local day, otherwise
  use a real available milestone.
- Current-time helpers must apply the returned timezone and refuse an unrelated
  local date. A selected event remains pinned while the user inspects it.
- Geocoding should not block the two API requests. Coordinates go only to the
  existing backend/provider path; no logging or persistence of location is added.
- Reuse fetched timeline data for interaction; no request on each tap or frame.
- Preserve `BACKEND_URL` configuration, iOS 17 support, and manual Xcode source
  membership. No broad transport-security exception is needed for Simulator.

## Implementation slices and delegation ledger

| Order / owner | Write scope | Outcome / acceptance | Depends on |
| --- | --- | --- | --- |
| 1 / parent | This plan | Evidence and contracts established | Complete |
| 2 / implementation agent | `frontend/YoukiApp/` and `frontend/README.md` | Parser/math fixed; real milestone selection; honest loading; coordinates; matching renderer; focused tests | Complete; manual live sky displayed |
| 3 / parent | `scripts/`, `docs/` | Independent HTML/Swift parity harness, build, API and simulator checks | Complete; UI suite still has two failed assertions |
| 4 / parent | `docs/artifacts/` | Final review, screenshot observation, results and limitations | Complete |

The implementation agent owns all app source edits, including any Xcode project
membership changes and UI tests. Parent prepares independent verification and
simulator services without editing the agent's files concurrently.

## Decisions and alternatives

Retain the existing local Swift generator (Option A). A server gradient endpoint
would duplicate the established timeline contract and require additional requests
for every event; a WebView would not integrate with native components. A single
`estimatedHex` cannot reproduce the HTML's spatial gradient. Manual coordinates
provide the same input seam as the HTML while Core Location remains the default.

## Verification plan

- Regression: valid HH:mm/HH:mm:ss sampling, distinct sunrise/noon/sunset,
  interpolation, timezone/date handling, missing values/milestones, out-of-range
  coordinate rejection, and partial API failure behavior where practical.
- Exact generator parity: use identical atmospheric inputs in the retrieved HTML
  and compiled Swift, compare all nine hex/position pairs, ramp and geometry.
  Cover clear, cloudy, rainy, hazy, and high-cloud values outside the bell interval.
- Integration parity: feed the same live timeline to both implementations and
  compare at the same minute (HTML intentionally works at minute resolution).
- Build: Xcode `YoukiApp` simulator target; meaningful UI interaction checks.
- Live API: health, predictions, and day timeline via the running Podman backend.
- Visual: install, launch, and inspect the iPhone simulator at a named Tokyo or
  Yokohama coordinate; select sunrise/daylight/sunset, compare colors, inspect
  expanded layout, capture evidence, and leave the app visible.
- Hygiene: `git diff --check`, review assigned scope, no build output in Git.

Verification completed: model regressions passed, 38 reference/live parity
comparisons matched exactly, the Podman backend health and live timeline passed,
and the app launched with live Tokyo data in iPhone 16 Pro simulator. After the
current-time correction, the device clock and selected Now time both showed
11:59, with six solar milestones still visible. The UI
suite compiled but two UI assertions still fail; details and exact report path
are recorded in [the work summary](artifacts/2026-09-25-ios-live-sky-integration.md).

## Risks and follow-ups

The rendering remains a heuristic visual prediction with known partly-cloudy and
night calibration gaps. Browser and SwiftUI blur/compositing can differ despite
identical numeric colors. Physical-device networking and production deployment
are unverified. Existing score calibration and full seven-day forecast stay future
work. Rollback is the focused branch diff; no migration or persistent state change.
