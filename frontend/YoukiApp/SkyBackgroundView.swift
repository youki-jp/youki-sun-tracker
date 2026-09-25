import SwiftUI

struct SkyBackgroundView: View {
    let appearance: SkyAppearance
    let isExpanded: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    stops: appearance.stops.map {
                        Gradient.Stop(color: Color(hex: $0.hex), location: $0.offset)
                    },
                    startPoint: .top,
                    endPoint: .bottom
                )

                ForEach(appearance.cloudBands) { band in
                    cloudRow(band: band, size: proxy.size)
                }

                glow(size: proxy.size)
            }
            .clipped()
        }
    }

    private func cloudRow(band: SkyCloudBand, size: CGSize) -> some View {
        Ellipse()
        .fill(Color(hex: band.hex))
        .frame(width: size.width * 1.28, height: max(size.height * band.height, 1))
        .blur(radius: size.height * band.blur)
        .opacity(band.opacity)
        .offset(
            x: 0,
            y: size.height * (band.y + band.height / 2 - 0.5)
        )
    }

    private func glow(size: CGSize) -> some View {
        let diameter = max(size.height * appearance.glow.radius * 2, 1)
        // CSS's circle gradient extends to the square's farthest corner.
        return Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: Color(red: 255 / 255, green: 242 / 255, blue: 208 / 255).opacity(0.95), location: 0),
                        .init(color: Color(red: 255 / 255, green: 214 / 255, blue: 150 / 255).opacity(0.5), location: 0.32),
                        .init(color: Color(red: 255 / 255, green: 185 / 255, blue: 120 / 255).opacity(0), location: 0.68)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2 * sqrt(2)
                )
            )
            .frame(width: diameter, height: diameter)
            .position(
                x: size.width * appearance.glow.centerX,
                y: size.height * appearance.glow.centerY
            )
            .opacity(appearance.glow.intensity > 0.01 ? appearance.glow.intensity : 0)
    }
}
