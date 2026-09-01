import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
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

enum ActiveSheet: String, Identifiable {
    case calendar
    case settings
    case locations
    case paywall

    var id: String { rawValue }
}

enum SubscriptionPlan {
    case yearly
    case monthly
}

enum SkyMoment: String, CaseIterable, Identifiable {
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

enum SkyMood: String {
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

struct PrototypeDay: Identifiable {
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

struct PrototypeLocation: Identifiable {
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
