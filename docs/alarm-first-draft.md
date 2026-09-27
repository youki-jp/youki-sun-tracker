# First sunrise alarm

Status: First draft implemented; AlarmKit integration requires Xcode 26 verification
Updated: 2026-09-27

## Quick read

Implementation update: the alarm button now opens a sunrise/sunset setup sheet, with a 0-120 minute lead time (15 minutes by default) before the start of golden hour. It loads actual timeline milestones for today and, when needed, tomorrow. The shared alarm model tracks scheduling/cancellation and durable UUIDs. The iOS-26-only AlarmKit adapter is included behind SDK availability guards, but the installed Xcode 16.4 cannot compile that branch; real ringing is not verified. Older builds show an availability explanation without scheduling a substitute notification.

The sections below preserve the original design context. The implemented scope uses golden-hour start for both events, not a fixed offset from sunrise, and does not expose independent automatic smart-alarm toggles.

Use AlarmKit on iOS 26+ for a Youki-owned system alarm. It provides scheduling and cancellation with user authorization; this design does not modify alarms belonging to Apple's Clock app. Keep iOS 17 compatibility, but show an unavailable explanation for real wake alarms on older systems. Implementation requires Xcode 26; the current installed toolchain is Xcode 16.4.

Apple references: [AlarmKit](https://developer.apple.com/documentation/alarmkit), [sample](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit), [WWDC lifecycle and authorization](https://developer.apple.com/videos/play/wwdc2025/230/).

## Scope and current evidence

Implemented: [LocationManager](../frontend/YoukiApp/LocationManager.swift) requests when-in-use authorization and retrieves coordinates; [ServerViewModel](../frontend/YoukiApp/ServerViewModel.swift) passes them to forecast APIs. No background location is needed for the first alarm.

Prototype: [ContentView](../frontend/YoukiApp/ContentView.swift) stores `wakeEnabled` locally, initially true; [ForecastComponents](../frontend/YoukiApp/ForecastComponents.swift) only toggles it. Settings has an independent smart-alarm toggle in [ForecastSheets](../frontend/YoukiApp/ForecastSheets.swift). Neither creates an alarm.

Proposed first scope: one explicitly scheduled future sunrise alarm, with a confirmed time, default system sound, and Stop action. No snooze/countdown, automatic recurring forecast decisions, Clock alarm editing, or subscriptions. Keep the advanced smart-alarm setting visibly unavailable until it has real behavior.

Assumption: initial suggested time is 30 minutes before sunrise, editable before scheduling. This is a product default, not an implemented best-color peak; the backend does not supply an explicit peak instant. Unknown: user's preferred lead time and minimum supported iOS for alarm functionality.

## Ownership and flow

- Add a Foundation `WakeAlarmRequest` containing UUID, absolute fire date, forecast location timezone ID, event date, and lead minutes. Resolve backend local event timestamps using the forecast's timezone, never the server/device default timezone. Require a live sunrise and a future time; do not schedule from sample fallback data or nullable polar events.
- Add an `AlarmScheduling` interface for authorization, scheduling, cancellation, and system-state reconciliation. Add an iOS-26-only `AlarmKitScheduler` behind availability guards. This needs Xcode 26 even when the deployment target stays 17.
- Add a main-actor `WakeAlarmViewModel`; it owns busy state, confirmed scheduled time, error messages, and one shared state for all alarm controls. Views issue commands rather than optimistically toggling local booleans.
- Add a small Codable local store for the alarm UUID and scheduling metadata. Do not persist precise coordinates for this feature. No backend alarm endpoint is needed.
- Add `NSAlarmKitUsageDescription` to [Info.plist](../frontend/YoukiApp/YoukiApp-Info.plist). Request permission only when the user explicitly enables an alarm.

Enable flow: select a valid future event -> show exact alarm date/time and location -> request authorization -> call `AlarmManager.shared.schedule(id:configuration:)` with a fixed schedule and alert-only presentation -> persist success -> show On and the confirmed time.

Disable flow: call `cancel(id:)` for the stored UUID -> update the store and UI after success. Do not use pause to disable a scheduled wake alarm. No backend refresh is required to cancel.

## State, failures, and persistence

States: unavailable, off, authorizing, scheduling, scheduled, cancelling, reconciliation required. Busy operations disable repeated taps. Permission denial or scheduling failure leaves the control off with a readable error. Cancellation failure retains the scheduled state with Retry. Reconcile on launch/foreground and observe system alarm/authorization changes so dismissal or revocation cannot leave a misleading On label.

Persist the UUID before invoking scheduling as a pending operation, then mark confirmed on success. Reconcile pending records against system alarms after process interruption. If persistence fails after system scheduling, keep the returned UUID in memory, report the failure, and attempt cancellation; never claim success for an untracked alarm. An absent system alarm clears a confirmed record.

Treat the scheduled absolute time as a user commitment. Forecast refresh, location changes, and timezone changes must not silently move or cancel it. Display the existing alarm with its original location/timezone context; require explicit cancellation before replacing it in this draft. Expired sunrise requires loading a future target day via the existing API or an explicit user-selected future time; today's sample calendar is insufficient.

## Ordered implementation slices

1. Install/use Xcode 26 and compile a minimal availability-gated AlarmKit adapter. Add new Swift files to the explicit Xcode project source entries. Acceptance: app still builds for iOS 17, alarm feature is gated to 26.
2. Implement date resolution, request validation, durable UUID tracking, and scheduling state with a fake scheduler. Acceptance: denied permission, failures, duplicate taps, past times, polar nulls, and process-interruption reconciliation produce truthful state.
3. Replace the wake boolean and independent settings preview with shared model state; add time confirmation. Acceptance: On appears only for a confirmed system alarm, Off cancels it, and manual location changes preserve the previously confirmed alarm.
4. Integrate the adapter and system updates. Acceptance: a short test alarm rings on a physical iOS 26 device with the app closed; cancel prevents firing; relaunch reconciles dismissal and authorization changes.

## Alternatives, risks, and rollout

Local notifications can support reminders on iOS 17-25, but are not an equivalent wake alarm: they depend on notification settings and do not offer AlarmKit's silent-mode/Focus behavior. Do not silently substitute one for the other. Shortcuts-based Clock actions require a separate user workflow and do not give this app an owned alarm lifecycle.

AlarmKit fixed schedules represent absolute instants, appropriate for a specific sunrise. Background forecast recalculation is deferred because iOS background execution cannot be assumed at an exact time. Snooze/countdown would require a Live Activity extension and is deferred. Enable only after physical-device testing; disable new scheduling if problems arise while retaining cancellation for existing alarms.

## Verification

Currently verified: location integration and preview alarm controls inspected in source; Apple documentation consulted. AlarmKit code is not implemented or tested.

Required: deterministic timezone/DST/past-event tests; state-machine and persistence failures with a fake scheduler; Xcode 26 simulator build and iOS 17 availability check; physical-device locked-screen/closed-app, silent mode, Focus, cancellation, relaunch, timezone change, and permission-denial checks. Verify that no sample forecast can enable a real alarm.
