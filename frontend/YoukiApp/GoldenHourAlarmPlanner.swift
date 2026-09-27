import Foundation

enum GoldenHourAlarmPlanner {
    static func next(event: GoldenHourAlarmEvent, leadMinutes: Int, locationName: String,
                     now: Date, loadTimeline: (String?) async throws -> SkyDayTimelineResponse) async throws -> GoldenHourAlarmRequest {
        guard (0...120).contains(leadMinutes) else {
            throw GoldenHourAlarmError.message("Choose a valid lead time between 0 and 120 minutes.")
        }
        try Task.checkCancellation()
        let today = try await loadTimeline(nil)
        guard let zone = TimeZone(identifier: today.location.timezoneId) else { throw invalidTimeline }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd"
        try validate(today, expectedDay: formatter.string(from: now), original: today.location)

        for day in 0...1 {
            try Task.checkCancellation()
            let timeline: SkyDayTimelineResponse
            if day == 0 {
                timeline = today
            } else {
                guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { throw invalidTimeline }
                let target = formatter.string(from: tomorrow)
                timeline = try await loadTimeline(target)
                try validate(timeline, expectedDay: target, original: today.location)
            }
            let iso = event == .sunrise ? timeline.milestones.goldenHourStartIso : timeline.milestones.goldenHourPmStartIso
            if let iso {
                guard iso.hasPrefix(timeline.targetDateIso + "T") else { throw invalidTimeline }
                let candidate = try GoldenHourAlarmRequest.make(event: event, localIso: iso,
                    timezoneID: zone.identifier, locationName: locationName, leadMinutes: leadMinutes, now: .distantPast)
                if candidate.fireDate > now {
                    try Task.checkCancellation()
                    return candidate
                }
            }
        }
        try Task.checkCancellation()
        throw GoldenHourAlarmError.message("No upcoming \(event.label.lowercased()) golden hour is available today or tomorrow for this location.")
    }

    private static var invalidTimeline: GoldenHourAlarmError {
        .message("The forecast timing could not be verified. Try loading the forecast again.")
    }

    private static func validate(_ timeline: SkyDayTimelineResponse, expectedDay: String,
                                 original: SkyDayTimelineResponse.ResolvedLocation) throws {
        let location = timeline.location
        guard timeline.targetDateIso == expectedDay, location.timezoneId == original.timezoneId,
              location.latitude.isFinite, (-90...90).contains(location.latitude),
              location.longitude.isFinite, (-180...180).contains(location.longitude),
              abs(location.latitude - original.latitude) <= 0.0001,
              abs(location.longitude - original.longitude) <= 0.0001,
              !timeline.solar.isEmpty else { throw invalidTimeline }
    }
}
