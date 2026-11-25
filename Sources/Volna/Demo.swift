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
        settings.v.saverOn = false
        settings.v.vizPalette = value("-colors").flatMap(VizColors.init(rawValue:)) ?? .accent
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
        if args.contains("-folder"), library.folders.isEmpty {
            await library.add(urls: [makeFolder()])
            if let t = library.tracks.first { library.edit(t.id, title: t.title, artist: t.artist, album: "Земля") }
        }
        if args.contains("-lossless"), let t = await addFormats(library).first {
            settings.v.direct = true
            settings.v.matchRate = true
            ui.collection = .lossless
            player.play(t.id, from: library.tracks.map(\.id))
        }
        if let t = value("-tab") { ui.listTab = ListTab.allCases.first { "\($0)" == t } ?? .songs }
        if args.contains("-album"), let t = library.tracks.first(where: { !$0.album.isEmpty }) { ui.collection = .album(Library.albumKey(t)) }
        if args.contains("-selftest") {
            await selfTest(library: library, player: player, settings: settings, ui: ui)
            return
        }
        if !args.contains("-lossless"), let first = library.tracks.first { player.play(first.id, from: library.tracks.map(\.id)) }
        if args.contains("-eqrock") { settings.v.bands = EQPreset.all[2].bands }
        if args.contains("-landscape"), let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
        }
        try? await Task.sleep(for: .seconds(1))
        if let p = value("-panel").flatMap(Panel.init(rawValue:)) { ui.panel = p }
        if args.contains("-saver") { ui.saver = true }
        if let page = value("-page").flatMap(SettingsPage.init(rawValue:)) { ui.settingsPath = [page] }
    }

    private static func selfTest(library: Library, player: Player, settings: Settings, ui: UIState) async {
        func log(_ s: String) { NSLog("SELFTEST %@", s) }
        func check(_ name: String, _ ok: Bool, _ info: String) { log((ok ? "ok   " : "FAIL ") + name + " " + info) }
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
        check("pause keeps position", abs(player.position - p) < 0.01 && !player.isPlaying, "")
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
        check("shuffle keeps song", player.current?.id == ids[2] && player.qi == 0, "")
        player.toggleShuffle()
        check("unshuffle", player.queue == ids && player.qi == 2, "")
        await wait(4)
        player.previousTrack()
        await wait(0.5)
        check("previous song", player.qi == 1 && player.isPlaying && player.position < 2, "qi \(player.qi)")
        player.play(ids[0], from: ids)
        await wait(1.5)
        player.previousTrack()
        await wait(0.5)
        check("first song goes on", player.qi == 0 && player.isPlaying && player.position > 1.5, String(format: "qi %d at %.2f", player.qi, player.position))
        player.previous()
        await wait(0.5)
        check("button restarts the first", player.qi == 0 && player.isPlaying && player.position < 1.5, String(format: "qi %d at %.2f", player.qi, player.position))
        player.cycleRepeat()
        player.previousTrack()
        await wait(0.5)
        check("previous of the first, repeat all", player.qi == ids.count - 1 && player.isPlaying, "qi \(player.qi)")
        player.cycleRepeat()
        player.cycleRepeat()
        player.next()
        await wait(0.5)
        check("next of the last", player.qi == 0 && player.isPlaying, "qi \(player.qi)")
        player.play(ids[2], from: ids)
        await wait(0.5)
        let t0 = Date()
        for t in library.tracks { player.analyzer.request(t, first: false) }
        while library.tracks.contains(where: { $0.wave == nil }), Date().timeIntervalSince(t0) < 60 { await wait(0.5) }
        log(String(format: "waveforms took %.1f s more", Date().timeIntervalSince(t0)))
        check("widget data", WidgetState.load().title == player.current?.title && WidgetState.load().playing, WidgetState.folder == nil ? "no app group" : "\(WidgetState.load())")
        PlayerBridge.toggle?()
        check("widget button", !player.isPlaying && !WidgetState.load().playing, "")
        PlayerBridge.toggle?()
        check("waveforms", library.tracks.allSatisfy { ($0.wave?.count ?? 0) == 180 && ($0.wave?.max() ?? 0) == 100 }, "\(library.tracks.map { $0.gainDb ?? 99 })")
        player.seek(to: 1)
        player.play(ids[0], from: ids)
        await wait(1.5)
        let a = SpectrumAnalyzer()
        for _ in 0..<20 { a.update(player.graph.tap); await wait(0.03) }
        check("visualizer sees sound", (a.bins.max() ?? 0) > 0.2, "\(a.bins.max() ?? 0)")
        check("lyrics file", LyricsStore.load(ids[0]).map { LyricsParser.lines($0.text)?.count == 4 } ?? false, "")
        check("title cleaning", TagCleaner.clean("Пелюстки троянд (Sefon.Pro)") == "Пелюстки троянд" && TagCleaner.clean("Muzaf.net") == "Muzaf.net"
            && TagCleaner.clean("Mr. Vain") == "Mr. Vain", TagCleaner.clean("Слава Україні 2022 (Muzaf.net)"))
        check("cover reading", SongReading.all(library.tracks[2]).first?.artist == "The Kolors", "\(SongReading.all(library.tracks[2]))")
        library.toggleFavourite(ids[0])
        library.createPlaylist("Тест", with: [ids[0], ids[1]])
        library.remove([ids[0]])
        check("remove playing song", player.current == nil && !player.isPlaying && library.tracks.count == 3, "")
        await wait(1)
        player.play(ids[1], from: [ids[1], ids[2]])
        await wait(1)
        check("plays after removal", player.isPlaying && player.position > 0.4, "")
        await folderTest(library, player, settings, check, wait)
        let formats = await addFormats(library)
        check("formats added", formats.map(\.kind) == ["FLAC", "ALAC", "M4A"], "\(formats.map(\.formatLine))")
        check("lossless mark", formats.map(\.isLossless) == [true, true, false], "\(formats.map { $0.bits ?? 0 })")
        // iOS does not report the bit depth of a FLAC file, so the header reading is checked on known headers
        for (bytes, rate, bits) in [([0x0A, 0xC4, 0x42, 0xF0] as [UInt8], 44100.0, 16), ([0x17, 0x70, 0x03, 0x70], 96000, 24)] {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("header.flac")
            try? Data(Array("fLaC".utf8) + [0x80, 0, 0, 34] + [UInt8](repeating: 0, count: 10) + bytes + [UInt8](repeating: 0, count: 20)).write(to: url)
            let h = MetadataReader.header(of: url)
            check("FLAC header \(bits)", h.bits == bits && h.sampleRate == rate, "\(h.bits ?? 0) \(h.sampleRate ?? 0)")
        }
        check("lossless list", library.songs(in: .lossless, stats: Stats()).count == library.tracks.count - 1, "")
        for t in formats {
            player.play(t.id, from: formats.map(\.id))
            await wait(2)
            check("play " + t.kind, player.isPlaying && player.position > 1 && player.position < 3, String(format: "%.2f of %.2f", player.position, player.duration))
        }
        if let long = library.tracks.max(by: { $0.duration < $1.duration }) { player.play(long.id, from: [long.id]) }
        settings.v.saverOn = true
        settings.v.saver = 2
        await wait(1.5)
        ui.touch(true)
        ui.touch(false)
        await wait(1.2)
        check("screensaver waits after a touch", !ui.saver && player.isPlaying, "")
        await wait(1.5)
        check("screensaver starts", ui.saver, "")
        player.pause()
        await wait(0.5)
        check("screensaver closes on pause", !ui.saver, "")
        player.resume()
        ui.panel = .eq
        await wait(3)
        check("no screensaver over a panel", !ui.saver && player.isPlaying, "")
        ui.panel = nil
        settings.v.saverOn = false
        settings.v.saver = 10
        await wait(1)
        check("screensaver can be switched off", !ui.saver, "")
        player.cycleRepeat()
        player.cycleRepeat() // the same song again and again, so that there is always sound
        player.seek(to: 0)
        player.resume()
        for m in VizMode.allCases where m != .off {
            settings.v.saverViz = m
            ui.saver = true
            await wait(0.3)
            let f = VizState.frames, t = Date()
            await wait(1.2)
            if !player.isPlaying { log("silence!") }
            log(String(format: "frames per second %.0f ", Double(VizState.frames - f) / Date().timeIntervalSince(t)) + m.rawValue)
            ui.saver = false
        }
        settings.v.saverViz = .off
        settings.v.viz = .ring
        await wait(0.3)
        let f = VizState.frames, t1 = Date()
        await wait(1.5)
        log(String(format: "frames per second %.0f ring on the main screen", Double(VizState.frames - f) / Date().timeIntervalSince(t1)))
        settings.v.viz = .bars
        log("done")
    }

    /// The same sound as FLAC, Apple Lossless and AAC.
    private static func addFormats(_ library: Library) async -> [Track] {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let specs = [("Формат один.flac", kAudioFormatFLAC), ("Формат два.m4a", kAudioFormatAppleLossless), ("Формат три.m4a", kAudioFormatMPEG4AAC)]
        let urls = specs.map { s in
            let url = dir.appendingPathComponent(s.0)
            synth(url, rate: 44100, channels: 2, seconds: 8, format: s.1)
            return url
        }
        await library.add(urls: urls)
        return urls.compactMap { u in library.tracks.first { $0.fileName == u.lastPathComponent } }
    }

    private static func makeFolder() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Концерт", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir.appendingPathComponent("CD 2"), withIntermediateDirectories: true)
        synth(dir.appendingPathComponent("01 Перша.wav"), rate: 44100, channels: 2, seconds: 7)
        synth(dir.appendingPathComponent("02 Друга.wav"), rate: 44100, channels: 2, seconds: 7)
        synth(dir.appendingPathComponent("CD 2/01 Третя.wav"), rate: 44100, channels: 2, seconds: 7)
        return dir
    }

    private static func folderTest(_ library: Library, _ player: Player, _ settings: Settings,
                                   _ check: (String, Bool, String) -> Void, _ wait: (Double) async -> Void) async {
        let before = library.tracks.count
        let dir = makeFolder()
        await library.add(urls: [dir])
        let ids = library.tracks.filter { $0.folderID != nil }.map(\.id)
        check("folder added", ids.count == 3 && library.tracks.count == before + 3, "\(ids.count)")
        check("folder labels", library.track(ids.last)?.folder == "Концерт / CD 2" && library.track(ids.first)?.album == "Концерт", library.track(ids.last)?.folder ?? "")

        settings.v.gapless = true
        player.play(ids[0], from: ids)
        await wait(1)
        player.seek(to: 5)
        await wait(4)
        check("gapless", player.qi == 1 && player.isPlaying && abs(player.position - 2) < 0.35, String(format: "qi %d at %.2f", player.qi, player.position))
        await wait(1)
        player.toggleShuffle()
        player.toggleShuffle()
        check("order change keeps playing", player.isPlaying && player.qi == 1 && abs(player.position - 3) < 0.5, String(format: "%.2f", player.position))
        await wait(5.5)
        check("goes on after order change", player.qi == 2 && player.isPlaying, "qi \(player.qi)")
        player.cycleRepeat()
        player.cycleRepeat()
        await wait(7)
        check("repeat one", player.qi == 2 && player.isPlaying && player.position < 6, String(format: "qi %d at %.2f", player.qi, player.position))
        player.cycleRepeat()

        settings.v.direct = true
        let d = player.position
        player.seek(to: 1)
        await wait(1)
        check("direct output plays", player.isPlaying && player.position > 1.5, String(format: "%.2f (was %.2f)", player.position, d))
        settings.v.direct = false
        player.pause()
        player.graph.engine.stop()
        player.graph.rebuild(rate: 96000)
        try? player.graph.engine.start()
        player.resume()
        await wait(1)
        check("plays at 96 kHz output", player.isPlaying && player.position > 2, String(format: "%.2f", player.position))
        player.pause()
        player.resume()
        await wait(1)
        check("plays after the output goes back", player.isPlaying && player.position > 2.7, String(format: "%.2f", player.position))

        library.remove([ids[1]])
        synth(dir.appendingPathComponent("03 Нова.wav"), rate: 44100, channels: 2, seconds: 3)
        await library.refreshFolders(quiet: true)
        let now = library.tracks.filter { $0.folderID != nil }
        check("folder refresh", now.count == 3 && now.contains { $0.title.contains("Нова") } && !now.contains { $0.title.contains("Друга") }, "\(now.map(\.title))")
        library.edit(ids[0], title: "Моя назва", artist: "Я", album: "Мій альбом")
        check("edit", library.track(ids[0])?.title == "Моя назва", "")
        await library.restoreTags(ids[0])
        check("restore tags", library.track(ids[0])?.title == "Перша", library.track(ids[0])?.title ?? "")
        let stats = Stats()
        check("album list", library.songs(in: .album("концерт"), stats: stats).count == 2, "\(library.songs(in: .album("концерт"), stats: stats).map(\.title))")
        check("recent", library.songs(in: .recent, stats: stats).first?.title.contains("Нова") == true, "")
        // a library saved by build 7 has none of the newer fields
        let old = #"[{"id":"6C9A3A52-1111-4222-8333-944455556666","bookmark":"AAAA","path":"/a/b.mp3","title":"T","artist":"A","album":"","duration":10,"hasArtwork":false}]"#
        check("hi-res mark", library.tracks.contains { $0.isHiRes && $0.sampleRate == 96000 } && library.tracks.filter(\.isHiRes).count == 1, "")
        let pairs: [(String, String, String, String)] = [
            ("The Kolors - ITALODISCO", "", "ITALODISCO", "The Kolors"),
            ("Bakhtin - Целовала", "Хиты 2025", "Целовала", "Bakhtin"),
            ("SAMCHUK - ЯКА ШИКАРНА ЛЕДІ", "SAMCHUK", "ЯКА ШИКАРНА ЛЕДІ", "SAMCHUK"),
            ("01 - Колін - Змія", "", "Змія", "Колін"),
            ("Тумани - Remix", "", "Тумани - Remix", ""),
            ("Тумани - DJ Kolin Remix 2024", "", "Тумани - DJ Kolin Remix 2024", ""),
            ("Meduza - Lose Control (Original Mix)", "", "Lose Control (Original Mix)", "Meduza"),
            ("Opus - Live is Life", "", "Live is Life", "Opus"),
            ("Обійми - Live", "Океан Ельзи", "Обійми - Live", "Океан Ельзи"),
            ("Love - Hate", "Колін", "Love - Hate", "Колін"),
            ("Тумани", "Марина і компанія", "Тумани", "Марина і компанія"),
            ("Не-беси", "", "Не-беси", ""),
        ]
        for p in pairs {
            let r = SongReading.separate(title: p.0, artist: p.1)
            check("title «\(p.0)»", r.title == p.2 && r.artist == p.3, "\(r.artist) | \(r.title)")
        }
        check("old library opens", (try? JSONDecoder().decode([Track].self, from: Data(old.utf8)))?.count == 1, "")
        let oldStats = #"{"songs":{"x":{"plays":1,"seconds":5,"title":"T","artist":"A"}},"days":{},"total":5}"#
        check("old statistics open", (try? JSONDecoder().decode(Stats.Data.self, from: Data(oldStats.utf8)))?.songs.count == 1, "")
    }

    private static func synth(_ url: URL, rate: Double, channels: Int, seconds: Double, format kind: AudioFormatID = kAudioFormatLinearPCM) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: AVAudioChannelCount(channels)) else { return }
        var settings: [String: Any] = [AVFormatIDKey: kind, AVSampleRateKey: rate, AVNumberOfChannelsKey: channels]
        if kind == kAudioFormatLinearPCM {
            settings.merge([AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]) { $1 }
        } else if kind != kAudioFormatMPEG4AAC {
            settings[AVEncoderBitDepthHintKey] = 16
        }
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
            let beat = (t * 2).truncatingRemainder(dividingBy: 1)
            let hiss = Double.random(in: -0.03...0.03) * (0.4 + 0.6 * exp(-9 * (t * 4).truncatingRemainder(dividingBy: 1)))
            let kick = 0.24 * sin(2 * .pi * 58 * t) * exp(-7 * beat)
            for c in 0..<channels { data[c][i] = Float(s * env * 0.3 * (c == 0 ? 1 : 0.7) + kick + hiss) }
        }
        try? file.write(from: buffer)
    }
}

/// The widgets drawn inside the app, only to take a picture of them.
struct WidgetGallery: View {
    @ObservedObject var player: Player

    var body: some View {
        let s = WidgetState.load(), c = WidgetState.cover()
        VStack(spacing: 30) {
            SmallWidgetView(state: s, cover: c).padding(16).frame(width: 170, height: 170).background(widgetBackground).clipShape(RoundedRectangle(cornerRadius: 24))
            MediumWidgetView(state: s, cover: c).padding(16).frame(width: 364, height: 170).background(widgetBackground).clipShape(RoundedRectangle(cornerRadius: 24))
            LockWidgetView(state: s).foregroundStyle(.white).frame(width: 170, height: 72)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray)
    }
}
#endif
