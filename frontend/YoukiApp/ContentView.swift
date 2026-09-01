import SwiftUI

struct ContentView: View {
    @State private var selectedDayID = PrototypeDay.sampleDays[0].id
    @State private var isSkyExpanded = false
    @State private var activeSheet: ActiveSheet?
    @State private var wakeEnabled = true
    @State private var smartAlarmEnabled = true
    @State private var sunsetAlertEnabled = false
    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var showCalendarInfo = false
    @State private var selectedMoment: SkyMoment = .sunrise
    @State private var appTheme: AppTheme = .dark

    private var backgroundColor: Color { appTheme.backgroundColor }
    private var panelColor: Color { appTheme.panelColor }
    private var inkColor: Color { appTheme.inkColor }
    private var accentColor: Color { appTheme.accentColor }
    private var barColor: Color { appTheme.barColor }
    private var cardColor: Color { appTheme.cardColor }

    private var selectedDay: PrototypeDay {
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
                        .presentationDetents([.height(480)])
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

    private func skyHeight(for proxy: GeometryProxy) -> CGFloat {
        isSkyExpanded ? proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom : 266
    }

    private func skyHero(height: CGFloat, topInset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            SkyBackgroundView(mood: selectedDay.mood, isExpanded: isSkyExpanded, accentColor: accentColor)

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
            .offset(x: isSkyExpanded ? -50 : 0)

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

    private func scoreHeader(availableWidth: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            scoreHeaderPrimary
                .frame(width: max(availableWidth - 150, 0), alignment: .leading)

            scoreHeaderSecondary(alignment: .trailing)
                .frame(width: 142, alignment: .trailing)
        }
        .frame(width: availableWidth, alignment: .leading)
    }

    private var scoreHeaderPrimary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(selectedDay.qualityScore)")
                .font(.system(size: 72, weight: .light, design: .rounded))
                .tracking(-2.5)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(selectedDay.summaryLabel)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func scoreHeaderSecondary(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(selectedDay.heroTime)
                .font(.system(size: 24, weight: .medium, design: .rounded))

            Text(selectedDay.heroSubtitle)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(accentColor)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    wakeEnabled.toggle()
                }
            } label: {
                Text(wakeEnabled ? "Wake alarm on" : "Wake me")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(wakeEnabled ? accentColor : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(wakeEnabled ? accentColor.opacity(0.12) : accentColor)
                    )
                    .overlay {
                        Capsule()
                            .stroke(wakeEnabled ? accentColor.opacity(0.35) : accentColor, lineWidth: 1.5)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var predictedColorRamp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PREDICTED COLORS")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(inkColor.opacity(0.55))

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: selectedDay.colorRamp,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 12)
        }
    }

    private var eventTimeline: some View {
        VStack(spacing: 0) {
            ForEach(SkyMoment.allCases) { moment in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedMoment = moment
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(moment == selectedMoment ? moment.dotColor : Color.clear)
                            .frame(width: 9, height: 9)
                            .overlay {
                                Circle()
                                    .stroke(moment == selectedMoment ? moment.dotColor : inkColor.opacity(0.25), lineWidth: moment == selectedMoment ? 0 : 1.5)
                            }

                        Text(moment.label)
                            .font(.system(size: 14, weight: moment == selectedMoment ? .semibold : .medium, design: .rounded))

                        Spacer()

                        Text(selectedDay.time(for: moment))
                            .font(.system(size: 13, weight: moment == selectedMoment ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(moment == selectedMoment ? inkColor : inkColor.opacity(0.55))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(moment == selectedMoment ? accentColor.opacity(0.09) : .clear)
                    )
                    .overlay(alignment: .bottom) {
                        if moment != SkyMoment.allCases.last {
                            Divider()
                                .padding(.leading, 30)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func analysisCard(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            HStack {
                Text("Color analysis")
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                Spacer()

                Text("\(selectedDay.qualityScore)/100")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            .padding(.top, 12)

            Text(selectedDay.analysisText)
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(colors: selectedDay.colorRamp, startPoint: .leading, endPoint: .trailing)
                )
                .frame(height: 10)
                .padding(.top, 16)

            HStack {
                Text(selectedDay.firstLight)
                Spacer()
                Text(selectedDay.sunrise)
                Spacer()
                Text(selectedDay.blueEnd)
            }
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.72))
            .padding(.top, 6)

            analysisMetrics
                .padding(.top, 16)
                .overlay(alignment: .top) {
                    Divider()
                        .background(.white.opacity(0.15))
                }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.black.opacity(0.38))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .foregroundStyle(.white)
    }

    private var analysisMetrics: some View {
        HStack(spacing: 18) {
            analysisMetric(title: "Golden", value: selectedDay.golden)
            analysisMetric(title: "Cloud", value: selectedDay.cloud)
            analysisMetric(title: "UV", value: selectedDay.uv)
        }
    }

    private func analysisMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))

            Text(value)
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bottomBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 15, height: 15)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.6), lineWidth: 2)
                            .padding(2)
                    }
                Text("youki")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }

            Spacer()

            HStack(spacing: 2) {
                bottomIconButton(systemName: isSkyExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.88)) {
                        isSkyExpanded.toggle()
                    }
                }
                bottomIconButton(systemName: "calendar") {
                    activeSheet = .calendar
                }
                bottomIconButton(systemName: "slider.horizontal.3") {
                    activeSheet = .settings
                }
            }
        }
        .padding(.horizontal, 30)
        .frame(height: 60)
        .background(barColor.opacity(0.94))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func bottomIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(inkColor.opacity(0.68))
        }
        .buttonStyle(.plain)
    }

    private var calendarSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Forecast calendar")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .padding(.bottom, 12)

                ForEach(PrototypeDay.sampleDays) { day in
                    Button {
                        if day.isLocked {
                            activeSheet = .paywall
                        } else {
                            selectedDayID = day.id
                            activeSheet = nil
                        }
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(day.weekday)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    if day.id == selectedDayID {
                                        Circle()
                                            .fill(accentColor)
                                            .frame(width: 6, height: 6)
                                    }
                                }

                                Text(day.dateLabel)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(inkColor.opacity(0.55))
                            }

                            Spacer()

                            Text(day.confidenceLabel)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(inkColor.opacity(0.5))

                            if day.isLocked {
                                Image(systemName: "lock")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(inkColor.opacity(0.55))
                            } else {
                                Circle()
                                    .fill(day.mood.displayColor)
                                    .frame(width: 9, height: 9)
                                Text("\(day.qualityScore)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                            }
                        }
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    Divider()
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCalendarInfo.toggle()
                    }
                } label: {
                    Label("About these forecasts", systemImage: "info.circle")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(inkColor.opacity(0.62))
                        .padding(.top, 16)
                }
                .buttonStyle(.plain)

                if showCalendarInfo {
                    Text("This prototype uses a curated quality score to show how sunrise potential could be presented over the week. Locked days hint at a future premium forecast view.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(inkColor.opacity(0.55))
                        .lineSpacing(3)
                        .padding(.top, 10)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .background(panelColor)
        }
    }

    private var settingsSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.bottom, 12)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Theme")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("Preview the light and dark mock")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(inkColor.opacity(0.55))
                }

                Spacer()

                Picker("Theme", selection: $appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 142)
            }
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Divider()
            }

            settingsRow(
                title: "Plan",
                subtitle: selectedPlan == .yearly ? "Youki Pro yearly" : "Youki Pro monthly"
            ) {
                Button("Upgrade") {
                    activeSheet = .paywall
                }
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(accentColor, in: Capsule())
                .foregroundStyle(.white)
            }

            settingsToggleRow(
                title: "Smart alarm",
                subtitle: "Wake you when the forecast peaks.",
                isOn: $smartAlarmEnabled
            )

            settingsToggleRow(
                title: "Sunset alerts",
                subtitle: "Evening reminders for strong glow days.",
                isOn: $sunsetAlertEnabled
            )

            Button {
                activeSheet = .locations
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All settings")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("Locations, forecast defaults, notifications")
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(inkColor.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(inkColor.opacity(0.45))
                }
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .background(panelColor)
    }

    private func settingsRow<Accessory: View>(
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(inkColor.opacity(0.55))
            }
            Spacer()
            accessory()
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func settingsToggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(inkColor.opacity(0.55))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(accentColor)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var locationsSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Locations")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.bottom, 14)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                Text("Search city")
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(inkColor.opacity(0.45))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(inkColor.opacity(0.08), lineWidth: 1)
            }

            Button {
                activeSheet = nil
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "location.circle.fill")
                    Text("Use my location")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(accentColor)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .bottom) {
                Divider()
            }

            ForEach(PrototypeLocation.sampleLocations) { location in
                Button {
                    activeSheet = nil
                } label: {
                    HStack {
                        HStack(spacing: 10) {
                            Image(systemName: "circle.grid.2x2")
                                .foregroundStyle(inkColor.opacity(0.4))
                            Text(location.name)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        Spacer()
                        if location.isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(accentColor)
                        }
                    }
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) {
                    Divider()
                }
            }

            Button {
                activeSheet = .paywall
            } label: {
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                        Text("Add location")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(inkColor.opacity(0.55))

                    Spacer()

                    Image(systemName: "lock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(inkColor.opacity(0.45))
                }
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .background(panelColor)
    }

    private var paywallSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 16, height: 16)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.6), lineWidth: 2)
                            .padding(2)
                    }
                Text("Youki Pro")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }

            Text("Unlock a full week of sky forecasts, smart sunrise alarms, and widgets for your next glow window.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(inkColor.opacity(0.58))
                .lineSpacing(3)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 12) {
                paywallFeature("7-day sunrise and sunset outlook")
                paywallFeature("Smart alarm timed to the best color window")
                paywallFeature("Multiple saved locations")
                paywallFeature("Home Screen widgets")
            }
            .padding(.top, 18)

            HStack(spacing: 10) {
                subscriptionCard(
                    plan: .yearly,
                    title: "Yearly",
                    note: "Best value",
                    isSelected: selectedPlan == .yearly
                )
                subscriptionCard(
                    plan: .monthly,
                    title: "Monthly",
                    note: "Flexible",
                    isSelected: selectedPlan == .monthly
                )
            }
            .padding(.top, 18)

            Button {
                activeSheet = nil
            } label: {
                Text("Start free trial")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)

            Text("Restore purchases")
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(inkColor.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            Spacer()
        }
        .padding(.horizontal, 26)
        .padding(.top, 12)
        .background(panelColor)
    }

    private func paywallFeature(_ text: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(accentColor)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
        }
    }

    private func subscriptionCard(
        plan: SubscriptionPlan,
        title: String,
        note: String,
        isSelected: Bool
    ) -> some View {
        Button {
            selectedPlan = plan
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(note)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? accentColor : inkColor.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(cardColor)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? accentColor : inkColor.opacity(0.12), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }
}

private enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var colorScheme: ColorScheme {
        self == .dark ? .dark : .light
    }

    var backgroundColor: Color {
        self == .dark ? Color(hex: "#141110") : Color(hex: "#ECE5DA")
    }

    var panelColor: Color {
        self == .dark ? Color(hex: "#141110") : Color(hex: "#F6F1E8")
    }

    var inkColor: Color {
        self == .dark ? Color(hex: "#F3ECE1") : Color(hex: "#1B1712")
    }

    var accentColor: Color {
        self == .dark ? Color(hex: "#F0B968") : Color(hex: "#C37A2C")
    }

    var barColor: Color {
        self == .dark ? Color(hex: "#141110") : Color(hex: "#F6F1E8")
    }

    var cardColor: Color {
        self == .dark ? Color.white.opacity(0.06) : Color(hex: "#1B1712").opacity(0.05)
    }
}

private enum ActiveSheet: String, Identifiable {
    case calendar
    case settings
    case locations
    case paywall

    var id: String { rawValue }
}

private enum SubscriptionPlan {
    case yearly
    case monthly
}

private enum SkyMoment: String, CaseIterable, Identifiable {
    case firstLight
    case goldenHour
    case sunrise
    case daylight
    case goldenHourPM
    case sunset

    var id: String { rawValue }

