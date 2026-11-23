#if DEBUG
import AVFoundation
import SwiftUI

/// Only in test builds: makes a few sound files and opens the screen named on the command line,
/// so the cloud Mac can check the app and take screenshots. Not part of the TestFlight build.
@MainActor
enum Demo {
    static func run(library: Library, player: Player, settings: Settings, ui: UIState) async {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-demo") else { return }
        func value(_ name: String) -> String? {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        settings.v.onlineArt = false
        if library.tracks.isEmpty {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let specs: [(String, Double, Int, Double)] = [
                ("Океан Ельзи - Обійми", 44100, 2, 24), ("Хіти - Бас і біт", 48000, 2, 14), ("The Kolors - ITALODISCO", 32000, 1, 14),
                ("01. Свип", 96000, 2, 10),
            ]
            var urls: [URL] = []
            for s in specs {
                let url = dir.appendingPathComponent(s.0 + ".wav")
                synth(url, rate: s.1, channels: s.2, seconds: s.3)
                urls.append(url)
            }
            let lrc = dir.appendingPathComponent("Океан Ельзи - Обійми.lrc")
            try? "[00:00.00]Перший рядок\n[00:03.00]Другий рядок тексту\n[00:06.00]Третій рядок\n[00:09.00]Четвертий".write(to: lrc, atomically: true, encoding: .utf8)
            await library.add(urls: urls + [lrc])
        }
        if let m = value("-viz").flatMap(VizMode.init(rawValue:)) { settings.v.viz = m }
        if let t = value("-theme") { settings.v.themeMode = t }
        settings.v.lyricsOn = args.contains("-lyrics")
        if args.contains("-selftest") {
            await selfTest(library: library, player: player, settings: settings)
            return
        }
        if let first = library.tracks.first { player.play(first.id, from: library.tracks.map(\.id)) }
        if args.contains("-eqrock") { settings.v.bands = EQPreset.all[2].bands }
        try? await Task.sleep(for: .seconds(1))
        if let p = value("-panel").flatMap(Panel.init(rawValue:)) { ui.panel = p }
        if let page = value("-page").flatMap(SettingsPage.init(rawValue:)) { ui.settingsPath = [page] }
    }

    private static func selfTest(library: Library, player: Player, settings: Settings) async {
        func log(_ s: String) { NSLog("SELFTEST %@", s) }
        func check(_ name: String, _ ok: Bool, _ info: String = "") { log((ok ? "ok   " : "FAIL ") + name + " " + info) }
        func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
        let ids = library.tracks.map(\.id)
        check("library", ids.count == 4, "\(ids.count)")
        settings.v.crossfade = 0
        for (i, id) in ids.enumerated() {
            player.play(id, from: ids)
            await wait(2)
            check("play \(i)", player.isPlaying && player.position > 1 && player.position < 3, String(format: "%.2f of %.2f", player.position, player.duration))
        }
        player.play(ids[0], from: ids)
        await wait(0.5)
        player.seek(to: 10)
        await wait(1)
        check("seek", abs(player.position - 11) < 0.6, String(format: "%.2f", player.position))
        player.pause()
        let p = player.position
        await wait(1)
        check("pause keeps position", abs(player.position - p) < 0.01 && !player.isPlaying)
        player.resume()
        await wait(1)
        check("resume", abs(player.position - p - 1) < 0.6, String(format: "%.2f after %.2f", player.position, p))
        settings.v.rate = 1.5
        let r = player.position
        await wait(2)
        check("speed 1.5", abs(player.position - r - 3) < 0.8, String(format: "%.2f", player.position - r))
        settings.v.rate = 1
        settings.v.crossfade = 3
        player.seek(to: player.duration - 4)
        await wait(2.5)
        check("crossfade started", player.qi == 1 && player.isPlaying, "qi \(player.qi)")
        await wait(4)
        check("crossfade finished", player.qi == 1 && player.position > 4, String(format: "%.2f", player.position))
        settings.v.crossfade = 0
        player.seek(to: player.duration - 1)
        await wait(2.5)
        check("auto next", player.qi == 2 && player.isPlaying, "qi \(player.qi)")
        player.toggleShuffle()
        check("shuffle keeps song", player.current?.id == ids[2] && player.qi == 0)
        player.toggleShuffle()
        check("unshuffle", player.queue == ids && player.qi == 2)
        let t0 = Date()
        for t in library.tracks { player.analyzer.request(t, first: false) }
        while library.tracks.contains(where: { $0.wave == nil }), Date().timeIntervalSince(t0) < 60 { await wait(0.5) }
        log(String(format: "waveforms took %.1f s more", Date().timeIntervalSince(t0)))
        check("waveforms", library.tracks.allSatisfy { ($0.wave?.count ?? 0) == 180 && ($0.wave?.max() ?? 0) == 100 }, "\(library.tracks.map { $0.gainDb ?? 99 })")
        player.seek(to: 1)
        player.play(ids[0], from: ids)
        await wait(1.5)
        let a = SpectrumAnalyzer()
        for _ in 0..<20 { a.update(player.graph.tap); await wait(0.03) }
        check("visualizer sees sound", (a.bins.max() ?? 0) > 0.2, "\(a.bins.max() ?? 0)")
        check("lyrics file", LyricsStore.load(ids[0]).map { LyricsParser.lines($0.text)?.count == 4 } ?? false)
        check("title cleaning", TagCleaner.clean("Пелюстки троянд (Sefon.Pro)") == "Пелюстки троянд" && TagCleaner.clean("Muzaf.net") == "Muzaf.net"
            && TagCleaner.clean("Mr. Vain") == "Mr. Vain", TagCleaner.clean("Слава Україні 2022 (Muzaf.net)"))
        check("cover reading", SongReading.all(library.tracks[2]).first?.artist == "The Kolors", "\(SongReading.all(library.tracks[2]))")
        library.toggleFavourite(ids[0])
        library.createPlaylist("Тест", with: [ids[0], ids[1]])
        library.remove([ids[0]])
        check("remove playing song", player.current == nil && !player.isPlaying && library.tracks.count == 3)
        await wait(1)
        player.play(ids[1], from: [ids[1], ids[2]])
        await wait(1)
        check("plays after removal", player.isPlaying && player.position > 0.4)
        log("done")
    }

    private static func synth(_ url: URL, rate: Double, channels: Int, seconds: Double) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: AVAudioChannelCount(channels)) else { return }
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: channels,
                                       AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
        let n = AVAudioFrameCount(rate * seconds)
        guard let file = try? AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n), let data = buffer.floatChannelData else { return }
        buffer.frameLength = n
        let notes = [220.0, 261.6, 329.6, 440, 523.3, 659.3]
        for i in 0..<Int(n) {
            let t = Double(i) / rate
            let note = notes[Int(t * 4) % notes.count]
            let env = exp(-3 * (t * 4).truncatingRemainder(dividingBy: 1)) * (0.5 + 0.5 * abs(sin(t / 2)))
            var s = 0.0
            for h in 1...6 { s += sin(2 * .pi * note * Double(h * h) * t) / Double(h) }
            for c in 0..<channels { data[c][i] = Float(s * env * 0.3) }
        }
        try? file.write(from: buffer)
    }
}
#endif
