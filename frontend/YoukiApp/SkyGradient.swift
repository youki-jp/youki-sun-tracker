import Foundation

enum SkyMoment: String, CaseIterable, Identifiable {
    case now, firstLight, goldenHour, sunrise, daylight, goldenHourPM, sunset
    var id: String { rawValue }
    var label: String {
        switch self {
        case .now: return "Now"
        case .firstLight: return "First light"
        case .goldenHour: return "Golden hour"
        case .sunrise: return "Sunrise"
        case .daylight: return "Daylight"
        case .goldenHourPM: return "Golden PM"
        case .sunset: return "Sunset"
        }
    }
    var isEvening: Bool { self == .goldenHourPM || self == .sunset }
    func localIso(in milestones: SkyDayTimelineResponse.Milestones) -> String? {
        switch self {
        case .now: return nil
        case .firstLight: return milestones.civilDawnIso
        case .goldenHour: return milestones.goldenHourStartIso
        case .sunrise: return milestones.sunriseIso
        case .daylight: return milestones.solarNoonIso
        case .goldenHourPM: return milestones.goldenHourPmStartIso
        case .sunset: return milestones.sunsetIso
        }
    }
}

struct ForecastCoordinates: Equatable {
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double?

    init?(latitude: Double, longitude: Double, altitudeMeters: Double? = nil) {
        guard latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude),
              altitudeMeters.map({ $0.isFinite && (-500...9000).contains($0) }) ?? true else { return nil }
        self.latitude = latitude
        self.longitude = longitude
        self.altitudeMeters = altitudeMeters
    }

    var label: String { String(format: "%.4f, %.4f", latitude, longitude) }
}

struct SkyGradientInput: Equatable {
    let elevationDegrees: Double
    let azimuthDegrees: Double
    let cloudTotalPct: Double
    let cloudLowPct: Double
    let cloudMidPct: Double
    let cloudHighPct: Double
    let visibilityMeters: Double
    let relativeHumidityPct: Double
    let precipitationMillimeters: Double
    let aerosolOpticalDepth: Double
    let dustUgM3: Double
    let pm25UgM3: Double
}

struct SkyGradientStop: Equatable {
    let offset: Double
    let hex: String
}

struct SkyGradientGlow: Equatable {
    let centerX: Double
    let centerY: Double
    let radius: Double
    let intensity: Double
}

struct SkyCloudBand: Equatable, Identifiable {
    let id: String
    let y: Double
    let height: Double
    let hex: String
    let opacity: Double
    let blur: Double
}

struct SkyAppearance: Equatable {
    let stops: [SkyGradientStop]
    let ramp: [String]
    let glow: SkyGradientGlow
    let cloudBands: [SkyCloudBand]

    static var fallback: SkyAppearance {
        SkyGradientGenerator.generate(
            SkyGradientInput(
                elevationDegrees: -0.5,
                azimuthDegrees: 90,
                cloudTotalPct: 35,
                cloudLowPct: 10,
                cloudMidPct: 20,
                cloudHighPct: 58,
                visibilityMeters: 24_000,
                relativeHumidityPct: 60,
                precipitationMillimeters: 0,
                aerosolOpticalDepth: 0.16,
                dustUgM3: 0,
                pm25UgM3: 4
            )
        )
    }
}

enum SkyGradientGenerator {
    static let stopPositions: [Double] = [0, 0.16, 0.32, 0.46, 0.60, 0.72, 0.83, 0.93, 1]

    private static let bulgeAmplitude = 0.086
    private static let bulgeHue = 6.0