    var label: String {
        switch self {
        case .firstLight:
            return "First light"
        case .goldenHour:
            return "Golden hour"
        case .sunrise:
            return "Sunrise"
        case .daylight:
            return "Daylight"
        case .goldenHourPM:
            return "Golden PM"
        case .sunset:
            return "Sunset"
        }
    }

    var dotColor: Color {
        switch self {
        case .firstLight, .daylight:
            return Color.white.opacity(0.75)
        case .goldenHour, .goldenHourPM:
            return Color(red: 224 / 255, green: 145 / 255, blue: 58 / 255)
        case .sunrise:
            return Color(red: 195 / 255, green: 122 / 255, blue: 44 / 255)
        case .sunset:
            return Color.black.opacity(0.28)
        }
    }

    var overlayGradient: [Color]? {
        switch self {
        case .firstLight:
            return [Color.indigo.opacity(0.18), Color.orange.opacity(0.2)]
        case .goldenHour:
            return [Color.pink.opacity(0.14), Color.orange.opacity(0.24)]
        case .sunrise:
            return [Color.orange.opacity(0.15), Color.yellow.opacity(0.18)]
        case .daylight:
            return [Color.clear]
        case .goldenHourPM:
            return [Color.orange.opacity(0.16), Color.red.opacity(0.16)]
        case .sunset:
            return [Color.red.opacity(0.18), Color.purple.opacity(0.16)]
        }
    }
}

