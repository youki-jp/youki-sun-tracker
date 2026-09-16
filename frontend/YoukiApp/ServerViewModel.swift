import CoreLocation
import Combine
import Foundation
import SwiftUI

@MainActor
final class ServerViewModel: ObservableObject {
    @Published private(set) var serverURLText = AppConfig.serverURL.absoluteString
    @Published private(set) var forecastDays = PrototypeDay.sampleDays
    @Published private(set) var statusText = "Using sample data"
    @Published private(set) var isLoading = false
    @Published private(set) var isLive = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var skyAppearance = SkyAppearance.fallback

    private let locationManager = LocationManager()
    private let apiClient = SkyColorAPIClient(baseURL: AppConfig.serverURL)
    private let timelineClient = SkyDayTimelineAPIClient(baseURL: AppConfig.serverURL)
    private let geocoder = CLGeocoder()
    private var timeline: SkyDayTimelineResponse?

    func appearance(at date: Date) -> SkyAppearance {
        guard let timeline,
              let appearance = SkyTimelineSampler(timeline: timeline).appearance(at: date) else {
            return skyAppearance
        }

        return appearance
    }

    func loadForecast() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil
        statusText = "Finding your location..."
        timeline = nil
        skyAppearance = .fallback

        defer {
            isLoading = false
        }

        do {
            let location = try await locationManager.currentLocation()
            statusText = "Loading live forecast..."
            let locationName = await reverseGeocodedName(for: location)

            async let responseTask = apiClient.fetchPredictions(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil
            )
            async let timelineTask = timelineClient.fetchTimeline(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil
            )

            let response = try await responseTask
            let liveTimeline = try? await timelineTask

            if let liveTimeline,
               let liveAppearance = SkyTimelineSampler(timeline: liveTimeline).appearance(at: Date()) {
                timeline = liveTimeline
                skyAppearance = liveAppearance
            }

            guard let liveDay = ForecastMapper.makeDay(
                from: response,
                locationName: locationName,
                generatedRamp: skyAppearance.ramp.map { Color(hex: $0) }
            ) else {
                throw SkyColorAPIError.emptyPredictions
            }

            forecastDays = [liveDay]
            isLive = true
            statusText = "Live forecast"
        } catch {
            isLive = false
            statusText = "Using sample data"
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func reverseGeocodedName(for location: CLLocation) async -> String {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else {
                return "Current location"
            }

            if let locality = placemark.locality {
                if let country = placemark.country {
                    return "\(locality), \(country)"
                }

                return locality
            }

            return placemark.name ?? "Current location"
        } catch {
            return "Current location"
        }
    }
}
