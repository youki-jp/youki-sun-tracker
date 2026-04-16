//
//  LocationProvider.swift
//  Youki app
//
//  Created by Kazuki Kagoshima on 2026/04/16.
//


import Foundation
import CoreLocation
import Combine

class LocationProvider: NSObject, CLLocationManagerDelegate, ObservableObject {

    @Published var location: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func start() throws {
        guard CLLocationManager.locationServicesEnabled() else {
            throw NSError(domain: "LocationServicesDisabled", code: 1)
        }
        manager.startUpdatingLocation()
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }
}
