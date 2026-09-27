import Foundation
#if os(iOS) && canImport(AlarmKit)
import AlarmKit
import SwiftUI

@available(iOS 26.0, *)
private struct GoldenHourAlarmMetadata: AlarmMetadata {
    let event: String
}
#endif

@MainActor final class SystemAlarmScheduler: AlarmScheduling {
    var unavailableReason: String? {
        #if os(iOS) && canImport(AlarmKit)
        if #available(iOS 26.0, *) { return nil }
        return "System alarms require iOS 26 or later."
        #else
        return "System alarms require iOS 26 or later and are unavailable in this build."
        #endif
    }

    func authorize() async throws {
        #if os(iOS) && canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let state = try await AlarmManager.shared.requestAuthorization()
            guard state == .authorized else {
                throw GoldenHourAlarmError.message("Alarm permission is off. Allow Youki alarms in Settings to set this alarm.")
            }
            return
        }
        #endif
        throw GoldenHourAlarmError.message(unavailableReason ?? "System alarms are unavailable.")
    }

    func schedule(_ request: GoldenHourAlarmRequest) async throws {
        #if os(iOS) && canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let stop = AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle")
            let title: LocalizedStringResource = request.event == .sunrise ? "Sunrise golden hour" : "Sunset golden hour"
            let alert = AlarmPresentation.Alert(title: title, stopButton: stop)
            let attributes = AlarmAttributes<GoldenHourAlarmMetadata>(
                presentation: AlarmPresentation(alert: alert),
                metadata: GoldenHourAlarmMetadata(event: request.event.rawValue), tintColor: .orange)
            let configuration = AlarmManager.AlarmConfiguration<GoldenHourAlarmMetadata>.alarm(
                schedule: .fixed(request.fireDate), attributes: attributes)
            _ = try await AlarmManager.shared.schedule(id: request.id, configuration: configuration)
            return
        }
        #endif
        throw GoldenHourAlarmError.message(unavailableReason ?? "System alarms are unavailable.")
    }

    func cancel(id: UUID) throws {
        #if os(iOS) && canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            try AlarmManager.shared.cancel(id: id)
            return
        }
        #endif
        throw GoldenHourAlarmError.message(unavailableReason ?? "System alarms are unavailable.")
    }

    func updates() -> AsyncStream<Void> {
        #if os(iOS) && canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            return AsyncStream { continuation in
                let task = Task { @MainActor in
                    for await _ in AlarmManager.shared.alarmUpdates {
                        guard !Task.isCancelled else { break }
                        continuation.yield(())
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
        #endif
        return AsyncStream { $0.finish() }
    }

    func scheduledIDs() throws -> Set<UUID> {
        #if os(iOS) && canImport(AlarmKit)
        if #available(iOS 26.0, *) { return Set(try AlarmManager.shared.alarms.map(\.id)) }
        #endif
        throw GoldenHourAlarmError.message(unavailableReason ?? "System alarms are unavailable.")
    }
}
