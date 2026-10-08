import SwiftUI

struct GoldenHourAlarmSheet: View {
    @ObservedObject var model: GoldenHourAlarmViewModel
    @ObservedObject var server: ServerViewModel
    let theme: AppTheme
    @State private var event: GoldenHourAlarmEvent = .sunrise
    @State private var leadMinutes = 15
    @State private var preview: GoldenHourAlarmRequest?
    @State private var previewError: String?
    @State private var isPreparing = false

    private var previewKey: String {
        "\(event.rawValue)-\(leadMinutes)-\(server.coordinates?.latitude.description ?? "")-\(server.coordinates?.longitude.description ?? "")-\(server.coordinates?.altitudeMeters?.description ?? "")-\((model.scheduled ?? model.unconfirmed)?.id.uuidString ?? "")"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Golden-hour alarm")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Wake up for sunrise or make time for sunset.")
                    .foregroundStyle(theme.inkColor.opacity(0.65))

                if let scheduled = model.scheduled {
                    Label("Alarm on", systemImage: "alarm.fill")
                        .foregroundStyle(theme.accentColor)
                        .accessibilityIdentifier("confirmedAlarm")
                    alarmDetails(scheduled)
                    Text("This alarm keeps its confirmed time when the forecast or your location changes.")
                        .font(.footnote)
                    actionButton("Turn alarm off") { await model.cancel() }
                        .accessibilityIdentifier("cancelAlarmButton")
                } else if let pending = model.unconfirmed {
                    Text("Alarm status needs checking")
                        .font(.headline)
                    alarmDetails(pending)
                    Text("We could not confirm whether the system has this alarm. Check its status or cancel it before setting another.")
                        .font(.footnote)
                    actionButton("Check alarm status") { await model.reconcile() }
                    actionButton("Cancel this alarm") { await model.cancel() }
                } else {
                    Picker("Event", selection: $event) {
                        ForEach(GoldenHourAlarmEvent.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("alarmEventPicker")
                    Stepper(AppLocalization.isJapanese ? "ゴールデンアワーの\(leadMinutes)分前" : "\(leadMinutes) minutes before golden hour", value: $leadMinutes, in: 0...120, step: 5)
                        .accessibilityIdentifier("alarmLeadStepper")
                    Text("One alarm for the next golden-hour window. If today's time has passed, we check tomorrow.")
                        .font(.footnote)
                        .foregroundStyle(theme.inkColor.opacity(0.65))

                    if let reason = model.unavailableReason {
                        Text(AppLocalization.text(reason))
                            .accessibilityIdentifier("alarmUnavailable")
                    } else if isPreparing {
                        ProgressView("Finding the next golden hour…")
                    } else if let preview {
                        alarmDetails(preview)
                        actionButton("Turn alarm on") { await model.schedule(preview) }
                            .accessibilityIdentifier("scheduleAlarmButton")
                    }
                    if let previewError {
                        Text(AppLocalization.text(previewError)).font(.footnote)
                        Button("Try again") { Task { await preparePreview() } }
                    }
                }
                if model.isBusy { ProgressView("Updating alarm…") }
                if let error = model.errorMessage {
                    Text(AppLocalization.text(error))
                        .font(.footnote)
                        .accessibilityIdentifier("alarmError")
                }
                Text("Youki alarms use the system alarm sound. This first version schedules one event and does not repeat automatically.")
                    .font(.footnote)
                    .foregroundStyle(theme.inkColor.opacity(0.65))
            }
            .padding(24)
        }
        .foregroundStyle(theme.inkColor)
        .background(theme.panelColor)
        .tint(theme.accentColor)
        .task { await model.prepareForDisplay() }
        .task(id: previewKey) { await preparePreview() }
        .onAppear { event = server.selectedMoment.isEvening ? .sunset : .sunrise }
    }

    private func alarmDetails(_ request: GoldenHourAlarmRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(request.event.label) · \(AppLocalization.text(request.locationName))")
                .font(.headline)
            Text(AppLocalization.isJapanese ? "アラーム：\(formatted(request.fireDate, timezone: request.timezoneID))" : "Alarm: \(formatted(request.fireDate, timezone: request.timezoneID))")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .accessibilityIdentifier("alarmTime")
            Text(AppLocalization.isJapanese ? "ゴールデンアワー：\(formatted(request.goldenHourDate, timezone: request.timezoneID))" : "Golden hour: \(formatted(request.goldenHourDate, timezone: request.timezoneID))")
            Text(AppLocalization.isJapanese ? "\(request.leadMinutes)分前 · \(request.timezoneID)" : "\(request.leadMinutes) minutes before · \(request.timezoneID)")
                .font(.footnote)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardColor, in: RoundedRectangle(cornerRadius: 16))
    }

    private func actionButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(AppLocalization.text(title))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(theme.accentColor, in: Capsule())
                .foregroundStyle(theme.panelColor)
        }
        .disabled(model.isBusy)
    }

    private func formatted(_ date: Date, timezone: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.timeZone = TimeZone(identifier: timezone)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    @MainActor private func preparePreview() async {
        let key = previewKey
        preview = nil
        previewError = nil
        guard model.scheduled == nil, model.unconfirmed == nil, model.unavailableReason == nil else { return }
        guard let coordinates = server.coordinates else {
            previewError = "Choose a location before setting an alarm."
            return
        }
        #if DEBUG
        guard !ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uiSkyFixture") }) else {
            previewError = "Sample skies cannot schedule a real alarm. Load a live location first."
            return
        }
        #endif
        let selectedEvent = event
        let selectedLead = leadMinutes
        let locationName = server.locationName
        isPreparing = true
        defer { if !Task.isCancelled && key == previewKey { isPreparing = false } }
        do {
            let client = SkyDayTimelineAPIClient(baseURL: AppConfig.serverURL)
            let candidate = try await GoldenHourAlarmPlanner.next(event: selectedEvent,
                leadMinutes: selectedLead, locationName: locationName, now: Date()) { targetDate in
                try await client.fetchTimeline(latitude: coordinates.latitude,
                    longitude: coordinates.longitude, altitudeMeters: coordinates.altitudeMeters,
                    targetDateIso: targetDate)
            }
            try Task.checkCancellation()
            guard key == previewKey else { return }
            preview = candidate
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, key == previewKey else { return }
            previewError = error.localizedDescription
        }
    }

}
