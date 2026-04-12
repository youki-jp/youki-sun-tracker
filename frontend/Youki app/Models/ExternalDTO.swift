import Foundation

struct SunriseSunsetResponse: Codable, Identifiable {
    let id = UUID()
    let results: SunResults
    let status: String
    let tzid: String

    enum CodingKeys: String, CodingKey {
        case results
        case status
        case tzid
    }
}

struct SunResults: Codable {
    let sunrise: String
    let sunset: String
    let solarNoon: String
    let dayLength: String
    let civilTwilightBegin: String
    let civilTwilightEnd: String
    let nauticalTwilightBegin: String
    let nauticalTwilightEnd: String
    let astronomicalTwilightBegin: String
    let astronomicalTwilightEnd: String

    enum CodingKeys: String, CodingKey {
        case sunrise
        case sunset
        case solarNoon = "solar_noon"
        case dayLength = "day_length"
        case civilTwilightBegin = "civil_twilight_begin"
        case civilTwilightEnd = "civil_twilight_end"
        case nauticalTwilightBegin = "nautical_twilight_begin"
        case nauticalTwilightEnd = "nautical_twilight_end"
        case astronomicalTwilightBegin = "astronomical_twilight_begin"
        case astronomicalTwilightEnd = "astronomical_twilight_end"
    }
}
