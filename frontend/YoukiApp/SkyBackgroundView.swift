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
            .overlay(alignment: .bottom) {
                if isExpanded {
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.22)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
    }

    private func cloudRow(band: SkyCloudBand, size: CGSize) -> some View {
        HStack(spacing: -24) {
            ForEach(0..<5, id: \.self) { index in
                Ellipse()
                    .fill(Color(hex: band.hex).opacity(0.9 - Double(index) * 0.08))
                    .frame(
                        width: max(size.width * 0.28 + CGFloat(index * 12), 1),
                        height: max(size.height * band.height + CGFloat(index % 2) * CGFloat(6), CGFloat(1))
                    )
            }
        }
        .frame(width: size.width * 1.28, height: max(size.height * band.height, 1))
        .blur(radius: max(size.height * band.blur, 0.5))
        .opacity(band.opacity)
        .offset(
            x: -size.width * 0.14,
            y: size.height * (band.y + band.height / 2 - 0.5)
        )
    }

    private func glow(size: CGSize) -> some View {
        let diameter = max(size.height * appearance.glow.radius * 2, 1)
        let warmColor = Color(hex: appearance.ramp.last ?? "#FFD17A")

        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.94),
                        warmColor.opacity(0.46),
                        .clear
                    ],
                    center: .center,
                    startRadius: 6,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
            .position(
                x: size.width * appearance.glow.centerX,
                y: size.height * appearance.glow.centerY
            )
            .opacity(appearance.glow.intensity)
    }
}
