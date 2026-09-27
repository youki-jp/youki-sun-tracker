import Foundation

@main
struct SkySceneRegression {
    static func appearance(_ elevation: Double) -> SkyAppearance {
        SkyGradientGenerator.generate(.init(elevationDegrees: elevation, azimuthDegrees: 180,
            cloudTotalPct: 0, cloudLowPct: 0, cloudMidPct: 0, cloudHighPct: 0,
            visibilityMeters: 24_000, relativeHumidityPct: 65, precipitationMillimeters: 0,
            aerosolOpticalDepth: 0.08, dustUgM3: 0, pm25UgM3: 0))
    }
    struct Fixture: Decodable {
        let synthetic: Bool
        let oldServer: SkyDayTimelineResponse
        let enrichedServer: SkyDayTimelineResponse
    }

    static func observation(elevation: Double, low: Double? = 0, mid: Double? = 0,
                            high: Double? = 0, total: Double? = 0,
                            visibility: Double? = 24_000, dni: Double? = 700,
                            global: Double? = 700, diffuse: Double? = 100) -> SkySceneObservation {
        .init(localIso: "2026-09-25T12:00:00", elevationDegrees: elevation, azimuthDegrees: 180,
              cloudTotalPct: total, cloudLowPct: low, cloudMidPct: mid, cloudHighPct: high,
              visibilityMeters: visibility, precipitationMillimeters: 0,
              directNormalWm2: dni, globalHorizontalWm2: global,
              diffuseHorizontalWm2: diffuse, heldFields: false, missingFields: false)
    }

    static func main() throws {
        let url = URL(fileURLWithPath: "frontend/YoukiApp/Tests/Fixtures/sky-scenes.json")
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        precondition(fixture.synthetic)
        let old = SkySceneSampler(timeline: fixture.oldServer)
        let enriched = SkySceneSampler(timeline: fixture.enrichedServer)
        let noon = "2026-09-25T12:00:00"
        let oldScene = old.scene(atLocalIso: noon)!
        let newScene = enriched.scene(atLocalIso: noon)!
        precondition(oldScene.base == newScene.base)
        precondition(oldScene.quality == .cloudEstimated && newScene.quality == .radiationSupported)
        precondition(newScene.sun != nil && newScene.sun!.opacity > 0.9)
        precondition(oldScene.seed == newScene.seed && enriched.scene(atLocalIso: noon) == newScene)
        precondition(enriched.scene(atLocalIso: "2026-09-26T12:00:00") == nil)
        precondition(enriched.scene(atLocalIso: "2026-09-25T05:30:00")?.sun == nil)
        precondition(enriched.scene(atLocalIso: "2026-09-25T06:00:00")?.sun == nil)

        let base = newScene.base
        let beforeSunrise = SkySceneGenerator.generate(base: appearance(-3), observation: observation(elevation: -3), seed: 5)
        precondition(beforeSunrise.sun == nil && beforeSunrise.horizonGlow > 0)
        let night = SkySceneGenerator.generate(base: base, observation: observation(elevation: -20), seed: 5)
        precondition(night.sun == nil && night.horizonGlow == 0 && night.daylight == 0)
        for (elevation, limb) in [(-0.267, 0.0), (0.0, 0.5), (0.267, 1.0)] {
            let result = SkySceneGenerator.generate(base: base, observation: observation(elevation: elevation), seed: 5)
            precondition(abs((result.sun?.visibleLimb ?? 0) - limb) < 0.001)
        }
        let zero = SkySceneGenerator.generate(base: base, observation: observation(elevation: 25, dni: 0), seed: 5)
        precondition(zero.sun == nil && zero.quality == .radiationSupported)
        let lowOvercast = SkySceneGenerator.generate(base: base, observation: observation(elevation: 25, low: 100, total: 100, dni: 0), seed: 5)
        precondition(lowOvercast.sun == nil && lowOvercast.cloudLayers.contains { $0.id == .low })
        let fog = SkySceneGenerator.generate(base: base, observation: observation(elevation: 15, visibility: 150), seed: 5)
        precondition(fog.sun == nil && fog.veilOpacity > 0)
        let highWisp = SkySceneGenerator.generate(base: base, observation: observation(elevation: 30, high: 70, total: 70, dni: 350), seed: 5)
        precondition(highWisp.sun != nil && highWisp.cloudLayers.map(\.id) == [.high])
        let generic = SkySceneGenerator.generate(base: base,
            observation: observation(elevation: 25, low: nil, mid: nil, high: nil, total: 70, dni: nil), seed: 5)
        precondition(generic.quality == .cloudEstimated && generic.cloudLayers.map(\.id) == [.generic])
        let missing = SkySceneGenerator.generate(base: base,
            observation: observation(elevation: 25, low: nil, mid: nil, high: nil, total: nil, dni: nil), seed: 5)
        precondition(missing.quality == .unavailable && missing.sun == nil && missing.cloudLayers.isEmpty)
        let invalidRatio = SkySceneGenerator.generate(base: base,
            observation: observation(elevation: 25, dni: 300, global: 0, diffuse: 100), seed: 5)
        precondition(invalidRatio.sun != nil && invalidRatio.sun!.softness.isFinite)
        var previous = 1.0
        for cover in [0.0, 30, 60, 85, 92, 100] {
            let scene = SkySceneGenerator.generate(base: base,
                observation: observation(elevation: 25, low: cover, total: cover, dni: nil), seed: 5)
            let opacity = scene.sun?.opacity ?? 0
            precondition(opacity <= previous)
            previous = opacity
        }

        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        var sparse = root["enrichedServer"] as! [String: Any]
        let weather = sparse["weather"] as! [[String: Any]]
        sparse["weather"] = [weather[1], weather[2]]
        let sparseData = try JSONSerialization.data(withJSONObject: sparse)
        let sparseTimeline = try JSONDecoder().decode(SkyDayTimelineResponse.self, from: sparseData)
        let sparseScene = SkySceneSampler(timeline: sparseTimeline)
        precondition(sparseScene.scene(atLocalIso: "2026-09-25T09:00:00")?.quality == .unavailable)
        precondition(sparseScene.scene(atLocalIso: "2026-09-25T06:30:00")?.heldFields == true)

        // The local timestamps have no UTC offset. A transition day deliberately
        // uses legacy rendering until the API supplies unambiguous instants.
        var transition = String(data: sparseData, encoding: .utf8)!
        transition = transition.replacingOccurrences(of: "2026-09-25", with: "2026-10-25")
            .replacingOccurrences(of: "Asia/Tokyo", with: "Europe/London")
            .replacingOccurrences(of: "Asia\\/Tokyo", with: "Europe\\/London")
        let transitionTimeline = try JSONDecoder().decode(SkyDayTimelineResponse.self, from: Data(transition.utf8))
        precondition(SkySceneSampler(timeline: transitionTimeline).scene(atLocalIso: "2026-10-25T12:00:00")?.seed == 0)

        print("PASS: old/new server decoding, gradient parity, scene regimes, missing/zero, time gaps, transition day, stable seed")
    }
}
