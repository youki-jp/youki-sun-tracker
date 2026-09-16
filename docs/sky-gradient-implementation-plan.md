# Sky Gradient Integration Plan

Status: implementation-ready plan

This document captures the proposed branch consolidation and the clean-architecture implementation plan for integrating the sky-color/sky-gradient feature into Youki Sun Tracker.

It is based on the current repository snapshot, the recent gradient feature branch, the existing uncommitted local work, and the reference prototype in the youki-prototype checkout.

## 1. Goals and non-goals

### Goals

- Make develop the latest coherent project state.
- Preserve the current local work and integrate the recent gradient feature work safely.
- Keep the existing sky-color prediction/scoring capability separate from visual sky-gradient generation.
- Provide a stable, testable contract that can support the Bun/Hono backend and the SwiftUI client.
- Generate a smooth, physically plausible-looking sky ramp from solar geometry and atmospheric inputs.
- Make the feature usable with sensible fallbacks when weather, air-quality, or solar-event data is unavailable.

### Non-goals for the first implementation

- Replacing the current weather provider.
- Rebuilding the entire SwiftUI screen architecture.
- Promising pixel-identical output between Swift and JavaScript before the model and fixtures are stable.
- Treating the reference prototype as production-ready code.
- Merging stale branches that conflict with the current architecture merely because they contain historical work.

## 2. Repository and branch findings

At the time this plan was written:

- develop and origin/develop point to 9466f2943d2d97d10c9ffe94561c4a0a30c9ea2e.
- origin/feature/gradient-features is a direct descendant of develop, three commits ahead:
  - d8d275c: real solar geometry and optional feature payload.
  - 64af371: whole-day sky timeline with real solar milestones.
  - 4250cd8: documentation handoff for the SwiftUI live sky gradient.
- origin/feature/sun-information-get is an old alternate app state. It has two unique commits, is behind current develop, and removes or replaces current architecture. It should be archived, not merged.
- origin/feature/server-env-preparation is an old setup branch, behind current develop, and conflicts with the current Bun/Hono setup. It should be archived, not merged.
- The other historical feature branches have no unique commits relative to develop and can be removed after normal branch/PR verification.
- main is a separate release line and should remain untouched.

The worktree is currently dirty with user-owned changes in project documentation, server sky-color/weather code, SwiftUI files, project configuration, and new local files. Those changes must be preserved. Do not reset, clean, stash, or overwrite them without explicit approval.

## 3. Safe branch-consolidation procedure

The branch work and implementation work should be treated as two explicit phases. First create a safe checkpoint and consolidate the known good branch. Then implement and verify the feature.

### Phase A: create a safety checkpoint

1. Confirm the current branch, upstream, worktree status, and all local/remote branch tips.
2. Review the dirty diff and untracked files so the current local work is understood.
3. Create a temporary safety branch or tag pointing at the current develop commit. Use a clearly dated name such as checkpoint/develop-before-sky-gradient-YYYYMMDD.
4. Do not include the current dirty changes in a branch operation that might overwrite them. Either commit them as a coherent local integration checkpoint, or temporarily preserve them using a safe, explicitly named stash only if necessary. The preferred outcome is a reviewable commit containing the current intended work.

### Phase B: consolidate the gradient branch

1. Create a short-lived consolidation branch from the latest develop, for example integration/sky-gradient.
2. Merge origin/feature/gradient-features. Since it is a direct descendant, a fast-forward is possible if the worktree is clean; otherwise commit/preserve the local work first and resolve any overlap deliberately.
3. Keep the useful work already present on the current worktree, including the current API integration, uvIndex and conditions support, UI tests, documentation updates, and any deliberate changes to the heuristic sky-color implementation.
4. Retain from the feature branch:
   - timezone-aware location/date handling;
   - NOAA-style solar position calculations;
   - solar milestones, including nullable milestones at polar latitudes;
   - adaptive solar sampling based on sun movement speed;
   - hourly weather and air-quality inputs;
   - the includeFeatures option and CORS behavior;
   - the timeline endpoint and its documented response shape.
5. Resolve conflicts in favor of the current architecture and current project state, not by accepting one entire side.
6. Run the backend build, existing tests, endpoint smoke tests, and the reference prototype checks before moving develop.
7. Fast-forward develop to the verified consolidation branch. Push normally. Do not force-push.

### Phase C: archive stale branches

After the consolidation branch has been reviewed and pushed:

- Tag or record the tips of feature/sun-information-get and feature/server-env-preparation if their history may be useful, then delete them as stale alternate lines after team/PR checks.
- Delete fully merged historical branches only after confirming they have no open work or required commits.
- Leave main untouched.
- Prune local remote-tracking references only after the remote branch cleanup is intentional.

## 4. Architectural decision

The product has two related but distinct concepts:

