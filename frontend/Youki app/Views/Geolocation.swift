import SwiftUI

struct GeolocationView: View {
    @StateObject private var viewModel = GeoLocationViewModel()
    
    var body: some View {
        ZStack {
            Image("Image")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .clipped()
        }
        VStack{
            Text("latitude \(viewModel.latitude)")
            Text("longitude \(viewModel.longitude)")
        }
        .onAppear {
            viewModel.start()
        }
    }
}


#Preview {
    GeolocationView()
}
