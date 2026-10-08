import Foundation

enum SkyEventKind: String, Codable {
    case sunrise
    case sunset
}

struct SkyColorPredictionRequest: Encodable {
    struct Location: Encodable {
        let latitude: Double
        let longitude: Double
        let altitudeMeters: Double?
    }

    let location: Location
    let requestedEvents: [SkyEventKind]
}

struct SkyColorAPIResponse: Decodable {
    let location: ResolvedLocation
    let generatedAtIso: String
    let predictions: [SkyColorPrediction]

    struct ResolvedLocation: Decodable {
        let latitude: Double
        let longitude: Double
        let altitudeMeters: Double?
        let timezoneId: String
    }

    struct SkyColorPrediction: Decodable {
        let kind: SkyEventKind
        let score: Int
        let confidence: Int
        let label: String
        let estimatedColorName: String
        let estimatedHex: String
        let dominantColors: [String]
        let reasons: [String]
        let conditions: Conditions?
        let window: EventWindow

        struct Conditions: Decodable {
            let cloudCoverPct: Double?
            let highCloudPct: Double?
            let lowCloudPct: Double?
            let relativeHumidityPct: Double?
            let visibilityMeters: Double?
            let precipitationMillimeters: Double?
            let uvIndex: Double?
        }

        struct EventWindow: Decodable {
            let eventTimeIso: String
            let scoringWindow: TimeRange
            let twilight: TwilightBoundaries
        }

        struct TimeRange: Decodable {
            let startsAtIso: String
            let endsAtIso: String
        }

        struct TwilightBoundaries: Decodable {
            let civilStartsAtIso: String
            let civilEndsAtIso: String
            let nauticalStartsAtIso: String
            let nauticalEndsAtIso: String
            let astronomicalStartsAtIso: String
            let astronomicalEndsAtIso: String
        }
    }
}

enum SkyColorAPIError: LocalizedError {
    case invalidResponse
    case server(message: String)
    case emptyPredictions

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return AppLocalization.text("The forecast server returned an invalid response.")
        case let .server(message):
            return AppLocalization.text(message)
        case .emptyPredictions:
            return AppLocalization.text("The forecast server returned no predictions.")
        }
    }
}

enum AuthenticatedJSONTransportError: Error {
    case invalidResponse
    case server(message: String)
}

@MainActor
enum AuthenticatedJSONTransport {
    static func post<Body: Encodable, Response: Decodable>(
        to endpoint: URL,
        body: Body,
        fallbackErrorMessage: String
    ) async throws -> Response {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = endpoint.lastPathComponent == "week" ? 90 : 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await AuthSession.shared.send(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticatedJSONTransportError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AuthenticatedJSONTransportError.server(
                message: decodeServerError(from: data)
                    ?? "\(fallbackErrorMessage) (HTTP \(httpResponse.statusCode))."
            )
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private static func decodeServerError(from data: Data) -> String? {
        struct ErrorResponse: Decodable {
            struct ErrorBody: Decodable { let message: String }
            let error: ErrorBody
        }
        return try? JSONDecoder().decode(ErrorResponse.self, from: data).error.message
    }
}

@MainActor
struct SkyColorAPIClient {
    let baseURL: URL

    func fetchPredictions(
        latitude: Double,
        longitude: Double,
        altitudeMeters: Double?
    ) async throws -> SkyColorAPIResponse {
        let endpoint = baseURL.appendingPathComponent("api/v1/sky-color/predictions")
        let decoded: SkyColorAPIResponse
        do {
            decoded = try await AuthenticatedJSONTransport.post(
                to: endpoint,
                body: SkyColorPredictionRequest(
                location: .init(
                    latitude: latitude,
                    longitude: longitude,
                    altitudeMeters: altitudeMeters
                ),
                requestedEvents: [.sunrise, .sunset]
                ),
                fallbackErrorMessage: "Forecast request failed"
            )
        } catch AuthenticatedJSONTransportError.invalidResponse {
            throw SkyColorAPIError.invalidResponse
        } catch let AuthenticatedJSONTransportError.server(message) {
            throw SkyColorAPIError.server(message: message)
        }

        guard !decoded.predictions.isEmpty else {
            throw SkyColorAPIError.emptyPredictions
        }

        return decoded
    }
}
