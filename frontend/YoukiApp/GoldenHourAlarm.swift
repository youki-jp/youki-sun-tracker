import Foundation
import Combine

enum GoldenHourAlarmEvent: String, Codable, CaseIterable, Identifiable {
    case sunrise, sunset
    var id: String { rawValue }
    var label: String { self == .sunrise ? "Sunrise" : "Sunset" }
}

struct GoldenHourAlarmRequest: Codable, Equatable, Identifiable {
    let id: UUID
    let event: GoldenHourAlarmEvent
    let goldenHourDate: Date
    let fireDate: Date
    let timezoneID: String
    let locationName: String
    let leadMinutes: Int

    static func make(event: GoldenHourAlarmEvent, localIso: String, timezoneID: String,
                     locationName: String, leadMinutes: Int, now: Date) throws -> Self {
        let date = try GoldenHourAlarmDate.resolve(localIso: localIso, timezoneID: timezoneID)
        let request = Self(id: UUID(), event: event, goldenHourDate: date,
                           fireDate: date.addingTimeInterval(-Double(leadMinutes) * 60),
                           timezoneID: timezoneID, locationName: locationName, leadMinutes: leadMinutes)
        try request.validate(now: now)
        return request
    }

    func validate(now: Date) throws {
        guard (0...120).contains(leadMinutes), TimeZone(identifier: timezoneID) != nil,
              goldenHourDate.timeIntervalSinceReferenceDate.isFinite,
              fireDate.timeIntervalSinceReferenceDate.isFinite,
              abs(goldenHourDate.timeIntervalSince(fireDate) - Double(leadMinutes) * 60) < 0.01 else {
            throw GoldenHourAlarmError.message("Choose a valid lead time between 0 and 120 minutes.")
        }
        guard fireDate > now else {
            throw GoldenHourAlarmError.message("This alarm time has passed. Choose the next golden hour.")
        }
    }
}

enum GoldenHourAlarmError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}

enum GoldenHourAlarmDate {
    // Backend timestamps have no offset; resolve strictly in the forecast timezone.
    static func resolve(localIso: String, timezoneID: String) throws -> Date {
        guard let zone = TimeZone(identifier: timezoneID),
              localIso.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$"#, options: .regularExpression) != nil else {
            throw GoldenHourAlarmError.message("The forecast has an invalid golden-hour time or timezone.")
        }
        let format = localIso.count == 16 ? "yyyy-MM-dd'T'HH:mm" : "yyyy-MM-dd'T'HH:mm:ss"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        formatter.isLenient = false
        guard let wallDate = formatter.date(from: localIso), formatter.string(from: wallDate) == localIso else {
            throw GoldenHourAlarmError.message("The forecast has an invalid golden-hour time.")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: wallDate)
        let anchor = wallDate.addingTimeInterval(-48 * 3600)
        guard let first = calendar.nextDate(after: anchor, matching: parts, matchingPolicy: .strict,
                                            repeatedTimePolicy: .first),
              let last = calendar.nextDate(after: anchor, matching: parts, matchingPolicy: .strict,
                                           repeatedTimePolicy: .last), first == last else {
            throw GoldenHourAlarmError.message("The forecast time is missing or ambiguous because of a clock change.")
        }
        formatter.timeZone = zone
        guard formatter.string(from: first) == localIso else {
            throw GoldenHourAlarmError.message("The forecast time does not exist in this timezone.")
        }
        return first
    }
}

@MainActor protocol AlarmScheduling {
    var unavailableReason: String? { get }
    func authorize() async throws
    func schedule(_ request: GoldenHourAlarmRequest) async throws
    func cancel(id: UUID) throws
    func scheduledIDs() throws -> Set<UUID>
    func updates() -> AsyncStream<Void>
}

extension AlarmScheduling {
    func updates() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}

struct GoldenHourAlarmRecord: Codable {
    let request: GoldenHourAlarmRequest
    let confirmed: Bool
}

@MainActor protocol GoldenHourAlarmStoring {
    func load() throws -> GoldenHourAlarmRecord?
    func save(_ record: GoldenHourAlarmRecord?) throws
}

