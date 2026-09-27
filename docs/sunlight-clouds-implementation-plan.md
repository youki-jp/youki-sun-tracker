# Sunlight and clouds: implementation handoff

Status: Implemented with verification notes below

Updated: 2026-09-25

Design authority: [Sunlight and clouds design](sunlight-clouds-design.md). Delivery evidence: [2026-09-25 implementation report](artifacts/2026-09-25-sunlight-clouds.md).

## Quick read

An additive Swift scene now composes over the existing gradient. The weather contract includes nullable instantaneous radiation; the client samples cloud/radiation inputs, derives lighting/cloud descriptors, renders native layers, and handles same-day freshness. Existing gradient outputs and scoring remain unchanged. The implementation steps below are retained as a design record; verification results and outstanding limits are recorded at the end and in the dated report.

Repository standards were read before implementation. File names in the ordered work now refer to implemented files unless noted otherwise.

## Ordered work

### 1. Establish baseline and deterministic scenarios

Dependencies: none. First inspect [ModelRegression.swift](../frontend/YoukiApp/Tests/ModelRegression.swift) and [SkyBackgroundView.swift](../frontend/YoukiApp/SkyBackgroundView.swift).

1. Record Git status and run existing backend/model checks before editing. Record the current UI-test baseline; the [prior integration artifact](artifacts/2026-09-25-ios-live-sky-integration.md) reports two UI failures.
2. Capture the current sky at the same input for sunrise, noon, sunset, and expanded mode. Keep the underlying palette as the comparison baseline.
3. Add proposed `frontend/YoukiApp/Tests/Fixtures/sky-scenes.json` containing small synthetic timeline responses and expected qualitative outcomes. Use fixed dates/timezones and explicitly mark fixtures synthetic. Include an old-server response without radiation and an enriched response.
4. Add a debug-only fixture selection seam using existing loader injection. UI/snapshot tests must not depend on the day's real weather. Keep live API smoke verification separate.
5. Use actual apparent-elevation conventions in new fixtures. The existing model fixture's -0.833 sunrise value is not the production day-event threshold; do not copy it into new sun-limb expectations.

Acceptance: the baseline is recorded, every scenario in the matrix below is reproducible, and the production app still uses normal loaders by default. Do not embed fixture data into release behavior.

### 2. Add radiation to the provider and DTO contracts

Dependencies: step 1.

Write surfaces: [weather domain](../server/src/domain/weather.ts), [provider types](../server/src/infrastructure/open-meteo/open-meteo-types.ts), [weather provider](../server/src/infrastructure/open-meteo/open-meteo-weather-provider.ts), [Swift timeline DTO](../frontend/YoukiApp/SkyDayTimelineAPI.swift). Proposed provider tests: `server/src/infrastructure/open-meteo/open-meteo-weather-provider.test.ts`.

1. Add optional `solarRadiation` with `sampling: "instant"`, nullable `directNormalWm2`, `globalHorizontalWm2`, and `diffuseHorizontalWm2` as specified in the design.
2. Append the three exact `_instant` variables to the existing hourly request. Keep coordinates, timezone, date filtering, and existing weather fields unchanged.
3. Decode `hourly_units` and normalize new fields individually. Missing arrays, short arrays, nulls, negative/non-finite values, and wrong units become null. Zero must survive.
4. Keep a successful weather response usable if radiation is absent. An HTTP failure still follows the existing external-service error path; do not add speculative retries for arbitrary errors. If live checks show the enriched request is rejected, correct or disable the added query fields before rollout rather than shipping a new dependency that breaks base weather.
5. Give Swift decoding/source initializers a compatibility path for old JSON and existing fixtures. Unknown sampling values disable radiation only.
6. Confirm the timeline service naturally carries the extended weather samples. Do not add a route or alter the scoring engine. Check prediction `includeFeatures` compatibility as well.
7. Smoke-check real response fields/units for Tokyo and another region; record null coverage and latency without retaining precise user coordinates in logs.

Acceptance: old and new payloads decode; missing radiation does not fail the timeline; zeros and timestamps survive normalization; enriched weather yields identical semantic scores for the same existing input values. No new API credential is required in the iOS app.

### 3. Implement the nullable scene sampler

Dependencies: step 2.

Write surfaces: new `frontend/YoukiApp/SkyScene.swift`, `SkySceneSampler.swift`; existing [SkyGradient.swift](../frontend/YoukiApp/SkyGradient.swift) only if extracting shared parsing without changing legacy behavior; [Xcode project](../frontend/YoukiApp/YoukiApp.xcodeproj/project.pbxproj).

