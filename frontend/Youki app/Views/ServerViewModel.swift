import Foundation
import LocationProvider
import SwiftUI


//This ServerViewModel is going to handle logic for fetching data from the server. 
@MainActor
class ServerViewModel: ObservableObject {
    // If sunData (Which is of type SunriseSunsetReponse changes), then whatever View that is observing it will change. 
    @Published var sunData: SunriseSunsetResponse?

    let locationProvider = LocationProvider()

    private var backendUrl =
        ProcessInfo.processInfo.environment["BACKEND_URL"] ?? "http://localhost:3000"

    func fetchSunResult() async {

        guard let location = locationProvider.location else { return }

        let lat = location.coordinate.latitude
        let long = location.coordinate.longitude

        guard var components = URLComponents(string: backendUrl) else { return }

        components.queryItems = [
            URLQueryItem(name: "lat", value: "\(lat)"),
            URLQueryItem(name: "lng", value: "\(long)")
        ]

        guard let url = components.url else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let decoded = try decoder.decode(SunriseSunsetResponse.self, from: data)

            sunData = decoded

        } catch {
            print(error)
        }
    }
}