private enum SkyMood: String {
    case vivid
    case clear
    case overcast
    case pastel
    case muted

    var gradient: [Color] {
        switch self {
        case .vivid:
            return [
                Color(hex: "#6E7F99"),
                Color(hex: "#8B89A2"),
                Color(hex: "#A68AA0"),
                Color(hex: "#C28D97"),
                Color(hex: "#DE8D7D"),
                Color(hex: "#F29A72"),
                Color(hex: "#F9A55C"),
                Color(hex: "#FFD27A")
            ]
        case .clear:
            return [
                Color(hex: "#2E4157"),
                Color(hex: "#48607A"),
                Color(hex: "#748BA0"),
                Color(hex: "#A7B6BC"),
                Color(hex: "#DCC68F"),
                Color(hex: "#F0B656"),
                Color(hex: "#F7A844")
            ]
        case .overcast:
            return [
                Color(hex: "#9791A6"),
                Color(hex: "#A89CB2"),
                Color(hex: "#B6A5B6"),
                Color(hex: "#C9ADB4"),
                Color(hex: "#EEBD80"),
                Color(hex: "#F4A94F")
            ]
        case .pastel:
            return [
                Color(hex: "#46536E"),
                Color(hex: "#687792"),
                Color(hex: "#8B96AB"),
                Color(hex: "#C2B49F"),
                Color(hex: "#ECD39A"),
                Color(hex: "#FFD98A")
            ]
        case .muted:
            return [
                Color(hex: "#5A6474"),
                Color(hex: "#79808F"),
                Color(hex: "#8A8EA0"),
                Color(hex: "#A89E9E"),
                Color(hex: "#C4AB92"),
                Color(hex: "#D9B183")
            ]
        }
    }

    var displayColor: Color {
        switch self {
        case .vivid:
            return Color(hex: "#F29A72")
        case .clear:
            return Color(hex: "#F0B656")
        case .overcast:
            return Color(hex: "#C9ADB4")
        case .pastel:
            return Color(hex: "#ECD39A")
        case .muted:
            return Color(hex: "#A89E9E")
        }
    }
}

private struct PrototypeDay: Identifiable {
    let id: String
    let weekday: String
    let dateLabel: String
    let qualityScore: Int
    let summaryLabel: String
    let heroTime: String
    let heroSubtitle: String
    let location: String
    let mood: SkyMood
    let firstLight: String
    let golden: String
    let sunrise: String
    let daylight: String
    let goldenPM: String
    let sunset: String
    let blueEnd: String
    let cloud: String
    let uv: String
    let confidenceLabel: String
    let analysisText: String
    let colorRamp: [Color]
    let isLocked: Bool

