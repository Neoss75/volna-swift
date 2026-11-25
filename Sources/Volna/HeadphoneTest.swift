#if DEBUG
import AVFoundation
import Foundation

extension Demo {
    /// Plays one click through the equaliser and looks at what comes out, frequency by frequency.
    private static func measure(_ p: HeadphoneProfile, rate: Double, at list: [Double]) -> [Double]? {
        let engine = AVAudioEngine(), node = AVAudioPlayerNode(), eq = AVAudioUnitEQ(numberOfBands: HeadphoneProfile.maxFilters)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1), let click = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000),
              let part = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else { return nil }
        engine.attach(node)
        engine.attach(eq)
        engine.connect(node, to: eq, format: format)
        engine.connect(eq, to: engine.mainMixerNode, format: format)
        eq.load(p)
        eq.bypass = false
        click.frameLength = 48000
        for i in 0..<48000 { click.floatChannelData?[0][i] = 0 }
        click.floatChannelData?[0][2000] = 0.25
        var out: [Float] = []
        do {
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
            try engine.start()
            node.scheduleBuffer(click, at: nil)
            node.play()
            while out.count < 40960 {
                guard try engine.renderOffline(4096, to: part) == .success, let d = part.floatChannelData else { break }
                out += UnsafeBufferPointer(start: d[0], count: Int(part.frameLength))
            }
        } catch { return nil }
        engine.stop()
        guard out.count > 20000 else { return nil }
        return list.map { f in
            var re = 0.0, im = 0.0
            for (i, x) in out.enumerated() where x != 0 {
                let a = 2 * .pi * f * Double(i) / rate
                re += Double(x) * cos(a)
                im -= Double(x) * sin(a)
            }
            return 10 * log10(max(re * re + im * im, 1e-12)) - 20 * log10(0.25)
        }
    }

    static func headphoneTest(_ player: Player, _ settings: Settings, _ headphones: Headphones,
                              _ check: (String, Bool, String) -> Void, _ wait: (Double) async -> Void) async {
        let t0 = Date(), count = HeadphoneBase.all.count
        check("headphone models", count > 6000 && Date().timeIntervalSince(t0) < 3, "\(count) in " + String(format: "%.2f s", Date().timeIntervalSince(t0)))
        let t1 = Date(), redmi = HeadphoneBase.guess("Redmi Buds 6 Pro"), pods = HeadphoneBase.guess("AirPods Pro (Андрей )")
        check("guess the model", redmi.count == 3 && redmi.allSatisfy { $0.name.hasPrefix("Redmi Buds 6 Pro") } && pods.first?.name == "Apple AirPods Pro",
              "\(redmi.map(\.name)) \(pods.map(\.name)) " + String(format: "%.2f s", Date().timeIntervalSince(t1)))
        check("search of models", HeadphoneBase.search("xm4 sony").contains { $0.name == "Sony WH-1000XM4" } && HeadphoneBase.search("zzzz").isEmpty, HeadphoneBase.search("sony xm4").first?.name ?? "")
        let text = "Preamp: -5.8 dB\nFilter 1: ON LSC Fc 105 Hz Gain 3.6 dB Q 0.70\nFilter 2: ON PK Fc 931 Hz Gain -1.8 dB Q 0.18\nFilter 3: OFF PK Fc 1 Hz Gain 1 dB Q 1\n"
        let file = HeadphoneProfile(text: text, name: "F")
        check("profile from a file", file?.preamp == -5.8 && file?.filters == [EQFilter(kind: .low, hz: 105, db: 3.6, q: 0.7), EQFilter(kind: .peak, hz: 931, db: -1.8, q: 0.18)]
            && HeadphoneProfile(text: "hello", name: "") == nil, "")

        // is the sound what the curve promises?
        let points: [Double] = [30, 60, 105, 200, 400, 700, 1000, 1500, 2300, 3400, 5000, 6500, 8000, 10000, 12000, 15000]
        let single = [EQFilter(kind: .peak, hz: 1000, db: 6, q: 1), EQFilter(kind: .peak, hz: 6500, db: 6, q: 1.2), EQFilter(kind: .peak, hz: 900, db: -5, q: 0.2),
                      EQFilter(kind: .low, hz: 105, db: 6, q: 0.7), EQFilter(kind: .high, hz: 10000, db: 6, q: 0.7)]
        for f in single {
            let p = HeadphoneProfile(name: "", filters: [f])
            let got = measure(p, rate: 48000, at: points) ?? []
            let off = zip(points, got).map { $1 - f.response($0) }
            NSLog("SELFTEST filter %@ %g Hz Q %g: %@", f.kind.rawValue, f.hz, f.q, off.map { String(format: "%+.1f", $0) }.joined(separator: " "))
        }
        for m in [redmi.first, pods.first].compactMap({ $0 }) {
            let p = m.profile
            for rate in [44100.0, 48000] {
                let got = measure(p, rate: rate, at: points) ?? []
                let off = zip(points, got).map { $1 - p.response($0) }
                let worst = off.map { abs($0) }.max() ?? 99
                check("sound of «\(m.name)» \(Int(rate))", worst < 1.5 && got.count == points.count, off.map { String(format: "%+.1f", $0) }.joined(separator: " "))
            }
        }

        Headphones.fake = (.bluetoothA2DP, "AirPods Pro (Андрей )", "AA:BB-tacl")
        headphones.look()
        check("headphones connected", headphones.current.name == "AirPods Pro (Андрей )" && headphones.active == nil && !player.graph.correctionOn, headphones.current.id)
        if let m = pods.first { headphones.assign(headphones.add(m.profile), to: headphones.current.id) }
        check("profile chosen", headphones.active?.name == "Apple AirPods Pro" && player.graph.correctionOn, headphones.active?.name ?? "")
        let first = SoundPath.now(player, settings).steps.map(\.value).joined(separator: " ")
        check("profile in the sound path", first.contains("Apple AirPods Pro"), "")
        Headphones.fake = (.bluetoothA2DP, "Redmi Buds 6 Pro", "CC:DD-tacl")
        headphones.look()
        check("other headphones have no profile", headphones.active == nil && !player.graph.correctionOn, headphones.current.name)
        if let m = redmi.first { headphones.assign(headphones.add(m.profile), to: headphones.current.id) }
        Headphones.fake = (.bluetoothA2DP, "AirPods Pro (Андрей )", "AA:BB-tacl")
        headphones.look()
        check("profile follows the device", headphones.active?.name == "Apple AirPods Pro" && player.graph.correctionOn, headphones.active?.name ?? "")
        settings.v.direct = true
        let bypassed = !player.graph.correctionOn
        settings.v.direct = false
        check("direct output has no profile", bypassed && player.graph.correctionOn, "")
        headphones.turn(false)
        check("profile switched off", !player.graph.correctionOn && headphones.chosen != nil, "")
        headphones.turn(true)
        headphones.write()
        let again = Headphones()
        check("profiles are saved", again.data.profiles.count == 2 && again.active?.name == "Apple AirPods Pro" && again.data.devices.count == 2, "\(again.data.devices.map(\.name))")
        for p in headphones.data.profiles { headphones.remove(p.id) }
        check("profile removed", headphones.data.profiles.isEmpty && !player.graph.correctionOn && headphones.active == nil, "")
        Headphones.fake = nil
        for d in headphones.data.devices { headphones.forget(d.id) }
        headphones.look()
    }
}
#endif
