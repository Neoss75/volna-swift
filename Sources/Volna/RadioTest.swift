#if DEBUG
import AVFoundation
import Foundation
import Network
import UIKit

/// A tiny radio station inside the app, for the test builds only.
final class TestServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "test.server")
    private var listener: NWListener?
    private(set) var port: UInt16 = 0
    private let aac: Data
    private let perSecond: Int
    private var counts: [String: Int] = [:]
    /// Ogg files sent as an endless station, by path.
    var ogg: [String: Data] = [:]
    private let born = Date()

    init(aac: Data, seconds: Double) {
        self.aac = aac
        perSecond = max(1, Int(Double(aac.count) / seconds))
    }

    func start() async -> Bool {
        guard let l = try? NWListener(using: .tcp) else { return false }
        listener = l
        l.newConnectionHandler = { [weak self] c in
            guard let self else { return }
            c.start(queue: self.queue)
            c.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
                let line = String(data: data ?? Data(), encoding: .utf8)?.components(separatedBy: "\r\n").first ?? ""
                let path = line.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
                self.counts[path, default: 0] += 1
                self.answer(path, c)
            }
        }
        l.start(queue: queue)
        for _ in 0..<50 {
            if l.state == .ready, let p = l.port { port = p.rawValue }
            if port != 0 { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    func url(_ path: String) -> String { "http://127.0.0.1:\(port)\(path)" }
    func count(_ path: String) -> Int { queue.sync { counts[path] ?? 0 } }

    private func answer(_ path: String, _ c: NWConnection) {
        func whole(_ type: String, _ body: Data, _ status: String = "200 OK") {
            let head = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
            c.send(content: Data(head.utf8) + body, isComplete: true, completion: .contentProcessed { _ in c.cancel() })
        }
        if let file = ogg[path], !file.isEmpty {
            c.send(content: Data("HTTP/1.0 200 OK\r\nContent-Type: application/ogg\r\nicy-name: Ogg FM\r\n\r\n".utf8), completion: .idempotent)
            return pump(c, file, max(1, file.count / 3), title: nil, limit: .infinity)
        }
        switch path {
        case "/live", "/drop", "/icy", "/stall":
            let head = (path == "/icy" ? "ICY" : "HTTP/1.0") + " 200 OK\r\nContent-Type: audio/aac\r\nicy-name: Тест FM\r\nicy-br: 128\r\nicy-metaint: 4000\r\n\r\n"
            c.send(content: Data(head.utf8), completion: .idempotent)
            pump(c, aac, perSecond, title: "Океан Ельзи - Обійми", limit: path == "/drop" ? 5 : path == "/stall" ? 4 : .infinity, hang: path == "/stall")
        case "/mp3":
            // a valid MPEG-1 Layer III frame of silence, 128 kbit/s, 44.1 kHz
            let frame = Data([0xFF, 0xFB, 0x90, 0x64]) + Data(count: 413)
            c.send(content: Data("HTTP/1.1 200 OK\r\nContent-Type: audio/mpeg\r\nicy-br: 128\r\n\r\n".utf8), completion: .idempotent)
            pump(c, Data((0..<200).map { _ in frame }.joined()), 417 * 383 / 10, title: nil, limit: .infinity)
        case "/list.m3u":
            whole("audio/x-mpegurl", Data("#EXTM3U\n#EXTINF:-1,Тест\n\(url("/live"))\n".utf8))
        case "/two.pls":
            whole("audio/x-scpls", Data("[playlist]\nFile1=\(url("/live?a"))\nTitle1=Перша\nFile2=\(url("/live?b"))\nTitle2=Друга\nNumberOfEntries=2\n".utf8))
        case "/hls": whole("application/vnd.apple.mpegurl", Data("#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-MAP:URI=\"i.mp4\"\n#EXTINF:6,\na.m4s\n".utf8))
        case "/kyiv/master.m3u8":
            whole("application/vnd.apple.mpegurl", Data("#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=64000,CODECS=\"mp4a.40.2\"\nlow.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=140000,CODECS=\"mp4a.40.2\"\nts/live.m3u8\n".utf8))
        case "/kyiv/ts/live.m3u8", "/aac/live.m3u8", "/plain":
            // two-second pieces, ten in the list, a new one every two seconds
            let now = 100 + Int(Date().timeIntervalSince(born) / 2), kind = path.hasPrefix("/kyiv") ? "ts" : "aac"
            let items = (now - 9...now).map { "#EXTINF:2.0,\($0 % 2 == 0 ? "Тартак - Понад хмарами" : "")\n/piece/\($0).\(kind)" }.joined(separator: "\n")
            whole("application/vnd.apple.mpegurl", Data("#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXT-X-MEDIA-SEQUENCE:\(now - 9)\n\(items)\n".utf8))
        case _ where path.hasPrefix("/piece/"):
            let name = path.dropFirst(7), n = Int(name.prefix { $0.isNumber }) ?? 0
            if n % 7 == 0 { return whole("text/plain", Data(), "404 Not Found") } // pieces get lost
            let part = piece(n)
            if name.hasSuffix("ts") {
                whole("video/mp2t", Self.transport(part))
            } else {
                let tag = Data([0x49, 0x44, 0x33, 4, 0, 0, 0, 0, 0, 3, 1, 2, 3])
                whole("audio/aac", tag + part)
            }
        case "/mute": break // says nothing at all
        case "/ogg2": whole("audio/ogg", Data(count: 1000))
        case "/ogg": whole("application/ogg", Data(count: 1000))
        case "/page": whole("text/html", Data("<html></html>".utf8))
        default: whole("text/plain", Data("no".utf8), "404 Not Found")
        }
    }

    /// Two seconds of whole AAC frames.
    private func piece(_ n: Int) -> Data {
        var starts: [Int] = [], at = 0
        let b = [UInt8](aac)
        while at + 7 < b.count {
            starts.append(at)
            at += Int(b[at + 3] & 3) << 11 | Int(b[at + 4]) << 3 | Int(b[at + 5]) >> 5
        }
        let per = 86, first = (n % 3) * per
        guard starts.count > first + per else { return Data() }
        return Data(b[starts[first]..<starts[first + per]])
    }

    /// A transport stream: a table of programs, a table of tracks, the sound in 188-byte packets.
    static func transport(_ sound: Data) -> Data {
        func packet(_ pid: Int, _ first: Bool, _ body: [UInt8]) -> [UInt8] {
            var p: [UInt8] = [0x47, (first ? 0x40 : 0) | UInt8(pid >> 8), UInt8(pid & 0xFF)]
            let room = 184 - body.count
            if room == 0 {
                p.append(0x10)
                return p + body
            }
            p.append(0x30) // stuffing
            p.append(UInt8(room - 1))
            if room > 1 {
                p.append(0)
                p += [UInt8](repeating: 0xFF, count: room - 2)
            }
            return p + body
        }
        func table(_ pid: Int, _ t: [UInt8]) -> [UInt8] {
            var body: [UInt8] = [0]
            body += t
            body += [UInt8](repeating: 0xFF, count: 184 - body.count)
            return packet(pid, true, body)
        }
        var out = table(0, [0, 0xB0, 13, 0, 1, 0xC1, 0, 0, 0, 1, 0xE1, 0x00])
        out += table(0x100, [2, 0xB0, 23, 0, 1, 0xC1, 0, 0, 0xE1, 0x01, 0xF0, 0, 0x1B, 0xE1, 0x02, 0xF0, 0, 0x0F, 0xE1, 0x01, 0xF0, 0])
        var body: [UInt8] = [0, 0, 1, 0xC0, 0, 0, 0x80, 0x80, 5, 0x21, 0, 1, 0, 1]
        body += [UInt8](sound)
        var at = 0
        while at < body.count {
            out += packet(0x101, at == 0, Array(body[at..<min(body.count, at + 184)]))
            out += packet(0x102, at == 0, [0, 0, 1, 0xE0, 1, 2, 3]) // the picture, not wanted
            at += 184
        }
        return Data(out)
    }

    /// Three seconds at once, then at the speed of listening, the way real stations do.
    private func pump(_ c: NWConnection, _ sound: Data, _ speed: Int, title: String?, limit: Double, hang: Bool = false) {
        var at = 0, sent = 0, untilMeta = 4000, first = true
        func next(_ n: Int) -> Data {
            var out = Data()
            for _ in 0..<n {
                out.append(sound[sound.startIndex + at])
                at = (at + 1) % sound.count
                untilMeta -= 1
                if title != nil, untilMeta == 0 {
                    untilMeta = 4000
                    if first, let title {
                        first = false
                        var text = Data("StreamTitle='\(title)';".utf8)
                        while text.count % 16 != 0 { text.append(0) }
                        out.append(UInt8(text.count / 16))
                        out.append(text)
                    } else {
                        out.append(0)
                    }
                }
            }
            sent += n
            return out
        }
        c.send(content: next(speed * 3), completion: .idempotent)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.2, repeating: 0.2)
        timer.setEventHandler {
            switch c.state {
            case .ready: break
            default: return timer.cancel()
            }
            if Double(sent) > limit * Double(speed) {
                if hang { return } // the connection stays, but nothing comes
                c.cancel()
                return timer.cancel()
            }
            c.send(content: next(speed / 5), completion: .idempotent)
        }
        timer.resume()
    }
}