1. Define the Foundation-only observation, quality, provenance, sun/cloud descriptors, and `SkyScene` contracts from the design. Preserve `SkyAppearance` and its generator as the base contract.
2. Compose the existing timeline sampler with nullable scene sampling at one selected minute. Implement exact-row, two-valid-bracket, one-sided hold, gap, date-edge, and missing-field rules. Do not reuse zero-filled gradient inputs as measurements.
3. Reject invalid solar values; flag missing radiation independently from missing cloud cover. Return a usable base fallback when enhanced observation cannot be derived.
4. Detect ambiguous/transition dates for the documented legacy-only DST fallback. Test the same-day/other-day boundary. Do not attempt a UTC wire migration in this slice.
5. Generate stable scene identity from coarse location cell + target date, and stable cloud IDs from layer/slot. Keep exact coordinates in memory only as already required by the app.
6. Add all new model files to manual Xcode source membership. Update the standalone model compilation command to include them.

Acceptance: tests distinguish missing from zero, hold at most 60 minutes, reject gaps above 90 minutes, preserve selected timezone/date, and produce identical observations for repeated requests. Legacy nine stops/ramp/glow/bands remain numerically unchanged for baseline fixtures.

### 4. Implement the pure scene generator

Dependencies: step 3.

Write surfaces: new `frontend/YoukiApp/SkySceneGenerator.swift`; scene model/style constants; proposed `frontend/YoukiApp/Tests/SkySceneRegression.swift` as a standalone runner, or extend the existing regression runner with the same coverage.

1. Compute sun emergence from apparent elevation and the existing -0.267-degree horizon convention. Keep direct light gated by solar geometry.
2. Map DNI to direct strength; use the cloud-only estimate only for unavailable DNI. Derive valid diffuse share using matching horizontal quantities.
3. Apply conservative fog/low-overcast limits; preserve partial-data quality and contradictions. Avoid double-applying cloud attenuation already used by the gradient/radiation.
4. Derive independent twilight glow, cloud-layer densities/tints, and optional visibility veil. Make all transitions continuous and outputs finite/bounded.
5. Use generic clouds when only total cover is present. Missing data must not silently produce an unqualified clear scene.
6. Keep the style constants centrally named and mark them artistic. Tests should validate behavioral relationships and safety invariants, not simply restate every numeric coefficient.

Acceptance: all scene invariants and scenario expectations below pass. Increasing low cloud/fog under otherwise identical input cannot strengthen the visible disc. Valid zero DNI suppresses direct light. A below-horizon solar sample wins over contradictory positive radiation. Old-server responses still yield a cloud-estimated scene.

### 5. Render the layers

Dependencies: step 4.

Write surfaces: [SkyBackgroundView.swift](../frontend/YoukiApp/SkyBackgroundView.swift), new `SkySunLayer.swift` / `SkyCloudLayer.swift`, and manual [Xcode membership](../frontend/YoukiApp/YoukiApp.xcodeproj/project.pbxproj).

1. Add an internal enhanced/legacy rendering switch, defaulting to legacy while this slice is incomplete. It is a release/debug seam, not a user preference or remote-config dependency.
2. Draw the existing stops, broad ambient/twilight glow, sun halo/disc, clouds in high-to-low order, then the veil. Keep the legacy renderer available for comparison/rollback. Never draw legacy cloud bands/glow under the enhanced equivalents.
3. Build a limited set of seeded cloud paths or masks with reusable slots. Use coverage for continuous density/opacity; keep layout stable across updates and view sizes.
4. Use the same geometry to occlude the sun and draw the cloud. Do not draw a halo over all cloud layers. Avoid a second global gray overlay that destroys palette saturation.
5. Apply normalized scene geometry to both contained and expanded layouts. Preserve safe areas, clipping, existing controls and themed text contrast.
6. Add accessibility handling for Reduce Motion and reduced transparency/contrast needs. Decorative paths should not become individual VoiceOver elements.

Acceptance: side-by-side fixtures are recognizably different, clouds occlude rather than sit behind the sun, twilight can exist without a disc, no solar light is visible at night, and the gradient/ramp remain the baseline values. Inspect compact/expanded screens and both themes. No runtime asset/network calls occur in views.

### 6. Connect selected state, fallback, and freshness

Dependencies: step 5.

Write surfaces: [ServerViewModel.swift](../frontend/YoukiApp/ServerViewModel.swift), [ContentView.swift](../frontend/YoukiApp/ContentView.swift), status presentation in [ForecastComponents.swift](../frontend/YoukiApp/ForecastComponents.swift), attribution where appropriate in the forecast presentation, plus model regressions.

