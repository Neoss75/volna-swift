import AVKit
import SwiftUI

/// The system list of AirPlay speakers, TVs and Bluetooth headphones.
struct AirPlayButton: UIViewRepresentable {
    var tint: UIColor
    var active: UIColor

    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.prioritizesVideoDevices = false
        v.backgroundColor = .clear
        update(v)
        return v
    }

    func updateUIView(_ v: AVRoutePickerView, context: Context) { update(v) }

    private func update(_ v: AVRoutePickerView) {
        v.tintColor = tint
        v.activeTintColor = active
    }
}
