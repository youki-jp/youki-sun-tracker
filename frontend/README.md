# Youki iOS app

This directory contains the SwiftUI prototype for Youki's sunrise and sunset color forecast experience.

## Run in Xcode

Open `YoukiApp/YoukiApp.xcodeproj`, select the `YoukiApp` scheme, choose an iOS Simulator or connected iPhone, and run. The project currently targets iOS 17 and newer.

## Current behavior

The screen requests the device's location and independently loads the prediction and whole-day timeline APIs. Tap the location pill to use device location or enter latitude, longitude, and optional altitude. Coordinates are not saved. A denied or timed-out location request can be replaced with manual coordinates.

- Six selectable real solar milestones: civil dawn, golden-hour start, sunrise, solar noon, afternoon golden-hour start, and sunset
- One selected timestamp drives the native sky and five-color ramp, including expanded analysis; sunrise is selected first when available
- The enhanced sky scene layers a geometry-gated sun, twilight glow, and seeded cloud masks over the unchanged nine-stop gradient. It uses instantaneous direct/global/diffuse solar radiation when available and falls back to cloud-estimated light for older servers.
- The scene distinguishes reported radiation, cloud-estimated light, and unavailable atmospheric data; it has a VoiceOver summary, and Open-Meteo attribution is available in the Locations sheet.
- The location chip shows a reverse-geocoded city/region name for current and manually entered coordinates; it falls back to a generic label if geocoding is unavailable.
- Nullable polar milestones show an unavailable time and are disabled; another real milestone is selected instead
- Sunset and golden PM show the sunset score, reasons, and conditions
- Expandable sky color analysis
- Forecast calendar with locked premium days
- Manual locations and subscription preview sheets
- Light and dark theme previews
- Loading progress, a retry control when the forecast is incomplete, and detailed errors in Locations

The sample data remains as a clearly labelled fallback and for previews. Timeline-only success keeps the live sky with unavailable scores; prediction-only success labels its sample sky and disables unavailable timeline events. Loading or changing location clears prior results, and late responses cannot replace the newest request. Same-day foreground/minute refreshes retain a usable scene, mark it stale on failure, and retry automatically no more often than every five minutes. Transient Core Location `locationUnknown` errors are retried up to three times before the app reports a readable location-unavailable message. Missing atmospheric values use the HTML defaults before interpolation and are labelled partial.

`SkyGradient.swift`, `SkyScene.swift`, `SkySceneSampler.swift`, `SkySceneGenerator.swift`, and `SkyDayTimelineAPI.swift` remain Foundation-only for standalone regression verification. Local timestamps accept HH:mm or HH:mm:ss and intentionally sample at whole-minute precision, matching the HTML. Date-based sampling uses the returned timezone and rejects dates outside the loaded day. The legacy renderer uses the same nine stops, fractional cloud ellipses, and radial glow colors/positions as the reference; native/browser blur rasterization may differ.

Only one live day is loaded. Calendar sample days, subscriptions, and alarm controls remain prototype UI.

## Backend URL

The default backend URL is `http://localhost:3000`. To override it, add `BACKEND_URL` to the Xcode scheme environment. This default works in the iOS Simulator; a physical device needs a reachable Mac/LAN URL instead of `localhost`.

## Regression verification

Run from the repository root on macOS, without booting a simulator:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -parse-as-library -module-cache-path /tmp/youki-model-module-cache \
  frontend/YoukiApp/{SkyGradient,SkyScene,SkySceneSampler,SkySceneGenerator,SkyDayTimelineAPI,SkyColorAPI,ServerViewModel,LocationManager,ForecastMapper,PrototypeModels,Color+Hex,AppConfig}.swift \
  frontend/YoukiApp/Tests/ModelRegression.swift -o /tmp/youki-model-regression
/tmp/youki-model-regression
```

This checks timestamp validation, interpolation defaults, timezone/day boundaries, coordinate validation, missing milestones, event/score selection, independent API failures, and overlapping location requests.

Run the scene model and generator regressions with:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -parse-as-library -module-cache-path /tmp/youki-scene-module-cache \
  frontend/YoukiApp/{SkyGradient,SkyScene,SkySceneSampler,SkySceneGenerator,SkyDayTimelineAPI,SkyColorAPI}.swift \
  frontend/YoukiApp/Tests/SkySceneRegression.swift -o /tmp/youki-scene-regression
/tmp/youki-scene-regression
```

For deterministic UI previews, use the debug-only launch arguments `-uiSkyFixture`, `-uiSkyFixtureOvercast`, `-uiSkyFixtureMissing`, and `-uiSkyFixtureNight`. They load synthetic local-day samples and do not affect release builds.

The `YoukiAppUITests` target covers the sample/manual flows plus deterministic sun/cloud/missing-data fixtures. Existing live event-selection tests still require the backend; the synthetic sky tests set an unreachable URL to prove they use fixtures:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project frontend/YoukiApp/YoukiApp.xcodeproj -scheme YoukiAppUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/youki-ui-tests test
```

UI tests use the debug-only `-uiAudit` launch argument to start in sample mode and enter explicit Tokyo coordinates. The live interaction test waits for a live sky and forecast (including partial-atmosphere results), then waits for sunrise, solar noon, and sunset to be available from the timeline API.
