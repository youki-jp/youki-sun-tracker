import SwiftUI

extension ContentView {
    var calendarSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Forecast calendar")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .padding(.bottom, 12)

                ForEach(serverViewModel.forecastDays) { day in
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
                    Text(serverViewModel.statusText + ". Only the requested day is loaded; other days in sample mode are previews.")
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
                .accessibilityIdentifier("upgradeButton")
            }

            settingsToggleRow(
                title: "Smart alarm",
                subtitle: "Wake you when the forecast peaks.",
                isOn: $smartAlarmEnabled
            )
            .accessibilityIdentifier("smartAlarmToggle")

            settingsToggleRow(
                title: "Sunset alerts",
                subtitle: "Evening reminders for strong glow days.",
                isOn: $sunsetAlertEnabled
            )
            .accessibilityIdentifier("sunsetAlertsToggle")

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
                Text("Locations")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

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

                Text(serverViewModel.statusText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
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
            .accessibilityIdentifier("startTrialButton")
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

    func paywallFeature(_ text: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(accentColor)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
        }
    }

    func subscriptionCard(
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
        .accessibilityIdentifier(plan == .yearly ? "yearlyPlanButton" : "monthlyPlanButton")
    }
}
