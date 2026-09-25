import SwiftUI

extension ContentView {
    func scoreHeader(availableWidth: CGFloat, compact: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            scoreHeaderPrimary(compact: compact)
                .frame(width: max(availableWidth - 150, 0), alignment: .leading)

            scoreHeaderSecondary(alignment: .trailing, compact: compact)
                .frame(width: 142, alignment: .trailing)
        }
        .frame(width: availableWidth, alignment: .leading)
    }

    func scoreHeaderPrimary(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 5) {
            Text(scoreText)
                .accessibilityIdentifier("forecastScore")
                .font(.system(size: compact ? 58 : 64, weight: .light, design: .rounded))
                .tracking(-2.5)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(selectedDay?.summaryLabel ?? "")
                .font(.system(size: compact ? 13 : 14, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }

    func scoreHeaderSecondary(alignment: HorizontalAlignment, compact: Bool) -> some View {
        VStack(alignment: alignment, spacing: compact ? 4 : 6) {
            Text(selectedDay?.heroTime ?? "")
                .accessibilityIdentifier("selectedEventTime")
                .font(.system(size: compact ? 21 : 24, weight: .medium, design: .rounded))

            Text(selectedDay?.heroSubtitle ?? "")
                .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
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
                    .padding(.vertical, compact ? 6 : 8)
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
            .accessibilityIdentifier("wakeAlarmButton")
        }
    }

    var predictedColorRamp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PREDICTED COLORS")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(inkColor.opacity(0.55))

            if serverViewModel.hasLiveSky {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: selectedRamp, startPoint: .leading, endPoint: .trailing))
                    .frame(height: 12)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("colorRamp")
                    .accessibilityLabel(selectedAppearance.ramp.joined(separator: ","))
            } else {
                Text("Sky colors unavailable")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(inkColor.opacity(0.55))
                    .frame(height: 12, alignment: .leading)
            }
        }
    }

    func eventTimeline(rowHeight: CGFloat, compact: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(SkyMoment.allCases) { moment in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        serverViewModel.select(moment)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(moment == selectedMoment ? moment.dotColor : Color.clear)
                            .frame(width: 9, height: 9)
                            .overlay {
                                Circle()
                                    .stroke(
                                        moment == selectedMoment ? moment.dotColor : inkColor.opacity(0.25),
                                        lineWidth: moment == selectedMoment ? 0 : 1.5
                                    )
                            }

                        Text(moment.label)
                            .font(.system(size: compact ? 13 : 14, weight: moment == selectedMoment ? .semibold : .medium, design: .rounded))

                        Spacer()

                        Text(moment == .now ? (selectedDay?.nowTime ?? "—") : (selectedDay?.time(for: moment) ?? "—"))
                            .font(.system(size: compact ? 12 : 13, weight: moment == selectedMoment ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(moment == selectedMoment ? inkColor : inkColor.opacity(0.55))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: rowHeight)
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
                .accessibilityIdentifier("moment.\(moment.id)")
                .accessibilityValue(moment == selectedMoment ? "Selected" : "Not selected")
                .disabled(!serverViewModel.isAvailable(moment))
                .opacity(serverViewModel.isAvailable(moment) ? 1 : 0.4)
            }
        }
    }

    func forecastSkeleton(availableWidth: CGFloat, headerHeight: CGFloat, rowHeight: CGFloat,
                          sectionSpacing: CGFloat, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: compact ? 6 : 9) {
                    skeletonShape(width: 68, height: compact ? 50 : 56, radius: 16)
                    skeletonShape(width: max(44, min(availableWidth - 166, 158)), height: 13)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: compact ? 6 : 8) {
                    skeletonShape(width: 72, height: 23)
                    skeletonShape(width: 124, height: 11)
                    skeletonShape(width: 122, height: 29, radius: 15)
                }
            }
            .frame(height: headerHeight, alignment: .top)

            VStack(alignment: .leading, spacing: 8) {
                skeletonShape(width: 125, height: 10)
                skeletonShape(height: 12, radius: 8)
            }
            .padding(.top, sectionSpacing)

            VStack(spacing: 0) {
                ForEach(0..<SkyMoment.allCases.count, id: \.self) { index in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(inkColor.opacity(0.12))
                            .frame(width: 9, height: 9)
                        skeletonShape(width: index == 2 || index == 5 ? 92 : 75, height: 13)
                        Spacer()
                        skeletonShape(width: 42, height: 13)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: rowHeight)
                    .overlay(alignment: .bottom) {
                        if index < SkyMoment.allCases.count - 1 {
                            Divider().padding(.leading, 30)
                        }
                    }
                }
            }
            .padding(.top, sectionSpacing)
        }
        .frame(width: availableWidth, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading forecast")
        .accessibilityIdentifier("forecastSkeleton")
    }

    func skeletonShape(width: CGFloat? = nil, height: CGFloat, radius: CGFloat = 6) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(inkColor.opacity(appTheme == .dark ? 0.12 : 0.11))
            .frame(width: width, height: height)
    }

    var forecastEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.slash")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(accentColor)
            Text("Forecast unavailable")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Text(serverViewModel.errorMessage ?? "No forecast is available for this location.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(inkColor.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineLimit(4)
            Button("Try again") {
                Task { await serverViewModel.loadForecast() }
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(panelColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(accentColor, in: Capsule())
            .accessibilityIdentifier("retryForecastButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("forecastEmptyState")
    }

    func analysisEmptyCard(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            Text(serverViewModel.isLoading ? "Loading forecast" : "Forecast unavailable")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            if let error = serverViewModel.errorMessage {
                Text(error)
                    .font(.system(size: 12, design: .rounded))
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(width: width)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 26))
    }

    func analysisCard(width: CGFloat) -> some View {
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

                Text(serverViewModel.isScoreAvailable ? "\(scoreText)/100" : "Score unavailable")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            .padding(.top, 12)

            Text(selectedDay?.analysisText ?? "")
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            if serverViewModel.hasLiveSky {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: selectedRamp, startPoint: .leading, endPoint: .trailing))
                    .frame(height: 10)
                    .padding(.top, 16)
            } else {
                Text("Sky colors unavailable")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.top, 16)
            }

            HStack {
                Text(selectedMoment.label)
                Spacer()
                Text(selectedDay?.time(for: selectedMoment) ?? "—")
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

    var analysisMetrics: some View {
        HStack(spacing: 18) {
            analysisMetric(title: "Golden", value: selectedMoment.isEvening ? (selectedDay?.goldenPM ?? "—") : (selectedDay?.golden ?? "—"))
            analysisMetric(title: "Cloud", value: selectedDay?.cloud ?? "—")
            analysisMetric(title: "UV", value: selectedDay?.uv ?? "—")
        }
    }

    func analysisMetric(title: String, value: String) -> some View {
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

    var bottomBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image("YoukiSun")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 19, height: 19)
                    .accessibilityHidden(true)
                Text("youki")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }

            Spacer()

            HStack(spacing: 2) {
                bottomIconButton(
                    systemName: isSkyExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                    accessibilityIdentifier: "expandButton"
                ) {
                    if selectedDay != nil && !serverViewModel.isLoading {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.88)) {
                            isSkyExpanded.toggle()
                        }
                    }
                }
                bottomIconButton(systemName: "calendar", accessibilityIdentifier: "calendarButton") {
                    activeSheet = .calendar
                }
                bottomIconButton(systemName: "slider.horizontal.3", accessibilityIdentifier: "settingsButton") {
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

    func bottomIconButton(
        systemName: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(inkColor.opacity(0.68))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
