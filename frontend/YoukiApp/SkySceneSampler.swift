import Foundation

struct SkySceneSampler {
    let timeline: SkyDayTimelineResponse

    func scene(at date: Date) -> SkyScene? {
        guard let timezone = TimeZone(identifier: timeline.location.timezoneId) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return scene(atLocalIso: formatter.string(from: date))
    }

    func scene(atLocalIso iso: String) -> SkyScene? {
        guard iso.hasPrefix(timeline.targetDateIso + "T"),
              let minutes = SkyTimelineSampler.localMinutes(from: iso),
              let base = SkyTimelineSampler(timeline: timeline).appearance(atLocalIso: iso) else { return nil }
        if hasTimezoneTransition {
            return .legacy(base: base, selectedLocalIso: iso)
        }
        let solarRows = timeline.solar.compactMap { row -> (Double, SkyDayTimelineResponse.SolarSample)? in
            guard let minute = rowMinutes(row.timeIso), row.elevationDegrees.isFinite,
                  row.azimuthDegrees.isFinite else { return nil }
            return (minute, row)
        }.sorted { $0.0 < $1.0 }
        guard let first = solarRows.first, let last = solarRows.last,
              minutes >= first.0, minutes <= last.0 else {
            return .legacy(base: base, selectedLocalIso: iso)
        }
        let before = solarRows.last { $0.0 <= minutes } ?? first
        let after = solarRows.first { $0.0 >= minutes } ?? last
        let t = before.0 == after.0 ? 0 : (minutes - before.0) / (after.0 - before.0)
        let elevation = before.1.elevationDegrees + (after.1.elevationDegrees - before.1.elevationDegrees) * t
        // Azimuth wraps at north; follow the shortest arc without changing the
        // legacy gradient's interpolation or its numerical parity.
        var azimuthDelta = (after.1.azimuthDegrees - before.1.azimuthDegrees).truncatingRemainder(dividingBy: 360)
        if azimuthDelta > 180 { azimuthDelta -= 360 }
        if azimuthDelta < -180 { azimuthDelta += 360 }
        let azimuth = (before.1.azimuthDegrees + azimuthDelta * t + 360).truncatingRemainder(dividingBy: 360)

        let rows = timeline.weather
        func weather(_ field: (SkyDayTimelineResponse.WeatherSample) -> Double?) -> SampledValue {
            sample(rows: rows, minutes: minutes, time: { $0.timeIso }, value: field)
        }
        let total = weather { $0.cloudCover.totalPct }
        let low = weather { $0.cloudCover.lowPct }
        let mid = weather { $0.cloudCover.midPct }
        let high = weather { $0.cloudCover.highPct }
        let visibility = weather { $0.visibilityMeters }
        let precipitation = weather { $0.precipitationMillimeters }
        let direct = weather { $0.solarRadiation?.isInstant == true ? $0.solarRadiation?.directNormalWm2 : nil }
        let global = weather { $0.solarRadiation?.isInstant == true ? $0.solarRadiation?.globalHorizontalWm2 : nil }
        let diffuse = weather { $0.solarRadiation?.isInstant == true ? $0.solarRadiation?.diffuseHorizontalWm2 : nil }
        let samples = [total, low, mid, high, visibility, precipitation, direct, global, diffuse]
        let observation = SkySceneObservation(
            localIso: iso, elevationDegrees: elevation, azimuthDegrees: azimuth,
            cloudTotalPct: total.value, cloudLowPct: low.value, cloudMidPct: mid.value,
            cloudHighPct: high.value, visibilityMeters: visibility.value,
            precipitationMillimeters: precipitation.value, directNormalWm2: direct.value,
            globalHorizontalWm2: global.value, diffuseHorizontalWm2: diffuse.value,
            heldFields: samples.contains { $0.held }, missingFields: samples.contains { $0.value == nil }
        )
        return SkySceneGenerator.generate(base: base, observation: observation, seed: seed)
    }

    private struct SampledValue {
        let value: Double?
        let held: Bool
    }

    private func sample<Row>(rows: [Row], minutes: Double,
                             time: (Row) -> String, value: (Row) -> Double?) -> SampledValue {
        let valid = rows.compactMap { row -> (Double, Double)? in
            guard let instant = rowMinutes(time(row)), let number = value(row),
                  number.isFinite, number >= 0 else { return nil }
            return (instant, number)
        }.sorted { $0.0 < $1.0 }
        if let exact = valid.first(where: { $0.0 == minutes }) { return .init(value: exact.1, held: false) }
        let before = valid.last { $0.0 < minutes }
        let after = valid.first { $0.0 > minutes }
        if let before, let after, after.0 - before.0 <= 90 {
            let fraction = (minutes - before.0) / (after.0 - before.0)
            return .init(value: before.1 + (after.1 - before.1) * fraction, held: false)
        }
        let nearest = [before, after].compactMap { $0 }.min { abs($0.0 - minutes) < abs($1.0 - minutes) }
        if let nearest, abs(nearest.0 - minutes) <= 60 { return .init(value: nearest.1, held: true) }
        return .init(value: nil, held: false)
    }

    private func rowMinutes(_ iso: String) -> Double? {
        guard iso.hasPrefix(timeline.targetDateIso + "T") else { return nil }
        return SkyTimelineSampler.localMinutes(from: iso)
    }

    private var hasTimezoneTransition: Bool {
        guard let timezone = TimeZone(identifier: timeline.location.timezoneId) else { return true }
        let parts = timeline.targetDateIso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return true }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        guard let noon = calendar.date(from: .init(year: parts[0], month: parts[1], day: parts[2], hour: 12)),
              let interval = calendar.dateInterval(of: .day, for: noon) else { return true }
        return abs(interval.duration - 86_400) > 1
    }

    private var seed: UInt32 {
        // FNV-1a uses a documented stable hash; Swift Hasher varies per process.
        let cell = "\(Int((timeline.location.latitude * 10).rounded())):" +
                   "\(Int((timeline.location.longitude * 10).rounded())):" + timeline.targetDateIso
        return cell.utf8.reduce(UInt32(2_166_136_261)) { ($0 ^ UInt32($1)) &* 16_777_619 }
    }
}
