import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ServerViewModel()

    private let panelColor = Color(red: 0.14, green: 0.13, blue: 0.14)
    private let cardColor = Color(red: 0.17, green: 0.16, blue: 0.17)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let safeTop = proxy.safeAreaInsets.top
            let safeBottom = proxy.safeAreaInsets.bottom
            let hillAnchorY = safeTop + size.height * 0.38
            let sheetTop = hillAnchorY + 72
            let sheetHeight = max(size.height - sheetTop + safeBottom + 24, 320)

            ZStack(alignment: .top) {
                skyBackground(size: size, safeTop: safeTop, hillAnchorY: hillAnchorY)

                bottomSheet(width: size.width, height: sheetHeight, safeBottom: safeBottom)
                    .offset(y: sheetTop)
            }
            .ignoresSafeArea()
        }
        .task {
            viewModel.start()
        }
    }

    private func skyBackground(size: CGSize, safeTop: CGFloat, hillAnchorY: CGFloat) -> some View {
        let placement = viewModel.sunPlacement
        let sunX = size.width * placement.xRatio
        let sunY = hillAnchorY - 28 + (placement.yRatio - 0.84) * 38

        return ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    Color(red: 0.52, green: 0.66, blue: 0.90),
                    Color(red: 0.72, green: 0.64, blue: 0.80),
                    Color(red: 0.80, green: 0.45, blue: 0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            cloudLayer
                .padding(.top, safeTop + 16)

            locationPill
                .padding(.top, safeTop + 22)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.82, blue: 0.42).opacity(0.95),
                            Color(red: 0.98, green: 0.56, blue: 0.20).opacity(0.42),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 54
                    )
                )
                .frame(width: 110, height: 110)
                .position(x: sunX, y: sunY)
                .opacity(placement.opacity)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.94, blue: 0.72),
                            Color(red: 0.98, green: 0.74, blue: 0.28)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 36, height: 36)
                .shadow(color: Color.orange.opacity(0.32), radius: 18, y: 6)
                .position(x: sunX, y: sunY)
                .opacity(placement.opacity)

            Ellipse()
                .fill(panelColor)
                .frame(width: size.width * 1.95, height: 188)
                .overlay(
                    Ellipse()
                        .stroke(.white.opacity(0.02), lineWidth: 1)
                )
                .position(x: size.width / 2, y: hillAnchorY + 104)
        }
    }

    private func bottomSheet(width: CGFloat, height: CGFloat, safeBottom: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(panelColor)
                .ignoresSafeArea(edges: .bottom)

            VStack() {
                daySwitcher
                    .padding(.top, 0)

                summaryCard
                timelineCard
                footerBar
                    .padding(.top, 2)
                    .padding(.bottom, max(safeBottom, 12))
            }
            .padding(.horizontal, 24)
        }
        .clipShape(TopRoundedPanel(cornerRadius: 34))
    }

    private var locationPill: some View {
        Capsule()
            .fill(.white.opacity(0.16))
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.36), lineWidth: 1)
            )
            .frame(width: 150, height: 38)
            .overlay {
                Label(viewModel.locationName, systemImage: "location")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
            }
    }

    private var daySwitcher: some View {
        HStack(spacing: 20) {
            CircleButton(symbol: "chevron.left")

            Text("Today")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            CircleButton(symbol: "chevron.right")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(cardColor.opacity(0.9))
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.03), lineWidth: 1)
                )
        )
    }

    private var summaryCard: some View {
        let card = viewModel.phaseCard

        return VStack(spacing: 6) {
            Text(card.title)
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(card.subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))

            Image(systemName: "sun.max")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .padding(.vertical, 2)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.metricValue)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(card.metricLabel)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                Text(card.countdownText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 4)

            progressBar(progress: card.progress)

            Text(viewModel.cardCaption)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(surfaceCard(radius: 28))
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.72))
                    .lineLimit(1)
            }

            if viewModel.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text("Updating sun data...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            ForEach(viewModel.timelineEntries) { entry in
                HStack(spacing: 12) {
                    Image(systemName: entry.symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 16)

                    Text(entry.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(entry.value)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.84))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(surfaceCard(radius: 24))
    }

    private var footerBar: some View {
        HStack {
            Label("sunlight", systemImage: "sun.max.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.39))

            Spacer()

            Button {
                viewModel.refresh()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 10)
    }

    private func progressBar(progress: Double) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(0.12))
                .frame(height: 6)

            GeometryReader { proxy in
                Capsule()
                    .fill(.white.opacity(0.92))
                    .frame(width: max(proxy.size.width * progress, 18), height: 6)
            }
        }
        .frame(height: 6)
    }

    private func surfaceCard(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(cardColor)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(.white.opacity(0.04), lineWidth: 1)
            )
    }

    private var cloudLayer: some View {
        ZStack {
            cloudRow(width: 154, height: 44, opacity: 0.12)
                .offset(x: -94, y: 10)

            cloudRow(width: 170, height: 48, opacity: 0.11)
                .offset(x: 92, y: 10)

            cloudRow(width: 126, height: 38, opacity: 0.10)
                .offset(x: -88, y: 62)

            cloudRow(width: 138, height: 40, opacity: 0.09)
                .offset(x: 100, y: 72)
        }
    }

    private func cloudRow(width: CGFloat, height: CGFloat, opacity: Double) -> some View {
        HStack(spacing: -18) {
            Circle().frame(width: height * 0.82, height: height * 0.82)
            Circle().frame(width: height, height: height)
            Circle().frame(width: height * 0.9, height: height * 0.9)
            Circle().frame(width: height * 1.06, height: height * 1.06)
        }
        .frame(width: width, height: height)
        .foregroundStyle(.white.opacity(opacity))
    }
}

private struct CircleButton: View {
    let symbol: String

    var body: some View {
        Circle()
            .stroke(.white.opacity(0.58), lineWidth: 1)
            .frame(width: 26, height: 26)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
    }
}

private struct TopRoundedPanel: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ContentView()
}
