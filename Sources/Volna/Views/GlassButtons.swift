import SwiftUI

/// How the buttons of the player look: the usual ones, or convex glass with a rim and a highlight.
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

    /// The ink of icons and words on this glass: dark on chrome, the usual text colour on clear and frosted glass.
    var ink: Color { self == .chrome ? Color(white: 0.16) : Theme.fg }

    /// The ink on glass coloured with the accent: the coloured body takes the ink made for the accent colour.
    func tintedInk(_ clearness: Double) -> Color {
        self == .chrome ? ink : Theme.accentInk
    }

    static func of(_ s: String) -> ButtonLook { ButtonLook(rawValue: s) ?? .classic }
}

/// The glass itself in any shape: a body you can see through, a highlight on top, a light rim and a soft shadow.
struct GlassBody<S: InsettableShape>: View {
    let look: ButtonLook
    /// 0 = solid body, 1 = almost only the rim and the highlight are left.
    let clearness: Double
    let shape: S
    var tint: Color?
    var pressed = false
    @Environment(\.accessibilityReduceTransparency) private var solid

    /// How much of the body is seen.
    private var seen: Double { solid ? 1 : 1 - 0.85 * min(max(clearness, 0), 1) }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let round = abs(w - h) < 2
            ZStack {
                base(w, h, round: round)
                // the highlight on the upper half, like light on a curved glass
                let light = LinearGradient(colors: [.white.opacity(look == .chrome ? 0.9 : 0.55), .white.opacity(0)], startPoint: .top, endPoint: .bottom)
                Group {
                    if round {
                        Ellipse().fill(light).frame(width: w * 0.74, height: h * 0.44)
                    } else {
                        Capsule().fill(light).frame(width: max(0, w - h * 0.5), height: h * 0.46)
                    }
                }
                .opacity(pressed ? 0.35 : 1)
                .offset(y: pressed ? h * 0.24 : -h * 0.21)
                if pressed {
                    // pushed in: the upper edge falls into shade, like a dent
                    shape.fill(LinearGradient(colors: [.black.opacity(0.45), .black.opacity(0)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.6)))
                }
                // the rim: light at the top, darker at the bottom; turned over when pushed in
                shape.strokeBorder(LinearGradient(colors: pressed ? [.black.opacity(0.45), .white.opacity(0.15), .white.opacity(0.75)]
                                                                  : [.white.opacity(0.95), .white.opacity(0.2), .black.opacity(0.3)],
                                                  startPoint: .top, endPoint: .bottom),
                                   lineWidth: h > 60 ? 2.2 : h > 26 ? 1.6 : 1)
            }
            .frame(width: w, height: h)
            .clipShape(shape)
        }
        .compositingGroup()
        .shadow(color: glow, radius: pressed ? 1 : 6, y: pressed ? 0.5 : 4)
    }

    /// A coloured button glows in its colour, the others cast a plain shadow; pushed in, almost none.
    private var glow: Color {
        if pressed { return .black.opacity(0.1) }
        if let tint { return tint.opacity(0.6) }
        return .black.opacity(0.18 + 0.22 * seen)
    }

    @ViewBuilder private func base(_ w: CGFloat, _ h: CGFloat, round: Bool) -> some View {
        switch look {
        case .chrome:
            let metal = [Color(white: 0.98), Color(white: 0.8), Color(white: 0.42)]
            ZStack {
                shape.fill(.ultraThinMaterial)
                Group {
                    if round {
                        shape.fill(RadialGradient(colors: metal, center: UnitPoint(x: 0.5, y: 0.28), startRadius: 0, endRadius: h * 0.7))
                    } else {
                        shape.fill(LinearGradient(colors: [Color(white: 0.96), Color(white: 0.84), Color(white: 0.6)], startPoint: .top, endPoint: .bottom))
                    }
                }
                .opacity(seen)
                if let tint { shape.fill(tint.opacity(0.4 * seen + 0.25)) }
            }
        case .frosted:
            ZStack {
                shape.fill(.thickMaterial).opacity(0.3 + 0.7 * seen)
                shape.fill((tint ?? .white).opacity(tint == nil ? 0.12 * seen : 0.55 + 0.4 * seen))
            }
        case .glass, .classic:
            ZStack {
                shape.fill(.ultraThinMaterial).opacity(seen)
                shape.fill((tint ?? .white).opacity(tint == nil ? 0.08 + 0.1 * seen : 0.55 + 0.4 * seen))
            }
        }
    }
}

