# Youki TestFlight build 4

Status: Uploaded; Apple processing and tester availability unverified
Updated: 2026-10-08

## Quick read

Uploaded Youki version 1.0, build 4 to App Store Connect. The app includes the Droplet address and opens its UI before refreshing a saved account, addressing the startup wait. Update from TestFlight after Apple processing and group assignment.

## Changed surface

| Area | Status | Details |
| --- | --- | --- |
| Backend address | Implemented | [AppConfig.swift](../../frontend/YoukiApp/AppConfig.swift) uses the HTTPS Droplet in Release. |
| Startup | Implemented | [ContentView.swift](../../frontend/YoukiApp/ContentView.swift) opens before account refresh. |
| Display name and iPad orientations | Implemented | [Info.plist](../../frontend/YoukiApp/YoukiApp-Info.plist) sets Youki and all four iPad orientations. |
| Build number | Implemented | [Xcode project](../../frontend/YoukiApp/YoukiApp.xcodeproj/project.pbxproj) sets app Debug/Release to build 4. |

## Engineer details

The app retains cached session behavior, while account refresh runs after opening. A session request no longer blocks the startup screen. No backend deployment or invitations were performed. No agents were delegated.

### Verification

- Xcode 27.0 (27A266a), iOS 27.0 SDK.
- Signed Release device archive succeeded.
- Archive metadata confirms jp.youki.YoukiApp, Youki, version 1.0, build 4, iphoneos27.0, and all four iPad orientations.
- Droplet auth configuration returned appleSignInEnabled=false and testLoginEnabled=true.
- Droplet readiness returned HTTP 200, routing/database ok.
- App Store Connect upload returned `Upload succeeded` and `EXPORT SUCCEEDED` at 21:33:46 Japan time.
- No test suites or physical-device walkthrough were run.

Local archive: `/private/tmp/youki-testflight-build4/Youki.xcarchive`.
Local logs: `/private/tmp/youki-build4-archive.log` and `/private/tmp/youki-build4-upload.log`. These temporary paths are not durable repository artifacts.

### Risks and follow-ups

Apple processing, compliance completion, tester group assignment, and physical-device behavior remain unverified. The live weekly API compatibility has not been exercised. Check build 4 in App Store Connect, make it available to the existing tester group, then update Youki on the iPhone. Changes remain local and uncommitted.