private extension Array {
    func asyncMap<T>(_ body: (Element) async -> T) async -> [T] {
        var out: [T] = []
        for e in self { out.append(await body(e)) }
        return out
    }
}

extension Demo {
    static func makeServer() async -> TestServer? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("radio.aac")
        try? FileManager.default.removeItem(at: url)
        synth(url, rate: 44100, channels: 2, seconds: 8, format: kAudioFormatMPEG4AAC)
        guard let data = try? Data(contentsOf: url), data.count > 1000 else { return nil }
        let s = TestServer(aac: data, seconds: 8)
        return await s.start() ? s : nil
    }

    static func showRadio(_ player: Player, _ stations: Stations, _ server: TestServer) {
        var list = [("Тест FM", "/live", "Украина"), ("Старе добре радіо", "/mp3", "Украина"), ("Дуже довга назва станції, яка не поміститься в рядок", "/drop", "Рок"),
                    ("Київ HLS", "/kyiv/master.m3u8", "Рок"), ("Jazz Lounge", "/ogg", "Jazz")].map { Station(name: $0.0, url: server.url($0.1), group: $0.2) }
        list[0].favourite = true
        stations.add(list)
        player.play(list[0], from: stations.ordered.map(\.id))
    }

    static func radioTest(_ library: Library, _ player: Player, _ settings: Settings, _ stations: Stations,
                          _ check: (String, Bool, String) -> Void, _ wait: (Double) async -> Void) async {
        let m3u = StationList.parse("#EXTM3U\n#EXTINF:-1 tvg-logo=\"https://a.b/x,y.png\" group-title=\"Рок\",Радио, один\nhttps://a.b/1\n#EXTINF:0,Local\nC:\\music\\a.mp3\nicy://c.d:8000/stream\n")
        check("m3u", m3u.stations.map(\.name) == ["Радио, один", "c.d"] && m3u.stations.first?.group == "Рок" && m3u.stations.first?.logo == "https://a.b/x,y.png" && m3u.skipped == 1
            && m3u.stations.last?.url == "http://c.d:8000/stream", "\(m3u.stations.map(\.name)) \(m3u.skipped)")
        let old = "#EXTM3U\n#EXTINF:-1,Шансон\nhttp://a.b/1".data(using: .windowsCP1251) ?? Data()
        check("m3u in the Windows encoding", StationList.parse(StationList.text(old)).stations.first?.name == "Шансон", "")
        let two = StationList.parse("#EXTM3U\n#EXTINF:-1 group-title=\"A\", Хит FM\nМосква\n107,0 FM\nhttp://a.b/1\n#EXTINF:-1,Два\nhttp://a.b/2\n")
        check("a name on three lines", two.stations.map(\.name) == ["Хит FM Москва 107,0 FM", "Два"] && two.skipped == 0, "\(two.stations.map(\.name))")
        let damaged = Data("#EXTINF:-1,Русское радио и ещё много других названий".utf8) + Data([0xD0]) + Data("\nhttp://a.b/1".utf8)
        check("damaged letters", StationList.parse(StationList.text(damaged)).stations.first?.name == "Русское радио и ещё много других названий", "")
        let big = (0..<3000).map { Station(name: "S\($0)", url: "http://a.b/\($0)") }
        let t0 = Date()
        stations.add(big)
        let found = big.filter { stations.station($0.id) != nil }.count + stations.ordered.count
        let took = Date().timeIntervalSince(t0)
        stations.remove(Set(big.map(\.id)))
        check("3000 stations", found == 6000 && took < 1, String(format: "%.2f s", took))
        check("pls", StationList.parse("[playlist]\r\nFile1=http://a.b/1\r\nTitle1=Одна\r\n").stations.first?.name == "Одна", "")
        check("header names", StreamReader.repair(String(data: Data("Тест FM".utf8), encoding: .isoLatin1) ?? "") == "Тест FM", "")
        var icy = IcySplitter(interval: 3)
        var parts: [IcySplitter.Part] = []
        let text = Data("StreamTitle='It's A - B';".utf8) + Data(count: 7)
        for b in Data([1, 2, 3, 2]) + text + Data([4, 5, 6, 0, 7]) { parts += icy.feed(Data([b])) }
        let bytes = parts.reduce(into: Data()) { if case .sound(let d) = $1 { $0 += d } }
        check("song names in the stream", bytes == Data([1, 2, 3, 4, 5, 6, 7]) && parts.contains(.title("It's A - B")), "\(parts.count)")

        guard let server = await makeServer() else { return check("radio server", false, "") }
        func until(_ seconds: Double, _ ok: () -> Bool) async -> Bool {
            let end = Date().addingTimeInterval(seconds)
            while Date() < end {
                if ok() { return true }
                await wait(0.1)
            }
            return ok()
        }
        let live = player.live
        func station(_ path: String) -> Station {
            let s = Station(name: path, url: server.url(path))
            stations.add([s])
            return s
        }
        let a = station("/live"), drop = station("/drop"), mp3 = station("/mp3"), list = station("/list.m3u")
        let ids = [a, drop, mp3, list].map(\.id)
        let songs = library.tracks.map(\.id)
        player.play(songs[0], from: songs)
        await wait(2)
        settings.v.rate = 1.5
        player.play(a, from: ids)
        let place = { player.position }()
        check("radio plays AAC", await until(10) { live.state == .playing } && player.isPlaying && live.info.kind == "AAC" && live.info.rate == 44100,
              "\(live.state) \(live.info)")
        check("song name from the radio", await until(5) { live.artistAndSong?.title == "Обійми" } && live.info.name == "Тест FM", "\(live.title) \(live.info.name ?? "")")
        let extras = player.extras
        check("radio extras off by default", !Settings.Values().radioExtras && extras.state == .off && extras.cover == nil, "\(extras.state)")
        RadioExtras.fake = (UIImage(systemName: "music.note"), "[ar:X]\n[00:01.00]Один\n[00:02.50] Два")
        settings.v.radioExtras = true
        check("radio extras: cover and lyrics", await until(5) { extras.state == .done } && extras.cover != nil && extras.lyrics == "Один\nДва" && extras.song?.title == "Обійми",
              "\(extras.state) \(extras.lyrics ?? "-")")
        check("radio extras: no artist, no ads", RadioExtras.isNotSong(("Реклама", "Скидки")) && !RadioExtras.isNotSong(("Океан Ельзи", "Обійми")), "")
        settings.v.radioExtras = false
        check("radio extras switched off", extras.state == .off && extras.cover == nil && extras.lyrics == nil, "\(extras.state)")
        RadioExtras.fake = nil
        await wait(4)
        check("radio goes on", live.state == .playing && live.stored > 0.5 && live.stored < 6, String(format: "%.1f s in store", live.stored))
        check("radio ignores the speed", player.graph.decks.allSatisfy { $0.pitch.rate == 1 }, "")
        check("no song while the radio is on", player.current == nil && player.queue == songs, "")
        settings.v.rate = 1
        settings.v.radioBuffer = 10
        check("bigger store is collected", live.state == .buffering && live.target == 10, "\(live.state)")
        check("bigger store plays", await until(14) { live.state == .playing } && live.stored > 8.5, String(format: "%.1f", live.stored))
        settings.v.radioBuffer = 2
        await wait(0.5)
        check("smaller store goes on", live.state == .playing && live.stored > 7, String(format: "%.1f", live.stored))
        player.play(a, from: ids)
        check("small store starts", await until(6) { live.state == .playing } && live.stored < 5, String(format: "%.1f", live.stored))
        player.pause()
        check("radio pause", !player.isPlaying && live.state == .idle, "")
        player.resume()
        check("radio resume", await until(10) { live.state == .playing }, "\(live.state)")
        // another app plays something: the engine stops
        player.graph.engine.stop()
        NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: player.graph.engine)
        await wait(0.5)
        check("radio after the output changed", await until(10) { live.state == .playing } && player.graph.engine.isRunning, "\(live.state)")
        player.next()
        check("next station", player.radio?.id == drop.id, player.radio?.name ?? "")
        _ = await until(10) { live.state == .playing }
        await wait(9)
        check("connects again", server.count("/drop") >= 2 && player.isPlaying && live.state == .playing, "\(server.count("/drop")) times, \(live.state)")
        let stall = station("/stall")
        player.play(stall, from: ids)
        _ = await until(10) { live.state == .playing }
        check("sound comes in smoothly", live.goal == 1 && player.graph.decks.contains { $0.fade < 0.9 }, "\(player.graph.decks.map(\.fade))")
        await wait(0.8)
        check("sound is full", player.graph.decks.allSatisfy { $0.fade > 0.99 }, "\(player.graph.decks.map(\.fade))")
        var faded = false
        _ = await until(5) {
            if live.state == .playing, live.goal == 0 { faded = true }
            return live.state != .playing
        }
        check("sound goes out smoothly", faded && live.state != .idle, "\(live.state)")
        check("silent connection is changed", await until(12) { server.count("/stall") >= 2 && live.state == .playing }, "\(server.count("/stall")) times, \(live.state)")
        player.play(drop, from: ids)
        _ = await until(10) { live.state == .playing }
        player.next()
        check("radio plays MP3", await until(10) { live.state == .playing } && live.info.kind == "MP3", "\(live.state) \(live.info)")
        player.next()
        check("radio from a list", await until(10) { live.state == .playing } && live.info.kind == "AAC", "\(live.state)")
        player.next()
        check("stations go round", player.radio?.id == a.id, player.radio?.name ?? "")
        for (path, error) in [("/hls", StreamError.hls), ("/ogg", .format), ("/page", .notRadio), ("/none", .status(404)), ("/x.m3u8", .status(404))] {
            let s = station(path)
            player.play(s, from: ids + [s.id])
            check("radio error \(path)", await until(6) { !player.isPlaying } && stations.problems[s.id] == error.text, stations.problems[s.id] ?? "none")
        }
        let mute = station("/mute"), gone = station("/gone"), kept = station("/none2"), ogg = station("/ogg2")
        stations.toggleFavourite(kept.id)
        stations.startCheck([a, mp3, list, mute, gone, kept, ogg])
        check("station check", await until(25) { stations.check?.running == false } && stations.check?.alive == 3 && stations.check?.dead == [mute.id, gone.id, kept.id]
            && stations.check?.unsupported == 1 && stations.problems[a.id] == nil, "\(String(describing: stations.check))")
        let heard = [a, mp3].map { stations.station($0.id)?.facts }
        let kinds = heard.map { $0?.kind ?? "" }, rates = heard.map { $0?.kbps ?? 0 }, hours = heard.map { Int($0?.perHour ?? 0) }
        check("format of the stations", kinds == ["AAC", "MP3"] && rates == [128, 128] && hours == [57, 57], heard.map { $0?.text ?? "none" }.joined(separator: ", "))
        let fresh = await [a, mp3].asyncMap { await StationProbe.ask(Station(name: "", url: $0.url), StationProbe.session()).facts }
        let guess = fresh.map { $0?.kbps ?? 0 }
        check("format before playing", fresh.map { $0?.kind ?? "" } == ["AAC", "MP3"] && guess[1] == 128 && guess[0] > 60 && guess[0] < 260, fresh.map { $0?.text ?? "none" }.joined(separator: ", "))
        stations.removeDead()
        check("silent stations removed", stations.station(mute.id) == nil && stations.station(gone.id) == nil && stations.station(kept.id) != nil && stations.station(a.id) != nil, "")
        let icyLine = station("/icy")
        player.play(icyLine, from: [icyLine.id])
        check("old servers (ICY 200)", await until(8) { live.state == .playing && live.title.contains("Обійми") } && live.info.name == "Тест FM", "\(live.state) \(live.title) \(live.info)")
        let master = HLSPlaylist("#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=900000,RESOLUTION=1x1,CODECS=\"avc1,mp4a\"\nv\n#EXT-X-STREAM-INF:PROGRAM-ID=1, BANDWIDTH=281600, CODECS=\"mp4a.40.2\"\na\n#EXT-X-STREAM-INF:BANDWIDTH=112000\nb\n")
        check("HLS variants", master.best == "a" && master.variants.count == 3, "\(master.best ?? "")")
        let part = HLSPlaylist("#EXTM3U\n#EXT-X-TARGETDURATION:4\r\n#EXT-X-MEDIA-SEQUENCE:7\r\n#EXTINF:4,\r\na.ts\r\n#EXT-X-DISCONTINUITY\r\n#EXTINF:4.0,X - Y\r\nb.ts\r\n#EXTINF:4,\r\nc.ts\r\n#EXTINF:4,\r\nd.ts\r\n")
        check("HLS list", part.segments.map(\.number) == [7, 8, 9, 10] && part.segments[1].fresh && part.segments[1].title == "X - Y" && part.start(with: 2) == 8, "\(part.segments.count)")
        let raw = Data((0..<2000).map { UInt8($0 * 7 % 256) })
        var demux = TSDemuxer()
        check("transport stream", demux.sound(TestServer.transport(raw)) == raw && demux.soundPid == 0x101 && demux.type == "audio/aac", "\(demux.soundPid)")
        settings.v.radioBuffer = 5
        for path in ["/kyiv/master.m3u8", "/aac/live.m3u8", "/plain"] {
            let s = station(path)
            player.play(s, from: ids + [s.id])
            check("HLS plays \(path)", await until(10) { live.state == .playing } && live.info.kind == "AAC" && live.info.rate == 44100, "\(live.state) \(live.info)")
            await wait(5)
            check("HLS goes on \(path)", live.state == .playing && live.stored > 2 && live.stored < 25 && live.title == "Тартак - Понад хмарами", String(format: "%.1f s, ", live.stored) + live.title)
        }
        let kyiv = stations.all.first { $0.url.hasSuffix("/kyiv/master.m3u8") }
        check("traffic of HLS", kyiv?.facts?.kbps == 128 && (kyiv?.facts?.total ?? 0) > 135, kyiv?.facts?.text ?? "none")
        let silent = Station(name: "x", url: server.url("/kyiv/master.m3u8"))
        let answer = await StationProbe.ask(silent, StationProbe.session())
        check("traffic of HLS before playing", answer.error == nil && answer.facts?.kind == "HLS" && (answer.facts?.total ?? 0) > 135, answer.facts?.text ?? "none")
        var packets = Data([1, 2, 3])
        for _ in 0..<4 { packets += Data([0xFF, 0xFB, 0xB0, 0x00]) + Data(count: 622) }
        check("MP3 192", StationFacts.look(packets)?.kbps == 192 && StationFacts.look(Data(count: 5000)) == nil, "")
        check("traffic text", StationFacts(kind: "MP3", kbps: 128).text.contains("58 МБ") && StationFacts(kind: "HLS", total: 6800).text.contains("3.1 ГБ"), StationFacts(kind: "HLS", total: 6800).text)
        settings.v.radioBuffer = 2
        let tried = server.count("/kyiv/low.m3u8")
        check("HLS takes the better sound", tried == 0, "\(tried)")
        player.play(a, from: ids)
        check("link to a list", await stations.add(link: server.url("/two.pls"), name: "") && stations.all.suffix(2).map(\.name) == ["Перша", "Друга"], "\(stations.all.count)")
        check("link to a page", await stations.add(link: server.url("/page"), name: "") == false, "")
        player.play(a, from: ids)
        _ = await until(10) { live.state == .playing }
        player.leaveRadio()
        check("back to the songs", player.radio == nil && player.current?.id == songs[0] && abs(player.position - place) < 0.1 && !player.isPlaying,
              String(format: "%.2f, was %.2f", player.position, place))
        player.resume()
        await wait(1)
        check("the song goes on", player.isPlaying && abs(player.position - place - 1) < 0.6, String(format: "%.2f", player.position))
        let say = PlayStationIntent()
        say.station = StationEntity(id: mp3.id, name: mp3.name)
        _ = try? await say.perform()
        check("Siri: radio", await until(10) { live.state == .playing } && player.radio?.id == mp3.id, player.radio?.name ?? "")
        stations.remove(Set(stations.all.map(\.id)))
        check("removed station", player.radio == nil && !player.isPlaying && stations.all.isEmpty, "")
        player.play(songs[0], from: songs)
        await wait(1)
        check("songs after the radio", player.isPlaying && player.position > 0.4, String(format: "%.2f", player.position))
        player.pause()
    }
}
#endif
