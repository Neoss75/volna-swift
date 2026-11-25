import SwiftUI

/// Colours of the visualisation.
enum VizColors: String, Codable, CaseIterable, Identifiable {
    case accent, level, rainbow, fire, neon
    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        self = VizColors(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .level
    }

    var name: String {
        switch self {
        case .accent: tr("В тон плеера")
        case .level: tr("По уровню")
        case .rainbow: tr("Радуга")
        case .fire: tr("Огонь")
        case .neon: tr("Неон")
        }
    }

    /// From quiet to loud (for the rainbow from low to high notes), for the light and the dark theme.
    private var stops: [(light: UInt32, dark: UInt32)] {
        switch self {
        case .accent: []
        case .level: [(0x1D5FD6, 0x3B7BFF), (0x0891B2, 0x22C3E6), (0x16A05A, 0x34D17A), (0xD69A00, 0xFFD23F), (0xE06A10, 0xFF8A3D), (0xD61F36, 0xFF3B4E)]
        case .rainbow: [(0xD61F36, 0xFF4D5E), (0xE06A10, 0xFF9A3D), (0xC79100, 0xFFD84A), (0x16A05A, 0x3DDC84), (0x0891B2, 0x2CC8EE), (0x1D5FD6, 0x5A8CFF), (0x8B2FC9, 0xC56BFF)]
        case .fire: [(0x7A1616, 0x8A1C1C), (0xD2331A, 0xE8421F), (0xE8740C, 0xFF9A2E), (0xD69A00, 0xFFE27A)]
        case .neon: [(0x0891B2, 0x22D3EE), (0x4F46E5, 0x6C63FF), (0xA21CAF, 0xD946EF), (0xDB2777, 0xFF5FA2)]
        }
    }

    static let steps = 24
    private static let tables: [VizColors: [Color]] = Dictionary(uniqueKeysWithValues: allCases.map { (c: VizColors) -> (VizColors, [Color]) in
        let s = c.stops
        guard s.count > 1 else { return (c, []) }
        return (c, (0..<steps).map { (i: Int) -> Color in
            let p = Double(i) / Double(steps - 1) * Double(s.count - 1)
            let k = min(s.count - 2, Int(p)), t = p - Double(k)
            return Theme.dynamic(light: mix(s[k].light, s[k + 1].light, t), dark: mix(s[k].dark, s[k + 1].dark, t))
        })
    })

    private static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        var out: UInt32 = 0
        for shift: UInt32 in [16, 8, 0] {
            let x = Double((a >> shift) & 0xFF), y = Double((b >> shift) & 0xFF)
            out |= UInt32((x + (y - x) * t).rounded()) << shift
        }
        return out
    }

    var table: [Color] { Self.tables[self] ?? [] }
    var gradient: Gradient { Gradient(colors: stops.map { Theme.dynamic(light: $0.light, dark: $0.dark) }) }
    var loop: Gradient {
        let c = stops.map { Theme.dynamic(light: $0.light, dark: $0.dark) }
        return Gradient(colors: c + Array(c.prefix(1)))
    }
}

/// Picks a colour for a level (0…1) at a place (0…1).
struct VizPaint {
    let colors: VizColors
    let accent: Color

    var many: Bool { colors != .accent }

    /// The place in the table, so that parts of one colour can be drawn together.
    func index(_ level: Double, _ place: Double) -> Int {
        guard many else { return 0 }
        let x = colors == .rainbow ? place : level
        return min(VizColors.steps - 1, max(0, Int(x * Double(VizColors.steps))))
    }

    func at(_ i: Int) -> Color { many ? colors.table[i] : accent }
    func color(_ level: Double, _ place: Double) -> Color { at(index(level, place)) }

    /// One-colour bars show the level by brightness, coloured ones mostly by colour.
    func alpha(_ level: Double, _ low: Double = 0.35) -> Double { many ? 0.75 + 0.25 * level : low + (1 - low) * level }

    /// Bars growing from `bottom` to `top`.
    func shade(bottom: CGFloat, top: CGFloat, width: CGFloat) -> GraphicsContext.Shading {
        switch colors {
        case .accent: .color(accent)
        case .rainbow: .linearGradient(colors.gradient, startPoint: .zero, endPoint: CGPoint(x: width, y: 0))
        default: .linearGradient(colors.gradient, startPoint: CGPoint(x: 0, y: bottom), endPoint: CGPoint(x: 0, y: top))
        }
    }

    /// Rays growing from the centre.
    func shade(center: CGPoint, from r0: CGFloat, to r1: CGFloat) -> GraphicsContext.Shading {
        switch colors {
        case .accent: .color(accent)
        case .rainbow: .conicGradient(colors.loop, center: center, angle: .degrees(-90))
        default: .radialGradient(colors.gradient, center: center, startRadius: r0, endRadius: r1)
        }
    }
}
