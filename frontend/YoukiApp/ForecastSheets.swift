import SwiftUI

extension ContentView {
    var calendarSheet: some View {
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

    var locationsSheet: some View {
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
    }
}
