import Foundation

// Standalone macOS regression runner; compile with the production model files (README).
@main
struct ModelRegression {
    static func timeline(polar: Bool = false, malformed: Bool = false,
                         missingWeather: Bool = false) -> SkyDayTimelineResponse {
        let date = "2026-09-25"
        func iso(_ clock: String) -> String { date + "T" + clock }
        return SkyDayTimelineResponse(
            location: .init(latitude: 35, longitude: 139, altitudeMeters: nil, timezoneId: "Asia/Tokyo"),
            targetDateIso: date, generatedAtIso: iso("00:00:00"),
            milestones: .init(
                astronomicalDawnIso: nil, nauticalDawnIso: nil,
                civilDawnIso: polar ? nil : iso("05:00"),
                goldenHourStartIso: polar ? nil : iso("05:30"),
                sunriseIso: polar ? nil : iso("06:00:45"), goldenHourEndIso: nil,
                solarNoonIso: iso("12:00"), goldenHourPmStartIso: polar ? nil : iso("17:30"),
                sunsetIso: polar ? nil : iso("18:00"), goldenHourPmEndIso: nil,
                civilDuskIso: nil, nauticalDuskIso: nil, astronomicalDuskIso: nil,
                daylightMinutes: nil, maxElevationDegrees: 60, minElevationDegrees: -30),
            solar: [
                .init(timeIso: malformed ? "invalid" : iso("00:00"), elevationDegrees: -30, azimuthDegrees: 0, isRising: true, phase: .night),
                .init(timeIso: iso("06:00"), elevationDegrees: -0.833, azimuthDegrees: 90, isRising: true, phase: .goldenHourAm),
                .init(timeIso: iso("12:00"), elevationDegrees: 60, azimuthDegrees: 180, isRising: false, phase: .day),
                .init(timeIso: iso("18:00"), elevationDegrees: -0.833, azimuthDegrees: 270, isRising: false, phase: .goldenHourPm)
            ],
            weather: [
                .init(timeIso: iso("06:00"), cloudCover: .init(totalPct: 10, lowPct: 0, midPct: 0, highPct: missingWeather ? nil : 10),
                      visibilityMeters: 24000, relativeHumidityPct: 60, dewPointCelsius: nil, precipitationMillimeters: 0, uvIndex: 2),
                .init(timeIso: iso("18:00"), cloudCover: .init(totalPct: 80, lowPct: 20, midPct: 40, highPct: 80),
                      visibilityMeters: 24000, relativeHumidityPct: 60, dewPointCelsius: nil, precipitationMillimeters: 0, uvIndex: 2)
            ],
            airQuality: [.init(timeIso: iso("06:00"), aerosolOpticalDepth: 0.08,
                               particulateMatter2_5UgM3: 0, particulateMatter10UgM3: nil,
                               dustUgM3: 0, ozoneUgM3: nil)],
            summary: .init(sunriseLabel: nil, sunriseScore: nil, sunsetLabel: nil, sunsetScore: nil))
    }

    static func prediction() -> SkyColorAPIResponse {
        let events = [SkyEventKind.sunrise, .sunset].map { kind in
            let time = "2026-09-25T" + (kind == .sunrise ? "06:00:00" : "18:00:00")
            return SkyColorAPIResponse.SkyColorPrediction(
                kind: kind, score: kind == .sunrise ? 71 : 42, confidence: 80,
                label: "warm", estimatedColorName: "amber", estimatedHex: "#ffbb66",
                dominantColors: ["amber"], reasons: ["Test atmospheric conditions"], conditions: nil,
                window: .init(eventTimeIso: time, scoringWindow: .init(startsAtIso: time, endsAtIso: time),
                              twilight: .init(civilStartsAtIso: time, civilEndsAtIso: time,
                                              nauticalStartsAtIso: time, nauticalEndsAtIso: time,
                                              astronomicalStartsAtIso: time, astronomicalEndsAtIso: time)))
        }
        return .init(location: .init(latitude: 35, longitude: 139, altitudeMeters: nil, timezoneId: "Asia/Tokyo"),
                     generatedAtIso: "2026-09-25T00:00:00", predictions: events)
    }

