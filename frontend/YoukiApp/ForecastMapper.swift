import Foundation
import SwiftUI

enum ForecastMapper {
    static func makeDay(
        from response: SkyColorAPIResponse,
        locationName: String = "Current location",
        generatedRamp: [Color]? = nil,
        moment: SkyMoment = .sunrise,
        timeline: SkyDayTimelineResponse? = nil,
        currentDate: Date = Date()
    ) -> PrototypeDay? {
        let sunrise = response.predictions.first { $0.kind == .sunrise }
        let sunset = response.predictions.first { $0.kind == .sunset }
        let timezone = timeline?.location.timezoneId ?? response.location.timezoneId
        let localHour = Int(formatter(timezone: timezone, format: "H").string(from: currentDate))
        let useSunset = moment == .now ? (localHour.map { $0 >= 12 } ?? false) : moment.isEvening
        guard let primary = useSunset ? sunset : sunrise else {
            return nil
        }

        let primaryDate = date(from: primary.window.eventTimeIso, timezone: timezone)
        let primaryKindLabel = primary.kind == .sunrise ? "sunrise" : "sunset"
        let mood = mood(for: primary.label)
        let liveConditions = primary.conditions

        return PrototypeDay(
            id: "today",
            weekday: weekday(for: primaryDate, timezone: timezone),
            dateLabel: dateLabel(for: primaryDate, timezone: timezone),
            qualityScore: primary.score,
            summaryLabel: moment == .now ? "\(primaryKindLabel.capitalized) forecast score" : "\(primary.estimatedColorName.capitalized) \(primaryKindLabel) glow",
            heroTime: moment == .now ? "Now" : (timeline.map { milestoneTime(moment.localIso(in: $0.milestones)) } ?? displayTime(primary.window.eventTimeIso, timezone: timezone)),
            heroSubtitle: moment == .now ? "Current local time · \(displayClock(currentDate, timezone: timezone))" : (timeline.map { "\(moment.label) · \($0.location.timezoneId)" } ?? "\(primaryKindLabel.capitalized) forecast"),
            nowTime: displayClock(currentDate, timezone: timezone),
            location: locationName,
            mood: mood,
            firstLight: milestoneTime(timeline?.milestones.civilDawnIso),
            golden: milestoneTime(timeline?.milestones.goldenHourStartIso),
            sunrise: milestoneTime(timeline?.milestones.sunriseIso),
            daylight: milestoneTime(timeline?.milestones.solarNoonIso),
            goldenPM: milestoneTime(timeline?.milestones.goldenHourPmStartIso),
            sunset: milestoneTime(timeline?.milestones.sunsetIso),
            blueEnd: milestoneTime(timeline?.milestones.civilDuskIso),
            cloud: percentage(liveConditions?.cloudCoverPct, suffix: "% cover"),
            uv: decimal(liveConditions?.uvIndex),
            confidenceLabel: "\(primary.confidence)% confidence",
            analysisText: moment == .now ? "\(primaryKindLabel.capitalized) event forecast: \(analysisText(for: primary))" : analysisText(for: primary),
            colorRamp: generatedRamp ?? colorRamp(for: primary, mood: mood),
            isLocked: false
        )
    }

    static func milestoneTime(_ iso: String?) -> String {
        guard let iso, let minutes = SkyTimelineSampler.localMinutes(from: iso) else { return "—" }
        return String(format: "%02d:%02d", Int(minutes) / 60, Int(minutes) % 60)
    }

