import CoreLocation
import Foundation
import Combine

@MainActor
final class ServerViewModel: ObservableObject {
    @Published private(set) var serverURLText = AppConfig.serverURL.absoluteString
    @Published private(set) var forecastDays = PrototypeDay.sampleDays
    @Published private(set) var statusText = "Using sample data"
    @Published private(set) var isLoading = false
    @Published private(set) var isLive = false
    @Published private(set) var errorMessage: String?

    private let locationManager = LocationManager()
    private let apiClient = SkyColorAPIClient(baseURL: AppConfig.serverURL)
    private let geocoder = CLGeocoder()

    func loadForecast() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil
        statusText = "Finding your location..."

        defer {
            isLoading = false
        }

        do {
            let location = try await locationManager.currentLocation()
            statusText = "Loading live forecast..."
            let locationName = await reverseGeocodedName(for: location)

            let response = try await apiClient.fetchPredictions(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil
            )

            guard let liveDay = ForecastMapper.makeDay(
                from: response,
                locationName: locationName
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