    static func generate(_ input: SkyGradientInput) -> SkyAppearance {
        let elevation = clamp(finiteOr(input.elevationDegrees, 0), -90, 90)
        let dayF = smoothstep(-8, 10, elevation)
        let highSun = smoothstep(10, 60, elevation)
        let glowF = exp(-pow((elevation + 1.0) / 8.0, 2))

        let cloudTotal = clamp01(finiteOr(input.cloudTotalPct, 0) / 100)
        let cloudLow = clamp01(finiteOr(input.cloudLowPct, 0) / 100)
        let cloudMid = clamp01(finiteOr(input.cloudMidPct, 0) / 100)
        let cloudHigh = clamp01(finiteOr(input.cloudHighPct, 0) / 100)

        let aerosolWarm = clamp01(
            clamp01((finiteOr(input.aerosolOpticalDepth, 0.08) - 0.04) / 0.42)
                + 0.5 * clamp01(finiteOr(input.dustUgM3, 0) / 45)
                + 0.3 * clamp01(finiteOr(input.pm25UgM3, 0) / 60)
        )

        let haze = clamp01(
            0.55 * clamp01((finiteOr(input.relativeHumidityPct, 60) - 68) / 30)
                + 0.45 * (1 - clamp01(finiteOr(input.visibilityMeters, 24_000) / 22_000))
        )
        let wet = clamp01(finiteOr(input.precipitationMillimeters, 0) / 1.5)
        let blocked = clamp01((cloudLow - 0.30) / 0.60)
        let highCatch = bell(cloudHigh, 0.15, 0.60)
        let overcastF = clamp01(0.78 * cloudTotal + 0.30 * cloudLow - 0.08 * cloudHigh)
        let lowSunTint = exp(-pow((elevation + 1) / 11, 2))

        let topL = clamp(
            0.335 + 0.30 * overcastF + 0.22 * cloudHigh + 0.16 * dayF - 0.07 * highSun,
            0.14,
            0.90
        )
        let clearChroma = (0.045 + 0.055 * dayF * dayF) * (1 - 0.45 * aerosolWarm)
        let topC = clamp(
            lerp(clearChroma, 0.030, clamp01(cloudTotal * 1.05)) - 0.014 * haze,
            0.010,
            0.14
        )
        let topH = 250 + (54 * overcastF + 12 * aerosolWarm) * lowSunTint

        let botL = clamp(
            0.510 + 0.26 * glowF + 0.12 * dayF + 0.11 * cloudTotal + 0.09 * cloudHigh
                - 0.06 * overcastF * lowSunTint - 0.08 * haze - 0.10 * wet,
            0.30,
            0.94
        )
        let warmVigour = clamp01(
            glowF * (1 - 0.60 * blocked) * (1 - 0.42 * haze) * (1 - 0.80 * wet)
        )
        let botC = clamp((0.052 + 0.108 * warmVigour) * (1 - 0.30 * haze), 0.015, 0.165)
        let botH = 90 - 8 * glowF - 16 * aerosolWarm

        let spread = clamp01(0.30 + 0.45 * aerosolWarm + 0.35 * cloudTotal + 0.25 * haze)
        let warmStart = clamp01(0.66 - 0.66 * glowF * spread)
        let coolRamp = 0.68 - 0.48 * overcastF + 0.14 * highSun
        let warmPresence = clamp01(glowF * 1.15)
        let pink = clamp01(
            (0.52 * aerosolWarm + 0.52 * highCatch)
                * glowF * (1 - 0.75 * blocked) * (1 - 0.5 * wet)
        )

        func colourAt(_ y: Double) -> Oklch {
            let t = (warmStart >= 1 ? 0 : smoothstep(0, 1, clamp01((y - warmStart) / (1 - warmStart))))
                * warmPresence
            let hazeCeiling = 0.35 + 0.58 * dayF + 0.25 * overcastF + 0.30 * glowF
            let coolHorizonL = clamp(
                max(topL, min(topL + coolRamp * (1 - 0.55 * overcastF), hazeCeiling)),
                0.16,
                0.93
            )
            let coolL = lerp(topL, coolHorizonL, y)
            let coolC = topC * (1 - (0.45 + 0.28 * highSun) * y)
            let coolH = topH - 10 * y
            let coolRad = coolH * .pi / 180
            let botRad = botH * .pi / 180
            var a = lerp(coolC * cos(coolRad), botC * cos(botRad), t)
            var b = lerp(coolC * sin(coolRad), botC * sin(botRad), t)
            let bulge = pink * bulgeAmplitude * pow(sin(.pi * t), 1.4)
            a += bulge * cos(bulgeHue * .pi / 180)
            b += bulge * sin(bulgeHue * .pi / 180)

            return Oklch(
                lightness: lerp(coolL, botL, t),
                chroma: hypot(a, b),
                hue: atan2(b, a) * 180 / .pi
            )
        }

        let stops = stopPositions.map { position in
            SkyGradientStop(offset: position, hex: oklchToHex(colourAt(position)))
        }
        let ramp = [0, 0.28, 0.55, 0.78, 1].map { oklchToHex(colourAt($0)) }

        var cloudBands: [SkyCloudBand] = []
        addBand(
            cover: cloudHigh,
            y: 0.16,
            height: 0.13,
            color: colourAt(0.16),
            to: &cloudBands
        )
        addBand(
            cover: cloudMid,
            y: 0.38,
            height: 0.15,
            color: colourAt(0.38),
            to: &cloudBands
        )
        addBand(
            cover: cloudLow,
            y: 0.62,
            height: 0.17,
            color: colourAt(0.62),
            to: &cloudBands
        )

        return SkyAppearance(
            stops: stops,
            ramp: ramp,
            glow: SkyGradientGlow(
                centerX: 0.5,
                centerY: 0.89,
                radius: round((0.30 + 0.12 * glowF) * 1000) / 1000,
                intensity: round(clamp01(warmVigour * (1 - 0.50 * cloudTotal)) * 1000) / 1000
            ),
            cloudBands: cloudBands
        )
    }

