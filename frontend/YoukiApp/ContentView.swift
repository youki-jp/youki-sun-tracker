import SwiftUI

struct ContentView: View {
    @State var selectedDayID = PrototypeDay.sampleDays[0].id
    @State var isSkyExpanded = false
    @State var activeSheet: ActiveSheet?
    @State var wakeEnabled = true
    @State var smartAlarmEnabled = true
    @State var sunsetAlertEnabled = false
    @State var selectedPlan: SubscriptionPlan = .yearly
    @State var showCalendarInfo = false
    @State var selectedMoment: SkyMoment = .sunrise
    @State var appTheme: AppTheme = .dark

    var backgroundColor: Color { appTheme.backgroundColor }
    var panelColor: Color { appTheme.panelColor }
    var inkColor: Color { appTheme.inkColor }
    var accentColor: Color { appTheme.accentColor }
    var barColor: Color { appTheme.barColor }
    var cardColor: Color { appTheme.cardColor }

    var selectedDay: PrototypeDay {
        PrototypeDay.sampleDays.first(where: { $0.id == selectedDayID }) ?? PrototypeDay.sampleDays[0]
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
                        ZStack(alignment: .topLeading) {
                            panelColor

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
                            .padding(.bottom, 12)
                            .frame(width: contentWidth, alignment: .topLeading)
                            .padding(.leading, 26)
                        }
                        .frame(width: proxy.size.width, alignment: .top)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .offset(x: -50)
                    }
                }
                .frame(
                    width: proxy.size.width,
                    height: isSkyExpanded ? proxy.size.height + topInset + bottomInset : proxy.size.height,
                    alignment: .topLeading
                )
                .clipShape(RoundedRectangle(cornerRadius: isSkyExpanded ? 0 : 32, style: .continuous))
                .ignoresSafeArea(edges: isSkyExpanded ? .all : .top)

                if isSkyExpanded {
                    analysisCard(width: proxy.size.width - 32)
                        .padding(.bottom, bottomInset + 64)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .ignoresSafeArea(edges: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
                        .presentationDetents([.height(420)])
                        .presentationDragIndicator(.visible)
                case .paywall:
                    paywallSheet
                        .presentationDetents([.height(430)])
                        .presentationDragIndicator(.visible)
                }
            }
        }
        .preferredColorScheme(appTheme.colorScheme)
    }

    func skyHeight(for proxy: GeometryProxy) -> CGFloat {
        isSkyExpanded ? proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom : 266
    }

    func skyHero(height: CGFloat, topInset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            SkyBackgroundView(mood: selectedDay.mood, isExpanded: isSkyExpanded)

            if let overlay = selectedMoment.overlayGradient {
                LinearGradient(colors: overlay, startPoint: .top, endPoint: .bottom)
                    .opacity(0.26)
            }

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
                .padding(.top, topInset + 10)

                Spacer()
            }
            .offset(x: -50)
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
