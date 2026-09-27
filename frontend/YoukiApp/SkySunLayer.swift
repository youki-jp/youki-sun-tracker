import SwiftUI

struct SkySunLayer: View {
    let scene: SkyScene
    let size: CGSize

    var body: some View {
        ZStack {
            if scene.horizonGlow > 0.001 {
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.77, blue: 0.51).opacity(0.45), .clear],
                                         center: .center, startRadius: 0, endRadius: size.height * 0.57))
                    .frame(width: size.height * 1.14, height: size.height * 1.14)
                    .position(x: size.width * 0.5, y: size.height * 0.89)
                    .opacity(scene.horizonGlow)
            }
            if let sun = scene.sun {
                let radius = sun.radius * min(size.width, size.height)
                let center = CGPoint(x: size.width * sun.centerX, y: size.height * sun.centerY)
                let color = Color(red: 1, green: 0.99 - scene.warmth * 0.14,
                                  blue: 0.92 - scene.warmth * 0.33)
                Circle()
                    .fill(RadialGradient(colors: [color.opacity(0.48), color.opacity(0.18), .clear],
                                         center: .center, startRadius: 0,
                                         endRadius: radius * (9 + sun.softness * 6)))
                    .frame(width: radius * (18 + sun.softness * 12),
                           height: radius * (18 + sun.softness * 12))
                    .position(center)
                    .opacity(sun.opacity * sun.visibleLimb)
                Circle()
                    .fill(RadialGradient(colors: [color.opacity(0.5), .clear], center: .center,
                                         startRadius: 0, endRadius: radius * 2.3))
                    .frame(width: radius * 4.6, height: radius * 4.6)
                    .position(center)
                    .opacity(sun.opacity * sun.visibleLimb)
                Circle()
                    .fill(RadialGradient(stops: [
                        .init(color: color, location: 0),
                        .init(color: color.opacity(0.96), location: 0.72),
                        .init(color: color.opacity(0), location: 1)
                    ], center: .center, startRadius: 0,
                       endRadius: radius * (1.05 + sun.softness * 0.25)))
                    .frame(width: radius * 2.8, height: radius * 2.8)
                    .position(center)
                    .mask {
                        Rectangle()
                            .frame(width: size.width, height: max(0, center.y - radius + 2 * radius * sun.visibleLimb))
                            .frame(width: size.width, height: size.height, alignment: .top)
                    }
                    .opacity(sun.opacity)
            }
        }
        .accessibilityHidden(true)
    }
}