    private static func addBand(
        cover: Double,
        y: Double,
        height: Double,
        color: Oklch,
        to bands: inout [SkyCloudBand]
    ) {
        guard cover >= 0.14 else {
            return
        }

        bands.append(
            SkyCloudBand(
                id: "cloud-\(bands.count)",
                y: y,
                height: height,
                hex: oklchToHex(
                    Oklch(
                        lightness: color.lightness * 0.74,
                        chroma: color.chroma * 0.6,
                        hue: color.hue
                    )
                ),
                opacity: round((0.10 + 0.30 * cover) * 100) / 100,
                blur: 0.055
            )
        )
    }

    private static func oklchToHex(_ color: Oklch) -> String {
        let lightness = clamp(color.lightness, 0, 1)
        let hueRad = color.hue * .pi / 180
        var chroma = max(color.chroma, 0)
        var rgb = [Double](repeating: 0, count: 3)

        for _ in 0..<28 {
            rgb = oklabToLinearSrgb(
                lightness: lightness,
                a: chroma * cos(hueRad),
                b: chroma * sin(hueRad)
            )
            if rgb.allSatisfy({ $0 >= -0.0005 && $0 <= 1.0005 }) {
                break
            }
            chroma *= 0.94
        }

        let bytes = rgb.map { value in
            Int(round(clamp01(linearToGamma(clamp01(value))) * 255))
        }
        return "#" + bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func oklabToLinearSrgb(lightness L: Double, a: Double, b: Double) -> [Double] {
        let lPrime = L + 0.3963377774 * a + 0.2158037573 * b
        let mPrime = L - 0.1055613458 * a - 0.0638541728 * b
        let sPrime = L - 0.0894841775 * a - 1.2914855480 * b
        let l = lPrime * lPrime * lPrime
        let m = mPrime * mPrime * mPrime
        let s = sPrime * sPrime * sPrime

        return [
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        ]
    }

    private static func linearToGamma(_ value: Double) -> Double {
        value <= 0.0031308 ? 12.92 * value : 1.055 * pow(value, 1 / 2.4) - 0.055
    }

    private static func finiteOr(_ value: Double, _ fallback: Double) -> Double {
        value.isFinite ? value : fallback
    }

    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }

    private static func clamp01(_ value: Double) -> Double {
        clamp(value, 0, 1)
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ value: Double) -> Double {
        let t = clamp01((value - edge0) / (edge1 - edge0))
        return t * t * (3 - 2 * t)
    }

    private static func bell(_ value: Double, _ low: Double, _ high: Double) -> Double {
        if value >= low && value <= high {
            return 1
        }

        let span = high == low ? 1 : high - low
        let distance = value < low ? low - value : value - high
        return clamp01(1 - distance / span)
    }

