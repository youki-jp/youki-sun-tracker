# Youki account screen

Status: Implemented locally
Updated: 2026-09-28

## Quick read

### What changed

Youki now opens a dedicated full-screen account flow from the forecast or Settings. Signup and sign-in are separate screens, each using the matching native Sign in with Apple control. Signing out switches to sign-in.

### Why it matters

The sample forecast remains available without an account, while new and returning users get a focused entry point for live forecasts. Separate pages make it clear whether someone is creating an account or returning to one.

### Current state

Implemented and visually checked in the iPhone 16 Pro Simulator. Live Apple authentication has not been verified with production credentials.

### Next step

Configure real Apple credentials and test a first sign-in, relaunch, sign-out, and returning sign-in on a device.

## Changed surface

| Area | Status | Details |
| --- | --- | --- |
| Account UI | Implemented | [AccountScreen.swift](../../frontend/YoukiApp/AccountScreen.swift) |
| Navigation | Implemented | [ContentView.swift](../../frontend/YoukiApp/ContentView.swift), [ForecastSheets.swift](../../frontend/YoukiApp/ForecastSheets.swift) |
| UI checks | Updated | [YoukiAppUITests.swift](../../frontend/YoukiApp/YoukiAppUITests/YoukiAppUITests.swift) |
| Xcode source registration | Implemented | [project.pbxproj](../../frontend/YoukiApp/YoukiApp.xcodeproj/project.pbxproj) |

## Engineer details

### Design and decisions

The forecast stays accessible as the Free preview. Signup and sign-in each call the same Apple authorization and existing [AuthSession](../../frontend/YoukiApp/AuthSession.swift); the server creates a Free account on first use and recognizes the same Apple identity later. The account view is a separate SwiftUI source file and is presented with `fullScreenCover`. Test accounts have their own debug-only screen.

### Contracts and flow

The account screen requests a one-use challenge from `POST /api/v1/auth/challenge`, passes the nonce hash to Apple, then sends the Apple result to `POST /api/v1/auth/apple` through `AuthSession`. Youki session tokens remain in Keychain. See [auth implementation](../auth-implementation.md) for the backend contract and remaining deployment work.

### Delegated-agent outcomes

None.

### Verification

| Check | Result | Evidence |
| --- | --- | --- |
| iOS Simulator build | Passed | `xcodebuild ... CODE_SIGNING_ALLOWED=NO build -quiet` exited 0. |
| Manual iPhone 16 Pro check | Passed | Signup and sign-in appeared as separate screens with the matching Apple button labels. Signing out of Pro opened the sign-in screen. |
| `git diff --check` | Passed | No whitespace errors. |
| Focused Xcode UI tests | Not run | The current `YoukiApp` scheme has no test action (`xcodebuild` exit 66). Test assertions were updated but remain unexecuted. |

### Risks and limitations

- The local challenge server used temporary test keys only to render the Apple button. It cannot complete a production Apple sign-in.
- Both screens use Apple identity to create or restore the matching Youki account on the server.

### Follow-ups

- Configure the Xcode scheme's test action and run the updated UI checks.
- Verify live Apple login and session restoration with production credentials.

### Not implemented or unverified

- Password or email login, payment checkout, and live Apple authentication were not added or verified in this change.
