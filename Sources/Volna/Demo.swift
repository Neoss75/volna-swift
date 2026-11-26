#if DEBUG
import AVFoundation
import SwiftUI

/// Only in test builds: makes a few sound files and opens the screen named on the command line,
/// so the cloud Mac can check the app and take screenshots. Not part of the TestFlight build.
@MainActor
enum Demo {
    static func run(library: Library, player: Player, settings: Settings, ui: UIState, stations: Stations, headphones: Headphones) async {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-demo") else { return }
        func value(_ name: String) -> String? {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        settings.v.onlineArt = false
        settings.v.language = value("-lang") ?? "ru"
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
        if args.contains("-waiting") {
            _ = library.restore(favourites: [], playlists: [], songs: [
                BackupSong(id: UUID(), file: "Тартак - Понад хмарами.flac", duration: 215, title: "Понад хмарами", artist: "Тартак", album: ""),
                BackupSong(id: UUID(), file: "Kalush - Stefania.mp3", duration: 180, title: "Stefania", artist: "Kalush", album: ""),
            ])
        }
        // the simulator keeps the settings from the screenshot before
        settings.v.radioExtras = args.contains("-radioextras")
        if args.contains("-radioextras") {
            let size = CGSize(width: 600, height: 600)
            let image = UIGraphicsImageRenderer(size: size).image { c in
                let colors = [UIColor(red: 0.95, green: 0.45, blue: 0.2, alpha: 1).cgColor, UIColor(red: 0.35, green: 0.1, blue: 0.5, alpha: 1).cgColor]
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                    c.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 600, y: 600), options: [])
                }
                UIColor.white.withAlphaComponent(0.85).setFill()
                UIBezierPath(ovalIn: CGRect(x: 150, y: 150, width: 300, height: 300)).fill()
            }
            RadioExtras.fake = (image, "Перший рядок пісні\nДругий рядок\n\nПриспів, перший рядок\nПриспів, другий рядок")
        }
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
        if args.contains("-aac"), let t = await addFormats(library).last { player.play(t.id, from: library.tracks.map(\.id)) }
        switch value("-port") {
        case "usb": SoundPath.Output.fake = .init(port: .usbAudio, name: "USB DAC", rate: 44100, channels: 2, latency: 0.012, volume: 1)
        case "bt": SoundPath.Output.fake = .init(port: .bluetoothA2DP, name: "AirPods Pro", rate: 48000, channels: 2, latency: 0.16, volume: 0.6)
        default: break
        }
        if let t = value("-tab") { ui.listTab = ListTab.allCases.first { "\($0)" == t } ?? .songs }
        if args.contains("-album"), let t = library.tracks.first(where: { !$0.album.isEmpty }) { ui.collection = .album(Library.albumKey(t)) }
        if args.contains("-selftest") {
            await selfTest(library: library, player: player, settings: settings, ui: ui, stations: stations, headphones: headphones)
            return
        }
        if !args.contains("-lossless"), !args.contains("-aac"), !args.contains("-cue"), let first = library.tracks.first { player.play(first.id, from: library.tracks.map(\.id)) }
        if args.contains("-loop") {
            player.seek(to: 3)
            player.markLoop()
            player.seek(to: 9)
            player.markLoop()
            player.seek(to: 5)
        }
        if args.contains("-radio") {
            server = await makeServer()
            if let server { showRadio(player, stations, server) }
        }
        if args.contains("-stationcheck") {
            stations.startCheck(stations.ordered)
            try? await Task.sleep(for: .seconds(2))
        }
        if let name = value("-buds") {
            Headphones.fake = (.bluetoothA2DP, name, "test " + name)
            headphones.look()
            if args.contains("-profile"), let m = HeadphoneBase.guess(name).first { headphones.assign(headphones.add(m.profile), to: headphones.current.id) }
        }
        if args.contains("-cue") {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0], file = dir.appendingPathComponent("Концерт.wav"), cue = dir.appendingPathComponent("Концерт.cue")
            synth(file, rate: 44100, channels: 2, seconds: 30)
            try? "PERFORMER \"Океан Ельзи\"\nTITLE \"Земля\"\nFILE \"Концерт.wav\" WAVE\nTRACK 01 AUDIO\nTITLE \"Обійми\"\nINDEX 01 00:00:00\nTRACK 02 AUDIO\nTITLE \"Стріляй\"\nINDEX 01 00:12:00\n"
                .write(to: cue, atomically: true, encoding: .utf8)
            await library.add(urls: [cue, file])
            if let t = library.tracks.last(where: { $0.cueStart != nil }) { player.play(t.id, from: library.tracks.map(\.id)) }
        }
        if args.contains("-newstation") { ui.stationSheet = StationSheet() }
        if args.contains("-wifisent") { Task { await wifiShow() } }
        if args.contains("-still") { player.pause() }
        if args.contains("-eqrock") { settings.v.bands = EQPreset.all[2].bands }
        if args.contains("-landscape"), let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
        }
        try? await Task.sleep(for: .seconds(1))
        if let p = value("-panel").flatMap(Panel.init(rawValue:)) { ui.panel = p }
        if args.contains("-saver") { ui.saver = true }
        if let page = value("-page").flatMap(SettingsPage.init(rawValue:)) { ui.settingsPath = [page] }
    }

    private static var server: TestServer?

    private static func selfTest(library: Library, player: Player, settings: Settings, ui: UIState, stations: Stations, headphones: Headphones) async {
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
        player.play(ids[0], from: ids)
        await wait(2.5)
        // what a video in another app does: the engine is stopped first, the notice comes later
        player.graph.engine.stop()
        await wait(0.5)
        let note = { (type: AVAudioSession.InterruptionType, options: AVAudioSession.InterruptionOptions) in
            NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(),
                                            userInfo: [AVAudioSessionInterruptionTypeKey: type.rawValue, AVAudioSessionInterruptionOptionKey: options.rawValue])
        }
        note(.began, [])
        await wait(0.5)
        let stopped = player.position
        check("interruption keeps the place", !player.isPlaying && stopped > 1.8 && stopped < 3, String(format: "%.2f", stopped))
        note(.ended, .shouldResume)
        await wait(1)
        check("goes on after an interruption", player.isPlaying && abs(player.position - stopped - 1) < 0.6, String(format: "%.2f after %.2f", player.position, stopped))
        settings.v.rate = 1.5
        let r = player.position
        await wait(2)
        check("speed 1.5", abs(player.position - r - 3) < 0.8, String(format: "%.2f", player.position - r))
        settings.v.rate = 1
        settings.v.semitones = 3
        let r2 = player.position
        await wait(2)
        let pd = player.graph.decks[0].pitch
        check("pitch without speed", pd.pitch == 300 && pd.rate == 1 && !pd.bypass && abs(player.position - r2 - 2) < 0.6,
              String(format: "%.0f %.2f %.2f", pd.pitch, pd.rate, player.position - r2))
        settings.v.semitones = 0
        check("pitch back", player.graph.decks.allSatisfy { $0.pitch.bypass && $0.pitch.pitch == 0 }, "")
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
        let bandsBefore = settings.v.bands, eqBefore = settings.v.eqOn
        let nextIndex = ((EQPreset.all.firstIndex { $0.id == settings.preset?.id } ?? 0) + 1) % EQPreset.all.count
        PlayerBridge.nextPreset?()
        await wait(0.3)
        check("preset from the widget", settings.preset?.id == EQPreset.all[nextIndex].id && WidgetState.load().preset == tr(EQPreset.all[nextIndex].name),
              "\(settings.preset?.id ?? "-") \(WidgetState.load().preset ?? "-")")
        var presetIntent = PresetIntent()
        presetIntent.preset = .rock
        _ = try? await presetIntent.perform()
        check("siri preset", settings.preset?.id == "rock" && settings.v.eqOn, "\(settings.preset?.id ?? "-")")
        presetIntent.preset = .off
        _ = try? await presetIntent.perform()
        check("siri equaliser off", !settings.v.eqOn, "")
        settings.v.bands = bandsBefore
        settings.v.eqOn = eqBefore
        var sleepIntent = SleepTimerIntent()
        sleepIntent.time = .m30
        _ = try? await sleepIntent.perform()
        check("siri sleep timer", abs((player.sleepAt?.timeIntervalSinceNow ?? 0) - 1800) < 10, "\(player.sleepAt?.timeIntervalSinceNow ?? 0)")
        sleepIntent.time = .song
        _ = try? await sleepIntent.perform()
        check("siri sleep at the end of the song", player.sleepAfterTrack && player.sleepAt == nil, "")
        sleepIntent.time = .off
        _ = try? await sleepIntent.perform()
        check("siri sleep timer off", !player.sleepAfterTrack && player.sleepAt == nil, "")
        await backupTest(library: library, settings: settings, stations: stations, headphones: headphones, check: check)
        check("waveforms", library.tracks.allSatisfy { ($0.wave?.count ?? 0) == 180 && ($0.wave?.max() ?? 0) == 100 }, "\(library.tracks.map { $0.gainDb ?? 99 })")
        player.seek(to: 1)
        player.play(ids[0], from: ids)
        await wait(1.5)
        let a = SpectrumAnalyzer()
        for _ in 0..<20 { a.update(player.graph.tap); await wait(0.03) }
        check("visualizer sees sound", (a.bins.max() ?? 0) > 0.2, "\(a.bins.max() ?? 0)")
        // a steady tone must not flicker
        let steady = VizTap(), sa = SpectrumAnalyzer()
        var tone = [Float](repeating: 0, count: 8192)
        for i in 0..<tone.count {
            let phase: Double = 2 * Double.pi * 440 * Double(i) / 44100
            tone[i] = Float(0.3 * sin(phase))
        }
        steady.feed(tone, rate: 44100)
        var seen: [Float] = [], fine: [Float] = []
        for k in 0..<60 {
            sa.update(steady)
            let v = sa.bands(40, live: true, fall: 0.8).v.max() ?? 0, f = sa.fine(96, live: true).max() ?? 0
            if k > 40 { seen.append(v); fine.append(f) }
        }
        let top: Float = seen.max() ?? 0, low: Float = seen.min() ?? 0
        let swing: Float = top - low
        let swing2: Float = (fine.max() ?? 0) - (fine.min() ?? 0)
        let calm = low > 0.3 && swing < 0.05 && swing2 < 0.05
        check("steady tone does not flicker", calm, "\(swing) \(swing2) at \(top)")
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
        player.seek(to: 2)
        player.markLoop()
        check("loop start", player.loopA.map { abs($0 - 2) < 0.3 } == true && player.loopB == nil, "\(player.loopA ?? -1)")
        player.seek(to: 4)
        player.markLoop()
        check("loop end", player.loopB.map { abs($0 - 4) < 0.3 } == true && player.position < 2.6, String(format: "%.2f", player.position))
        var lowest = 99.0, highest = 0.0
        for _ in 0..<35 {
            await wait(0.1)
            lowest = min(lowest, player.position)
            highest = max(highest, player.position)
        }
        check("loop goes round", player.isPlaying && lowest >= 1.8 && highest < 4.35 && highest > 3.5, String(format: "%.2f…%.2f", lowest, highest))
        player.markLoop()
        check("loop off", player.loopA == nil && player.loopB == nil, "")
        player.seek(to: 6)
        player.markLoop()
        player.seek(to: 6.3)
        player.markLoop()
        check("loop too short", player.loopB == nil && player.loopA != nil, "")
        player.next()
        check("loop forgotten with the next song", player.loopA == nil, "")
        await folderTest(library, player, settings, check, wait)
        await radioTest(library, player, settings, stations, check, wait)
        await cueTest(library, player, settings, check, wait)
        await headphoneTest(player, settings, headphones, check, wait)
        await wifiTest(library, settings, check, wait)
        await oggTest(library, player, stations, check, wait)
        await smartTest(library, player, check, wait)
        await fourTest(library, player, settings, check, wait)
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
        let gone = try? JSONDecoder().decode([VizMode].self, from: Data(#"["falls","ring"]"#.utf8))
        check("removed visualisation", gone == [.bars, .ring], "\(gone?.map(\.rawValue) ?? [])")
        let wrong = Translations.table.filter { k, v in v.contains { $0.isEmpty || $0.components(separatedBy: "{}").count != k.components(separatedBy: "{}").count } }
        check("translations", Translations.table.count > 400 && wrong.isEmpty, "\(Translations.table.count) \(wrong.keys.prefix(3))")
        settings.v.language = "en"
        check("English", tr("Песни") == "Songs" && plural(21, tr("песня"), tr("песни"), tr("песен")) == "21 songs" && tr("{} из {}", "2", "46") == "2 of 46", plural(1, tr("песня"), tr("песни"), tr("песен")))
        settings.v.language = "uk"
        check("Ukrainian", plural(5, tr("раз"), tr("раза"), tr("раз#мн")) == "5 разів" && formatSpan(3700) == "1 год 1 хв", formatDb(-3))
        settings.v.language = "ru"
        check("Russian", plural(5, tr("раз"), tr("раза"), tr("раз#мн")) == "5 раз" && tr("Песни") == "Песни", "")
        pathTest(check)
        let all = library.tracks.map(\.id)
        library.toggleFavourite(all[1])
        _ = try? await PlayFavouritesIntent().perform()
        await wait(0.5)
        check("Siri: favourites", player.current.map { library.isFavourite($0.id) } ?? false && player.isPlaying, player.current?.title ?? "")
        let song = PlaySongIntent()
        song.song = SongEntity(library.tracks[2])
        _ = try? await song.perform()
        await wait(0.5)
        check("Siri: song", player.current?.id == all[2] && player.isPlaying, player.current?.title ?? "")
        let found = (try? await SongQuery().entities(matching: "italodisko")) ?? []
        let cyr = (try? await SongQuery().entities(matching: "Бас и бит")) ?? []
        check("Siri: search", found.first?.title == "ITALODISCO" || cyr.first != nil, "\(found.map(\.title)) \(cyr.map(\.title))")
        let artists = (try? await ArtistQuery().suggestedEntities()) ?? []
        check("Siri: artists", artists.contains { $0.name == "The Kolors" }, "\(artists.map(\.name))")
        player.pause()
        check("old library opens", (try? JSONDecoder().decode([Track].self, from: Data(old.utf8)))?.count == 1, "")
        let oldStats = #"{"songs":{"x":{"plays":1,"seconds":5,"title":"T","artist":"A"}},"days":{},"total":5}"#
        check("old statistics open", (try? JSONDecoder().decode(Stats.Data.self, from: Data(oldStats.utf8)))?.songs.count == 1, "")
    }

    private static func pathTest(_ check: (String, Bool, String) -> Void) {
        var t = Track(id: UUID(), bookmark: Data(), path: "/a.flac", title: "T", artist: "A", album: "", duration: 200, hasArtwork: false)
        t.ext = "FLAC"
        t.bits = 16
        t.sampleRate = 44100
        var v = Settings.Values()
        v.direct = true
        func build(_ port: AVAudioSession.Port, _ rate: Double) -> SoundPath {
            SoundPath.build(t, rate: 44100, channels: 2, graph: rate, v, preset: nil, .init(port: port, name: "X", rate: rate, channels: 2, latency: 0.01, volume: 1))
        }
        let usb = build(.usbAudio, 44100), other = build(.usbAudio, 48000), bt = build(.bluetoothA2DP, 44100), speaker = build(.builtInSpeaker, 48000)
        check("sound path: DAC", usb.clean && usb.steps.count == 7 && !usb.steps.contains { $0.mark == .changed }, usb.verdict)
        check("sound path: resampled", !other.clean && other.steps[2].mark == .changed, other.steps[2].value)
        check("sound path: Bluetooth", !bt.clean && bt.verdict.contains("Bluetooth"), bt.steps[5].detail)
        check("sound path: speaker", !speaker.clean, speaker.verdict)
        t.ext = "MP3"
        t.bits = nil
        let lossy = [build(.bluetoothA2DP, 48000), build(.builtInSpeaker, 48000)].map(\.verdict)
        check("sound path: lossy file", lossy.allSatisfy { $0.contains("с потерями") && !$0.contains("без потерь") }, lossy.joined(separator: " "))
        t.ext = "FLAC"
        t.bits = 16
        v.direct = false
        v.bass = 3
        let bass = build(.usbAudio, 44100)
        check("sound path: processing", !bass.clean && bass.steps[3].mark == .changed, bass.steps[3].value)
    }

    static func synth(_ url: URL, rate: Double, channels: Int, seconds: Double, format kind: AudioFormatID = kAudioFormatLinearPCM) {
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
extension Demo {
    /// A backup made here, then restored as if on a new phone where every song has a new mark.
    static func backupTest(library: Library, settings: Settings, stations: Stations, headphones: Headphones, check: (String, Bool, String) -> Void) async {
        let stats = Stats()
        let t = library.tracks
        guard t.count >= 4 else { return check("backup: songs", false, "\(t.count)") }
        let lyrics = Lyrics(text: "Рядок один", source: "добавлен вручную"), ownLyrics = LyricsStore.load(t[0].id)
        LyricsStore.save(lyrics, id: t[0].id)
        if !library.isFavourite(t[1].id) { library.toggleFavourite(t[1].id) }
        let list = library.createPlaylist("Копия", with: [t[2].id, t[0].id])
        let oldTitle = t[3].title, oldArtist = t[3].artist, oldAlbum = t[3].album
        library.edit(t[3].id, title: "Исправлено", artist: oldArtist, album: oldAlbum)
        settings.v.semitones = 2
        let made = BackupFile.make(library: library, settings: settings, stations: stations, headphones: headphones, stats: stats)
        var b: Backup
        do {
            b = try BackupFile.read(try BackupFile.write(made))
        } catch {
            return check("backup: file", false, "\(error)")
        }
        check("backup: file", b.songs?.count == t.count && b.stations?.count == stations.all.count && b.playlists?.contains { $0.id == list.id } == true, "\(b.songs?.count ?? -1)")

        // a new phone: the same files under new marks
        var map: [UUID: UUID] = [:]
        for s in b.songs ?? [] { map[s.id] = UUID() }
        b.songs = b.songs?.map { var s = $0; s.id = map[s.id] ?? s.id; return s }
        b.favourites = b.favourites?.map { map[$0] ?? $0 }
        b.playlists = b.playlists?.map { var p = $0; p.keys = p.keys.map { map[$0] ?? $0 }; return p }
        LyricsStore.delete(t[0].id)
        library.toggleFavourite(t[1].id)
        library.deletePlaylist(list.id)
        library.edit(t[3].id, title: oldTitle, artist: oldArtist, album: oldAlbum)
        library.update(t[3].id) { $0.edited = nil }
        settings.v.semitones = 0
        let r = BackupFile.restore(b, library: library, settings: settings, stations: stations, headphones: headphones, stats: stats)
        check("backup: songs recognised", r.found == r.total && library.waiting.isEmpty, "\(r.found) of \(r.total)")
        check("backup: settings", settings.v.semitones == 2, "\(settings.v.semitones)")
        check("backup: favourite", library.isFavourite(t[1].id) && !library.favourites.contains { map.values.contains($0) }, "")
        check("backup: playlist", library.playlists.first { $0.id == list.id }?.keys == [t[2].id, t[0].id], "")
        check("backup: lyrics", LyricsStore.load(t[0].id)?.text == lyrics.text, "")
        check("backup: corrected name", library.track(t[3].id)?.title == "Исправлено", library.track(t[3].id)?.title ?? "-")

        // a song whose file is not here yet waits, and is recognised once it comes
        let gone = BackupSong(id: UUID(), file: t[2].fileName, size: t[2].size, cueStart: t[2].cueStart, duration: t[2].duration, title: t[2].title, artist: t[2].artist, album: t[2].album)
        var later = Backup()
        later.songs = [BackupSong(id: UUID(), file: "Нет такого.mp3", duration: 100, title: "Нет", artist: "Никто", album: ""), gone]
        later.favourites = [gone.id]
        let r2 = BackupFile.restore(later, library: library, settings: settings, stations: stations, headphones: headphones, stats: stats)
        check("backup: waiting", r2.found == 1 && library.waiting.count == 1 && library.isFavourite(t[2].id), "\(r2.found) \(library.waiting.count)")
        library.forgetWaiting()
        check("backup: not a backup", (try? BackupFile.decode(Data("{\"a\":1}".utf8))) == nil && (try? BackupFile.decode(Data("{\"kind\":\"volna-backup\"}".utf8))) != nil, "")

        // back as it was
        settings.v.semitones = 0
        library.toggleFavourite(t[2].id)
        library.toggleFavourite(t[1].id)
        library.deletePlaylist(list.id)
        if let ownLyrics { LyricsStore.save(ownLyrics, id: t[0].id) } else { LyricsStore.delete(t[0].id) }
        library.edit(t[3].id, title: oldTitle, artist: oldArtist, album: oldAlbum)
        library.update(t[3].id) { $0.edited = nil }
    }
}

#endif
