//
//  Untitled.swift
//  Youki app
//
//  Created by Kazuki Kagoshima on 2025/12/30.
//


struct SunriseSunsetResponse: Decodable {
    var results: SunResults
    let status: String
}


struct SunResults: Decodable {
    let sunrise: String
    let sunset: String
    let solarNoon: String
    let goldenHour: String
    let dayLength: String
    let timeZone: String
    let utcOffset: Int

    enum CodingKeys: String, CodingKey {
        case sunrise
        case sunset
        case solarNoon = "solar_noon"
        case goldenHour = "golden_hour"
        case dayLength = "day_length"
        case timeZone = "timezone"
        case utcOffset = "utc_offset"
    }
}
