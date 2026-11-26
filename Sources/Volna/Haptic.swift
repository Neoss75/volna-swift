import UIKit

/// A light touch of the phone under the finger; switched off in the settings.
@MainActor
enum Haptic {
    static var on = true

    static func tap() {
        guard on else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func liked(_ yes: Bool) {
        guard on else { return }
        if yes {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
}
