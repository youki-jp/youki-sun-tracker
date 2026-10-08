# TestFlight build 4 startup watchdog and build 5 fix

Status: Uploaded as build 5; Apple processing in progress
Updated: 2026-10-08

## Quick read

### What changed

The iPhone crash report for TestFlight 1.0 (4) symbolicates to Youki's AlarmKit update listener, which was started during app initialization. Alarm observation now starts only when an alarm exists; reconciliation runs when the alarm screen opens. Build 5 also declares that the app uses no non-exempt encryption.

### Why it matters

The app was killed by iOS's 10-second scene-update watchdog while waiting on AlarmKit. The report does not implicate the Droplet request.

### Current state

Version 1.0, build 5 uploaded successfully to App Store Connect and is processing. The fix builds in Release and the app stays running in the iOS 18.6 simulator while configured for the Droplet. The iPhone report came from iOS 26.2; that exact runtime and the authenticated forecast path have not been reproduced locally.

### Next step

Wait for Apple processing to finish, then update Youki from TestFlight and verify on the iPhone.

## Changed surface

| Area | Status | Details |
| --- | --- | --- |
| App startup | Implemented | [`ContentView.swift`](../../frontend/YoukiApp/ContentView.swift) no longer reconciles AlarmKit at startup or on every foreground transition. |
| Alarm state | Implemented | [`GoldenHourAlarm.swift`](../../frontend/YoukiApp/GoldenHourAlarm.swift) starts update observation only after an alarm is confirmed or reconciled. |
| Alarm screen | Implemented | [`GoldenHourAlarmSheet.swift`](../../frontend/YoukiApp/GoldenHourAlarmSheet.swift) reconciles when opened. |
| Alarm update stream | Implemented | [`AlarmKitScheduler.swift`](../../frontend/YoukiApp/AlarmKitScheduler.swift) yields once before subscribing, so the request does not begin inline with its creation. |
| Export declaration | Implemented | [`YoukiApp-Info.plist`](../../frontend/YoukiApp/YoukiApp-Info.plist) sets `ITSAppUsesNonExemptEncryption` to `false`, avoiding repeated export-compliance questions for this app's encryption use. |

## Engineer details

### Design and decisions

- The crash report is build 4 on iPhone 14 / iOS 26.2. It records `EXC_CRASH` / `SIGKILL`, FrontBoard watchdog code `0x8BADF00D`, and a 10-second `scene-update` timeout.
- The report's app UUID matches the build 4 archive dSYM. `atos` maps the app frame to `SystemAlarmScheduler.updates()` at `AlarmKitScheduler.swift:68` (before this change), specifically access to `AlarmManager.shared.alarmUpdates`.
- Keep alarm reconciliation scoped to alarm use. The forecast screen doesn't need to query AlarmKit.

### Contracts and flow

The view model reconciles stored alarm state when the alarm sheet opens. It observes AlarmKit updates only while an alarm is active, then stops observing when the alarm is removed. See the view model and scheduler links above.

### Delegated-agent outcomes

None.

### Verification

| Check | Result | Evidence |
| --- | --- | --- |
| Release simulator build | Passed | Xcode 27.0, iOS 27.0 SDK; `xcodebuild -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' ... build` completed with `BUILD SUCCEEDED`. |
| Release launch and backend configuration | Passed | On iOS 18.6 simulator, the app remained running and rendered the test-account sign-in screen with `BACKEND_URL` set to the Droplet. |
| Droplet readiness | Passed | `GET https://206.189.178.229.sslip.io/api/v1/health/ready` returned HTTP 200; routing and database checks were `ok`. |
| Archive | Passed | `/private/tmp/youki-testflight-build5/Youki.xcarchive` contains `jp.youki.YoukiApp`, display name Youki, version 1.0, build 5, `iphoneos27.0`, team `3U39S7T8GK`, and `ITSAppUsesNonExemptEncryption=false`. |
| App Store Connect upload | Passed | Xcode reported `Upload succeeded`, `Uploaded YoukiApp`, and `EXPORT SUCCEEDED` at 21:59 Japan time on 2026-10-08. Apple reported the package is processing. |
| Auth configuration | Passed | `GET /api/v1/auth/config` returned HTTP 200 with temporary test login enabled and Apple sign-in disabled. |
| iOS 26.2 device reproduction | Unverified | No physical iPhone was connected; simulator runtimes available here were iOS 18.6 and 27.0. |
| Authenticated forecast flow | Unverified | No account session was installed in the simulator. |
| Regression suites | Not run | No test suite was requested. |

### Risks and limitations

- Apple processing, tester-group availability, and installation of build 5 remain unverified. Build 4 is the last confirmed processed build.
- AlarmKit status is refreshed when the alarm screen opens. External alarm changes while that screen is not open are handled the next time it is opened.

### Follow-ups

- Confirm build 5 finishes processing and appears in TestFlight; install it and confirm startup on the user's iPhone.
- After sign-in, verify that live forecast loading completes.

### Not implemented or unverified

- No backend deployment, tester-group assignment, or tester invitations were performed.
- The report establishes the startup watchdog path; it does not prove every subsequent forecast request succeeds.