1. Sky-color prediction: a semantic score, label, and reasons such as “clear,” “golden,” or “hazy.”
2. Sky-gradient generation: a continuous visual model containing color stops, glow information, and cloud-band geometry for rendering.

They may share normalized observations and solar geometry, but they should not be one large function or one overloaded response model.

The proposed boundaries are:

~~~text
Provider adapters
  Open-Meteo weather / air quality
  Location and timezone resolution
          |
          v
Application services
  SkyDayTimelineService
  SkyColorPredictionService
  SkyGradientService
          |
          v
Domain engines
  SkyColorEngine       -> semantic score/label/reasons
  SkyGradientEngine    -> stops/glow/cloud geometry
          |
          v
Transport adapters
  Bun/Hono routes, validation, serialization, CORS
          |
          v
Clients
  SwiftUI rendering, animation, accessibility, fallback UI
~~~

The backend should own location/timezone resolution, external provider calls, solar calculations, timeline construction, and normalized contracts. The client should own rendering, animation timing, screen state, and accessibility behavior.

## 5. Reference prototype logic

The reference prototype’s generateSky(s) is a pure function. It accepts normalized moment observations and returns a nine-stop gradient ramp plus glow and cloud-band parameters.

### Required or strongly recommended inputs

The first production contract should support these fields:

~~~ts
type SkyGradientInput = {
  elevationDegrees: number;
  azimuthDegrees?: number;
  cloudTotalPct: number;
  cloudLowPct: number;
  cloudMidPct: number;
  cloudHighPct: number;
  visibilityMeters: number;
  relativeHumidityPct: number;
  precipitationMillimeters: number;
  aerosolOpticalDepth: number;
  dustUgM3: number;
  pm25UgM3: number;
};
~~~

elevationDegrees, cloud coverage, visibility, humidity, precipitation, and at least one aerosol/particulate signal are needed for a useful first version. azimuthDegrees should be carried through the model even though the current vertical ramp does not use it; it is needed for future directional glow and sunrise/sunset orientation.

The current prototype does not use UV index, dew point, PM10, ozone, phase, or isRising in the color calculation. Those values may remain available in the broader timeline contract without being passed to the first gradient engine.

### Core factors

The prototype derives these factors from solar elevation:

~~~text
dayF    = smoothstep(-8°, 10°, elevation)
highSun = smoothstep(10°, 60°, elevation)
glowF   = exp(-((elevation + 1°) / 8°)²)
~~~

- dayF transitions from night/twilight to daytime.
- highSun reduces warm coloration around high noon.
- glowF creates a strong but smooth horizon glow near the sun’s low-elevation region.

Atmospheric modifiers are then calculated:

- aerosol warmth from aerosol optical depth, dust, and PM2.5;
- haze from relative humidity and reduced visibility;
- wetness from precipitation;
- low-cloud blocking near the horizon;
- high-cloud light capture and cloud brightness;
- overcast-dependent reductions in lightness and chroma.

The color path is built from a cool top anchor and a warm bottom anchor. Warmth is strongest during twilight and fades as the sun rises high. Colors are interpolated in rectangular Oklab rather than directly in sRGB, avoiding the muddy or green detours that can occur with naive RGB interpolation. A controlled magenta adjustment prevents the warm path from looking unnaturally yellow.

Finally, Oklab/Oklch values are converted to sRGB. Chroma is reduced iteratively when necessary so that colors remain in gamut instead of clipping harshly.

### Output shape

The first output should preserve the prototype’s useful structure:

~~~ts
type SkyGradientOutput = {
  stops: Array<{ offset: number; color: string }>;
  ramp: Array<{ offset: number; color: string }>;
  glow: {
    intensity: number;
    center: number;
    spread: number;
  };
  cloudBands: {
    low: number;
    mid: number;
    high: number;
  };
};
~~~

The canonical ramp has nine stops at offsets:

~~~text
[0, 0.16, 0.32, 0.46, 0.60, 0.72, 0.83, 0.93, 1]
~~~

The geometry values are fractional and should not be rounded into pixel coordinates. This allows SwiftUI, Canvas, CSS, or another renderer to adapt the visual to any screen size.

## 6. Timeline contract and temporal model

The feature branch introduces:

~~~text
POST /api/v1/sky-day/timeline
~~~

The request should contain a nested location and a local target date, for example:

~~~json
{
  "location": {
    "latitude": 35.6762,
    "longitude": 139.6503,
    "timezone": "Asia/Tokyo"
  },
  "targetDateIso": "2026-09-16",
  "includeFeatures": true
}
~~~

The response should include:

- the resolved timezone and requested local date;
- solar samples with local wall-clock timestamps, elevation, azimuth, and day/night classification;
- weather samples containing cloud and precipitation values;
- air-quality samples containing particulate and aerosol inputs where available;
- solar milestones such as dawn, sunrise, sunset, and dusk, with null where a milestone does not occur;
- a summary suitable for the existing semantic sky-color feature.

