# Youki iOS app

This directory contains the SwiftUI prototype for Youki's sunrise and sunset color forecast experience.

## Run in Xcode

Open `YoukiApp/YoukiApp.xcodeproj`, select the `YoukiApp` scheme, choose an iOS Simulator or connected iPhone, and run. The project currently targets iOS 17 and newer.

## Current behavior

The screen requests the device's location and independently loads the prediction and whole-day timeline APIs. Tap the location pill to use device location or enter latitude, longitude, and optional altitude. Coordinates are not saved. A denied or timed-out location request can be replaced with manual coordinates.

- Six selectable real solar milestones: civil dawn, golden-hour start, sunrise, solar noon, afternoon golden-hour start, and sunset
- One selected timestamp drives the native sky and five-color ramp, including expanded analysis; sunrise is selected first when available
- Nullable polar milestones show an unavailable time and are disabled; another real milestone is selected instead
- Sunset and golden PM show the sunset score, reasons, and conditions
- Expandable sky color analysis
- Forecast calendar with locked premium days
- Manual locations and subscription preview sheets
- Light and dark theme previews
- Persistent live, partial, loading, and sample status with retry; error details in Locations

The sample data remains as a clearly labelled fallback and for previews. Timeline-only success keeps the live sky with unavailable scores; prediction-only success labels its sample sky and disables unavailable timeline events. Loading or changing location clears prior results, and late responses cannot replace the newest request. Missing atmospheric values use the HTML defaults before interpolation and are labelled partial.

`SkyGradient.swift` and `SkyDayTimelineAPI.swift` remain Foundation-only for independent HTML parity verification. Local timestamps accept HH:mm or HH:mm:ss and intentionally sample at whole-minute precision, matching the HTML. Date-based sampling uses the returned timezone and rejects dates outside the loaded day. The renderer uses the same nine stops, fractional cloud ellipses, and radial glow colors/positions as the reference; native/browser blur rasterization may differ.

Only one live day is loaded. Calendar sample days, subscriptions, and alarm controls remain prototype UI.

## Backend URL

The default backend URL is `http://localhost:3000`. To override it, add `BACKEND_URL` to the Xcode scheme environment. This default works in the iOS Simulator; a physical device needs a reachable Mac/LAN URL instead of `localhost`.

## Regression verification

Run from the repository root on macOS, without booting a simulator:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -parse-as-library -module-cache-path /tmp/youki-model-module-cache \
  frontend/YoukiApp/{SkyGradient,SkyDayTimelineAPI,SkyColorAPI,ServerViewModel,LocationManager,ForecastMapper,PrototypeModels,Color+Hex,AppConfig}.swift \
  frontend/YoukiApp/Tests/ModelRegression.swift -o /tmp/youki-model-regression
/tmp/youki-model-regression
```

This checks timestamp validation, interpolation defaults, timezone/day boundaries, coordinate validation, missing milestones, event/score selection, independent API failures, and overlapping location requests.

The existing `YoukiAppUITests` target covers sample status and disabled empty-coordinate submission, manual input validation, live event selection, and expanded analysis. It sets `BACKEND_URL` to `http://localhost:3000` for each app launch, so the backend must be reachable from the simulator:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project frontend/YoukiApp/YoukiApp.xcodeproj -scheme YoukiAppUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/youki-ui-tests test
```

UI tests use the debug-only `-uiAudit` launch argument to start in sample mode and enter explicit Tokyo coordinates. The live interaction test waits for a live sky and forecast (including partial-atmosphere results), then waits for sunrise, solar noon, and sunset to be available from the timeline API.
