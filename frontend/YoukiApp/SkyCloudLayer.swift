import CoreGraphics
import Foundation
import SwiftUI

struct SkyCloudLayer: View {
    let scene: SkyScene

    var body: some View {
        GeometryReader { proxy in
            Canvas(opaque: false) { context, size in
                for layer in scene.cloudLayers {
                    guard let image = SkyCloudTexture.image(layer: layer, scene: scene) else { continue }
                    context.draw(Image(decorative: image, scale: 1),
                                 in: CGRect(origin: .zero, size: size))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum SkyCloudTexture {
    static let width = 180
    static let height = 240
    static let count = width * height
    private static let lock = NSLock()
    private static var fields: [String: [Float]] = [:]

    static func image(layer: SkySceneCloud, scene: SkyScene) -> CGImage? {
        let noise = field(layer: layer, seed: scene.seed)
        let threshold = 0.76 - 0.60 * layer.cover
        let deck = layer.id == .low || layer.id == .generic ? smooth(0.78, 1, layer.cover) : 0
        var pixels = [UInt8](repeating: 0, count: count * 4)
        for y in 0..<height {
            let v = Double(y) / Double(height)
            let envelope = exp(-pow((v - layer.centerY) / layer.spread, 4))
            let sky = colorAt(scene.base, y: v)
            let body = zip(sky, [120.0, 133.0, 148.0]).map { a, b in
                (a * 0.65 + b * 0.35) * (0.54 + 0.34 * scene.daylight)
            }
            let lit = [239.0, 241.0, 236.0].enumerated().map { index, channel in
                channel * (1 - scene.warmth * 0.82) + [250.0, 186.0, 135.0][index] * scene.warmth * 0.82
            }
            for x in 0..<width {
                let i = y * width + x
                let n = Double(noise[i])
                let density = smooth(threshold, threshold + 0.22, n)
                let shape = max(density * envelope, deck * (0.68 + 0.3 * n))
                let upper = Double(noise[max(0, y - 2) * width + x])
                let edge = clamp((n - upper) * 12 + 0.33)
                let illumination = scene.daylight * (0.13 + (scene.sun?.opacity ?? 0) * 0.36) + scene.warmth * 0.30
                let blend = clamp(edge * illumination)
                let p = i * 4
                for c in 0..<3 { pixels[p + c] = UInt8(clamping: Int((body[c] * (1 - blend) + lit[c] * blend).rounded())) }
                pixels[p + 3] = UInt8(clamping: Int((255 * clamp(shape * layer.opacity * smooth(0, 0.12, layer.cover))).rounded()))
            }
        }
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    private static func field(layer: SkySceneCloud, seed: UInt32) -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(seed):\(layer.id.rawValue)"
        if let cached = fields[key] { return cached }
        let layerIndex: UInt32 = layer.id == .high ? 1 : layer.id == .mid ? 2 : layer.id == .low ? 3 : 4
        var values = [Float](repeating: 0, count: count)
        for y in 0..<height {
            for x in 0..<width {
                let u = Double(x) / Double(width), v = Double(y) / Double(height)
                let warp = noise(u * 3, v * 4, seed &+ layerIndex) * 0.8
                values[y * width + x] = Float(fbm(u * (layer.id == .high ? 3 : 5) + warp + 13,
                                                 v * (layer.id == .high ? 24 : 9) + warp + 5,
                                                 seed &+ layerIndex &* 97))
            }
        }
        if fields.count >= 4 { fields.removeAll() }
        fields[key] = values
        return values
    }

    private static func hash(_ x: Int, _ y: Int, _ seed: UInt32) -> Double {
        var h = UInt32(truncatingIfNeeded: x) &* 374_761_393
        h = h &+ UInt32(truncatingIfNeeded: y) &* 668_265_263
        h = h &+ seed &* 1_442_695_041
        h = (h ^ (h >> 13)) &* 1_274_126_177
        return Double(h ^ (h >> 16)) / Double(UInt32.max)
    }

    private static func noise(_ x: Double, _ y: Double, _ seed: UInt32) -> Double {
        let ix = Int(floor(x)), iy = Int(floor(y))
        let tx = smooth(0, 1, x - Double(ix)), ty = smooth(0, 1, y - Double(iy))
        let a = hash(ix, iy, seed) * (1 - tx) + hash(ix + 1, iy, seed) * tx
        let b = hash(ix, iy + 1, seed) * (1 - tx) + hash(ix + 1, iy + 1, seed) * tx
        return a * (1 - ty) + b * ty
    }

    private static func fbm(_ x: Double, _ y: Double, _ seed: UInt32) -> Double {
        var result = 0.0, amplitude = 0.53, frequency = 1.0
        for i in 0..<5 {
            result += noise(x * frequency, y * frequency, seed &+ UInt32(i * 7)) * amplitude
            amplitude *= 0.48
            frequency *= 2.03
        }
        return result / 1.005
    }

    private static func colorAt(_ base: SkyAppearance, y: Double) -> [Double] {
        let index = base.stops.firstIndex { $0.offset >= y } ?? base.stops.count - 1
        if index == 0 { return rgb(base.stops[0].hex) }
        let a = base.stops[index - 1], b = base.stops[index]
        let t = (y - a.offset) / (b.offset - a.offset)
        return zip(rgb(a.hex), rgb(b.hex)).map { $0 * (1 - t) + $1 * t }
    }

    private static func rgb(_ hex: String) -> [Double] {
        let chars = Array(hex.dropFirst())
        guard chars.count == 6 else { return [128, 128, 128] }
        return stride(from: 0, to: 6, by: 2).map { Double(Int(String(chars[$0...($0 + 1)]), radix: 16) ?? 128) }
    }

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
    private static func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
        let t = clamp((value - low) / (high - low))
        return t * t * (3 - 2 * t)
    }
}
