# Youki usability fixes and Japanese localization

Status: Uploaded to TestFlight; Apple processing
Updated: 2026-10-08

## Quick read

### What changed

The iPhone app is portrait-only, event rows accept taps across their full width, confirmed alarms show immediately without a blocking status query, and returning to Youki selects the current moment. Selecting Japanese now localizes the forecast, calendar, alarm, account, sign-in, and location screens.

### Why it matters

These changes address the first usability issues noticed during TestFlight use and make the language preference apply throughout the app.

### Current state

Version 1.0 build 6 was archived, validated locally, and uploaded to App Store Connect. Apple reports that the package is processing. The archive includes the Japanese localization resource and portrait-only iPhone orientation.

### Next step

After Apple finishes processing, update Youki from TestFlight and check the four reported behaviors on the iPhone.

## Changed surface

| Area | Status | Details |
| --- | --- | --- |
| Orientation and event selection | Implemented | [YoukiApp-Info.plist](../../frontend/YoukiApp/YoukiApp-Info.plist) allows portrait on iPhone; [ForecastComponents.swift](../../frontend/YoukiApp/ForecastComponents.swift) makes each event row fill and hit-test its available width. |
| Alarm status | Implemented | [GoldenHourAlarm.swift](../../frontend/YoukiApp/GoldenHourAlarm.swift), [AlarmKitScheduler.swift](../../frontend/YoukiApp/AlarmKitScheduler.swift), and [GoldenHourAlarmSheet.swift](../../frontend/YoukiApp/GoldenHourAlarmSheet.swift) render confirmed saved alarms immediately and apply AlarmKit update snapshots. |
| Current time selection | Implemented | [ServerViewModel.swift](../../frontend/YoukiApp/ServerViewModel.swift) selects Now on app activation and after forecast loads. |
| Japanese UI | Implemented | [AppLocalization.swift](../../frontend/YoukiApp/AppLocalization.swift), [ja.lproj/Localizable.strings](../../frontend/YoukiApp/ja.lproj/Localizable.strings), and the root locale environment apply the chosen language across screens. |
| Release | Uploaded | Version 1.0 build 6; archive at /private/tmp/youki-testflight-build6/Youki.xcarchive. |

## Engineer details

### Design and decisions

- Existing confirmed alarm records are displayed from local storage when the alarm sheet opens. The sheet no longer queries AlarmManager.alarms for a confirmed record before showing its state.
- Alarm change events use the alarm array emitted by AlarmManager.alarmUpdates, so Youki can reconcile state from that snapshot instead of querying the daemon again for each update.
- appLanguage drives both SwiftUI's locale environment and AppLocalization string lookup. Date labels use the selected locale where they are formatted for display.
- The uploaded app uses iOS 27.0 SDK. Apple's current upload requirement is Xcode 26 or later with iOS 26 SDK or later: [SDK minimum requirements](https://developer.apple.com/news/upcoming-requirements/?id=04282026a).

### Contracts and flow

The app stores the selected language in appLanguage. Static SwiftUI strings resolve through the Japanese Localizable.strings resource. Dynamic event, date, forecast, and error labels use AppLocalization where their text is created or presented.

### Delegated-agent outcomes

None.

### Verification

| Check | Result | Evidence |
| --- | --- | --- |
| Japanese strings and project/plist syntax | Passed | plutil -lint accepted Localizable.strings, YoukiApp-Info.plist, and YoukiApp.xcodeproj/project.pbxproj. |
| Release archive | Passed | Xcode 27.0 archived version 1.0, build 6, bundle jp.youki.YoukiApp, SDK iphoneos27.0. |
| Archive configuration | Passed | App display name Youki; iPhone orientation portrait only; iPad portrait, upside-down portrait, and both landscapes; ITSAppUsesNonExemptEncryption=false; team 3U39S7T8GK. |
| Japanese resource in archive | Passed | ja.lproj/Localizable.strings is present in the archived app. |
| App Store Connect upload | Passed | Xcode reported “Upload succeeded” and “Uploaded YoukiApp” at 22:24 JST; package was processing at upload completion. |
| git diff --check | Passed | No whitespace errors. |
| Automated tests and on-device interaction | Not run | No test suite or physical-device UI check was requested/performed. Verify behavior on the iPhone after processing. |

### Risks and limitations

- App Store Connect processing and availability to tester groups are not yet confirmed. This upload did not assign groups or send invitations.
- The sandboxed build attempt could not load Xcode's SwiftUI macro plugin. The signed Release archive succeeded when Xcode was run with access to its build services.
- Forecast reasons supplied as arbitrary server text may remain English; the app-owned interface labels and standard error messages have Japanese translations.

### Follow-ups

- Install build 6 from TestFlight after processing and check portrait lock, alarm sheet behavior, full-row event taps, current-time selection, and Japanese UI.

### Not implemented or unverified

- No backend deployment, tester-group assignment, external beta review, or tester invitations were performed.
- Japanese rendering has not yet been visually checked on the physical iPhone.
