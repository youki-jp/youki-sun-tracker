import Foundation

enum SkySceneGenerator {
    // These constants style the illustration; they are not a calibrated
    // probability that a person can see the solar disc.
    static func generate(base: SkyAppearance, observation s: SkySceneObservation, seed: UInt32) -> SkyScene {
        let elevation = clamp(s.elevationDegrees, -90, 90)
        let low = normalized(s.cloudLowPct)
        let mid = normalized(s.cloudMidPct)
        let high = normalized(s.cloudHighPct)
        let total = normalized(s.cloudTotalPct)
        let hasCloud = [low, mid, high, total].contains { $0 != nil }
        let radiation = positive(s.directNormalWm2)

        let transmission: Double
        if let low, let mid, let high {
            transmission = (1 - 0.9 * low) * (1 - 0.6 * mid) * (1 - 0.25 * high)
        } else if let total {
            transmission = pow(1 - total, 1.5)
        } else if hasCloud {
            transmission = min(0.35, (1 - 0.9 * (low ?? 0)) * (1 - 0.6 * (mid ?? 0)) * (1 - 0.25 * (high ?? 0)))
        } else {
            transmission = 0
        }
        let visibilityCap = positive(s.visibilityMeters).map { smooth(200, 5_000, $0) } ?? 1
        let overcastCap = low.map { 1 - smooth(0.85, 1, $0) } ?? 1
        let direct = elevation <= -0.267 ? 0 :
            (radiation.map { smooth(20, 500, $0) } ?? transmission) * visibilityCap * overcastCap
        let limb = smooth(-0.267, 0.267, elevation)
        let global = positive(s.globalHorizontalWm2)
        let diffuse = positive(s.diffuseHorizontalWm2)
        let diffuseShare: Double?
        if let global, let diffuse, global >= 20, diffuse <= global + 1 {
            diffuseShare = clamp(diffuse / global, 0, 1)
        } else {
            diffuseShare = nil
        }
        let daylight = smooth(-6, 8, elevation)
        let warmth = exp(-pow((elevation + 1) / 10, 2)) * smooth(-6, -2, elevation)
        let horizonGlow = elevation <= -6 ? 0 : base.glow.intensity * smooth(-6, -4, elevation)
        let veil = positive(s.visibilityMeters).map { (1 - smooth(200, 18_000, $0)) * 0.5 } ?? 0
        let sun = direct > 0.001 && limb > 0 ? SkySceneSun(
            centerX: 0.5, centerY: 0.86 - 0.72 * clamp(elevation / 90, 0, 1),
            radius: 0.025, visibleLimb: limb, opacity: clamp(direct, 0, 1),
            softness: diffuseShare ?? clamp((high ?? total ?? 0) * 0.6 + (mid ?? 0) * 0.3, 0, 1)
        ) : nil

        var layers: [SkySceneCloud] = []
        if let high, high > 0 { layers.append(.init(id: .high, cover: high, opacity: 0.42, centerY: 0.26, spread: 0.28)) }
        if let mid, mid > 0 { layers.append(.init(id: .mid, cover: mid, opacity: 0.72, centerY: 0.48, spread: 0.24)) }
        if let low, low > 0 { layers.append(.init(id: .low, cover: low, opacity: 0.93, centerY: 0.63, spread: 0.32)) }
        if low == nil && mid == nil && high == nil, let total, total > 0 {
            layers.append(.init(id: .generic, cover: total, opacity: 0.8, centerY: 0.5, spread: 0.45))
        }
        return SkyScene(
            base: base, sun: sun, horizonGlow: clamp(horizonGlow, 0, 1), cloudLayers: layers,
            veilOpacity: clamp(veil, 0, 1), daylight: daylight, warmth: clamp(warmth, 0, 1),
            quality: radiation != nil ? .radiationSupported : hasCloud ? .cloudEstimated : .unavailable,
            provenance: .forecast, selectedLocalIso: s.localIso, seed: seed,
            heldFields: s.heldFields, missingFields: s.missingFields,
            contradictoryRadiation: (radiation ?? 0) > 100 && (low ?? 0) > 0.95
        )
    }

    private static func positive(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }

    private static func normalized(_ value: Double?) -> Double? {
        positive(value).map { clamp($0 / 100, 0, 1) }
    }

    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }

    private static func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
        let t = clamp((value - low) / (high - low), 0, 1)
        return t * t * (3 - 2 * t)
    }
}
