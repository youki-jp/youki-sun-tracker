import Foundation
import SwiftUI

enum ForecastMapper {
    static func makeDay(
        from response: SkyColorAPIResponse,
        locationName: String = "Current location",
        now: Date = Date()
    ) -> PrototypeDay? {
        let sunrise = response.predictions.first { $0.kind == .sunrise }
        let sunset = response.predictions.first { $0.kind == .sunset }
        guard let primary = sunrise ?? sunset else {
            return nil
        }

        let timezone = response.location.timezoneId
        let primaryDate = date(from: primary.window.eventTimeIso, timezone: timezone)
        let primaryKindLabel = primary.kind == .sunrise ? "sunrise" : "sunset"
        let mood = mood(for: primary.label)
        let sunriseWindow = sunrise?.window
        let sunsetWindow = sunset?.window
        let liveConditions = (sunrise ?? sunset)?.conditions

        return PrototypeDay(
            id: "today",
            weekday: weekday(for: primaryDate, timezone: timezone),
            dateLabel: dateLabel(for: primaryDate, timezone: timezone),
            qualityScore: primary.score,
            summaryLabel: "\(primary.estimatedColorName.capitalized) \(primaryKindLabel) glow",
            heroTime: displayTime(primary.window.eventTimeIso, timezone: timezone),
            heroSubtitle: eventSubtitle(
                kind: primaryKindLabel,
                eventDate: primaryDate,
                now: now
            ),
            location: locationName,
            mood: mood,
            firstLight: displayTime(sunriseWindow?.twilight.civilStartsAtIso, timezone: timezone),
            golden: displayTime(sunriseWindow?.scoringWindow.startsAtIso, timezone: timezone),
            sunrise: displayTime(sunriseWindow?.eventTimeIso, timezone: timezone),
            daylight: displayTime(sunriseWindow?.twilight.civilEndsAtIso, timezone: timezone),
            goldenPM: displayTime(sunsetWindow?.scoringWindow.startsAtIso, timezone: timezone),
            sunset: displayTime(sunsetWindow?.eventTimeIso, timezone: timezone),
            blueEnd: displayTime(sunriseWindow?.twilight.civilEndsAtIso, timezone: timezone),
            cloud: percentage(liveConditions?.cloudCoverPct, suffix: "% cover"),
            uv: decimal(liveConditions?.uvIndex),
            confidenceLabel: "\(primary.confidence)% confidence",
            analysisText: analysisText(for: primary),
            colorRamp: colorRamp(for: primary, mood: mood),
            isLocked: false
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

    private static func eventSubtitle(kind: String, eventDate: Date?, now: Date) -> String {
        guard let eventDate else {
            return "Live forecast from weather data"
        }

        let minutes = Int((eventDate.timeIntervalSince(now) / 60).rounded())
        if abs(minutes) <= 1 {
            return "\(kind.capitalized) is happening now"
        }

        if minutes > 0 {
            return "\(kind.capitalized) in \(minutes) min"
        }

        return "\(kind.capitalized) was \(abs(minutes)) min ago"
    }

    private static func displayTime(_ iso: String?, timezone: String) -> String {
        guard let iso, let date = date(from: iso, timezone: timezone) else {
            return "—"
        }

        let formatter = formatter(timezone: timezone, format: "H:mm")
        return formatter.string(from: date)
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
