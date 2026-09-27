# HTML atmosphere simulator

Status: Prototype

Updated: 2026-09-25

## Quick read

Created a local, interactive comparison of the original sky gradient and new sunlight/cloud layers. Open [the simulator](../sky-atmosphere-simulator.html) directly, or serve the repository with `python3 -m http.server 8765 --bind 127.0.0.1` and visit `http://localhost:8765/docs/sky-atmosphere-simulator.html`.

Eight synthetic scenarios, a day scrubber, cloud/light controls, layer switches, missing-data modes, focus view, and PNG/JSON exports let the user review the aesthetic before app implementation. No live weather requests or app/backend changes are included. Next step: user visual review.

## Changed surface

| Area | Status | Files |
| --- | --- | --- |
| Simulator | Prototype | [HTML](../sky-atmosphere-simulator.html), [styles](../sky-simulator/studio.css), [interaction](../sky-simulator/studio.js) |
| Scene generation/drawing | Prototype | [Atmosphere model and renderer](../sky-simulator/atmosphere.js) |
| Preserved gradient | Implemented in simulator | [Local reference generator](../sky-simulator/gradient.js) |
| Verification | Implemented | [Verification script](../../scripts/verify-sky-atmosphere.mjs) |

## Decisions and verification

The simulator uses classic local scripts so it also works from a file URL without a build system. The base gradient is kept separate from procedural Canvas clouds and solar lighting. The sun follows a synthetic fixed-length day; cloud masks are deterministic and remain fixed while scrubbing. This is a visual experiment, not the proposed production weather acquisition or refresh implementation.

JavaScript syntax checks passed. The verification script passed 36 exact comparisons against the repository TypeScript gradient engine and checks for horizon/night gating, valid zero radiation, missing-data fallback, safe diffuse ratios, deterministic outputs, and monotonic cloud attenuation. The local HTTP page returned 200.

Optional software Canvas/DOM verification uses temporary `@napi-rs/canvas` and `jsdom` dependencies through `--render-with /path/to/node_modules`; these are not application dependencies. Bun's optional DOM run encountered a jsdom PointerEvent/Window incompatibility, separate from the passing model checks. Running `node scripts/verify-sky-atmosphere.mjs --render-with /tmp/youki-sky-verification/node_modules` passed all eight Canvas renders and DOM checks for sliders, time, data availability, reset, focus, overlays, layer equality, play/pause, and exports. Mean software rendering time was 22 ms; this is not a browser benchmark. Temporary render artifacts are in `/tmp/youki-sky-verification-output`.

Live browser visual review was unavailable: computer-use access to Chrome was denied and no in-app browser was available. Browser layout, Safari rendering, and physical-device performance remain unverified. The user will review the local HTML. No agents were delegated work.

## Limitations and follow-ups

- All weather and solar timing are synthetic; controls do not represent a real location.
- Cloud shapes and lighting constants are artistic. The existing night palette is deliberately preserved.
- PNG export contains the atmosphere canvas; the optional HTML text overlay is not part of the image.
- Review appearance and calibrate the renderer before porting to Swift. See the [design](../sunlight-clouds-design.md) and [implementation plan](../sunlight-clouds-implementation-plan.md).
