import SwiftUI

extension ContentView {
    var calendarSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Forecast calendar")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Spacer()
                        Button("Close") { activeSheet = nil }
                            .accessibilityIdentifier("calendarDoneButton")
                    }
                    Text(authSession.account?.tier == "pro" ? "Your next seven days" : "Today and tomorrow · Seven days with Pro")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(inkColor.opacity(0.6))
                    HStack {
                        if serverViewModel.isCalendarLoading { ProgressView("Updating forecasts…") }
                        Spacer()
                        Button("Refresh") { Task { await serverViewModel.loadCalendar(force: true) } }
                            .disabled(serverViewModel.isCalendarLoading)
                            .accessibilityIdentifier("calendarRefreshButton")
                    }
                    .font(.system(size: 12, design: .rounded))
                    if let error = serverViewModel.calendarError {
                        Text(AppLocalization.text(error + (serverViewModel.calendarDays.isEmpty ? "" : " Showing earlier forecasts.")))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(accentColor)
                    }
                    if let updated = serverViewModel.calendarUpdatedLabel {
                        Text(updated)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(inkColor.opacity(0.55))
                    }
                    ForEach(serverViewModel.calendarDays) { day in
                        Button {
                            if day.locked { activeSheet = .paywall }
                            else {
                                serverViewModel.selectDay(day)
                                activeSheet = nil
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(serverViewModel.dateLabel(day.id))
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    if day.id == selectedDay?.id {
                                        Circle().fill(accentColor).frame(width: 6, height: 6)
                                    }
                                    Spacer()
                                    if day.locked { Image(systemName: "lock.fill") }
                                    else if day.isAvailable { Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)) }
                                }
                                Text(day.forecastType == "outlook" ? "OUTLOOK · Conditions may change" : "FORECAST")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .tracking(0.8)
                                    .foregroundStyle(inkColor.opacity(0.55))
                                if day.locked {
                                    Text("Unlock this day's sunrise and sunset with Pro")
                                        .font(.system(size: 12, design: .rounded))
                                } else {
                                    HStack(alignment: .top, spacing: 16) {
                                        calendarEvent(day, kind: .sunrise)
                                        calendarEvent(day, kind: .sunset)
                                    }
                                    if !day.errors.isEmpty {
                                        Text("Some forecast details are unavailable. Refresh to retry.")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(accentColor)
                                    }
                                }
                            }
                            .foregroundStyle(inkColor)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(cardColor, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .disabled(!day.locked && !day.isAvailable)
                        .accessibilityIdentifier("calendarDay.\(day.id)")
                    }
                    Button {
                        showCalendarInfo.toggle()
                    } label: {
                        Label("About these forecasts", systemImage: "info.circle")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .accessibilityIdentifier("calendarInfoButton")
                    if showCalendarInfo {
                        Text("Today and tomorrow use the latest available forecast inputs. Days 3–7 are outlooks and may change as weather models update. Sunrise and sunset times are calculated; sky colors and quality depend on the weather. All sky forecasts are estimates. Data percentages describe available inputs, not the probability that the forecast is correct.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(inkColor.opacity(0.65))
                            .lineSpacing(4)
                    }
                }
                .padding(24)
            }
            .foregroundStyle(inkColor)
            .background(panelColor)
            .task { await serverViewModel.loadCalendar() }
        }
    }

    private func calendarEvent(_ day: ForecastWeekDay, kind: SkyEventKind) -> some View {
        let prediction = kind == .sunrise ? day.sunrisePrediction : day.sunsetPrediction
        let iso = kind == .sunrise ? day.timeline?.milestones.sunriseIso : day.timeline?.milestones.sunsetIso
        return VStack(alignment: .leading, spacing: 4) {
            Label(kind == .sunrise ? "Sunrise" : "Sunset", systemImage: kind == .sunrise ? "sunrise" : "sunset")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Text(ForecastMapper.milestoneTime(iso ?? prediction?.window.eventTimeIso))
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .monospacedDigit()
            Text(prediction.map { "\($0.score)/100 · \($0.confidence)% data" } ?? "Quality unavailable")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(inkColor.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var settingsSheet: some View {
        let japanese = appLanguage == "ja"
        return VStack(alignment: .leading, spacing: 0) {
            Text(japanese ? "設定" : "Settings")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.bottom, 12)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(japanese ? "テーマ" : "Theme")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(japanese ? "ライト・ダーク表示を切り替え" : "Preview the light and dark mock")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(inkColor.opacity(0.55))
                }

                Spacer()

                Picker(japanese ? "テーマ" : "Theme", selection: $appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 142)
                .accessibilityIdentifier("themePicker")
            }
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Divider()
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(japanese ? "言語" : "Language")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(japanese ? "表示言語を選択" : "Choose your display language")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(inkColor.opacity(0.55))
                }

                Spacer()

                Picker(japanese ? "言語" : "Language", selection: $appLanguage) {
                    Text("English").tag("en")
                    Text("日本語").tag("ja")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 142)
                .accessibilityIdentifier("languagePicker")
            }
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Divider()
            }

            settingsRow(
                title: japanese ? "アカウント" : "Account",
                subtitle: authSession.isAuthenticated
                    ? (authSession.account?.tier == "pro"
                        ? (japanese ? "Youki Pro · 永続" : "Youki Pro · lifetime")
                        : (japanese ? "無料アカウント" : "Free account"))
                    : (japanese ? "サインインして空の予報を見る" : "Sign in for your live sky")
            ) {
                Button(authSession.isAuthenticated
                       ? (japanese ? "管理" : "Manage")
                       : (japanese ? "サインイン" : "Sign in")) {
                    activeSheet = nil
                    showAccountScreen = true
                }
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(accentColor, in: Capsule())
                .foregroundStyle(.white)
                .accessibilityIdentifier("accountButton")
            }

            settingsToggleRow(
                title: japanese ? "ゴールデンアワーのアラーム" : "Golden-hour alarm",
                subtitle: alarmModel.scheduled != nil
                    ? (japanese ? "アラームを設定しました。" : "An alarm is scheduled.")
                    : (japanese ? "日の出・日の入りと通知時間を選択。" : "Choose sunrise or sunset and a lead time."),
                isOn: Binding(get: { alarmModel.scheduled != nil }, set: { enabled in
                    if enabled { activeSheet = .alarm }
                    else { Task { await alarmModel.cancel() } }
                })
            )
            .disabled(alarmModel.isBusy)
            .accessibilityIdentifier("smartAlarmToggle")

            if let error = alarmModel.errorMessage {
                        Text(AppLocalization.text(error))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(accentColor)
            }

            settingsRow(title: japanese ? "日の入り通知" : "Sunset alerts",
                        subtitle: japanese ? "今後対応予定" : "Coming later") { EmptyView() }
            .accessibilityIdentifier("sunsetAlertsRow")

            Button {
                activeSheet = .locations
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(japanese ? "場所" : "Locations")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text(japanese ? "予報する場所を管理" : "Manage your forecast location")
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
            .accessibilityIdentifier("allSettingsButton")

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .foregroundStyle(inkColor)
        .background(panelColor)
    }

    func settingsRow<Accessory: View>(
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppLocalization.text(title))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(AppLocalization.text(subtitle))
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

    func settingsToggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppLocalization.text(title))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(AppLocalization.text(subtitle))
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

    var manualCoordinates: ForecastCoordinates? {
        guard let latitude = Double(manualLatitude.trimmingCharacters(in: .whitespaces)),
              let longitude = Double(manualLongitude.trimmingCharacters(in: .whitespaces)) else { return nil }
        let altitudeText = manualAltitude.trimmingCharacters(in: .whitespaces)
        if !altitudeText.isEmpty && Double(altitudeText) == nil { return nil }
        return ForecastCoordinates(latitude: latitude, longitude: longitude,
                                   altitudeMeters: Double(altitudeText))
    }

    var locationsSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Locations")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Spacer()
                    Button("Done") { activeSheet = nil }
                        .accessibilityIdentifier("locationsDoneButton")
                }

                Button {
                    activeSheet = nil
                    Task { await serverViewModel.loadDeviceLocation() }
                } label: {
                    Label("Use my location", systemImage: "location.circle.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .padding(.vertical, 10)
                }
                .accessibilityIdentifier("useLocationButton")

                Divider()
                Text("Enter coordinates")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                coordinateField("Latitude", placeholder: "-90 to 90", text: $manualLatitude, id: "latitudeField")
                coordinateField("Longitude", placeholder: "-180 to 180", text: $manualLongitude, id: "longitudeField")
                coordinateField("Altitude in meters (optional)", placeholder: "-500 to 9000", text: $manualAltitude, id: "altitudeField")

                if manualCoordinates == nil && (!manualLatitude.isEmpty || !manualLongitude.isEmpty || !manualAltitude.isEmpty) {
                    Text("Enter valid latitude and longitude. Altitude, if supplied, must be between -500 and 9000 meters.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(accentColor)
                        .accessibilityIdentifier("coordinateValidation")
                }

                Button {
                    guard let coordinates = manualCoordinates else { return }
                    activeSheet = nil
                    Task { await serverViewModel.load(coordinates) }
                } label: {
                    Text("Show sky")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(accentColor, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(panelColor)
                }
                .disabled(manualCoordinates == nil)
                .opacity(manualCoordinates == nil ? 0.45 : 1)
                .accessibilityIdentifier("manualLocationButton")

                if let error = serverViewModel.errorMessage {
                    Text(AppLocalization.text(error))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(inkColor.opacity(0.65))
                    Button("Retry forecast") {
                        activeSheet = nil
                        Task { await serverViewModel.loadForecast() }
                    }
                    .foregroundStyle(accentColor)
                }
                Link(destination: URL(string: "https://open-meteo.com/")!) {
                    Label("Weather data by Open-Meteo", systemImage: "cloud.sun")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(inkColor.opacity(0.65))
                }
                .accessibilityIdentifier("weatherAttribution")
                Text("Coordinates are used for this forecast and are not saved.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(inkColor.opacity(0.55))
            }
            .padding(24)
        }
        .foregroundStyle(inkColor)
        .background(panelColor)
        .onAppear {
            if manualLatitude.isEmpty, let coordinates = serverViewModel.coordinates {
                manualLatitude = String(coordinates.latitude)
                manualLongitude = String(coordinates.longitude)
                manualAltitude = coordinates.altitudeMeters.map { String($0) } ?? ""
            }
        }
    }

    func coordinateField(_ title: String, placeholder: String, text: Binding<String>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(AppLocalization.text(title))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(inkColor.opacity(0.65))
            TextField(AppLocalization.text(placeholder), text: text)
                .keyboardType(.numbersAndPunctuation)
                .focused($coordinateFocus, equals: id)
                .submitLabel(.done)
                .onSubmit { coordinateFocus = nil }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(cardColor, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier(id)
        }
    }

    var paywallSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Youki Pro")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text("A one-time Pro upgrade is planned. Purchases are not available yet, and today and tomorrow's forecasts and golden-hour alarms remain free.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(inkColor.opacity(0.65))
            Button("Done") { activeSheet = nil }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
            Spacer()
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(inkColor)
        .background(panelColor)
    }
}
