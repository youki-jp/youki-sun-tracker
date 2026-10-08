import SwiftUI
import AuthenticationServices

struct ContentView: View {
    @StateObject var serverViewModel = ServerViewModel()
    @StateObject var authSession = AuthSession.shared
    @State private var isRestoringSession = true
    @State var isSkyExpanded = false
    @State var activeSheet: ActiveSheet?
    @StateObject var alarmModel = GoldenHourAlarmViewModel()
    @State var showAccountScreen = false
    @State var showCalendarInfo = false
    @State var manualLatitude = ""
    @State var manualLongitude = ""
    @State var manualAltitude = ""
    @FocusState var coordinateFocus: String?
    @State var appTheme: AppTheme = .dark
    @AppStorage("appLanguage") var appLanguage = "en"
    @Environment(\.scenePhase) private var scenePhase

    var backgroundColor: Color { appTheme.backgroundColor }
    var panelColor: Color { appTheme.panelColor }
    var inkColor: Color { appTheme.inkColor }
    var accentColor: Color { appTheme.accentColor }
    var barColor: Color { appTheme.barColor }
    var cardColor: Color { appTheme.cardColor }
    var selectedMoment: SkyMoment { serverViewModel.selectedMoment }
    var selectedAppearance: SkyAppearance { serverViewModel.skyScene.base }
    var selectedRamp: [Color] { selectedAppearance.ramp.map { Color(hex: $0) } }
    var scoreText: String {
        guard serverViewModel.isScoreAvailable, let selectedDay else { return "—" }
        return String(selectedDay.qualityScore)
    }

    var selectedDay: PrototypeDay? { serverViewModel.forecastDays.first }

