
import Foundation
import Combine
import LocationProvider

class GeoLocationViewModel: ObservableObject {

    @Published var latitude: Double = 0
    @Published var longitude: Double = 0

    private let provider = LocationProvider()
    private var cancellables = Set<AnyCancellable>()

    init() {
        provider.$location
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.latitude = location.coordinate.latitude
                self?.longitude = location.coordinate.longitude
            }
            .store(in: &cancellables)
    }

    func start() {
        do {
            try provider.start()
        } catch {
            provider.requestAuthorization()
        }
    }
}