1. Publish a scene and derive existing ramp/presentation from `scene.base`. Replace or consolidate the private appearance cache with scenes so only one selected timestamp drives the view.
2. Sample Now on the existing minute tick. Cache named moments, rebuilding them only for new timeline data. Repeated taps reuse data.
3. Preserve independent score/timeline successes. Keep lighting quality separate from score confidence and from the existing whole-day atmospheric-fallback flag. Use concise status such as "Forecast sky", "Limited weather data", or "Forecast may be outdated" when applicable; no numeric probability of sun visibility.
4. Preserve request IDs for location changes. Add a same-location refresh path that retains the old scene and selected event until a valid replacement arrives; do not reuse `beginRequest` if it clears every visible value.
5. Add an injected clock/retrieval timestamp for deterministic freshness tests. Refresh after 30 minutes on foreground activation or minute tick, at local-day rollover, or manual retry. Coalesce calls and impose the five-minute failed-refresh cooldown. Do not poll in background.
6. Keep a pinned milestone if still present after same-day refresh; otherwise use the documented valid fallback. On a changed target day, replace data atomically and rebuild both scene and time labels.
7. Add source attribution with a link and short indication that the scene is derived. The link is placed in the Locations sheet so it stays available without adding text over the sky.

Acceptance: newest location wins; score failure leaves a usable scene; a fresh clock with stale weather does not gain a fresh-data label; failed refresh retains only correctly identified same-day data; midnight never renders yesterday as Now. Tapping moments and rendering frames issue no requests.

### 7. Calibrate, verify, and roll out

Dependencies: steps 1-6.

1. Run the checks below and record the exact commands, tool versions, results, fixture set, and screenshots. Rebaseline the known UI failures rather than claiming a clean suite from historical reports.
2. Review fixture screenshots before tuning live conditions. Tune the style configuration, then rerun affected behavior tests and visual comparisons.
3. Profile the oldest supported available iPhone/Simulator class in compact and expanded mode. Measure generation time and scrolling/transition responsiveness; record device and limitations. Do not infer physical-device battery performance from a simulator.
4. Enable enhanced rendering by default after the matrix passes. Old backend versions must remain usable. Server can ship first because its response is additive; client can ship first using the cloud fallback.
5. Update [current-state.md](current-state.md), [frontend README](../frontend/README.md), and a dated work-summary artifact with actual implemented behavior/results. Preserve this document as the proposal or annotate decisions that changed.

Acceptance: new feature is reviewable with deterministic evidence; compatibility and model tests pass; app builds; relevant UI assertions pass or have a clearly recorded unrelated baseline failure with manual evidence for this feature. Runtime coverage gaps and unavailable device tests remain explicitly unverified. Rollback is switching to legacy rendering and, if needed, disabling the added provider variables; no data migration is involved.

## Required scenario matrix

Use realistic internally consistent values except explicitly contradictory fixtures. Numeric values here are test inputs, not requirements for classifying real weather.

| Scenario | Key inputs | Observable expectation |
| --- | --- | --- |
| Clear midday | Elevation 55; cloud 0-5%; DNI 700; GHI 700; DHI 100 | Defined sun, restrained halo, mostly open gradient |
| Thin high cloud | Elevation 30; high 70%, low 0%; DNI 350 | Wispy translucent layer; softer sun remains possible |
| Broken cloud | Elevation 25; total 50%; low 30%; DNI 300 | Separated clouds/gaps; stable layout; partial occlusion |
| Low overcast | Elevation 25; low/total 100%; DNI 0; GHI/DHI 120 | Continuous low deck, no sharp disc, diffuse light |
| Fog-like visibility | Elevation 15; visibility 150 m | Low contrast and no crisp bright disc; no unsupported claim of exact fog type |
| Clear dawn before sunrise | Elevation -3; DNI 0 | Warm horizon permitted; no disc |
| Limb emergence | Elevation -0.3, -0.267, 0, +0.267 | Hidden, threshold, half-revealed, then fully revealed disc when illumination is supported |
| Sunset high clouds | Elevation +1 through -4 | Warm subtle cloud tint, smoothly disappearing sun, retained twilight glow |
| Night | Elevation -20, even with erroneous DNI 700 | No sun, direct halo, twilight glow, or daylight cloud highlights |
| Polar day/night | Null sunrise/sunset milestones; valid elevation samples | Geometry controls scene; no fabricated event times |
| Cloud-only server | No radiation object | Valid cloud-estimated scene, same legacy gradient |
| Valid zero radiation | DNI 0; otherwise clear midday | Direct light suppressed; no missing-data fallback |
| Missing atmosphere | All clouds/radiation null or absent | No confident sun; limited-data state; usable base fallback |
| Partial cloud layers | Total present, layers null | Generic cloud appearance with partial provenance |
| Invalid radiation relation | DHI substantially above GHI; GHI near zero | Ratio unavailable; finite outputs; no divide-by-zero |
| Sparse/edge grid | One valid neighbor; >90-minute gap; 23:59 | Documented bounded hold or unavailable inputs, never unbounded extrapolation |
| Timezones/DST | Tokyo, opposite date in another zone, transition date | Correct selected day; enhanced fallback on ambiguous date |
| Refresh race | Location A resolves after B; old refresh resolves after switch | B remains displayed; scene and labels agree |
| Stable geometry | Same input after restart; resized/expanded; minute tick | Stable cloud IDs/paths, no random jump |
| Accessibility | Both themes, larger text, Reduce Motion, reduced transparency | Readable controls; stable static scene; decorative layers excluded from navigation |

