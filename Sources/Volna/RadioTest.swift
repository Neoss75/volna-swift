#if DEBUG
import AVFoundation
import Foundation
import Network

/// A tiny radio station inside the app, for the test builds only.
final class TestServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "test.server")
    private var listener: NWListener?
    private(set) var port: UInt16 = 0
    private let aac: Data
    private let perSecond: Int
    private var counts: [String: Int] = [:]

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
        switch path {
        case "/live", "/drop":
            let head = "HTTP/1.0 200 OK\r\nContent-Type: audio/aac\r\nicy-name: Тест FM\r\nicy-br: 128\r\nicy-metaint: 4000\r\n\r\n"
            c.send(content: Data(head.utf8), completion: .idempotent)
            pump(c, aac, perSecond, title: "Океан Ельзи - Обійми", limit: path == "/drop" ? 5 : .infinity)
        case "/mp3":
            // a valid MPEG-1 Layer III frame of silence, 128 kbit/s, 44.1 kHz
            let frame = Data([0xFF, 0xFB, 0x90, 0x64]) + Data(count: 413)
            c.send(content: Data("HTTP/1.1 200 OK\r\nContent-Type: audio/mpeg\r\nicy-br: 128\r\n\r\n".utf8), completion: .idempotent)
            pump(c, Data((0..<200).map { _ in frame }.joined()), 417 * 383 / 10, title: nil, limit: .infinity)
        case "/list.m3u":
            whole("audio/x-mpegurl", Data("#EXTM3U\n#EXTINF:-1,Тест\n\(url("/live"))\n".utf8))
        case "/two.pls":
            whole("audio/x-scpls", Data("[playlist]\nFile1=\(url("/live?a"))\nTitle1=Перша\nFile2=\(url("/live?b"))\nTitle2=Друга\nNumberOfEntries=2\n".utf8))
        case "/hls": whole("application/vnd.apple.mpegurl", Data("#EXTM3U\n#EXT-X-VERSION:3\n#EXTINF:6,\na.ts\n".utf8))
        case "/ogg": whole("application/ogg", Data(count: 1000))
        case "/page": whole("text/html", Data("<html></html>".utf8))
        default: whole("text/plain", Data("no".utf8), "404 Not Found")
        }
    }

    /// Three seconds at once, then at the speed of listening, the way real stations do.
    private func pump(_ c: NWConnection, _ sound: Data, _ speed: Int, title: String?, limit: Double) {
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
                c.cancel()
                return timer.cancel()
            }
            c.send(content: next(speed / 5), completion: .idempotent)
        }
        timer.resume()
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
                    ("HLS станция", "/hls.m3u8", "Рок"), ("Jazz Lounge", "/ogg", "Jazz")].map { Station(name: $0.0, url: server.url($0.1), group: $0.2) }
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
        await wait(4)
        check("radio goes on", live.state == .playing && live.stored > 0.5 && live.stored < 6, String(format: "%.1f s in store", live.stored))
        check("radio ignores the speed", player.graph.decks.allSatisfy { $0.pitch.rate == 1 }, "")
        check("no song while the radio is on", player.current == nil && player.queue == songs, "")
        settings.v.rate = 1
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
        player.next()
        check("radio plays MP3", await until(10) { live.state == .playing } && live.info.kind == "MP3", "\(live.state) \(live.info)")
        player.next()
        check("radio from a list", await until(10) { live.state == .playing } && live.info.kind == "AAC", "\(live.state)")
        player.next()
        check("stations go round", player.radio?.id == a.id, player.radio?.name ?? "")
        for (path, error) in [("/hls", StreamError.hls), ("/ogg", .ogg), ("/page", .notRadio), ("/none", .status(404)), ("/x.m3u8", .hls)] {
            let s = station(path)
            player.play(s, from: ids + [s.id])
            check("radio error \(path)", await until(6) { !player.isPlaying } && stations.problems[s.id] == error.text, stations.problems[s.id] ?? "none")
        }
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
        var say = PlayStationIntent()
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
