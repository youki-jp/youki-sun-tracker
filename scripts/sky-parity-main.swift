import Foundation

// Compile with the production generator and timeline DTO/client files.
@main
struct SkyParityRunner {
    static func main() throws {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        let request = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var outputs: [Any] = []

        for sample in request["samples"] as? [[String: Double]] ?? [] {
            func n(_ key: String) -> Double { sample[key]! }
            outputs.append(encode(SkyGradientGenerator.generate(SkyGradientInput(
                elevationDegrees: n("elevationDegrees"), azimuthDegrees: n("azimuthDegrees"),
                cloudTotalPct: n("cloudTotalPct"), cloudLowPct: n("cloudLowPct"),
                cloudMidPct: n("cloudMidPct"), cloudHighPct: n("cloudHighPct"),
                visibilityMeters: n("visibilityMeters"), relativeHumidityPct: n("relativeHumidityPct"),
                precipitationMillimeters: n("precipitationMillimeters"),
                aerosolOpticalDepth: n("aerosolOpticalDepth"), dustUgM3: n("dustUgM3"),
                pm25UgM3: n("pm25UgM3")
            ))))
        }

        if let timelineObject = request["timeline"] {
            let timelineData = try JSONSerialization.data(withJSONObject: timelineObject)
            let timeline = try JSONDecoder().decode(SkyDayTimelineResponse.self, from: timelineData)
            let sampler = SkyTimelineSampler(timeline: timeline)
            for iso in request["times"] as? [String] ?? [] {
                outputs.append(sampler.appearance(atLocalIso: iso).map(encode) ?? NSNull())
            }
        }

        let result = try JSONSerialization.data(withJSONObject: outputs, options: [.sortedKeys])
        FileHandle.standardOutput.write(result)
    }

    static func encode(_ appearance: SkyAppearance) -> [String: Any] {
        [
            "stops": appearance.stops.map { ["position": $0.offset, "hex": $0.hex] as [String: Any] },
            "ramp": appearance.ramp,
            "glow": [
                "centerX": appearance.glow.centerX, "centerY": appearance.glow.centerY,
                "radius": appearance.glow.radius, "intensity": appearance.glow.intensity
            ],
            "cloudBands": appearance.cloudBands.map {
                ["y": $0.y, "height": $0.height, "hex": $0.hex,
                 "opacity": $0.opacity, "blur": $0.blur] as [String: Any]
            }
        ]
    }
}
