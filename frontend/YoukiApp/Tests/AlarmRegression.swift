import Foundation

@MainActor private final class FakeScheduler: AlarmScheduling {
    var unavailableReason: String?
    var ids: Set<UUID> = []
    var denied = false
    var failSchedule = false
    var failCancel = false
    var failQuery = false
    var delay = false
    var calls = 0
    var continuation: AsyncStream<Set<UUID>>.Continuation?
    func updates() -> AsyncStream<Set<UUID>> { AsyncStream { continuation = $0 } }
    func authorize() async throws {
        if delay { try await Task.sleep(nanoseconds: 20_000_000) }
        if denied { throw GoldenHourAlarmError.message("Denied") }
    }
    func schedule(_ request: GoldenHourAlarmRequest) async throws {
        calls += 1
        if failSchedule { throw GoldenHourAlarmError.message("Schedule failed") }
        ids.insert(request.id)
    }
    func cancel(id: UUID) throws {
        if failCancel { throw GoldenHourAlarmError.message("Cancel failed") }
        ids.remove(id)
    }
    func scheduledIDs() throws -> Set<UUID> {
        if failQuery { throw GoldenHourAlarmError.message("Query failed") }
        return ids
    }
}

@MainActor private final class MemoryStore: GoldenHourAlarmStoring {
    var value: GoldenHourAlarmRecord?
    var fail = false
    var failLoad = false
    var failConfirmation = false
    func load() throws -> GoldenHourAlarmRecord? {
        if failLoad { throw GoldenHourAlarmError.message("Load failed") }
        return value
    }
    func save(_ record: GoldenHourAlarmRecord?) throws {
        if fail || (failConfirmation && record?.confirmed == true) {
            throw GoldenHourAlarmError.message("Store failed")
        }
        value = record
    }
}

