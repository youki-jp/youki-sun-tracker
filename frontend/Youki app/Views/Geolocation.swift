import SwiftUI

struct GeolocationView: View {
    @StateObject private var viewModel = GeoLocationViewModel()
    
    var body: some View {
        VStack{
            Text("latitude \(viewModel.latitude)")
            Text("longitude \(viewModel.longitude)")
        }
        .onAppear {
            viewModel.start()
        }
    }
}
