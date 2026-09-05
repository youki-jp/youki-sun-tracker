import SwiftUI

struct SkyBackgroundView: View {
    let mood: SkyMood
    let isExpanded: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: mood.gradient, startPoint: .top, endPoint: .bottom)

            switch mood {
            case .vivid:
                cloudRow(color: Color(hex: "#54617C").opacity(0.55), y: 70, height: 28, blur: 10)
                cloudRow(color: Color(hex: "#7A7492").opacity(0.4), y: 165, height: 26, blur: 12)
                glow(width: 220, yOffset: 90, opacity: 1.0)
            case .clear:
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color(hex: "#7A7C84").opacity(0.16), Color(hex: "#868286").opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(maxHeight: .infinity, alignment: .bottom)
                glow(width: 210, yOffset: 84, opacity: 0.95)
            case .overcast:
                cloudRow(color: Color(hex: "#948AA2").opacity(0.72), y: 72, height: 40, blur: 14)
                cloudRow(color: Color(hex: "#A494AA").opacity(0.68), y: 214, height: 34, blur: 12)
                glow(width: 180, yOffset: 116, opacity: 0.78)
            case .pastel:
                cloudRow(color: Color(hex: "#A0A0BE").opacity(0.35), y: 180, height: 16, blur: 8)
                glow(width: 190, yOffset: 86, opacity: 0.84)
            case .muted:
                cloudRow(color: Color(hex: "#606678").opacity(0.58), y: 84, height: 30, blur: 12)
                cloudRow(color: Color(hex: "#82808E").opacity(0.42), y: 212, height: 24, blur: 10)
                glow(width: 170, yOffset: 92, opacity: 0.58)
            }
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

    private func cloudRow(color: Color, y: CGFloat, height: CGFloat, blur: CGFloat) -> some View {
        HStack(spacing: -24) {
            ForEach(0..<5, id: \.self) { index in
                Ellipse()
                    .fill(color.opacity(0.9 - Double(index) * 0.08))
                    .frame(width: 96 + CGFloat(index * 12), height: height + CGFloat(index % 2) * 6)
            }
        }
        .blur(radius: blur)
        .offset(x: -18, y: y)
    }

    private func glow(width: CGFloat, yOffset: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.94),
                        Color(red: 1.0, green: 0.87, blue: 0.62).opacity(0.46),
                        .clear
                    ],
                    center: .center,
                    startRadius: 6,
                    endRadius: width / 2
                )
            )
            .frame(width: width, height: width)
            .offset(y: yOffset)
            .opacity(opacity)
    }
}