@MainActor final class UserDefaultsGoldenHourAlarmStore: GoldenHourAlarmStoring {
    private let defaults: UserDefaults
    private let key = "youki.goldenHourAlarm.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() throws -> GoldenHourAlarmRecord? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(GoldenHourAlarmRecord.self, from: data)
    }
    func save(_ record: GoldenHourAlarmRecord?) throws {
        if let record { defaults.set(try JSONEncoder().encode(record), forKey: key) }
        else { defaults.removeObject(forKey: key) }
        // Commit the pending UUID before handing scheduling to the system.
        guard defaults.synchronize() else { throw GoldenHourAlarmError.message("Could not save alarm state. Please retry.") }
    }
}

@MainActor final class GoldenHourAlarmViewModel: ObservableObject {
    @Published private(set) var scheduled: GoldenHourAlarmRequest?
    @Published private(set) var isBusy = false
    @Published private(set) var errorMessage: String?
    var unavailableReason: String? { scheduler.unavailableReason }
    var unconfirmed: GoldenHourAlarmRequest? { scheduled == nil ? record?.request : nil }
    private let scheduler: any AlarmScheduling
    private let store: any GoldenHourAlarmStoring
    private let now: () -> Date
    @Published private var record: GoldenHourAlarmRecord?
    private var storageReadFailed = false
    private var observationTask: Task<Void, Never>?
    private var needsReconciliation = false

    init(scheduler: (any AlarmScheduling)? = nil, store: (any GoldenHourAlarmStoring)? = nil,
         now: @escaping () -> Date = Date.init) {
        self.scheduler = scheduler ?? SystemAlarmScheduler()
        self.store = store ?? UserDefaultsGoldenHourAlarmStore()
        self.now = now
        do { record = try self.store.load() }
        catch { storageReadFailed = true; errorMessage = error.localizedDescription }
        // Persisted state is not a system confirmation; reconcile before displaying On.
        let updates = self.scheduler.updates()
        observationTask = Task { [weak self] in
            for await _ in updates {
                guard !Task.isCancelled else { return }
                await self?.reconcile()
            }
        }
    }

    deinit { observationTask?.cancel() }

    func schedule(_ request: GoldenHourAlarmRequest) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { finishCommand() }
        do {
            if let reason = unavailableReason { throw GoldenHourAlarmError.message(reason) }
            try reconcileState()
            guard record == nil else { throw GoldenHourAlarmError.message("Cancel your existing alarm before setting another.") }
            try request.validate(now: now())
            try await scheduler.authorize()
            try request.validate(now: now())
            let pending = GoldenHourAlarmRecord(request: request, confirmed: false)
            try store.save(pending)
            record = pending
            do { try await scheduler.schedule(request) }
            catch {
                // A failed call may still have reached the system; resolve the saved UUID.
                try? reconcileState()
                throw error
            }
            scheduled = request
            let confirmed = GoldenHourAlarmRecord(request: request, confirmed: true)
            do { try store.save(confirmed); record = confirmed }
            catch {
                // The pending UUID remains durable even if the confirmation write fails.
                throw GoldenHourAlarmError.message("Alarm was scheduled, but its saved confirmation failed. Check or cancel it here.")
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func cancel() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { finishCommand() }
        do {
            guard let request = record?.request ?? scheduled else { return }
            try scheduler.cancel(id: request.id)
            scheduled = nil
            try store.save(nil)
            record = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func reconcile() async {
        guard !isBusy else { needsReconciliation = true; return }
        isBusy = true
        defer { finishCommand() }
        do { try reconcileState(); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }

    private func finishCommand() {
        isBusy = false
        if needsReconciliation {
            needsReconciliation = false
            do { try reconcileState() }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private func reconcileState() throws {
        if storageReadFailed {
            record = try store.load()
            storageReadFailed = false
        }
        guard let record else { return }
        let ids = try scheduler.scheduledIDs()
        if ids.contains(record.request.id) {
            scheduled = record.request
            if !record.confirmed {
                let confirmed = GoldenHourAlarmRecord(request: record.request, confirmed: true)
                try store.save(confirmed)
                self.record = confirmed
            }
        } else {
            scheduled = nil
            try store.save(nil)
            self.record = nil
        }
    }
}