/// A round convex button face with its label on top.
struct Orb<Label: View>: View {
    let look: ButtonLook
    let clearness: Double
    let size: CGFloat
    var tint: Color?
    var pressed = false
    let label: Label

    init(look: ButtonLook, clearness: Double, size: CGFloat, tint: Color? = nil, pressed: Bool = false, @ViewBuilder label: () -> Label) {
        self.look = look
        self.clearness = clearness
        self.size = size
        self.tint = tint
        self.pressed = pressed
        self.label = label()
    }

    var body: some View {
        label
            .shadow(color: .black.opacity(0.22), radius: 0.8, y: 0.8)
            .frame(width: size, height: size)
            .background(GlassBody(look: look, clearness: clearness, shape: Circle(), tint: tint, pressed: pressed))
            .scaleEffect(pressed ? 0.9 : 1)
            .offset(y: pressed ? 1.5 : 0)
            .brightness(pressed ? -0.05 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressed)
    }
}

/// A button whose press is always seen. The swipe-up gesture around the player buttons holds the touch back
/// until the finger lifts, so the button is "pressed" only for an instant: a tap keeps it pushed in a little longer.
struct Pressable<Content: View>: View {
    let action: () -> Void
    let content: (_ pulse: Bool, _ action: @escaping () -> Void) -> Content
    @State private var pulse = false
    @State private var release: Task<Void, Never>?

    init(action: @escaping () -> Void, @ViewBuilder content: @escaping (_ pulse: Bool, _ action: @escaping () -> Void) -> Content) {
        self.action = action
        self.content = content
    }

    var body: some View {
        content(pulse) {
            pulse = true
            action()
            release?.cancel()
            release = Task {
                try? await Task.sleep(for: .milliseconds(200))
                if !Task.isCancelled { pulse = false }
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
    var pulse = false

    func makeBody(configuration: Configuration) -> some View {
        Orb(look: look, clearness: clearness, size: size, tint: tint, pressed: configuration.isPressed || pulse) { configuration.label }
            .contentShape(Circle())
    }
}

/// The usual system glass, or our convex glass when the player buttons are glass.
struct PlayerGlass<S: InsettableShape>: ViewModifier {
    @EnvironmentObject private var settings: Settings
    let shape: S
    var tint: Color?

    func body(content: Content) -> some View {
        let look = ButtonLook.of(settings.v.buttons)
        if look == .classic {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(GlassBody(look: look, clearness: settings.v.glass, shape: shape, tint: tint))
        }
    }
}

/// The press of a menu bar item: it dims, and on glass a dent appears under it.
struct DimPress: ButtonStyle {
    var look = ButtonLook.classic
    var pulse = false

    func makeBody(configuration: Configuration) -> some View {
        let p = configuration.isPressed || pulse, glass = look != .classic
        configuration.label
            .background {
                if p && glass {
                    Circle()
                        .fill(LinearGradient(colors: [.black.opacity(0.35), .white.opacity(0.12)], startPoint: .top, endPoint: .bottom))
                        .overlay(Circle().strokeBorder(LinearGradient(colors: [.black.opacity(0.35), .white.opacity(0.55)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                        .frame(width: 42, height: 42)
                }
            }
            .opacity(p && !glass ? 0.55 : 1)
            .scaleEffect(p ? 0.9 : 1)
            .offset(y: p && glass ? 1 : 0)
            .animation(.easeOut(duration: 0.12), value: p)
    }
}

/// A glass pill that sinks in when pressed: the A–B button.
struct GlassPillStyle: ButtonStyle {
    let look: ButtonLook
    let clearness: Double
    var tint: Color?
    var pulse = false

    func makeBody(configuration: Configuration) -> some View {
        let p = configuration.isPressed || pulse
        configuration.label
            .background(GlassBody(look: look, clearness: clearness, shape: Capsule(), tint: tint, pressed: p))
            .scaleEffect(p ? 0.92 : 1)
            .offset(y: p ? 1 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: p)
            .contentShape(Capsule())
    }
}