@main struct AlarmRegression {
    @MainActor static func main() async throws {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let request = try GoldenHourAlarmRequest.make(event: .sunrise, localIso: "2026-10-01T05:30:00",
             timezoneID: "Asia/Tokyo", locationName: "Tokyo", leadMinutes: 15, now: now)
        let iso = ISO8601DateFormatter()
        precondition(iso.string(from: request.fireDate) == "2026-09-30T20:15:00Z")
        for (value, zone) in [("2026-03-08T02:30:00", "America/New_York"),
                              ("2026-11-01T01:30:00", "America/New_York"),
                              ("2026-02-30T12:00:00", "Asia/Tokyo"),
                              ("2026-10-01T25:30:00", "Asia/Tokyo"),
                              ("2026-10-01T05:30:00Z", "Asia/Tokyo"),
                              ("2026-10-01T05:30:00", "Invalid/Zone")] {
            do { _ = try GoldenHourAlarmDate.resolve(localIso: value, timezoneID: zone); fatalError("Accepted invalid time: \(value)") }
            catch { }
        }
        let scheduler = FakeScheduler()
        let store = MemoryStore()
        let model = GoldenHourAlarmViewModel(scheduler: scheduler, store: store, now: { now })
        scheduler.denied = true
        await model.schedule(request)
        precondition(model.scheduled == nil && model.errorMessage != nil && store.value == nil)
        scheduler.denied = false
        scheduler.failSchedule = true
        await model.schedule(request)
        precondition(model.scheduled == nil && store.value == nil)
        scheduler.failSchedule = false
        store.fail = true
        await model.schedule(request)
        precondition(scheduler.ids.isEmpty)
        store.fail = false
        scheduler.delay = true
        async let first: Void = model.schedule(request)
        async let second: Void = model.schedule(request)
        _ = await (first, second)
        precondition(scheduler.calls == 2 && model.scheduled == request && !model.isBusy)
        let relaunched = GoldenHourAlarmViewModel(scheduler: scheduler, store: store, now: { now })
        precondition(relaunched.scheduled == nil)
        await relaunched.reconcile()
        precondition(relaunched.scheduled == request)
        scheduler.failCancel = true
        await relaunched.cancel()
        precondition(relaunched.scheduled == request && store.value != nil)
        scheduler.failCancel = false
        await relaunched.cancel()
        precondition(relaunched.scheduled == nil && store.value == nil && scheduler.ids.isEmpty)
        // Process dies after system scheduling but before confirmation save.
        store.value = GoldenHourAlarmRecord(request: request, confirmed: false)
        scheduler.ids.insert(request.id)
        let pending = GoldenHourAlarmViewModel(scheduler: scheduler, store: store, now: { now })
        await pending.reconcile()
        precondition(pending.scheduled == request && store.value?.confirmed == true)
        scheduler.ids.removeAll()
        await pending.reconcile()
        precondition(pending.scheduled == nil && store.value == nil)
        let past = GoldenHourAlarmViewModel(scheduler: scheduler, store: store, now: { request.fireDate })
        await past.schedule(request)
        precondition(past.scheduled == nil && past.errorMessage != nil)
        let invalid = GoldenHourAlarmRequest(id: UUID(), event: .sunset, goldenHourDate: request.goldenHourDate,
            fireDate: request.fireDate, timezoneID: "Asia/Tokyo", locationName: "Tokyo", leadMinutes: 121)
        await model.schedule(invalid)
        precondition(model.errorMessage != nil)
        store.failConfirmation = true
        await pending.schedule(request)
        precondition(pending.scheduled == request && store.value?.confirmed == false && pending.errorMessage != nil)
        store.failConfirmation = false
        await pending.reconcile()
        precondition(store.value?.confirmed == true)
        // Failure to read storage must not overwrite a potentially live UUID.
        let unreadableStore = MemoryStore()
        unreadableStore.value = GoldenHourAlarmRecord(request: request, confirmed: true)
        unreadableStore.failLoad = true
        let unreadableScheduler = FakeScheduler()
        let unreadable = GoldenHourAlarmViewModel(scheduler: unreadableScheduler, store: unreadableStore, now: { now })
        await unreadable.schedule(request)
        precondition(unreadableScheduler.calls == 0 && unreadableStore.value?.request.id == request.id && unreadable.errorMessage != nil)
        unreadableStore.failLoad = false
        unreadableScheduler.ids.insert(request.id)
        await unreadable.reconcile()
        precondition(unreadable.scheduled == request)
        // Pending UUID remains available for cancellation if daemon queries fail.
        let uncertainStore = MemoryStore()
        uncertainStore.value = GoldenHourAlarmRecord(request: request, confirmed: false)
        let uncertainScheduler = FakeScheduler()
        uncertainScheduler.failQuery = true
        uncertainScheduler.ids.insert(request.id)
        let uncertain = GoldenHourAlarmViewModel(scheduler: uncertainScheduler, store: uncertainStore, now: { now })
        await uncertain.reconcile()
        precondition(uncertain.scheduled == nil && uncertain.unconfirmed == request && uncertain.errorMessage != nil)
        await uncertain.cancel()
        precondition(uncertain.unconfirmed == nil && uncertainStore.value == nil && uncertainScheduler.ids.isEmpty)
        // Corrupt durable data also refuses to schedule.
        let suiteName = "youki.alarm.regression.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("broken JSON".utf8), forKey: "youki.goldenHourAlarm.v1")
        let corruptScheduler = FakeScheduler()
        let corrupt = GoldenHourAlarmViewModel(scheduler: corruptScheduler, store: UserDefaultsGoldenHourAlarmStore(defaults: defaults), now: { now })
        await corrupt.schedule(request)
        precondition(corruptScheduler.calls == 0 && corrupt.errorMessage != nil)
        // Foreground system dismissal updates the visible state without relaunching.
        let observerScheduler = FakeScheduler()
        let observerStore = MemoryStore()
        let observer = GoldenHourAlarmViewModel(scheduler: observerScheduler, store: observerStore, now: { now })
        await observer.schedule(request)
        precondition(observer.scheduled == request)
        observerScheduler.ids.removeAll()
        observerScheduler.continuation?.yield(observerScheduler.ids)
        try await Task.sleep(nanoseconds: 20_000_000)
        precondition(observer.scheduled == nil && observerStore.value == nil)
        print("Alarm regressions passed (timezone/DST, denial, failures, persistence, duplicate commands, reconciliation).")
    }
}
