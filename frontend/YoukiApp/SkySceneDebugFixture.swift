#if DEBUG
import Foundation

enum SkySceneDebugFixture {
    static func timeline() -> SkyDayTimelineResponse {
        let arguments = ProcessInfo.processInfo.arguments
        let overcast = arguments.contains("-uiSkyFixtureOvercast")
        let missing = arguments.contains("-uiSkyFixtureMissing")
        let night = arguments.contains("-uiSkyFixtureNight")
        let timezone = TimeZone(identifier: "Asia/Tokyo")!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: Date())
        func iso(_ time: String) -> String { day + "T" + time }
        let milestones = SkyDayTimelineResponse.Milestones(
            astronomicalDawnIso: nil, nauticalDawnIso: nil, civilDawnIso: iso("05:15:00"),
            goldenHourStartIso: iso("05:30:00"), sunriseIso: iso("06:00:00"),
            goldenHourEndIso: iso("06:35:00"), solarNoonIso: iso("12:00:00"),
            goldenHourPmStartIso: iso("17:20:00"), sunsetIso: iso("18:00:00"),
            goldenHourPmEndIso: iso("18:35:00"), civilDuskIso: iso("18:45:00"),
            nauticalDuskIso: nil, astronomicalDuskIso: nil, daylightMinutes: 720,
            maxElevationDegrees: 55, minElevationDegrees: -55)
        let positions: [(String, Double)] = [
            ("00:00:00", -55), ("05:15:00", -6), ("05:30:00", -3),
            ("06:00:00", -0.267), ("06:35:00", 6), ("12:00:00", 55),
            ("17:20:00", 6), ("18:00:00", -0.267),
            ("18:35:00", -3), ("18:45:00", -6), ("23:59:00", -55)
        ]
        let solar = positions.map { time, elevation in
            SkyDayTimelineResponse.SolarSample(timeIso: iso(time),
                elevationDegrees: night ? -20 : elevation,
                azimuthDegrees: time < "12" ? 90 : time == "12:00:00" ? 180 : 270,
                isRising: time < "12", phase: night ? .night : elevation > 6 ? .day :
                    time < "12" ? .goldenHourAm : .goldenHourPm)
        }
        let weather = stride(from: 0, through: 23, by: 1).map { hour in
            let localTime = String(format: "%02d:00:00", hour)
            let twilight = hour < 8 || hour > 16
            return SkyDayTimelineResponse.WeatherSample(
                timeIso: iso(localTime),
                cloudCover: .init(totalPct: missing ? nil : overcast ? 100 : twilight ? 44 : 18,
                                  lowPct: missing ? nil : overcast ? 100 : 8,
                                  midPct: missing ? nil : overcast ? 75 : twilight ? 20 : 6,
                                  highPct: missing ? nil : overcast ? 60 : twilight ? 55 : 25),
                visibilityMeters: missing ? nil : overcast ? 12_000 : 24_000,
                relativeHumidityPct: missing ? nil : 65, dewPointCelsius: 9,
                precipitationMillimeters: 0, uvIndex: twilight ? 0 : 4,
                solarRadiation: missing ? nil : .init(sampling: "instant",
                    directNormalWm2: night ? 700 : overcast ? 0 : hour >= 6 && hour <= 18 ? 560 : 0,
                    globalHorizontalWm2: night ? 700 : overcast ? 120 : hour >= 6 && hour <= 18 ? 620 : 0,
                    diffuseHorizontalWm2: night ? 100 : overcast ? 120 : hour >= 6 && hour <= 18 ? 120 : 0))
        }
        return SkyDayTimelineResponse(
            location: .init(latitude: 35, longitude: 139, altitudeMeters: nil, timezoneId: "Asia/Tokyo"),
            targetDateIso: day, generatedAtIso: ISO8601DateFormatter().string(from: Date()),
            milestones: night ? .init(astronomicalDawnIso: nil, nauticalDawnIso: nil,
                civilDawnIso: nil, goldenHourStartIso: nil, sunriseIso: nil, goldenHourEndIso: nil,
                solarNoonIso: iso("12:00:00"), goldenHourPmStartIso: nil, sunsetIso: nil,
                goldenHourPmEndIso: nil, civilDuskIso: nil, nauticalDuskIso: nil,
                astronomicalDuskIso: nil, daylightMinutes: nil,
                maxElevationDegrees: -20, minElevationDegrees: -20) : milestones,
            solar: solar, weather: weather, airQuality: [],
            summary: .init(sunriseLabel: nil, sunriseScore: nil, sunsetLabel: nil, sunsetScore: nil))
    }
}
#endif
