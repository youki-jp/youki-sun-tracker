import Foundation

@main struct AlarmPlannerRegression {
    static func timeline(day: String = "2026-09-27", zone: String = "Asia/Tokyo",
                         latitude: Double = 35.67, milestoneDay: String? = nil, sunrise: String? = "05:30:00",
                         sunset: String? = "17:00:00") throws -> SkyDayTimelineResponse {
        var milestones: [String: Any] = ["maxElevationDegrees": 60, "minElevationDegrees": -30]
        if let sunrise { milestones["goldenHourStartIso"] = "\(milestoneDay ?? day)T\(sunrise)" }
        if let sunset { milestones["goldenHourPmStartIso"] = "\(day)T\(sunset)" }
        let json: [String: Any] = [
            "location": ["latitude": latitude, "longitude": 139.65, "timezoneId": zone],
            "targetDateIso": day, "generatedAtIso": "2026-09-26T20:00:00Z",
            "milestones": milestones,
            "solar": [["timeIso": "\(day)T12:00:00", "elevationDegrees": 60,
                       "azimuthDegrees": 180, "isRising": false, "phase": "day"]],
            "weather": [], "airQuality": [], "summary": [:]
        ]
        return try JSONDecoder().decode(SkyDayTimelineResponse.self, from: JSONSerialization.data(withJSONObject: json))
    }

    static func rejects(_ operation: () async throws -> GoldenHourAlarmRequest) async {
        do { _ = try await operation(); fatalError("Accepted an invalid forecast") }
        catch { }
    }

    static func main() async throws {
        let beforeDawn = try GoldenHourAlarmDate.resolve(localIso: "2026-09-27T04:00:00", timezoneID: "Asia/Tokyo")
        let today = try timeline()
        var calls: [String?] = []
        let morning = try await GoldenHourAlarmPlanner.next(event: .sunrise, leadMinutes: 15,
            locationName: "Tokyo", now: beforeDawn) { day in calls.append(day); return today }
        precondition(calls.count == 1 && calls[0] == nil)
        precondition(morning.fireDate == morning.goldenHourDate.addingTimeInterval(-900))
        precondition(morning.locationName == "Tokyo" && morning.event == .sunrise)

        let afterLeadTime = beforeDawn.addingTimeInterval(75 * 60)
        let tomorrow = try timeline(day: "2026-09-28")
        calls = []
        let nextMorning = try await GoldenHourAlarmPlanner.next(event: .sunrise, leadMinutes: 30,
            locationName: "Tokyo", now: afterLeadTime) { day in
                calls.append(day); return day == nil ? today : tomorrow
            }
        precondition(calls.count == 2 && calls[1] == "2026-09-28")
        let expectedTomorrow = try GoldenHourAlarmDate.resolve(localIso: "2026-09-28T05:30:00", timezoneID: "Asia/Tokyo")
        precondition(nextMorning.goldenHourDate == expectedTomorrow)

        let evening = try await GoldenHourAlarmPlanner.next(event: .sunset, leadMinutes: 0,
            locationName: "Tokyo", now: afterLeadTime) { _ in today }
        let expectedEvening = try GoldenHourAlarmDate.resolve(localIso: "2026-09-27T17:00:00", timezoneID: "Asia/Tokyo")
        precondition(evening.goldenHourDate == expectedEvening)

        let polarToday = try timeline(sunrise: nil, sunset: nil)
        let polarTomorrow = try timeline(day: "2026-09-28", sunrise: nil, sunset: nil)
        do {
            _ = try await GoldenHourAlarmPlanner.next(event: .sunrise, leadMinutes: 15,
                locationName: "Tokyo", now: beforeDawn) { $0 == nil ? polarToday : polarTomorrow }
            fatalError("Accepted a missing event")
        } catch { precondition(error.localizedDescription.contains("today or tomorrow")) }

        for badToday in [try timeline(day: "2026-09-26"), try timeline(zone: "Invalid/Zone"),
                         try timeline(sunrise: "25:00:00"), try timeline(latitude: 100),
                         try timeline(milestoneDay: "2026-09-28")] {
            await rejects {
                try await GoldenHourAlarmPlanner.next(event: .sunrise, leadMinutes: 15,
                    locationName: "Tokyo", now: beforeDawn) { _ in badToday }
            }
        }
        for badTomorrow in [try timeline(day: "2026-09-29"),
                            try timeline(day: "2026-09-28", zone: "UTC"),
                            try timeline(day: "2026-09-28", latitude: 36)] {
            await rejects {
                try await GoldenHourAlarmPlanner.next(event: .sunrise, leadMinutes: 30,
                    locationName: "Tokyo", now: afterLeadTime) { $0 == nil ? today : badTomorrow }
            }
        }
        var invalidLeadCalls = 0
        await rejects {
            try await GoldenHourAlarmPlanner.next(event: .sunrise, leadMinutes: 121,
                locationName: "Tokyo", now: beforeDawn) { _ in invalidLeadCalls += 1; return today }
        }
        precondition(invalidLeadCalls == 0)

        // Simulate cancellation during a loader that completes despite cancellation.
        let task = Task {
            try await GoldenHourAlarmPlanner.next(event: .sunrise, leadMinutes: 15,
                locationName: "Tokyo", now: beforeDawn) { _ in
                    withUnsafeCurrentTask { $0?.cancel() }
                    return today
                }
        }
        do { _ = try await task.value; fatalError("Returned a cancelled preview") }
        catch is CancellationError { }
        print("Alarm planner regressions passed")
    }
}
