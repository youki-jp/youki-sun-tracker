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
        let solarNoonIso: String
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

struct SkyDayTimelineAPIClient {
    let baseURL: URL

    func fetchTimeline(
        latitude: Double,
        longitude: Double,
        altitudeMeters: Double?,
        targetDateIso: String? = nil
    ) async throws -> SkyDayTimelineResponse {
        let endpoint = baseURL.appendingPathComponent("api/v1/sky-day/timeline")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            SkyDayTimelineRequest(
                location: .init(
                    latitude: latitude,
                    longitude: longitude,
                    altitudeMeters: altitudeMeters
                ),
                targetDateIso: targetDateIso
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SkyDayTimelineAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = decodeServerError(from: data)
                ?? "Sky timeline request failed (HTTP \(httpResponse.statusCode))."
            throw SkyDayTimelineAPIError.server(message: message)
        }

        let decoded = try JSONDecoder().decode(SkyDayTimelineResponse.self, from: data)

        guard !decoded.solar.isEmpty else {
            throw SkyDayTimelineAPIError.emptyTimeline
        }

        return decoded
    }

    private func decodeServerError(from data: Data) -> String? {
        struct ErrorResponse: Decodable {
            struct ErrorBody: Decodable {
                let message: String
            }

            let error: ErrorBody
        }

        return try? JSONDecoder()
            .decode(ErrorResponse.self, from: data)
            .error
            .message
    }
}
