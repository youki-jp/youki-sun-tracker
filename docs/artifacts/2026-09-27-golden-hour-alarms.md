# Golden-hour alarm first draft

Date: 2026-09-27
Status: Code implemented; AlarmKit SDK build and physical ringing unverified

## Quick read

The alarm button opens a sunrise/sunset setup sheet with a lead time of 0-120 minutes, defaulting to 15. It finds the actual golden-hour start for today or tomorrow, displays the proposed alarm time in the forecast timezone, and schedules one app-owned system alarm after confirmation and permission. Turning it off cancels the alarm. Existing confirmed alarms retain their time when location or forecast data changes.

The installed Xcode 16.4 builds and verifies the older-system availability path. It cannot compile the AlarmKit branch. To finish runtime verification, build with Xcode 26+ and test on a physical iOS 26+ device. This build does not schedule a ringing alarm or substitute a notification.

## Changed surfaces

| Surface | Status | Source |
| --- | --- | --- |
| Setup and alarm controls | Implemented | [Setup sheet](../../frontend/YoukiApp/GoldenHourAlarmSheet.swift), [main button](../../frontend/YoukiApp/ForecastComponents.swift), [Settings](../../frontend/YoukiApp/ForecastSheets.swift) |
| Event planning | Implemented and regression tested | [Planner](../../frontend/YoukiApp/GoldenHourAlarmPlanner.swift), [tests](../../frontend/YoukiApp/Tests/AlarmPlannerRegression.swift) |
| Shared state and local storage | Implemented and regression tested | [Model](../../frontend/YoukiApp/GoldenHourAlarm.swift), [tests](../../frontend/YoukiApp/Tests/AlarmRegression.swift) |
| System alarm integration | Implemented, iOS 26 branch uncompiled | [Adapter](../../frontend/YoukiApp/AlarmKitScheduler.swift), [permission description](../../frontend/YoukiApp/YoukiApp-Info.plist) |
| Availability UI | Verified on iOS 18.6 | [Focused UI test](../../frontend/YoukiApp/YoukiAppUITests/YoukiAppUITests.swift) |
| Design and usage | Updated | [Design/status](../alarm-first-draft.md), [frontend README](../../frontend/README.md) |

## Decisions and data flow

The setup loads fresh day timelines independently of the selected sky illustration. It resolves the sunrise `goldenHourStartIso` or sunset `goldenHourPmStartIso` using the returned timezone and subtracts the chosen lead in elapsed minutes. Invalid dates, ambiguous/nonexistent daylight-saving times, incorrect returned days, and changed coordinates/timezones are rejected. If today's fire time has passed or its milestone is null, tomorrow is checked; no event across those two days produces a readable explanation. Cancelled or superseded requests cannot publish a stale preview.

Alarm scheduling validates the future time again after authorization. A pending UUID is saved before calling the system, then confirmed after successful scheduling. Persisted records are reconciled with system alarms before showing On. Cancellation failures preserve the existing scheduled state. Unconfirmed records expose recheck/cancel actions, and unreadable storage blocks new scheduling rather than losing the previous UUID. System alarm updates and launch/foreground reconciliation keep the UI current.

The adapter uses AlarmKit's traditional `.alarm(schedule:attributes:)` factory with a fixed date, default system sound, and Stop action. No countdown or snooze Live Activity is introduced. Official references: [AlarmKit](https://developer.apple.com/documentation/alarmkit), [scheduling sample](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit), [system alarm query](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarms).

## Verification evidence

- Generic iOS Simulator app build with Xcode 16.4: **BUILD SUCCEEDED**. The iOS 26 conditional branch is excluded by this SDK.
- Parent-run `AlarmRegression.swift`: passed under `TZ=Asia/Tokyo` and `TZ=America/Los_Angeles`. Covers timezone/DST, denied permission, scheduling/storage/cancellation failures, corrupt saved data, duplicate commands, pending recovery, relaunch, unknown state, and foreground dismissal.
- Parent-run `AlarmPlannerRegression.swift`: passed. Covers today/tomorrow, lead-time cutoff, sunset selection, null events, invalid day/timezone/coordinates, malformed milestones, lead validation before network, and cancellation.
- Final focused `testGoldenHourAlarmOnOlderIOS` on iPhone 16 Pro / iOS 18.6: **TEST SUCCEEDED**, with no schedule action or confirmed alarm shown. An earlier successful run's exported screenshot was visually inspected; the setup is legible and contained. Test logs and screenshots are temporary local artifacts under `/tmp/youki-alarm-*`.
- `git diff --check`: passed.

Two implementation agents contributed disjoint files: `alarm_core` owned the model, adapter, and state regressions; `alarm_preview` owned the planner and its regressions. The parent integrated and reviewed them, owned the UI/project/documentation changes, and reran verification.

## Remaining work and limits

- Required: compile the actual AlarmKit branch with Xcode 26+ and verify authorization, ringing, Stop, cancellation, app closed/locked, silent mode, Focus, and relaunch on a physical iOS 26+ device. Source review against Apple documentation is not a substitute for this build/device evidence.
- One alarm is supported at a time; no automatic daily rescheduling, notification fallback, snooze, or Clock-app alarm editing.
- The forecast screen still loads one live day; the alarm planner's additional tomorrow request does not implement a seven-day calendar.
- Source changes are uncommitted on `feature/golden-hour-alarms`. The earlier sky-sheet corner fix is preserved.
