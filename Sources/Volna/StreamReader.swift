import AVFoundation
import Foundation

enum StreamKind {
    case audio, list, ogg, video, page

    static func of(type: String, url: URL) -> StreamKind {
        let ext = url.pathExtension.lowercased()
        if type.contains("mpegurl") || type.contains("scpls") { return .list }
        if type.contains("ogg") || type.contains("opus") { return .ogg }
        if type.contains("video/") { return .video }
        if StationList.extensions.contains(ext), !type.hasPrefix("audio/mpeg") || type.contains("url") { return .list }
        if type.hasPrefix("text/") { return .page }
        return .audio
    }
}

enum StreamError: Error, Equatable {
    case status(Int), hls, ogg, video, notRadio, format, network(String)

    var text: String {
        switch self {
        case .status(404): tr("станции по этой ссылке больше нет")
        case .status(let c): tr("станция отвечает ошибкой {}", "\(c)")
        case .hls: tr("этот вид HLS не поддерживается")
        case .ogg: tr("потоки OGG и Opus пока не поддерживаются")
        case .video: tr("это видео, а не радио")
        case .notRadio: tr("по этой ссылке не радиопоток")
        case .format: tr("формат этого потока не распознан")
        case .network(let s): s
        }
    }

    /// Trying again will not help.
    var final: Bool {
        switch self {
        case .network: false
        case .status(let c): c < 500 && c != 408 && c != 429
        default: true
        }
    }
}

/// What is known about the stream.
struct StreamInfo: Equatable {
    var kind = ""
    var kbps: Double?
    var rate: Double = 0
    var channels = 2
    var name: String?
}

/// Downloads one broadcast, takes the song names out of it and decodes the sound piece by piece.
/// Everything happens on its own queue; the events come on the main thread, in order.
final class StreamReader: NSObject, URLSessionDataDelegate, SoundSource, @unchecked Sendable {
    enum Event {
        case info(StreamInfo), sound(AVAudioPCMBuffer), title(String), list(String), end(StreamError?)
    }

    private let url: URL
    private let onEvent: @MainActor (Event) -> Void
    private let queue = OperationQueue()
    private var session: URLSession?
    private var task: URLSessionDataTask?
    /// Touched on the main thread only.
    private var stopped = false
    private var held = false

    // the rest is touched on the queue only
    private var kind = StreamKind.audio
    private var listData = Data()
    private var info = StreamInfo()
    private var finite = false
    private var ended = false
    private var received = 0

    private var icy = IcySplitter(interval: 0)

    private var decoder: SoundDecoder?
    private var sniffing = true
    private var old = Data()

    @MainActor
    init(_ url: URL, onEvent: @escaping @MainActor (Event) -> Void) {
        self.url = url
        self.onEvent = onEvent
        super.init()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
    }

