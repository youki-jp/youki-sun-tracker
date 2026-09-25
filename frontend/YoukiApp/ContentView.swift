import SwiftUI

struct ContentView: View {
    @StateObject var serverViewModel = ServerViewModel()
    @State var selectedDayID = "today"
    @State var isSkyExpanded = false
    @State var activeSheet: ActiveSheet?
    @State var wakeEnabled = true
    @State var smartAlarmEnabled = true
    @State var sunsetAlertEnabled = false
    @State var selectedPlan: SubscriptionPlan = .yearly
    @State var showCalendarInfo = false
    @State var manualLatitude = ""
    @State var manualLongitude = ""
    @State var manualAltitude = ""
    @FocusState var coordinateFocus: String?
    @State var appTheme: AppTheme = .dark

    var backgroundColor: Color { appTheme.backgroundColor }
    var panelColor: Color { appTheme.panelColor }
    var inkColor: Color { appTheme.inkColor }
    var accentColor: Color { appTheme.accentColor }
    var barColor: Color { appTheme.barColor }
    var cardColor: Color { appTheme.cardColor }
    var selectedMoment: SkyMoment { serverViewModel.selectedMoment }
    var selectedAppearance: SkyAppearance { serverViewModel.skyAppearance }
    var selectedRamp: [Color] { selectedAppearance.ramp.map { Color(hex: $0) } }
    var scoreText: String { serverViewModel.isScoreAvailable ? String(selectedDay.qualityScore) : "—" }

    var selectedDay: PrototypeDay {
        serverViewModel.forecastDays.first(where: { $0.id == selectedDayID })
            ?? serverViewModel.forecastDays.first
            ?? PrototypeDay.sampleDays[0]
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom
            let contentWidth = max(proxy.size.width - 52, 0)

            ZStack(alignment: .bottom) {
                backgroundColor
                    .ignoresSafeArea(.container, edges: .vertical)

                VStack(spacing: 0) {
                    skyHero(
                        height: skyHeight(for: proxy),
                        topInset: topInset
                    )

                    if !isSkyExpanded {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                scoreHeader(availableWidth: contentWidth)
                                    .padding(.top, 28)

                                predictedColorRamp
                                    .frame(width: contentWidth)
                                    .padding(.top, 24)

                                eventTimeline
                                    .frame(width: contentWidth)
                                    .padding(.top, 20)
                            }
                            .padding(.horizontal, 26)
                            .padding(.bottom, 76)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .background(
                            panelColor
                                .ignoresSafeArea(.container, edges: .horizontal)
                        )
                    }
                }
                .frame(
                    height: isSkyExpanded ? proxy.size.height + topInset + bottomInset : proxy.size.height,
                    alignment: .topLeading
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: isSkyExpanded ? 0 : 32, style: .continuous))
                .ignoresSafeArea(edges: isSkyExpanded ? .all : .top)

                if isSkyExpanded {
                    analysisCard(width: proxy.size.width - 32)
                        .padding(.bottom, bottomInset + 64)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .ignoresSafeArea(edges: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                    Button {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.88)) {
                            isSkyExpanded = false
                        }
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .padding(14)
                            .background(.black.opacity(0.25), in: Circle())
                    }
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("expandButton")
                    .padding(.bottom, 10)
                }

                if !isSkyExpanded {
                    bottomBar
                        .frame(width: proxy.size.width)
                        .background(barColor)
                        .ignoresSafeArea(edges: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .foregroundStyle(inkColor)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .calendar:
                    calendarSheet
                        .presentationDetents([.height(520)])
                        .presentationDragIndicator(.visible)
                case .settings:
                    settingsSheet
                        .presentationDetents([.height(420)])
                        .presentationDragIndicator(.visible)
                case .locations:
                    locationsSheet
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                case .paywall:
                    paywallSheet
                        .presentationDetents([.height(430)])
                        .presentationDragIndicator(.visible)
                }
            }
        }
        .preferredColorScheme(appTheme.colorScheme)
        .task {
            #if DEBUG
            // UI audits enter explicit coordinates instead of depending on simulator GPS.
            if ProcessInfo.processInfo.arguments.contains("-uiAudit") { return }
            #endif
            await serverViewModel.loadForecast()
        }
    }

    func skyHeight(for proxy: GeometryProxy) -> CGFloat {
        isSkyExpanded ? proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom : 266
    }

    func skyHero(height: CGFloat, topInset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            SkyBackgroundView(appearance: selectedAppearance, isExpanded: isSkyExpanded)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("skyAppearance")
                .accessibilityLabel(selectedAppearance.stops.map(\.hex).joined(separator: ","))

            VStack(spacing: 0) {
                Button {
                    activeSheet = .locations
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 12, weight: .semibold))
                        Text(selectedDay.location)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("locationButton")
                .padding(.top, topInset + 10)

                HStack(spacing: 7) {
                    if serverViewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.7)
                    }
                    Text(serverViewModel.statusText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .accessibilityIdentifier("forecastStatus")
                    if !serverViewModel.isLoading && !serverViewModel.isLive {
                        Button("Retry") {
                            Task { await serverViewModel.loadForecast() }
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .accessibilityIdentifier("retryForecastButton")
                    }
                }
                .foregroundStyle(.white.opacity(0.86))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.18), in: Capsule())
                .padding(.top, 8)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.88)) {
                isSkyExpanded.toggle()
            }
        }
    }
}
