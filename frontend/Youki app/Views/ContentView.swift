import SwiftUI
import LocationProvider

struct ContentView: View {

    @StateObject private var viewModel = ServerViewModel()

    var body: some View {

        NavigationView {
            VStack {
                Button("Fetch Sun Data") {
                    Task {
                        await viewModel.fetchSunResult()
                    }
                }

                if let data = viewModel.sunData {
                    VStack(alignment: .leading) {
                        Text("Sunrise: \(data.results.sunrise)")
                        Text("Sunset: \(data.results.sunset)")
                        Text("Solar Noon: \(data.results.solarNoon)")
                        Text("Day Length: \(data.results.dayLength)")
                    }
                    .padding()
                }
            }
            .navigationTitle("Sun Data")
        }
    }
}