    private struct Oklch: Equatable {
        let lightness: Double
        let chroma: Double
        let hue: Double
    }
}

struct SkyTimelineSampler {
    private let timeline: SkyDayTimelineResponse

    init(timeline: SkyDayTimelineResponse) {
        self.timeline = timeline
    }

    var hasAtmosphericFallback: Bool {
        timeline.weather.isEmpty || timeline.airQuality.isEmpty ||
        timeline.weather.contains { row in
            sampleMinutes(row.timeIso) == nil ||
            [row.cloudCover.totalPct, row.cloudCover.lowPct, row.cloudCover.midPct,
             row.cloudCover.highPct, row.visibilityMeters, row.relativeHumidityPct,
             row.precipitationMillimeters].contains { $0 == nil || $0?.isFinite == false }
        } ||
        timeline.airQuality.contains { row in
            sampleMinutes(row.timeIso) == nil ||
            [row.aerosolOpticalDepth, row.dustUgM3, row.particulateMatter2_5UgM3]
                .contains { $0 == nil || $0?.isFinite == false }
        }
    }

    func appearance(at date: Date) -> SkyAppearance? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        guard let timezone = TimeZone(identifier: timeline.location.timezoneId) else { return nil }
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        return appearance(atLocalIso: formatter.string(from: date))
    }

    func appearance(atLocalIso localIso: String) -> SkyAppearance? {
        guard localIso.hasPrefix(timeline.targetDateIso + "T"),
              let minutes = Self.localMinutes(from: localIso), !timeline.solar.isEmpty else {
            return nil
        }

        guard let solarBracket = interpolate(
            timeline.solar,
            at: minutes,
            time: { sampleMinutes($0.timeIso) }
        ) else {
            return nil
        }

        let solar = interpolate(solarBracket)

        let weatherBracket = interpolate(
            timeline.weather,
            at: minutes,
            time: { sampleMinutes($0.timeIso) }
        )
        let airBracket = interpolate(
            timeline.airQuality,
            at: minutes,
            time: { sampleMinutes($0.timeIso) }
        )
        let weather = weatherBracket.map(interpolate)
        let air = airBracket.map(interpolate)

        let input = SkyGradientInput(
            elevationDegrees: solar.elevation,
            azimuthDegrees: solar.azimuth,
            cloudTotalPct: weather?.cloudTotal ?? 0,
            cloudLowPct: weather?.cloudLow ?? 0,
            cloudMidPct: weather?.cloudMid ?? 0,
            cloudHighPct: weather?.cloudHigh ?? 0,
            visibilityMeters: weather?.visibility ?? 24_000,
            relativeHumidityPct: weather?.humidity ?? 60,
            precipitationMillimeters: weather?.precipitation ?? 0,
            aerosolOpticalDepth: air?.aerosolOpticalDepth ?? 0.08,
            dustUgM3: air?.dust ?? 0,
            pm25UgM3: air?.pm25 ?? 0
        )

        return SkyGradientGenerator.generate(input)
    }

    // The HTML preview intentionally samples at minute resolution, even for HH:mm:ss.
    static func localMinutes(from value: String) -> Double? {
        guard value.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$"#,
                          options: .regularExpression) != nil else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = value.count == 19 ? "yyyy-MM-dd'T'HH:mm:ss" : "yyyy-MM-dd'T'HH:mm"
        formatter.isLenient = false
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
        let parts = value.split(separator: "T")[1].split(separator: ":")
        guard let hour = Double(parts[0]), let minute = Double(parts[1]) else { return nil }
        return hour * 60 + minute
    }

    private func sampleMinutes(_ iso: String) -> Double? {
        guard iso.hasPrefix(timeline.targetDateIso + "T") else { return nil }
        return Self.localMinutes(from: iso)
    }

    private func interpolate<T>(
        _ inputRows: [T],
        at minutes: Double,
        time: (T) -> Double?
    ) -> Bracket<T>? {
        let timedRows = inputRows.compactMap { row in time(row).map { (row, $0) } }
            .sorted { $0.1 < $1.1 }
        let rows = timedRows.map(\.0)
        guard !rows.isEmpty else {
            return nil
        }
        if rows.count == 1 || minutes <= timedRows[0].1 {
            return Bracket(before: rows[0], after: rows[0], fraction: 0)
        }
        if minutes >= timedRows[rows.count - 1].1 {
            let last = rows[rows.count - 1]
            return Bracket(before: last, after: last, fraction: 0)
        }

        for index in 0..<(rows.count - 1) {
            let before = rows[index]
            let after = rows[index + 1]
            let beforeMinutes = timedRows[index].1
            let afterMinutes = timedRows[index + 1].1
            guard minutes >= beforeMinutes && minutes <= afterMinutes else {
                continue
            }

            let span = afterMinutes - beforeMinutes
            let fraction = span == 0 ? 0 : (minutes - beforeMinutes) / span
            return Bracket(before: before, after: after, fraction: fraction)
        }

        let last = rows[rows.count - 1]
        return Bracket(before: last, after: last, fraction: 0)
    }

    private struct Bracket<T> {
        let before: T
        let after: T
        let fraction: Double
    }
}

