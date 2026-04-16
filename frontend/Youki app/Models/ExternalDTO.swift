import Foundation

struct SunriseSunsetResponse: Codable, Identifiable {
    let id = UUID()
    let results: SunResults
    let status: String
    let tzid: String?

    enum CodingKeys: String, CodingKey {
        case results
        case status
        case tzid
    }
}

struct SunResults: Codable {
    let date: String?
    let sunrise: String
    let sunset: String
    let solarNoon: String
    let dayLength: String
    let firstLight: String?
    let lastLight: String?
    let dawn: String?
    let dusk: String?
    let goldenHour: String?
    let nauticalTwilightBegin: String?
    let nauticalTwilightEnd: String?
    let timezone: String?
    let utcOffset: Int?

    enum CodingKeys: String, CodingKey {
        case date
        case sunrise
        case sunset
        case solarNoon = "solar_noon"
        case dayLength = "day_length"
        case firstLight = "first_light"
        case lastLight = "last_light"
        case dawn
        case dusk
        case goldenHour = "golden_hour"
        case nauticalTwilightBegin = "nautical_twilight_begin"
        case nauticalTwilightEnd = "nautical_twilight_end"
        case timezone
        case utcOffset = "utc_offset"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        date = try container.decodeIfPresent(String.self, forKey: .date)
        sunrise = try container.decode(String.self, forKey: .sunrise)
        sunset = try container.decode(String.self, forKey: .sunset)
        solarNoon = try container.decode(String.self, forKey: .solarNoon)

        if let stringValue = try? container.decode(String.self, forKey: .dayLength) {
            dayLength = stringValue
        } else if let intValue = try? container.decode(Int.self, forKey: .dayLength) {
            dayLength = String(intValue)
        } else if let doubleValue = try? container.decode(Double.self, forKey: .dayLength) {
            dayLength = String(Int(doubleValue))
        } else {
            dayLength = ""
        }

        firstLight = try container.decodeIfPresent(String.self, forKey: .firstLight)
        lastLight = try container.decodeIfPresent(String.self, forKey: .lastLight)
        dawn = try container.decodeIfPresent(String.self, forKey: .dawn)
        dusk = try container.decodeIfPresent(String.self, forKey: .dusk)
        goldenHour = try container.decodeIfPresent(String.self, forKey: .goldenHour)
        nauticalTwilightBegin = try container.decodeIfPresent(String.self, forKey: .nauticalTwilightBegin)
        nauticalTwilightEnd = try container.decodeIfPresent(String.self, forKey: .nauticalTwilightEnd)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        utcOffset = try container.decodeIfPresent(Int.self, forKey: .utcOffset)
    }
}