    @MainActor
    static func main() async throws {
        precondition(SkyTimelineSampler.localMinutes(from: "2026-09-25T05:14") == 314)
        precondition(SkyTimelineSampler.localMinutes(from: "2026-09-25T05:14:59") == 314)
        for invalid in ["bad", "2026-09-25T24:00", "2026-09-25T05:60", "2026-02-30T05:00",
                        "2026-09-25T05:14:60", "2026-09-25T05:14Z"] {
            precondition(SkyTimelineSampler.localMinutes(from: invalid) == nil, invalid)
        }
        precondition(ForecastCoordinates(latitude: .nan, longitude: 1) == nil)
        precondition(ForecastCoordinates(latitude: 91, longitude: 1) == nil)
        precondition(ForecastCoordinates(latitude: 1, longitude: 181) == nil)
        precondition(ForecastCoordinates(latitude: 1, longitude: 1, altitudeMeters: .infinity) == nil)
        precondition(ForecastCoordinates(latitude: -90, longitude: -180) != nil)
        let sampler = SkyTimelineSampler(timeline: timeline())
        let dawn = sampler.appearance(atLocalIso: "2026-09-25T06:00")!
        let noon = sampler.appearance(atLocalIso: "2026-09-25T12:00")!
        let dusk = sampler.appearance(atLocalIso: "2026-09-25T18:00")!
        precondition(dawn != noon && dawn != dusk && noon != dusk)
        precondition(sampler.appearance(atLocalIso: "2026-09-26T06:00") == nil)
        let utc = ISO8601DateFormatter()
        precondition(sampler.appearance(at: utc.date(from: "2026-09-24T21:00:00Z")!) == dawn)
        precondition(sampler.appearance(at: utc.date(from: "2026-09-25T21:00:00Z")!) == nil)
        precondition(SkyTimelineSampler(timeline: timeline(malformed: true)).appearance(atLocalIso: "2026-09-25T06:00") == dawn)
        let missing = SkyTimelineSampler(timeline: timeline(missingWeather: true))
        precondition(missing.hasAtmosphericFallback)
        let expectedNoon = SkyGradientGenerator.generate(.init(
            elevationDegrees: 60, azimuthDegrees: 180, cloudTotalPct: 45,
            cloudLowPct: 10, cloudMidPct: 20, cloudHighPct: 40,
            visibilityMeters: 24000, relativeHumidityPct: 60, precipitationMillimeters: 0,
            aerosolOpticalDepth: 0.08, dustUgM3: 0, pm25UgM3: 0))
        precondition(missing.appearance(atLocalIso: "2026-09-25T12:00") == expectedNoon)

        enum Failure: Error { case offline }
        let location = ForecastCoordinates(latitude: 35, longitude: 139)!
        let live = ServerViewModel(predictionLoader: { _ in prediction() }, timelineLoader: { _ in timeline() })
        precondition(live.isLoading && live.forecastDays.isEmpty && !live.hasLiveSky && !live.hasLiveForecast)
        precondition(live.statusText == "Finding location" && !live.isScoreAvailable)
        await live.load(location)
        let nowIsInLoadedDay = sampler.appearance(at: Date()) != nil
        precondition(live.isLive && live.selectedMoment == (nowIsInLoadedDay ? .now : .firstLight))
        precondition(live.forecastDays[0].qualityScore > 0 && live.hasLiveSky)
        for moment in SkyMoment.allCases where moment != .now { precondition(live.isAvailable(moment)) }
        live.select(.sunset)
        precondition(live.skyAppearance == dusk && live.forecastDays[0].qualityScore == 42)
        precondition(live.forecastDays[0].summaryLabel.contains("sunset"))
        precondition(live.forecastDays[0].heroTime == "18:00")
        precondition(live.forecastDays[0].daylight == "12:00")

        let skyOnly = ServerViewModel(predictionLoader: { _ in throw Failure.offline }, timelineLoader: { _ in timeline() })
        await skyOnly.load(location)
        precondition(skyOnly.hasLiveSky && !skyOnly.hasLiveForecast && !skyOnly.isLive)
        precondition(!skyOnly.isScoreAvailable && skyOnly.forecastDays[0].summaryLabel.contains("unavailable"))
        precondition(skyOnly.errorMessage != nil && !skyOnly.forecastDays.isEmpty)
        let scoreOnly = ServerViewModel(predictionLoader: { _ in prediction() }, timelineLoader: { _ in throw Failure.offline })
        await scoreOnly.load(location)
        precondition(!scoreOnly.hasLiveSky && scoreOnly.hasLiveForecast && !scoreOnly.isLive)
        precondition(scoreOnly.forecastDays[0].firstLight == "—" && scoreOnly.forecastDays[0].qualityScore > 0)
        precondition(scoreOnly.statusText == "Live score · sky unavailable")
        precondition(!scoreOnly.isAvailable(.sunrise))
        let polar = ServerViewModel(predictionLoader: { _ in throw Failure.offline }, timelineLoader: { _ in timeline(polar: true) })
        await polar.load(location)
        precondition(polar.selectedMoment == (nowIsInLoadedDay ? .now : .daylight) && polar.isAvailable(.daylight))
        precondition(!polar.isAvailable(.sunrise) && polar.forecastDays[0].sunrise == "—")
        polar.select(.sunrise)
        precondition(polar.selectedMoment == (nowIsInLoadedDay ? .now : .daylight))

        let race = ServerViewModel(predictionLoader: { coordinate in
            if coordinate.latitude == 35 { try await Task.sleep(for: .milliseconds(100)) }
            throw Failure.offline
        }, timelineLoader: { coordinate in
            if coordinate.latitude == 35 {
                try await Task.sleep(for: .milliseconds(100))
                return timeline()
            }
            throw Failure.offline
        })
        let older = Task { await race.load(location) }
        await Task.yield()
        try await Task.sleep(for: .milliseconds(10))
        precondition(race.isLoading && race.forecastDays.isEmpty && !race.hasLiveSky)
        let newer = ForecastCoordinates(latitude: 40, longitude: 140)!
        await race.load(newer)
        await older.value
        precondition(race.coordinates == newer && !race.hasLiveSky && !race.hasLiveForecast)
        precondition(race.forecastDays.isEmpty && race.errorMessage != nil)
        precondition(!race.isLoading && race.statusText == "Forecast unavailable")
        print("PASS: parser, interpolation/defaults, timezone/date, coordinates, milestones, event selection, API partial failures and stale-response isolation")
    }
}
