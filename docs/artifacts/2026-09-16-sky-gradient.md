# Sky Gradient Integration

Status: Implemented
Updated: 2026-09-16

## Quick read

### What changed

`origin/feature/gradient-features` was consolidated with the preserved live-forecast work. The Bun/Hono backend now has a tested gradient domain/application/engine slice, and SwiftUI loads the whole-day timeline, interpolates local conditions, and renders the reference nine-stop sky appearance.

### Why it matters

The backend remains responsible for timezone-safe solar geometry and provider aggregation, while the iOS client can animate and render the presentation model without duplicating provider or astronomy logic.

### Current state

Implemented as Option A from the [implementation plan](../sky-gradient-implementation-plan.md). Existing semantic prediction and sample fallbacks remain. The calendar still represents one target day, and generated server-side snapshots are intentionally not exposed.

### Next step

Review the generated appearance on a connected simulator/device across dawn, midday, sunset, overcast, rain, haze, and polar edge cases.

## Changed surface

| Area | Status | Details |
| --- | --- | --- |
| Branch consolidation | Implemented | Safety checkpoint, local forecast checkpoint, and only `origin/feature/gradient-features` integrated on the review branch. |
| Backend contract | Implemented | [timeline route](../../server/src/http/routes/sky-day.ts), [gradient domain types](../../server/src/domain/sky-gradient.ts), and [normalized service](../../server/src/application/services/sky-gradient-service.ts). |
| Backend engine | Implemented | [deterministic Oklch engine](../../server/src/infrastructure/engines/sky-gradient-engine.ts) with [Bun tests](../../server/src/infrastructure/engines/sky-gradient-engine.test.ts). |
| SwiftUI client | Implemented | [timeline client](../../frontend/YoukiApp/SkyDayTimelineAPI.swift), [local sampler/generator](../../frontend/YoukiApp/SkyGradient.swift), and [fractional renderer](../../frontend/YoukiApp/SkyBackgroundView.swift). |
| Documentation | Implemented | [current snapshot](../current-state.md), [SwiftUI handoff](../sky-gradient-implementation.md), and [technical explainer](../sky-gradient-explainer.html). |

## Engineer details

### Design and decisions

- [Sky gradient implementation plan](../sky-gradient-implementation-plan.md): separates semantic sky-color scoring from continuous sky-gradient generation.
- [SwiftUI implementation handoff](../sky-gradient-implementation.md): reference constants, nine-stop requirement, local-wall-clock rules, and renderer constraints.
- Option A is implemented: the server exposes the raw whole-day timeline; Swift owns interpolation, appearance generation, animation timing, accessibility, and fallbacks. No generated-gradient HTTP endpoint was added.

### Contracts and flow

`POST /api/v1/sky-day/timeline` returns a resolved timezone, nullable solar milestones, adaptive solar samples, and independent hourly weather/air-quality grids. `SkyGradientService` brackets one local moment against those grids, linearly interpolates numeric values, carries solar categorical values, clamps physical ranges, and retains availability. The engine applies display defaults only at generation time. Swift decodes the same timeline shape, performs the same local join, ports the pure Oklch generator, and feeds `Gradient(stops:)` plus fractional cloud/glow geometry into `SkyBackgroundView`.

### Delegated-agent outcomes

| Agent | Scope | Changed files | Verification | Assumptions or blockers |
| --- | --- | --- | --- | --- |
| Pasteur | Backend gradient domain, interpolation service, engine, and tests | [`sky-gradient.ts`](../../server/src/domain/sky-gradient.ts), [`sky-gradient-service.ts`](../../server/src/application/services/sky-gradient-service.ts), [`sky-gradient-engine.ts`](../../server/src/infrastructure/engines/sky-gradient-engine.ts), and related tests/port | Parent reran `bun test`: 10 passed; Bun bundle passed | No route/factory changes, consistent with Option A. |

### Verification

| Check | Result | Evidence |
| --- | --- | --- |
| `cd server && bun test` | Passed | 10 passed, 0 failed, 235 assertions. |
| `cd server && bun build src/index.ts --target bun --outdir /tmp/youki-server-build` | Passed | 45 modules bundled successfully. |
| Prototype `bun run checks/run.mjs` | Passed | 15 checks, 0 failed. |
| Prototype `bun run checks/mutations.mjs` | Passed | 9 deliberate faults caught, 0 escaped. |
| iOS app `xcodebuild ... -scheme YoukiApp ... build` | Passed | Exit 0; CoreSimulator service emitted environment warnings only. |
| UI target `xcodebuild ... -scheme YoukiAppUITests ... build-for-testing` | Passed | Exit 0; UI test bundle compiled. |
| Hono health/CORS/invalid timeline smoke tests | Passed | Health 200, CORS preflight 204, invalid request 400. |
| Tokyo timeline smoke test | Passed | HTTP 200; Asia/Tokyo response with 117 solar, 24 weather, and 24 air-quality rows. |
| UI test execution | Unverified | CoreSimulator was disconnected and no simulator runtime was available for launch. |

### Risks and limitations

- The semantic sky-color path still uses nearest hourly atmospheric samples; only the gradient path uses interpolation.
- The iOS calendar still loads one live target day and does not yet fetch a seven-day set.
- The Swift generator has no standalone unit-test target; its compilation is covered by the app and UI-target builds, while deterministic backend tests cover the model behavior.
- Open-Meteo remains a live dependency without repository fixtures for provider failure scenarios.
- The reference calibration still has known gaps for partly cloudy skies, deep twilight, and drifting cloud geometry.

### Follow-ups

- Add fixture-backed provider integration tests and a Swift unit-test target.
- Review visual output on a functioning simulator/device and refine only with corresponding reference-suite updates.

### Not implemented or unverified

- No server-generated `/api/v1/sky-day/gradient` snapshot endpoint; this is intentional under Option A.
- No full seven-day client calendar orchestration.
- UI test execution and screenshot review were not completed in this environment because CoreSimulator was unavailable.
