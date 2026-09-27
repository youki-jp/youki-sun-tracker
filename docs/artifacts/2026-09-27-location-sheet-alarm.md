# Location sheet and alarm draft

Date: 2026-09-27
Status: UI fix implemented; alarm design proposed

## Quick read

Removed the app's extra top-corner clipping so the sky fills the system-rounded surface behind a modal sheet. Device latitude/longitude access was already implemented and remains in place. The first alarm draft uses AlarmKit on iOS 26+, with confirmed scheduling and cancellation; implementation requires Xcode 26.

## Changed surfaces

| Surface | Status | Reference |
| --- | --- | --- |
| Root sky presentation | Implemented | [ContentView](../../frontend/YoukiApp/ContentView.swift) |
| Device coordinates | Existing, inspected | [LocationManager](../../frontend/YoukiApp/LocationManager.swift), [ServerViewModel](../../frontend/YoukiApp/ServerViewModel.swift) |
| First alarm | Proposed | [Implementation-ready design](../alarm-first-draft.md) |

## Decisions and verification

The system supplies rounded corners when presenting sheets; the additional 32-point app clip exposed the cream root background inside that surface. Removing it preserves the contained sky/panel layout while eliminating the extra corners.

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project frontend/YoukiApp/YoukiApp.xcodeproj -scheme YoukiApp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/youki-derived build CODE_SIGNING_ALLOWED=NO`: BUILD SUCCEEDED.

Installed and launched the build using `-uiSkyFixture` on the booted iPhone 16 Pro / iOS 18.6 Simulator. Visually inspected the Locations sheet in dark and light themes: the exposed top sky strip has no cream corner wedges. Synthetic scene data isolates rendering; it does not verify device GPS or live backend availability. No agents were delegated work.

## Remaining work

Follow-up: the first alarm draft has since been implemented. See the [alarm implementation handover](2026-09-27-golden-hour-alarms.md) for current behavior, verification, and the remaining Xcode 26/device checks. The paragraph below records the state at the time of the UI fix.

Alarm code is not implemented. Current wake/smart-alarm controls remain previews. Follow the alarm design for toolchain upgrade, shared alarm state, system scheduling, persistence, and physical iOS 26 device verification. Actual iPhone GPS was not exercised in this task.
