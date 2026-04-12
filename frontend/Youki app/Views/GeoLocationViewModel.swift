//
//  GeoLocationViewModel.swift
//  Youki app
//
//  Created by Kazuki Kagoshima on 2026/04/12.
//

import Foundation
import LocationProvider
import Combine

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
