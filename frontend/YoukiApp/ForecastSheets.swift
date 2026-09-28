import SwiftUI

extension ContentView {
    var calendarSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Forecast calendar")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                    Button("Done") { activeSheet = nil }
                        .accessibilityIdentifier("calendarDoneButton")
                }
                .padding(.bottom, 12)

                ForEach(serverViewModel.forecastDays) { day in
                    Button {
                        if day.isLocked && authSession.account?.tier != "pro" {
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

                            if day.isLocked && authSession.account?.tier != "pro" {
                                Image(systemName: "lock")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(inkColor.opacity(0.55))
                            } else {
                                Circle()
                                    .fill(day.mood.displayColor)
                                    .frame(width: 9, height: 9)
                                Text(serverViewModel.isScoreAvailable ? String(day.qualityScore) : "—")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                            }
                        }
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("calendarDay.\(day.id)")

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
                .accessibilityIdentifier("calendarInfoButton")

                if showCalendarInfo {
                    Text("Only today’s forecast is live. Other dates remain sample previews.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(inkColor.opacity(0.55))
                        .lineSpacing(3)
                        .padding(.top, 10)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .background(panelColor)
        }
    }

    var settingsSheet: some View {
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
                .accessibilityIdentifier("themePicker")
            }
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Divider()
            }

            settingsRow(
                title: "Account",
                subtitle: authSession.isAuthenticated
                    ? (authSession.account?.tier == "pro" ? "Youki Pro · lifetime" : "Free account")
                    : "Sign in for your live sky"
            ) {
                Button(authSession.isAuthenticated ? "Manage" : "Sign in") {
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
                title: "Golden-hour alarm",
                subtitle: alarmModel.scheduled != nil ? "An alarm is scheduled." : "Choose sunrise or sunset and a lead time.",
                isOn: Binding(get: { alarmModel.scheduled != nil }, set: { enabled in
                    if enabled { activeSheet = .alarm }
                    else { Task { await alarmModel.cancel() } }
                })
            )
            .disabled(alarmModel.isBusy)
            .accessibilityIdentifier("smartAlarmToggle")

            if let error = alarmModel.errorMessage {
                Text(error)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(accentColor)
            }

            settingsRow(title: "Sunset alerts", subtitle: "Coming later") { EmptyView() }
            .accessibilityIdentifier("sunsetAlertsRow")

            Button {
                activeSheet = .locations
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Locations")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("Manage your forecast location")
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

    func settingsToggleRow(
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
                    Text(error)
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
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(inkColor.opacity(0.65))
            TextField(placeholder, text: text)
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
            Text("A one-time Pro upgrade is planned. Purchases are not available yet, and today's live sky and golden-hour alarms remain free.")
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