The solar array is adaptive and may not share the same timestamps as the hourly weather/air arrays. This is intentional. The gradient service must not assume array indexes line up.

### Timezone rules

- Treat timeline timestamps as local wall-clock values associated with the resolved timezone.
- Use the project’s timezone-safe helpers when converting or comparing values.
- Do not blindly call Date.parse on a timezone-less local timestamp.
- Keep the original local timestamp in the response so clients can display it consistently.
- Model polar edge cases explicitly: a milestone may be absent because the sun never crosses that threshold.

## 7. Interpolation and normalization service

Before gradient generation, an application service should combine one solar sample with interpolated weather and air-quality observations.

Required behavior:

1. Find the two hourly rows bracketing the requested local time.
2. Linearly interpolate numeric values using the time fraction between those rows.
3. Clamp to the first or last available row outside the provider’s range.
4. Use nearest or explicitly defined categorical values for non-numeric fields.
5. Preserve null and use documented defaults only where the engine requires a numeric value.
6. Clamp provider values to safe physical/API ranges before passing them to the engine.

The existing branch scoring helper uses nearest samples. That can be acceptable for a semantic summary but should not be reused unchanged for a smooth animated gradient. The gradient path needs bracketing interpolation to avoid visible steps.

A useful internal type is:

~~~ts
type NormalizedSkyObservation = {
  timeIso: string;
  elevationDegrees: number;
  azimuthDegrees: number;
  cloudTotalPct: number;
  cloudLowPct: number;
  cloudMidPct: number;
  cloudHighPct: number;
  visibilityMeters: number;
  relativeHumidityPct: number;
  precipitationMillimeters: number;
  aerosolOpticalDepth: number;
  dustUgM3: number;
  pm25UgM3: number;
};
~~~

Keep provider-specific field names and missing-value handling inside the Open-Meteo adapter or normalization service. The domain engine should receive this stable vocabulary.

## 8. Backend implementation plan

### 8.1 Domain layer

Add framework-neutral types and interfaces in the domain/application boundary, for example:

~~~text
server/src/domain/sky-gradient.ts
server/src/application/ports/sky-gradient-engine.ts
server/src/application/services/sky-gradient-service.ts
server/src/infrastructure/engines/sky-gradient-engine.ts
~~~

The exact directories should follow the project’s current source map. The important rule is dependency direction:

- domain types do not import Hono, Open-Meteo types, or Swift concepts;
- the engine is deterministic and has no network or clock dependency;
- application services orchestrate use cases and ports;
- infrastructure implements provider adapters and the concrete engine;
- routes validate and serialize only.

The SkyGradientEngine port should expose a single deterministic operation such as:

~~~ts
interface SkyGradientEngine {
  generate(input: NormalizedSkyObservation): SkyGradientOutput;
}
~~~

Initially copy the prototype’s constants and formula structure into the engine with unit-level documentation. Do not improve the model and alter the visual result during the first port. Stabilize behavior and fixtures first.

### 8.2 Application service

SkyGradientService should:

1. Validate the requested location/date/time.
2. Load or receive the day timeline through the timeline service.
3. Select the requested solar moment or produce the current moment from a validated local time.
4. Interpolate hourly weather and air values around that moment.
5. Build a NormalizedSkyObservation.
6. Call the SkyGradientEngine.
7. Return the gradient output plus enough metadata for diagnostics, such as timestamp, timezone, and input availability.

This keeps the engine pure and makes it easy to test the orchestration separately.

### 8.3 HTTP endpoint

An optional single-moment endpoint can be added after the timeline is stable:

~~~text
POST /api/v1/sky-day/gradient
~~~

Example request:

~~~json
{
  "location": {
    "latitude": 35.6762,
    "longitude": 139.6503,
    "timezone": "Asia/Tokyo"
  },
  "targetDateIso": "2026-09-16",
  "atIso": "2026-09-16T17:42:00"
}
~~~

The route should use the same location/date validation and timezone rules as the timeline endpoint. Hono should not calculate solar geometry, interpolate provider arrays, or implement color math.

### 8.4 Endpoint choice

There are two viable integration options:

- Option A: the backend serves the normalized day timeline and Swift generates the gradient locally. This is recommended if only the iOS client needs the feature and local animation/offline behavior is important.
- Option B: the backend also serves generated gradient snapshots. This is recommended if web and iOS clients need byte-identical colors or if the gradient logic must be centrally updated.

The recommended first release is Option A plus a server-side engine test suite. Add Option B only when there is a concrete consumer for the generated snapshot. This avoids making HTTP serialization part of the rendering loop while preserving one canonical model.

## 9. SwiftUI integration plan

