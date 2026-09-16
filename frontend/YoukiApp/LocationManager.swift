import CoreLocation
import Combine
import Foundation

enum LocationProviderError: LocalizedError {
    case permissionDenied
    case unavailable
    case requestInProgress

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location access is disabled. Allow location access in Settings to load a live forecast."
        case .unavailable:
            return "Your current location could not be determined."
        case .requestInProgress:
            return "A location request is already in progress."
        }
    }
}

@MainActor
final class LocationManager: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = kCLDistanceFilterNone
    }

    func currentLocation() async throws -> CLLocation {
        guard locationContinuation == nil else {
            throw LocationProviderError.requestInProgress
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation

            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                finish(with: .failure(LocationProviderError.permissionDenied))
            @unknown default:
                finish(with: .failure(LocationProviderError.unavailable))
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if locationContinuation != nil {
                manager.requestLocation()
            }
        case .denied, .restricted:
            if locationContinuation != nil {
                finish(with: .failure(LocationProviderError.permissionDenied))
            }
        case .notDetermined:
            break
        @unknown default:
            if locationContinuation != nil {
                finish(with: .failure(LocationProviderError.unavailable))
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            finish(with: .failure(LocationProviderError.unavailable))
            return
        }

        finish(with: .success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: .failure(error))
    }

    private func finish(with result: Result<CLLocation, Error>) {
        guard let continuation = locationContinuation else {
            return
        }

        locationContinuation = nil
        continuation.resume(with: result)
    }
}
