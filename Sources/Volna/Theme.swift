import SwiftUI
import UIKit

/// Colours of the web version of «Волна», dark and light.
enum Theme {
    static let bg = dynamic(light: 0xECEEF3, dark: 0x11131A)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x191C25)
    static let raise = dynamic(light: 0xE2E6EE, dark: 0x232736)
    static let line = dynamic(light: 0xCFD5E0, dark: 0x30364A)
    static let fg = dynamic(light: 0x161922, dark: 0xECE9E2)
    static let muted = dynamic(light: 0x566074, dark: 0x959CAE)
    static let danger = dynamic(light: 0xC23A2B, dark: 0xFF8070)
    static let accentInk = dynamic(light: 0xFFFFFF, dark: 0x15120B)

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .light ? UIColor(hex: light) : UIColor(hex: dark) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    /// CSS hsl(): h in degrees, s and l in 0…1
    init(h: Double, s: Double, l: Double) {
        let v = l + s * min(l, 1 - l)
        let sv = v == 0 ? 0 : 2 * (1 - l / v)
        self.init(hue: h.truncatingRemainder(dividingBy: 360) / 360, saturation: sv, brightness: v)
    }
}

struct Accent: Identifiable {
    let id: String
    let name: String
    let color: Color

    static let all: [Accent] = [
        Accent(id: "amber", name: "Янтарь", color: Theme.dynamic(light: 0xB56B00, dark: 0xFFB547)),
        Accent(id: "mint", name: "Мята", color: Theme.dynamic(light: 0x0B7F5A, dark: 0x5FDCAE)),
        Accent(id: "coral", name: "Коралл", color: Theme.dynamic(light: 0xC0442A, dark: 0xFF8F70)),
        Accent(id: "lavender", name: "Лаванда", color: Theme.dynamic(light: 0x6A4FD0, dark: 0xB9A3FF)),
        Accent(id: "sky", name: "Небо", color: Theme.dynamic(light: 0x1B6FAA, dark: 0x6CC6FF)),
        Accent(id: "rose", name: "Роза", color: Theme.dynamic(light: 0xB82D63, dark: 0xFF82B2)),
    ]
}

extension Font {
    /// Wide headings, like Unbounded in the web version.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight).width(.expanded)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// 3:07
func formatTime(_ seconds: Double?) -> String {
    guard let s = seconds, s.isFinite, s >= 0 else { return "–:––" }
    let t = Int(s)
    return "\(t / 60):" + String(format: "%02d", t % 60)
}

func formatDb(_ v: Double) -> String {
    (v > 0 ? "+" : "") + String(format: "%.1f", v) + " дБ"
}

func formatSpan(_ seconds: Double) -> String {
    let s = Int(seconds.rounded()), h = s / 3600, m = s % 3600 / 60
    if h > 0 { return "\(h) ч \(m) мин" }
    return m > 0 ? "\(m) мин" : "\(s) с"
}

func pluralWord(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
    let m = n % 10, h = n % 100
    if m == 1, h != 11 { return one }
    return (2...4).contains(m) && !(12...14).contains(h) ? few : many
}

func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
    "\(n) " + pluralWord(n, one, few, many)
}

func hue(_ s: String) -> Double {
    var h: UInt32 = 0
    for c in s.unicodeScalars { h = (h * 31 + c.value) % 360 }
    return Double(h)
}

/// Short messages at the bottom of the screen, optionally with an "undo" button.
@MainActor
final class Toaster: ObservableObject {
    static let shared = Toaster()

    struct Message: Identifiable {
        let id = UUID()
        let text: String
        var action: String?
        var run: (() -> Void)?
    }

    @Published private(set) var message: Message?

    func show(_ text: String, action: String? = nil, run: (() -> Void)? = nil) {
        let m = Message(text: text, action: action, run: run)
        message = m
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(run == nil ? 2.6 : 6))
            if self?.message?.id == m.id { self?.message = nil }
        }
    }

    func dismiss() { message = nil }
}

@MainActor
func toast(_ text: String) { Toaster.shared.show(text) }