    @MainActor
    func start() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15 // between two pieces of data, too
        config.timeoutIntervalForResource = .infinity
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.networkServiceType = .avStreaming
        var request = URLRequest(url: url)
        request.setValue("1", forHTTPHeaderField: "Icy-MetaData")
        let s = URLSession(configuration: config, delegate: self, delegateQueue: queue)
        session = s
        task = s.dataTask(with: request)
        task?.resume()
    }

    @MainActor
    func stop() {
        stopped = true
        session?.invalidateAndCancel()
        session = nil
        task = nil
    }

    /// A file on a server comes much faster than it plays: wait until it is needed.
    @MainActor
    func hold(_ on: Bool) {
        guard on != held else { return }
        held = on
        if on { task?.suspend() } else { task?.resume() }
    }

    private func send(_ e: Event) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { if !self.stopped { self.onEvent(e) } }
        }
    }

    private func finish(_ error: StreamError?) {
        guard !ended else { return }
        ended = true
        send(.end(error))
    }

    // MARK: - Network

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let http = response as? HTTPURLResponse
        if let code = http?.statusCode, !(200..<300).contains(code) {
            finish(.status(code))
            return completionHandler(.cancel)
        }
        func header(_ name: String) -> String? { http?.value(forHTTPHeaderField: name) }
        let type = (header("Content-Type") ?? "").lowercased()
        kind = StreamKind.of(type: type, url: response.url ?? url)
        switch kind {
        case .ogg: finish(.ogg)
        case .video: finish(.video)
        case .page: finish(.notRadio)
        case .list: break
        case .audio:
            finite = response.expectedContentLength > 0
            describe(header)
            open(type)
        }
        completionHandler(ended ? .cancel : .allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !ended else { return }
        if kind == .list {
            listData.append(data)
            if listData.count > 2_000_000 { finish(.notRadio) }
            return
        }
        received += data.count
        if sniffing { takeOld(data) } else { take(data) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(.network(error.localizedDescription))
        } else if kind == .list {
            if !ended {
                ended = true
                send(.list(StationList.text(listData)))
            }
        } else {
            finish(finite ? nil : .network(tr("станция прервала передачу")))
        }
    }

    /// iOS reads headers as Latin letters, most stations send UTF-8 or the old Windows Cyrillic.
    static func repair(_ s: String) -> String {
        guard s.unicodeScalars.contains(where: { $0.value > 127 }), let raw = s.data(using: .isoLatin1) else { return s }
        return String(data: raw, encoding: .utf8) ?? String(data: raw, encoding: .windowsCP1251) ?? s
    }

    // MARK: - Sound

    private func open(_ type: String) {
        let d = SoundDecoder(type: type)
        d.onFormat = { [weak self] f in
            guard let self else { return }
            self.info.kind = f.kind
            self.info.rate = f.rate
            self.info.channels = f.channels
            if self.info.kbps == nil { self.info.kbps = f.kbps }
            self.send(.info(self.info))
        }
        d.onSound = { [weak self] b in self?.send(.sound(b)) }
        decoder = d
        if d.failed { finish(.format) }
    }

    private func take(_ data: Data) {
        for part in icy.feed(data) {
            switch part {
            case .sound(let d): decoder?.parse(d)
            case .title(let t): send(.title(t))
            }
        }
        if decoder?.failed == true { finish(.format) }
        if decoder?.gotSound != true, received > 400_000 { finish(.format) }
    }

    /// Very old servers answer "ICY 200 OK" instead of HTTP: iOS takes their headers for the beginning of the sound.
    private func takeOld(_ data: Data) {
        old.append(data)
        let mark = Data("ICY 200".utf8)
        if old.count < mark.count, mark.starts(with: old) { return }
        guard old.starts(with: mark) else {
            sniffing = false
            return take(old)
        }
        guard let end = old.range(of: Data("\r\n\r\n".utf8)) else {
            if old.count > 16000 { finish(.format) }
            return
        }
        sniffing = false
        var headers: [String: String] = [:]
        for line in (String(data: old[..<end.lowerBound], encoding: .isoLatin1) ?? "").components(separatedBy: "\r\n") {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        describe { headers[$0] }
        open((headers["content-type"] ?? "audio/mpeg").lowercased())
        take(Data(old[end.upperBound...]))
    }

    private func describe(_ header: (String) -> String?) {
        icy = IcySplitter(interval: header("icy-metaint").flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0)
        info.kbps = header("icy-br")?.split(separator: ",").first.flatMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        info.name = header("icy-name").map(Self.repair)
    }
}

/// Stations put the name of the song into the sound: after every `interval` bytes there is one length byte (× 16) and a text.
struct IcySplitter {
    enum Part: Equatable { case sound(Data), title(String) }

    let interval: Int
    private var left: Int
    private var meta = Data()
    private var metaLeft = 0

    init(interval: Int) {
        self.interval = interval
        left = interval
    }

    mutating func feed(_ data: Data) -> [Part] {
        guard interval > 0 else { return [.sound(data)] }
        var parts: [Part] = [], i = data.startIndex
        while i < data.endIndex {
            if metaLeft > 0 {
                let n = min(metaLeft, data.endIndex - i)
                meta.append(data[i..<i + n])
                metaLeft -= n
                i += n
                if metaLeft == 0 {
                    if let t = Self.title(meta) { parts.append(.title(t)) }
                    meta = Data()
                    left = interval
                }
            } else if left == 0 {
                metaLeft = Int(data[i]) * 16
                i += 1
                if metaLeft == 0 { left = interval }
            } else {
                let n = min(left, data.endIndex - i)
                parts.append(.sound(Data(data[i..<i + n])))
                left -= n
                i += n
            }
        }
        return parts
    }

    /// StreamTitle='Artist - Song';StreamUrl='…';
    static func title(_ data: Data) -> String? {
        let raw = data.prefix { $0 != 0 }
        guard let text = String(data: raw, encoding: .utf8) ?? String(data: raw, encoding: .windowsCP1251),
              let a = text.range(of: "StreamTitle='") else { return nil }
        let rest = text[a.upperBound...]
        let end = rest.range(of: "';")?.lowerBound ?? rest.lastIndex(of: "'") ?? rest.endIndex
        return rest[..<end].trimmingCharacters(in: .whitespaces)
    }
}