    private var isPreviewRun: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-uiAudit")
            || ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-uiSkyFixture") }
        #else
        return false
        #endif
    }

    var body: some View {
        Group {
            if isRestoringSession {
                ZStack {
                    panelColor.ignoresSafeArea()
                    ProgressView("Opening your sky…").tint(accentColor)
                        .foregroundStyle(inkColor)
                }
            } else if authSession.isAuthenticated || isPreviewRun {
                forecastBody
            } else {
                AccountEntryView(authSession: authSession, appTheme: appTheme,
                                 onClose: {}, initialMode: .signIn)
            }
        }
        .task {
            isRestoringSession = false
            await authSession.refreshAccount()
        }
        .onChange(of: authSession.account?.tier) { old, new in
            if old != nil && new != nil && old != new {
                Task { await serverViewModel.accountTierDidChange() }
            }
        }
        .onChange(of: authSession.isAuthenticated) { _, signedIn in
            showAccountScreen = false
            activeSheet = nil
            isSkyExpanded = false
            if !signedIn { serverViewModel.showSample() }
        }
        .environment(\.locale, Locale(identifier: appLanguage))
    }

    private var forecastBody: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom
            let contentWidth = max(proxy.size.width - 52, 0)
            let compactLayout = proxy.size.height < 740
            let heroHeight = skyHeight(for: proxy)
            let panelHeight = max(proxy.size.height - heroHeight, 0)
            let headerHeight: CGFloat = compactLayout ? 88 : 98
            let sectionSpacing: CGFloat = compactLayout ? 10 : 14
            let topPadding: CGFloat = compactLayout ? 10 : 16
            let rowHeight = max(28, (panelHeight - headerHeight - 30 - topPadding - sectionSpacing * 2 - 8) / 7)

            ZStack(alignment: .bottom) {
                backgroundColor
                    .ignoresSafeArea(.container, edges: .vertical)

                VStack(spacing: 0) {
                    skyHero(
                        height: heroHeight,
                        topInset: topInset
                    )

                    if !isSkyExpanded {
                        VStack(alignment: .leading, spacing: 0) {
                            if serverViewModel.isLoading {
                                forecastSkeleton(availableWidth: contentWidth, headerHeight: headerHeight,
                                                 rowHeight: rowHeight, sectionSpacing: sectionSpacing,
                                                 compact: compactLayout)
                                    .padding(.top, topPadding)
                            } else if selectedDay != nil {
                                scoreHeader(availableWidth: contentWidth, compact: compactLayout)
                                    .frame(height: headerHeight, alignment: .top)
                                    .padding(.top, topPadding)

                                predictedColorRamp
                                    .frame(width: contentWidth)
                                    .padding(.top, sectionSpacing)

                                eventTimeline(rowHeight: rowHeight, compact: compactLayout)
                                    .frame(width: contentWidth)
                                    .padding(.top, sectionSpacing)
                            } else {
                                forecastEmptyState
                                    .frame(maxWidth: contentWidth, maxHeight: .infinity)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 26)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .frame(height: panelHeight, alignment: .top)
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
                .ignoresSafeArea(edges: isSkyExpanded ? .all : .top)

                if isSkyExpanded {
                    Group {
                        if selectedDay != nil && !serverViewModel.isLoading {
                            analysisCard(width: proxy.size.width - 32)
                        } else {
                            analysisEmptyCard(width: proxy.size.width - 32)
                        }
                    }
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
                case .alarm:
                    GoldenHourAlarmSheet(model: alarmModel, server: serverViewModel,
                                         theme: appTheme)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                case .calendar:
                    calendarSheet
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                case .settings:
                    settingsSheet
                        .presentationDetents([.height(500)])
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
            .fullScreenCover(isPresented: $showAccountScreen) {
                AccountScreen(authSession: authSession, appTheme: appTheme) {
                    showAccountScreen = false
                }
            }
        }
        .preferredColorScheme(appTheme.colorScheme)
        .onChange(of: serverViewModel.isLoading) { _, loading in
            if loading { isSkyExpanded = false }
        }
        .onChange(of: authSession.isAuthenticated) { _, signedIn in
            if !signedIn { serverViewModel.showSample() }
        }
        .onChange(of: scenePhase) { _, phase in
            serverViewModel.setForeground(phase == .active)
            if phase == .active {
                serverViewModel.selectNow()
                Task { await authSession.refreshAccount() }
            }
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uiSkyFixture") }) {
                await serverViewModel.load(ForecastCoordinates(latitude: 35, longitude: 139)!)
                return
            }
            // UI audits enter explicit coordinates instead of depending on simulator GPS.
            if ProcessInfo.processInfo.arguments.contains("-uiAudit") {
                serverViewModel.showSample()
                return
            }
            #endif
            await authSession.refreshAccount()
            await serverViewModel.loadForecast()
        }
    }

    func skyHeight(for proxy: GeometryProxy) -> CGFloat {
        isSkyExpanded
            ? proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            : max(200, min(244, proxy.size.height * 0.31))
    }

    func skyHero(height: CGFloat, topInset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            if serverViewModel.hasLiveSky {
                SkyBackgroundView(scene: serverViewModel.skyScene, isExpanded: isSkyExpanded)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("skyAppearance")
                    .accessibilityLabel(serverViewModel.skyScene.accessibilityDescription)
            } else {
                LinearGradient(
                    colors: appTheme == .dark
                        ? [Color(hex: "#35353D"), Color(hex: "#565461")]
                        : [Color(hex: "#AEBAC9"), Color(hex: "#D2DCE6")],
                    startPoint: .top, endPoint: .bottom
                )
                .accessibilityLabel(serverViewModel.isLoading ? "Loading sky" : "Sky color unavailable")
            }

            VStack(spacing: 0) {
                Button {
                    activeSheet = .locations
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 12, weight: .semibold))
                        Text(AppLocalization.text(serverViewModel.locationName))
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

                Text(serverViewModel.displayedDateLabel)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 10)
                    .accessibilityIdentifier("forecastDateLabel")
                Text(serverViewModel.forecastProvenance)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                Text(serverViewModel.nextEventLabel)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 6)
                    .accessibilityIdentifier("nextEventLabel")

                if serverViewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.7)
                        .padding(.top, 12)
                        .accessibilityIdentifier("forecastLoadingIndicator")
                } else if serverViewModel.errorMessage != nil && selectedDay != nil {
                    Button(authSession.isAuthenticated ? "Retry" : "Sign in for live sky") {
                        if authSession.isAuthenticated { Task { await serverViewModel.retryForecast() } }
                        else { showAccountScreen = true }
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("retryForecastButton")
                    .padding(.top, 8)
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedDay != nil && !serverViewModel.isLoading {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.88)) {
                    isSkyExpanded.toggle()
                }
            }
        }
    }
}