    static func timelineDay(_ timeline: SkyDayTimelineResponse, locationName: String,
                            moment: SkyMoment, appearance: SkyAppearance, currentDate: Date = Date()) -> PrototypeDay {
        let milestones = timeline.milestones
        return PrototypeDay(
            id: "today", weekday: "Today", dateLabel: timeline.targetDateIso,
            qualityScore: 0, summaryLabel: moment == .now ? "Event score unavailable" : "Score unavailable",
            heroTime: moment == .now ? "Now" : milestoneTime(moment.localIso(in: milestones)),
            heroSubtitle: moment == .now ? "Current local time · \(displayClock(currentDate, timezone: timeline.location.timezoneId))" : "\(moment.label) · \(timeline.location.timezoneId)",
            nowTime: displayClock(currentDate, timezone: timeline.location.timezoneId),
            location: locationName, mood: .clear,
            firstLight: milestoneTime(milestones.civilDawnIso),
            golden: milestoneTime(milestones.goldenHourStartIso),
            sunrise: milestoneTime(milestones.sunriseIso),
            daylight: milestoneTime(milestones.solarNoonIso),
            goldenPM: milestoneTime(milestones.goldenHourPmStartIso),
            sunset: milestoneTime(milestones.sunsetIso),
            blueEnd: milestoneTime(milestones.civilDuskIso),
            cloud: "—", uv: "—", confidenceLabel: "Score unavailable",
            analysisText: "The sky uses the live solar and atmospheric timeline. Forecast score and analysis are unavailable for this event.",
            colorRamp: appearance.ramp.map { Color(hex: $0) }, isLocked: false
        )
    }

    private static func analysisText(
        for prediction: SkyColorAPIResponse.SkyColorPrediction
    ) -> String {
        let reasons = prediction.reasons.joined(separator: " ")
        let palette = prediction.dominantColors.joined(separator: ", ")
        return "\(reasons) Predicted colors: \(palette)."
    }

    private static func colorRamp(
        for prediction: SkyColorAPIResponse.SkyColorPrediction,
        mood: SkyMood
    ) -> [Color] {
        let moodColors = mood.gradient
        let primaryColor = Color(hex: prediction.estimatedHex)

        guard moodColors.count >= 4 else {
            return [primaryColor]
        }

        return [
            moodColors[0],
            moodColors[1],
            primaryColor,
            moodColors[moodColors.count - 2],
            moodColors[moodColors.count - 1]
        ]
    }

    private static func mood(for label: String) -> SkyMood {
        switch label.lowercased() {
        case "dramatic", "vivid":
            return .vivid
        case "warm":
            return .clear
        case "pastel":
            return .pastel
        case "muted":
            return .muted
        default:
            return .overcast
        }
    }

    private static func displayTime(_ iso: String?, timezone: String) -> String {
        guard let iso, let date = date(from: iso, timezone: timezone) else {
            return "—"
        }

        let formatter = formatter(timezone: timezone, format: "H:mm")
        return formatter.string(from: date)
    }

    private static func displayClock(_ date: Date, timezone: String) -> String {
        formatter(timezone: timezone, format: "HH:mm").string(from: date)
    }

    private static func date(from iso: String, timezone: String) -> Date? {
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm"] {
            let formatter = formatter(timezone: timezone, format: format)
            if let date = formatter.date(from: iso) {
                return date
            }
        }

        return nil
    }

    private static func weekday(for date: Date?, timezone: String) -> String {
        guard let date else {
            return "Today"
        }

        let calendar = calendar(timezone: timezone)
        if calendar.isDateInToday(date) {
            return "Today"
        }

        return formatter(timezone: timezone, format: "EEE").string(from: date)
    }

    private static func dateLabel(for date: Date?, timezone: String) -> String {
        guard let date else {
            return "Live forecast"
        }

        return formatter(timezone: timezone, format: "EEE, MMM d").string(from: date)
    }

    private static func percentage(_ value: Double?, suffix: String) -> String {
        guard let value else {
            return "—"
        }

        return "\(Int(value.rounded()))\(suffix)"
    }

    private static func decimal(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }

        return String(format: "%.1f", value)
    }

    private static func formatter(timezone: String, format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: timezone) ?? .current
        formatter.dateFormat = format
        return formatter
    }

    private static func calendar(timezone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone) ?? .current
        return calendar
    }
}
