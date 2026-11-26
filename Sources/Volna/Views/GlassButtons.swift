import SwiftUI

/// How the buttons of the player look: the usual ones, or round convex glass with a rim and a highlight.
enum ButtonLook: String, CaseIterable, Identifiable {
    case classic, glass, frosted, chrome
    var id: String { rawValue }

    var name: String {
        switch self {
        case .classic: tr("Обычные")
        case .glass: tr("Стекло")
        case .frosted: tr("Матовое")
        case .chrome: tr("Хром")
        }
    }

    static func of(_ s: String) -> ButtonLook { ButtonLook(rawValue: s) ?? .classic }
}

/// A round convex button: a body you can see through, a light rim, a highlight on top and a soft shadow.
struct Orb<Label: View>: View {
    let look: ButtonLook
    /// 0 = solid body, 1 = almost only the rim and the highlight are left.
    let clearness: Double
    let size: CGFloat
    var tint: Color?
    var pressed = false
    let label: Label
    @Environment(\.accessibilityReduceTransparency) private var solid

    init(look: ButtonLook, clearness: Double, size: CGFloat, tint: Color? = nil, pressed: Bool = false, @ViewBuilder label: () -> Label) {
        self.look = look
        self.clearness = clearness
        self.size = size
        self.tint = tint
        self.pressed = pressed
        self.label = label()
    }

    /// How much of the body is seen.
    private var seen: Double { solid ? 1 : 1 - 0.85 * min(max(clearness, 0), 1) }

    var body: some View {
        ZStack {
            base
            // the highlight on the upper half, like light on a curved glass
            Ellipse()
                .fill(LinearGradient(colors: [.white.opacity(look == .chrome ? 0.9 : 0.55), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.74, height: size * 0.44)
                .offset(y: -size * 0.21)
            // the rim: light at the top, darker at the bottom
            Circle()
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.2), .black.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                              lineWidth: size > 60 ? 2.2 : 1.6)
            label
                .shadow(color: .black.opacity(0.22), radius: 0.8, y: 0.8)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .compositingGroup()
        .shadow(color: .black.opacity(0.18 + 0.22 * seen), radius: pressed ? 2 : 6, y: pressed ? 1 : 4)
        .scaleEffect(pressed ? 0.93 : 1)
        .brightness(pressed ? -0.07 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressed)
    }

    @ViewBuilder private var base: some View {
        switch look {
        case .chrome:
            ZStack {
                Circle().fill(.ultraThinMaterial)
                Circle()
                    .fill(RadialGradient(colors: [Color(white: 0.98), Color(white: 0.8), Color(white: 0.42)],
                                         center: UnitPoint(x: 0.5, y: 0.28), startRadius: 0, endRadius: size * 0.7))
                    .opacity(seen)
                if let tint { Circle().fill(tint.opacity(0.3 * seen + 0.1)) }
            }
        case .frosted:
            ZStack {
                Circle().fill(.thickMaterial).opacity(0.3 + 0.7 * seen)
                Circle().fill((tint ?? .white).opacity(tint == nil ? 0.12 * seen : 0.25 + 0.55 * seen))
            }
        case .glass, .classic:
            ZStack {
                Circle().fill(.ultraThinMaterial).opacity(seen)
                Circle().fill((tint ?? .white).opacity(tint == nil ? 0.08 + 0.1 * seen : 0.25 + 0.55 * seen))
            }
        }
    }
}

/// A button drawn as an orb that sinks in when pressed.
struct OrbButtonStyle: ButtonStyle {
    let look: ButtonLook
    let clearness: Double
    let size: CGFloat
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        Orb(look: look, clearness: clearness, size: size, tint: tint, pressed: configuration.isPressed) { configuration.label }
            .contentShape(Circle())
    }
}
