import SwiftUI

/// Colours of the web version of «Волна» (dark theme), accent is amber #f5a524.
enum Theme {
    static let bg = Color(hex: 0x11131A)
    static let surface = Color(hex: 0x191C25)
    static let raise = Color(hex: 0x232736)
    static let line = Color(hex: 0x30364A)
    static let fg = Color(hex: 0xECE9E2)
    static let muted = Color(hex: 0x959CAE)
    static let accent = Color(hex: 0xF5A524)
    static let accentInk = Color(hex: 0x1D1405)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// 3:07, 1:02:15
func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds > 0 else { return "0:00" }
    let t = Int(seconds.rounded(.down))
    let h = t / 3600, m = (t % 3600) / 60, s = t % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}