private extension SkyTimelineSampler {
    private func interpolate(
        _ bracket: Bracket<SkyDayTimelineResponse.SolarSample>
    ) -> (elevation: Double, azimuth: Double) {
        (
            elevation: lerp(bracket.before.elevationDegrees, bracket.after.elevationDegrees, bracket.fraction),
            azimuth: lerp(bracket.before.azimuthDegrees, bracket.after.azimuthDegrees, bracket.fraction)
        )
    }

    private func interpolate(
        _ bracket: Bracket<SkyDayTimelineResponse.WeatherSample>
    ) -> (cloudTotal: Double?, cloudLow: Double?, cloudMid: Double?, cloudHigh: Double?, visibility: Double?, humidity: Double?, precipitation: Double?) {
        (
            cloudTotal: interpolate(bracket.before.cloudCover.totalPct, bracket.after.cloudCover.totalPct, bracket.fraction),
            cloudLow: interpolate(bracket.before.cloudCover.lowPct, bracket.after.cloudCover.lowPct, bracket.fraction),
            cloudMid: interpolate(bracket.before.cloudCover.midPct, bracket.after.cloudCover.midPct, bracket.fraction),
            cloudHigh: interpolate(bracket.before.cloudCover.highPct, bracket.after.cloudCover.highPct, bracket.fraction),
            visibility: interpolate(bracket.before.visibilityMeters, bracket.after.visibilityMeters, bracket.fraction, fallback: 24_000),
            humidity: interpolate(bracket.before.relativeHumidityPct, bracket.after.relativeHumidityPct, bracket.fraction, fallback: 60),
            precipitation: interpolate(bracket.before.precipitationMillimeters, bracket.after.precipitationMillimeters, bracket.fraction)
        )
    }

    private func interpolate(
        _ bracket: Bracket<SkyDayTimelineResponse.AirQualitySample>
    ) -> (aerosolOpticalDepth: Double?, dust: Double?, pm25: Double?) {
        (
            aerosolOpticalDepth: interpolate(bracket.before.aerosolOpticalDepth, bracket.after.aerosolOpticalDepth, bracket.fraction, fallback: 0.08),
            dust: interpolate(bracket.before.dustUgM3, bracket.after.dustUgM3, bracket.fraction),
            pm25: interpolate(bracket.before.particulateMatter2_5UgM3, bracket.after.particulateMatter2_5UgM3, bracket.fraction)
        )
    }

    func interpolate(_ before: Double?, _ after: Double?, _ fraction: Double, fallback: Double = 0) -> Double {
        let a = before.flatMap { $0.isFinite ? $0 : nil } ?? fallback
        let b = after.flatMap { $0.isFinite ? $0 : nil } ?? fallback
        return lerp(a, b, fraction)
    }

    func lerp(_ before: Double, _ after: Double, _ fraction: Double) -> Double {
        before + (after - before) * fraction
    }
}
