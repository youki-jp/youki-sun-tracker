import Foundation

struct SkyDayTimelineRequest: Encodable {
    struct Location: Encodable {
        let latitude: Double
        let longitude: Double
        let altitudeMeters: Double?
    }

    let location: Location
    let targetDateIso: String?
}

struct SkyDayTimelineResponse: Decodable {
    let location: ResolvedLocation
    let targetDateIso: String
    let generatedAtIso: String
    let milestones: Milestones
    let solar: [SolarSample]
    let weather: [WeatherSample]
    let airQuality: [AirQualitySample]
    let summary: Summary

    struct ResolvedLocation: Decodable {
        let latitude: Double
        let longitude: Double
        let altitudeMeters: Double?
        let timezoneId: String
    }

    struct Milestones: Decodable {
        let astronomicalDawnIso: String?
        let nauticalDawnIso: String?
        let civilDawnIso: String?
        let goldenHourStartIso: String?
        let sunriseIso: String?
        let goldenHourEndIso: String?
        let solarNoonIso: String?
        let goldenHourPmStartIso: String?
        let sunsetIso: String?
        let goldenHourPmEndIso: String?
        let civilDuskIso: String?
        let nauticalDuskIso: String?
        let astronomicalDuskIso: String?
        let daylightMinutes: Double?
        let maxElevationDegrees: Double
        let minElevationDegrees: Double
    }

    struct SolarSample: Decodable {
        let timeIso: String
        let elevationDegrees: Double
        let azimuthDegrees: Double
        let isRising: Bool
        let phase: Phase

        enum Phase: String, Decodable {
            case night
            case nauticalDawn
            case civilDawn
            case blueHourAm
            case goldenHourAm
            case day
            case goldenHourPm
            case blueHourPm
            case civilDusk
            case nauticalDusk
        }
    }

    struct WeatherSample: Decodable {
        let timeIso: String
        let cloudCover: CloudCover
        let visibilityMeters: Double?
        let relativeHumidityPct: Double?
        let dewPointCelsius: Double?
        let precipitationMillimeters: Double?
        let uvIndex: Double?
        var solarRadiation: SolarRadiation? = nil

        struct SolarRadiation: Decodable {
            let sampling: String
            let directNormalWm2: Double?
            let globalHorizontalWm2: Double?
            let diffuseHorizontalWm2: Double?

            var isInstant: Bool { sampling == "instant" }
        }

        struct CloudCover: Decodable {
            let totalPct: Double?
            let lowPct: Double?
            let midPct: Double?
            let highPct: Double?
        }
    }

    struct AirQualitySample: Decodable {
        let timeIso: String
        let aerosolOpticalDepth: Double?
        let particulateMatter2_5UgM3: Double?
        let particulateMatter10UgM3: Double?
        let dustUgM3: Double?
        let ozoneUgM3: Double?
    }

    struct Summary: Decodable {
        let sunriseLabel: String?
        let sunriseScore: Int?
        let sunsetLabel: String?
        let sunsetScore: Int?
    }
}

enum SkyDayTimelineAPIError: LocalizedError {
    case invalidResponse
    case server(message: String)
    case emptyTimeline

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The sky timeline server returned an invalid response."
        case let .server(message):
            return message
        case .emptyTimeline:
            return "The sky timeline server returned no solar samples."
        }
    }
}

@MainActor
struct SkyDayTimelineAPIClient {
    let baseURL: URL

    func fetchTimeline(
        latitude: Double,
        longitude: Double,
        altitudeMeters: Double?,
        targetDateIso: String? = nil
    ) async throws -> SkyDayTimelineResponse {
        let endpoint = baseURL.appendingPathComponent("api/v1/sky-day/timeline")
        let decoded: SkyDayTimelineResponse
        do {
            decoded = try await AuthenticatedJSONTransport.post(
                to: endpoint,
                body: SkyDayTimelineRequest(
                location: .init(
                    latitude: latitude,
                    longitude: longitude,
                    altitudeMeters: altitudeMeters
                ),
                targetDateIso: targetDateIso
                ),
                fallbackErrorMessage: "Sky timeline request failed"
            )
        } catch AuthenticatedJSONTransportError.invalidResponse {
            throw SkyDayTimelineAPIError.invalidResponse
        } catch let AuthenticatedJSONTransportError.server(message) {
            throw SkyDayTimelineAPIError.server(message: message)
        }

        guard !decoded.solar.isEmpty else {
            throw SkyDayTimelineAPIError.emptyTimeline
        }

        return decoded
    }
}

// The server returns seven dated rows. Free accounts receive locked outlook rows.
struct ForecastWeekResponse: Decodable {
    let location: SkyDayTimelineResponse.ResolvedLocation
    let today: String
    let generatedAtIso: String
    let days: [ForecastWeekDay]
}

struct ForecastWeekDay: Decodable, Identifiable {
    var id: String { targetDateIso }
    let targetDateIso: String
    let forecastType: String
    let locked: Bool
    let timeline: SkyDayTimelineResponse?
    let predictions: SkyColorAPIResponse?
    let errors: [String]

    var isAvailable: Bool { !locked && (timeline != nil || predictions != nil) }
    var sunrisePrediction: SkyColorAPIResponse.SkyColorPrediction? {
        predictions?.predictions.first { $0.kind == .sunrise }
    }
    var sunsetPrediction: SkyColorAPIResponse.SkyColorPrediction? {
        predictions?.predictions.first { $0.kind == .sunset }
    }
}

extension SkyDayTimelineAPIClient {
    func fetchWeek(_ coordinates: ForecastCoordinates) async throws -> ForecastWeekResponse {
        try await AuthenticatedJSONTransport.post(
            to: baseURL.appendingPathComponent("api/v1/sky-day/week"),
            body: SkyDayTimelineRequest(location: .init(latitude: coordinates.latitude,
                longitude: coordinates.longitude, altitudeMeters: coordinates.altitudeMeters), targetDateIso: nil),
            fallbackErrorMessage: "Calendar request failed")
    }
}
