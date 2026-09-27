# Sunlight and clouds implementation

Implemented an additive sky scene for the iOS forecast. Existing gradient stops, ramp, and prediction scoring remain the base; the app now layers a sun, twilight glow, and deterministic cloud masks based on apparent solar position, cloud cover, visibility, and optional instantaneous radiation.

## What changed

- The Open-Meteo weather adapter requests direct-normal, global-horizontal, and diffuse-horizontal instantaneous radiation. The server normalizes valid W/m² values and treats missing, malformed, negative, non-finite, or wrong-unit fields as null. Older provider payloads remain usable.
- Swift timeline decoding accepts the optional radiation object. Foundation-only scene sampling distinguishes zero from missing data, bounds interpolation/holds, and falls back on ambiguous DST transition days. A pure generator separates sun-above-horizon from direct illumination and derives cloud/twilight appearance.
- Native SwiftUI sun and cloud layers render with deterministic seeded geometry. Enhanced rendering is the default; `-legacySky` selects the prior renderer. Debug-only `-uiSkyFixture`, `-uiSkyFixtureOvercast`, `-uiSkyFixtureMissing`, and `-uiSkyFixtureNight` arguments provide local scenarios.
- Same-day refresh keeps the current scene available, marks failed data stale, retries after a cooldown, and clears it when the local day changes. The sky has a VoiceOver summary; source attribution is linked in the Locations sheet.
- Design rationale and detailed handoff status: [design](../sunlight-clouds-design.md), [implementation plan](../sunlight-clouds-implementation-plan.md). Frontend usage and regression instructions: [README](../../frontend/README.md).

## Verification

- `cd server && bun test`: 12 tests passed, 244 expectations. `bun build src/index.ts --target bun --outdir /tmp/youki-server-build`: passed.
- Standalone `SkySceneRegression.swift`: passed old/new DTO compatibility, legacy gradient parity, scene regimes, missing/zero handling, bounded sampling, DST fallback, and stable seeds.
- Standalone `ModelRegression.swift`: passed timestamp, selection, partial API failure, stale refresh/cooldown, midnight clearing, and request-race checks. The model fixture now includes a noon weather row so its selected Now scene has representative inputs.
- `xcodebuild ... -scheme YoukiApp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' ... build CODE_SIGNING_ALLOWED=NO`: **BUILD SUCCEEDED** (Xcode 16.4 / iOS Simulator SDK 18.5).
- Targeted `testSyntheticSkySceneAndAttribution` passed on iPhone 16 Pro / iOS Simulator 18.6, verifying the sun scene, location label, absence of the old sky attribution text, and attribution link inside Locations. Overcast/missing/night fixture tests and the full UI suite were not run.
- Live Open-Meteo smoke checks in Tokyo and London returned all three radiation fields in W/m² for the requested rows, and the local timeline endpoint preserved them. Coverage is not guaranteed for other regions or model hours.

## Remaining QA

Run the overcast/missing/night UI fixtures and broader UI suite. Review compact and expanded screenshots across dawn, noon, overcast, sunset, and night; profile an older physical device before making performance or battery claims. Radiation coverage was sampled in two locations only. The scene is illustrative and does not locate real cloud geometry.

## Follow-up: location error screenshot (2026-09-26)

The reported `kCLErrorDomain error 0` originates in Core Location before either forecast API request starts; Core Location code 0 is `locationUnknown`. `LocationManager` previously failed the whole load immediately for this transient callback. It now retries a one-shot location request up to three times, one second apart, while the existing 20-second request timeout remains in place. Repeated failure maps to the existing readable “Your current location could not be determined.” message. The regression runner verifies that `locationUnknown` is retryable while `denied` is terminal. Model regression and generic iOS Simulator app build pass; launching the simulator UI remains unavailable in this environment because CoreSimulatorService is disconnected.

## Follow-up: simulator backend and location label (2026-09-27)

The shared Xcode scheme now targets `http://localhost:3000/`, matching the local Podman backend when running in the Mac simulator. The Podman VM and existing container were started; health, prediction, and day-timeline endpoints responded. A Tokyo location was set in the iPhone 16 Pro simulator, and the live app displayed “Live sky and forecast.” The header no longer includes the “Illustrated forecast” source pill. Reverse geocoding now provides the city/region label for device and manually selected locations, with generic fallback labels if lookup fails. Open-Meteo attribution remains accessible in the Locations sheet. The focused UI test passed on iOS Simulator 18.6; Foundation model regressions also passed.

## Follow-up: Hayama location and header cleanup (2026-09-27)

The earlier Suginami label reflected the explicit Tokyo test location set in Simulator, not the MacBook or iPhone's physical GPS. Simulator location was changed to Hayama Town Hall coordinates from the [official town location page](https://www.town.hayama.lg.jp/soshiki/seisaku/15/988.html); reverse geocoding displayed “Hayama.” Removed “Live sky and forecast” from the header and Locations sheet because it duplicated internal state. Loading progress, Retry, and detailed errors remain. Focused UI checks for the sun fixture, location name, missing header copy, and relocated attribution passed; overcast/missing/night fixture checks and model regression passed.
