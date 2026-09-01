import SwiftUI

extension ContentView {
    func scoreHeader(availableWidth: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            scoreHeaderPrimary
                .frame(width: max(availableWidth - 150, 0), alignment: .leading)

            scoreHeaderSecondary(alignment: .trailing)
                .frame(width: 142, alignment: .trailing)
        }
        .frame(width: availableWidth, alignment: .leading)
    }

    var scoreHeaderPrimary: some View {
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

    func scoreHeaderSecondary(alignment: HorizontalAlignment) -> some View {
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

    var predictedColorRamp: some View {
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

    var eventTimeline: some View {
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
                                    .stroke(
                                        moment == selectedMoment ? moment.dotColor : inkColor.opacity(0.25),
                                        lineWidth: moment == selectedMoment ? 0 : 1.5
                                    )
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

    var analysisMetrics: some View {
        HStack(spacing: 18) {
            analysisMetric(title: "Golden", value: selectedDay.golden)
            analysisMetric(title: "Cloud", value: selectedDay.cloud)
            analysisMetric(title: "UV", value: selectedDay.uv)
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

    func bottomIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(inkColor.opacity(0.68))
        }
        .buttonStyle(.plain)
    }
}