    func time(for moment: SkyMoment) -> String {
        switch moment {
        case .firstLight:
            return firstLight
        case .goldenHour:
            return golden
        case .sunrise:
            return sunrise
        case .daylight:
            return daylight
        case .goldenHourPM:
            return goldenPM
        case .sunset:
            return sunset
        }
    }

    static let sampleDays: [PrototypeDay] = [
        PrototypeDay(
            id: "today",
            weekday: "Today",
            dateLabel: "Tue, Aug 25",
            qualityScore: 72,
            summaryLabel: "Promising sunrise glow",
            heroTime: "5:14",
            heroSubtitle: "Golden light starts in 18 min",
            location: "Tokyo, Japan",
            mood: .vivid,
            firstLight: "4:47",
            golden: "4:58",
            sunrise: "5:14",
            daylight: "5:42",
            goldenPM: "18:02",
            sunset: "18:27",
            blueEnd: "5:31",
            cloud: "Broken high clouds",
            uv: "2",
            confidenceLabel: "High confidence",
            analysisText: "Thin high clouds and modest aerosols should catch the first warm light nicely. Expect peach and apricot tones before sunrise, with the strongest color right around the horizon break.",
            colorRamp: [Color(hex: "#6E7F99"), Color(hex: "#DE8D7D"), Color(hex: "#F29A72"), Color(hex: "#FFBE5E"), Color(hex: "#FFD27A")],
            isLocked: false
        ),
        PrototypeDay(
            id: "wed",
            weekday: "Wed",
            dateLabel: "Aug 26",
            qualityScore: 64,
            summaryLabel: "Warm, soft sunrise",
            heroTime: "5:15",
            heroSubtitle: "Pastel conditions likely",
            location: "Tokyo, Japan",
            mood: .pastel,
            firstLight: "4:48",
            golden: "5:00",
            sunrise: "5:15",
            daylight: "5:43",
            goldenPM: "18:01",
            sunset: "18:26",
            blueEnd: "5:33",
            cloud: "Humid haze",
            uv: "3",
            confidenceLabel: "Good confidence",
            analysisText: "Humidity is likely to soften the scene into a gentler palette. Think blush pink and pale gold more than a dramatic red-orange blast.",
            colorRamp: [Color(hex: "#687792"), Color(hex: "#8B96AB"), Color(hex: "#C2B49F"), Color(hex: "#ECD39A"), Color(hex: "#FFD98A")],
            isLocked: false
        ),
        PrototypeDay(
            id: "thu",
            weekday: "Thu",
            dateLabel: "Aug 27",
            qualityScore: 58,
            summaryLabel: "Balanced morning light",
            heroTime: "5:16",
            heroSubtitle: "Cleaner air, fewer clouds",
            location: "Tokyo, Japan",
            mood: .clear,
            firstLight: "4:49",
            golden: "5:01",
            sunrise: "5:16",
            daylight: "5:44",
            goldenPM: "18:00",
            sunset: "18:24",
            blueEnd: "5:35",
            cloud: "Mostly clear",
            uv: "4",
            confidenceLabel: "Medium confidence",
            analysisText: "A cleaner, clearer sky should produce a neat golden edge at sunrise, though the scene may feel less layered than on a cloud-assisted day.",
            colorRamp: [Color(hex: "#48607A"), Color(hex: "#748BA0"), Color(hex: "#DCC68F"), Color(hex: "#F0B656"), Color(hex: "#F7A844")],
            isLocked: false
        ),
        PrototypeDay(
            id: "fri",
            weekday: "Fri",
            dateLabel: "Aug 28",
            qualityScore: 81,
            summaryLabel: "Standout color day",
            heroTime: "5:17",
            heroSubtitle: "Best glow of the week",
            location: "Tokyo, Japan",
            mood: .vivid,
            firstLight: "4:50",
            golden: "5:02",
            sunrise: "5:17",
            daylight: "5:45",
            goldenPM: "17:59",
            sunset: "18:23",
            blueEnd: "5:36",
            cloud: "High textured cloud",
            uv: "3",
            confidenceLabel: "High confidence",
            analysisText: "Friday looks like the strongest shot at a rose-gold sunrise. High cloud cover and a longer warm-light window could create a layered gradient from mauve to amber.",
            colorRamp: [Color(hex: "#8B89A2"), Color(hex: "#C28D97"), Color(hex: "#DE8D7D"), Color(hex: "#F29A72"), Color(hex: "#FFD27A")],
            isLocked: true
        ),
        PrototypeDay(
            id: "sat",
            weekday: "Sat",
            dateLabel: "Aug 29",
            qualityScore: 49,
            summaryLabel: "Subtle and muted",
            heroTime: "5:18",
            heroSubtitle: "More haze than glow",
            location: "Tokyo, Japan",
            mood: .muted,
            firstLight: "4:51",
            golden: "5:03",
            sunrise: "5:18",
            daylight: "5:46",
            goldenPM: "17:58",
            sunset: "18:22",
            blueEnd: "5:37",
            cloud: "Low haze",
            uv: "2",
            confidenceLabel: "Medium confidence",
            analysisText: "Muted gray-beige skies are more likely here. There may still be a warm edge to the horizon, but expect lower contrast and less separation between cloud layers.",
            colorRamp: [Color(hex: "#5A6474"), Color(hex: "#8A8EA0"), Color(hex: "#A89E9E"), Color(hex: "#C4AB92"), Color(hex: "#D9B183")],
            isLocked: true
        ),
        PrototypeDay(
            id: "sun",
            weekday: "Sun",
            dateLabel: "Aug 30",
            qualityScore: 67,
            summaryLabel: "Gentle weekend sunrise",
            heroTime: "5:19",
            heroSubtitle: "Warm gold likely",
            location: "Tokyo, Japan",
            mood: .overcast,
            firstLight: "4:52",
            golden: "5:04",
            sunrise: "5:19",
            daylight: "5:47",
            goldenPM: "17:57",
            sunset: "18:21",
            blueEnd: "5:38",
            cloud: "Layered morning cloud",
            uv: "2",
            confidenceLabel: "Good confidence",
            analysisText: "There is enough mid and high cloud to reflect light back into the scene, which may produce a buttery gold sunrise rather than a sharply vivid one.",
            colorRamp: [Color(hex: "#9791A6"), Color(hex: "#C9ADB4"), Color(hex: "#EEBD80"), Color(hex: "#F4A94F"), Color(hex: "#FFD27A")],
            isLocked: true
        ),
        PrototypeDay(
            id: "mon",
            weekday: "Mon",
            dateLabel: "Aug 31",
            qualityScore: 76,
            summaryLabel: "Strong sunset potential",
            heroTime: "18:20",
            heroSubtitle: "Evening color may outperform morning",
            location: "Tokyo, Japan",
            mood: .clear,
            firstLight: "4:53",
            golden: "5:05",
            sunrise: "5:20",
            daylight: "5:48",
            goldenPM: "17:55",
            sunset: "18:20",
            blueEnd: "5:39",
            cloud: "Clear with thin haze",
            uv: "3",
            confidenceLabel: "High confidence",
            analysisText: "This setup may deliver a stronger golden-orange sunset than sunrise. The sky should stay open enough for a long, clean afterglow window.",
            colorRamp: [Color(hex: "#48607A"), Color(hex: "#A7B6BC"), Color(hex: "#DCC68F"), Color(hex: "#F0B656"), Color(hex: "#F7A844")],
            isLocked: true
        )
    ]
}

private struct PrototypeLocation: Identifiable {
    let id: String
    let name: String
    let isSelected: Bool

    static let sampleLocations: [PrototypeLocation] = [
        PrototypeLocation(id: "tokyo", name: "Tokyo, Japan", isSelected: true),
        PrototypeLocation(id: "kamakura", name: "Kamakura", isSelected: false),
        PrototypeLocation(id: "hakone", name: "Hakone", isSelected: false),
        PrototypeLocation(id: "sapporo", name: "Sapporo", isSelected: false)
    ]
}

private struct SkyBackgroundView: View {
    let mood: SkyMood
    let isExpanded: Bool
    let accentColor: Color

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

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64

        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