The current UI uses a mood-based SkyBackgroundView and a LinearGradient(colors:) path. Replace that input over time with a model-driven sky appearance while retaining a mood fallback.

Add Codable models for:

- timeline response and solar samples;
- normalized weather/air values;
- gradient output if Option B is selected;
- the nullable milestone representation.

Add a view-model seam that:

1. Requests the timeline for the selected day/location.
2. Tracks the current local time or selected preview time.
3. Interpolates values if the generator runs in Swift.
4. Produces a stable SkyAppearance model.
5. Publishes a fallback appearance if the request fails or required data is missing.

The rendering layer should:

- use the nine stable stops rather than rebuilding an arbitrary number of colors every frame;
- use fractional stop positions and glow/cloud geometry;
- animate between appearances with a controlled duration and no sudden reset when data refreshes;
- preserve collapsed and expanded layouts;
- keep text contrast and accessibility behavior independent of the gradient;
- avoid making the SwiftUI view know about Open-Meteo field names or Hono response details.

If the generator is implemented in Swift, port the pure math with fixtures generated from the reference implementation. If the backend returns generated snapshots, Swift only decodes and renders the model. In either case, retain a local fallback for offline/error states.

Any new Swift source files must be added to the Xcode project target and verified in both simulator build and UI-test configuration.

## 10. Verification plan

### Before consolidation

- Inspect git status, git diff, and untracked files.
- Confirm the safety branch/tag exists.
- Confirm the exact commits being merged.

### Reference prototype

From the prototype checkout:

~~~bash
bun run checks/run.mjs
bun run checks/mutations.mjs
~~~

The known reference result is 15/15 checks passing and 9/9 deliberate mutation faults detected. Keep these checks green while porting the model.

### Backend

- Install/use the repository’s existing Bun dependencies.
- Build the server with the Bun target.
- Run all existing unit/integration tests.
- Smoke-test timeline validation, successful response, CORS, and missing/invalid inputs.
- Add deterministic tests for:
  - day/twilight/night transitions;
  - high-sun and horizon-glow behavior;
  - clear, hazy, rainy, and overcast inputs;
  - null/missing air-quality fields;
  - interpolation at an exact sample, between samples, and outside the range;
  - stable nine-stop offsets;
  - valid sRGB output and gamut mapping;
  - polar-day/polar-night nullable milestones;
  - deterministic repeated output for identical input.

### SwiftUI

- Build the app target and UI-test target.
- Run existing UI tests.
- Verify collapsed and expanded forecast views.
- Verify loading, provider failure, no-location, and missing-feature fallbacks.
- Inspect transitions around dawn, sunrise, midday, sunset, and dusk.
- Verify text remains readable over the brightest and darkest generated backgrounds.

### Visual review

Use a small fixed fixture set so visual changes are reviewable:

- clear midday;
- clear sunset;
- civil twilight;
- heavy overcast;
- rain/wet atmosphere;
- hazy or low-visibility air;
- polar edge case with missing milestone.

For each fixture, record the input, generated output, and an image or snapshot where practical. The reference gaps should remain explicit: partly cloudy 25–85% coverage, deep twilight below roughly -10° elevation, one overcast ground-truth photo, and the currently fixed cloud-band geometry need additional validation before claiming high fidelity.

## 11. Acceptance criteria

The work is ready for review when:

- develop contains the verified gradient-feature timeline work and the current intended local changes.
- No stale alternate branch was merged over the current architecture.
- The dirty worktree was preserved and its changes are represented intentionally.
- Timeline and gradient responsibilities are separated by application/domain boundaries.
- The gradient engine is deterministic, framework-neutral, and covered by fixture-based tests.
- Provider-specific missing values do not leak into the domain engine.
- Timezone and polar-location behavior is explicit and tested.
- The iOS UI renders the generated appearance while preserving fallback and accessibility behavior.
- Backend build/tests, prototype checks, and Swift build/UI tests pass.
- The implementation has a documented decision between local Swift generation and server-generated snapshots.

## 12. Suggested implementation order for the next agent

1. Read AGENTS.md, CLAUDE.md, .codex/standards.md, .codex/references.md, and docs/current-state.md.
2. Read this plan completely.
3. Re-audit the branch tips and dirty worktree; create the safety checkpoint before mutations.
4. Consolidate only origin/feature/gradient-features into a review branch and resolve conflicts deliberately.
5. Build and smoke-test the consolidated timeline before adding gradient code.
6. Add normalized observation types, interpolation, and the pure gradient engine.
7. Add deterministic backend tests and fixture snapshots.
8. Choose Option A or Option B explicitly, then implement the corresponding SwiftUI seam.
9. Run the full verification plan and update docs/current-state.md with what is actually implemented.
10. Only after review, fast-forward/push develop and archive stale branches.

Before committing:

~~~bash
git diff --check
git status --short --branch
~~~
