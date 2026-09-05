# Implementing the live sky gradient in SwiftUI

Status: the backend side is on this branch and working. The iOS side is not started. This document is the handoff.

The goal is to replace the five hardcoded gradients in `SkyBackgroundView.swift` with a sky synthesised from real atmospheric conditions, evolving as the sun moves through the day.

## Where the algorithm lives

The reference implementation is `generateSky()` in [`youki-prototype/gradient.html`](https://github.com/youki-jp/youki-prototype/blob/main/gradient.html). Open the page with this branch's server running and you can scrub a whole day and watch it work.

It is written to be ported by reading: pure, no DOM, no clock, no network, and nothing expressed in CSS that Swift cannot say. Port it as written before improving it. The constants are calibrated, and several of them are not obvious.

`youki-prototype/checks/` holds the calibration suite. Read [`checks/README.md`](https://github.com/youki-jp/youki-prototype/blob/main/checks/README.md) before changing any constant.

## What the backend gives you now

Two endpoints matter.

**`POST /api/v1/sky-color/predictions`** with `includeFeatures: true` adds a `features` array to each prediction: the aligned solar, weather and air-quality sample for every 15-minute step of the scoring window. Without that flag the response shape is exactly what it was before, so nothing existing breaks.

**`POST /api/v1/sky-day/timeline`** returns a whole local day and is the one to build against:

```json
{
  "location": { "latitude": 35.4437, "longitude": 139.638, "altitudeMeters": 40, "timezoneId": "Asia/Tokyo" },
  "targetDateIso": "2026-09-05",
  "milestones": { "civilDawnIso": "...", "sunriseIso": "...", "solarNoonIso": "...", "sunsetIso": "...", "daylightMinutes": 766, "...": "..." },
  "solar":      [ { "timeIso": "...", "elevationDegrees": -0.27, "azimuthDegrees": 80.8, "isRising": true, "phase": "goldenHourAm" } ],
  "weather":    [ { "timeIso": "...", "cloudCover": { "totalPct": 96, "lowPct": 23, "midPct": 29, "highPct": 96 }, "...": "..." } ],
  "airQuality": [ { "timeIso": "...", "aerosolOpticalDepth": 0.21, "...": "..." } ],
  "summary":    { "sunriseScore": 22, "sunriseLabel": "muted", "sunsetScore": 51, "sunsetLabel": "warm" }
}
```

About 22 KB, 3 KB gzipped, and the same 2.3 s as a single event window because the Open-Meteo providers already download a week of hourly data per request.

Three things about this shape that will bite if missed:

- **`solar`, `weather` and `airQuality` are on different grids on purpose.** Solar is dense near the horizon and sparse at midday; weather and air quality are hourly. Join by timestamp and **interpolate between the bracketing hours**. Snapping to the nearest hourly reading makes the sky step visibly on the hour.
- **Every milestone can be `null`.** Inside the polar circles the sun never reaches a given elevation. Svalbard today returns a sunrise and a sunset but no civil dawn or dusk at all. Do not force-unwrap.
- **All `timeIso` values are naive local wall-clock strings** with no offset, local to `location.timezoneId`. Only `generatedAtIso` is a real UTC instant. Decode them as components, not as `Date`, or apply the timezone explicitly.

## Three constraints that are not negotiable on iOS 17

The deployment target is 17.0 (`project.pbxproj`), which rules out `MeshGradient`, `Color.mix(with:in:)` and gradient colour-space control. The generator's output shape already accounts for this.

**1. Always exactly nine stops.** SwiftUI only morphs between two gradients smoothly when the stop count is stable. A changing count cross-fades instead, which looks like a glitch rather than a sky. Colours and positions move; the count never does.

**2. Use `Gradient(stops:)`, not `LinearGradient(colors:)`.** The current code uses the `colors:` initialiser, which spaces stops evenly. The generator emits explicit positions and they are not even.

```swift
LinearGradient(
    stops: model.stops.map { Gradient.Stop(color: Color(hex: $0.hex), location: $0.position) },
    startPoint: .top,
    endPoint: .bottom
)
```

**3. All geometry is a fraction of sky height, never points.** `SkyBackgroundView.swift` currently offsets clouds and the glow by absolute point values, which is why they sit at different relative heights in the 266 pt collapsed state and the full-screen expanded one. Multiply by the frame height at render time.

One more, easy to miss: `Color(hex:)` in `Color+Hex.swift` parses 8-digit hex as **AARRGGBB**, alpha first, not CSS `#RRGGBBAA`. The contract keeps opacity as a separate numeric field so this never comes up, but do not "helpfully" pack alpha into the hex.

## Where it plugs in

| File | Change |
|---|---|
| `SkyBackgroundView.swift` | Takes a generated model instead of `mood: SkyMood`. The `ZStack` structure stays: gradient, then cloud bands, then the radial glow, then the expanded scrim. |
| `PrototypeModels.swift` | `SkyMood` becomes redundant once stops are generated. `PrototypeDay.colorRamp` is fed by the generator's `ramp`. |
| `ForecastComponents.swift` | `predictedColorRamp` already renders a `LinearGradient` from `colorRamp`; point it at the generated ramp. The expanded card's ramp is labelled with first light / sunrise / blue-hour end, so it wants `dayRamp`, which is sampled across time rather than across the frame. |
| `ServerViewModel.swift`, `AppConfig.swift` | The existing seam. It currently does a bare `GET` on the root URL and decodes nothing. |
| new | `Codable` types for the timeline response, a `SkyGradientGenerator` holding the port, and a view model that maps a moment to a model. There are currently no `Codable` conformances anywhere in the target. |
| `project.pbxproj` | **Every new Swift file must be added manually.** The project lists sources explicitly. |

Keep the existing shape of the app: no network calls in a view body, and `PrototypeDay` replaced through a mapper rather than by scattering API calls through views. `.codex/standards.md` has the full rules.

## Suggested order

1. `Codable` types for `/api/v1/sky-day/timeline`, with a fixture JSON checked in so previews and tests do not need the network.
2. The grid join and interpolation, with its own tests. This is where the subtle bugs live, and it is testable without any UI.
3. `generateSky()` ported verbatim, verified against the prototype: feed both the same conditions and compare hex output. They should agree exactly, since the maths is deterministic.
4. `SkyBackgroundView` switched to `Gradient(stops:)` and fractional geometry, still fed by fixtures.
5. Wire the live fetch behind the existing `AppConfig` seam.
6. Only then consider `TimelineView` for continuous animation.

Step 3 is worth doing as a real check rather than by eye. If the Swift port and the HTML reference disagree on a hex value, one of them is wrong, and it is much cheaper to find that out at step 3 than after the UI is built on top of it.

## Calibration, and how not to break it

The generator was originally fitted to five hand-painted twilight gradients, which produced three separate bugs of the same shape: a parameter fitted at twilight and applied unconditionally across the whole day. The most recent was caught by looking out of a window in Yokohama, where the app rendered a clearly purple sky against a plainly blue-grey one.

The suite in `youki-prototype/checks/` exists so the next one is caught earlier:

```bash
bun run checks/run.mjs        # 15 checks across four reference layers
bun run checks/mutations.mjs  # proves those checks have teeth
```

Every threshold is a claim about the real sky. When one fails, decide whether the model is wrong or the claim is. Both have happened.

If the Swift port changes any constant, change it in the HTML reference too and re-run the suite. Two implementations that have drifted apart are worse than one.

## Known gaps

- **Partly cloudy skies, 25 to 85 percent cloud, have no reference at all.** They are interpolation between the clear-sky oracle and a single overcast photograph. This is the common case and the most likely thing to look wrong.
- **Night and deep twilight below -10 degrees** have no reference beyond continuity and monotonicity.
- We sit about 0.058 in CIE xy more saturated than physics, deliberately. A literally physical clear zenith reads flat on a phone.
- Weather and air quality are hourly. Finer would mean `minutely_15` from Open-Meteo, available for cloud and humidity but not for air quality.
- Cloud bands are three soft masses at fixed heights. They do not drift, and they are not the hand-drawn ellipse clusters of the design prototype.
- The heuristic score in `HeuristicSkyColorEngine` is unchanged and still uses only a subset of the fetched inputs. Mid-level cloud, dew point, PM10 and ozone are fetched and unused.
