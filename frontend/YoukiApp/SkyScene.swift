import Foundation

enum SkyLightingQuality: String, Equatable {
    case radiationSupported
    case cloudEstimated
    case unavailable
}

enum SkySceneProvenance: Equatable {
    case forecast
    case staleForecast
    case decorativeFallback
}

struct SkySceneObservation: Equatable {
    let localIso: String
    let elevationDegrees: Double
    let azimuthDegrees: Double
    let cloudTotalPct: Double?
    let cloudLowPct: Double?
    let cloudMidPct: Double?
    let cloudHighPct: Double?
    let visibilityMeters: Double?
    let precipitationMillimeters: Double?
    let directNormalWm2: Double?
    let globalHorizontalWm2: Double?
    let diffuseHorizontalWm2: Double?
    let heldFields: Bool
    let missingFields: Bool
}

struct SkySceneSun: Equatable {
    let centerX: Double
    let centerY: Double
    let radius: Double
    let visibleLimb: Double
    let opacity: Double
    let softness: Double
}

struct SkySceneCloud: Equatable, Identifiable {
    enum Altitude: String, Equatable { case high, mid, low, generic }
    let id: Altitude
    let cover: Double
    let opacity: Double
    let centerY: Double
    let spread: Double
}

struct SkyScene: Equatable {
    let base: SkyAppearance
    let sun: SkySceneSun?
    let horizonGlow: Double
    let cloudLayers: [SkySceneCloud]
    let veilOpacity: Double
    let daylight: Double
    let warmth: Double
    let quality: SkyLightingQuality
    let provenance: SkySceneProvenance
    let selectedLocalIso: String?
    let seed: UInt32
    let heldFields: Bool
    let missingFields: Bool
    let contradictoryRadiation: Bool

    var accessibilityDescription: String {
        let light = switch quality {
        case .radiationSupported: "light based on solar radiation"
        case .cloudEstimated: "light estimated from cloud cover"
        case .unavailable: "limited weather data"
        }
        let sunDescription = sun == nil ? "no visible sun" : "visible sun"
        let cloudDescription = cloudLayers.isEmpty ? "no reported cloud layers" : "cloud layers"
        let freshness = provenance == .staleForecast ? "forecast may be outdated" : "forecast"
        return "Sky, \(freshness), \(sunDescription), \(cloudDescription), \(light)"
    }

    static var fallback: SkyScene {
        SkyScene(base: .fallback, sun: nil, horizonGlow: 0, cloudLayers: [],
                 veilOpacity: 0, daylight: 0, warmth: 0, quality: .unavailable,
                 provenance: .decorativeFallback, selectedLocalIso: nil, seed: 0,
                 heldFields: false, missingFields: true, contradictoryRadiation: false)
    }

    static func legacy(base: SkyAppearance, selectedLocalIso: String? = nil) -> SkyScene {
        SkyScene(base: base, sun: nil, horizonGlow: 0, cloudLayers: [], veilOpacity: 0,
                 daylight: 0, warmth: 0, quality: .unavailable, provenance: .forecast,
                 selectedLocalIso: selectedLocalIso, seed: 0, heldFields: false,
                 missingFields: true, contradictoryRadiation: false)
    }

    func withProvenance(_ value: SkySceneProvenance) -> SkyScene {
        SkyScene(base: base, sun: sun, horizonGlow: horizonGlow, cloudLayers: cloudLayers,
                 veilOpacity: veilOpacity, daylight: daylight, warmth: warmth, quality: quality,
                 provenance: value, selectedLocalIso: selectedLocalIso, seed: seed,
                 heldFields: heldFields, missingFields: missingFields,
                 contradictoryRadiation: contradictoryRadiation)
    }
}