Also test symmetry around sunrise/sunset and monotonic suppression under increasingly dense low cloud with other inputs held constant. Review screenshots with the same stops but different radiation inputs to prove the new light components are making a useful difference.

## Verification commands and evidence

The implementation verification actually run is recorded in the dated report. It includes backend tests/build, standalone Swift regressions, simulator build, targeted deterministic UI tests, and live Open-Meteo smoke checks. Physical-device profiling and full-matrix screenshot coverage remain outstanding.

Backend, from `server/`:

```bash
bun test
bun build src/index.ts --target bun --outdir /tmp/youki-server-build
```

The package's `bun run build` is currently a placeholder. Add focused provider tests using a stubbed client/fetch seam; tests must not make real provider calls.

Model regressions: use the existing compiler/run command in [frontend/README.md](../frontend/README.md#regression-verification), extending its explicit source list for new Foundation model files. If a separate scene runner is added, document its compile/run command there. These must run without a booted simulator and cover nullable sampling, geometry/light rules, refresh races, and compatibility.

Legacy parity, from repo root, **only when an inspected reference HTML is available**:

```bash
bun scripts/verify-sky-parity.mjs /path/to/reviewed/gradient.html
```

The path is a placeholder, not a repository asset. The [existing harness](../scripts/verify-sky-parity.mjs) requires the original reference's expected script layout; do not substitute `sky-gradient-explainer.html`. Its old `/tmp` input is not a durable dependency. If unavailable, report reference parity as not run and compare legacy baseline numeric fixtures captured in step 1. Never change reference expectations merely to accommodate the enhanced rendering, which lives outside that contract.

iOS build, from repo root:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project frontend/YoukiApp/YoukiApp.xcodeproj \
  -scheme YoukiApp \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/youki-derived \
  build
```

Use the UI-test command in [frontend/README.md](../frontend/README.md), selecting an installed simulator. Add fixture-driven tests for event changes, compact/expanded scene, partial data, and source/status presentation. The current live test expects a reachable backend; do not mix its availability with deterministic rendering tests.

Live API smoke, after starting the backend with `bun run dev` in `server/`:

```bash
curl http://localhost:3000/api/v1/health
curl -X POST http://localhost:3000/api/v1/sky-day/timeline \
  -H 'content-type: application/json' \
  -d '{"location":{"latitude":35.6762,"longitude":139.6503}}'
```

Inspect at least one daylight and one night weather row, units at the provider boundary, null behavior, and generation timestamp. Repeat with a non-Japan location. Do not assert that every region or hour must have non-null radiation. Separately verify old/new payloads with fixtures.

Review `git diff --check` and `git status --short` at the end. Deliver screenshots for clear midday, overcast, dawn, sunset high clouds, night, and missing data in compact and expanded mode; report observed performance on the actual test device. No generated build directories or machine-specific Xcode state belong in Git.

## Implementation status and remaining verification

Completed: additive provider fields and units validation; backward-compatible Swift DTO; deterministic scene sampler/generator; seeded native sun/cloud layers; same-day stale refresh; Open-Meteo attribution; DEBUG-only scenario fixtures; regression coverage. Enhanced rendering is enabled by default, with `-legacySky` available as a launch-time rollback seam. The old nine-stop generator and scoring path were preserved.

Verified: 12 backend tests (244 expectations) and Bun build; standalone scene and model regressions; iOS Simulator app build; focused synthetic sun/cloud, header/location-name/attribution, overcast, missing-data, and night UI tests on iOS Simulator 18.6; Tokyo/London live endpoint smoke; visual inspection of sunrise and Hayama live fixtures. See the report for commands and results.

Not verified: physical-device performance/battery behavior, the full UI suite, every matrix row in both compact and expanded modes, and provider radiation coverage outside the two smoke locations. These are follow-up calibration/QA, not blockers for the implemented slice.

## Definition of done

- One selected timestamp drives the gradient, sun, cloud appearance, and existing ramp.
- New data is additive and nullable; old servers/clients still work.
- Sun-above-horizon and visible-direct-light decisions are separate and tested.
- Overcast clouds obscure the sun; twilight glow can outlive it; night has no solar light.
- Missing/stale data and failed refreshes do not manufacture confidently sunny live conditions.
- Deterministic geometry and bounded drawing preserve the existing layout and readability.
- Backend/model checks and simulator build pass; visual and UI evidence covers the matrix.
- Actual implementation, remaining limitations, and verification are recorded for the next reviewer.
