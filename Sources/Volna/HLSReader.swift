import AVFoundation
import Foundation

/// A broadcast cut into pieces (HLS): a list of the latest pieces that changes all the time.
struct HLSPlaylist: Equatable {
    struct Variant: Equatable {
        var uri: String
        var bandwidth: Int
        var video: Bool
    }

    struct Segment: Equatable {
        var number: Int
        var uri: String
        var seconds: Double
        var title: String
        /// The sound before this piece was made by another encoder.
        var fresh: Bool
    }

    var variants: [Variant] = []
    /// A sound track kept apart from the picture.
    var audio: String?
    var segments: [Segment] = []
    var target = 6.0
    var ended = false
    /// Encrypted, or the pieces are of a kind that cannot be read here.
    var unsupported = false

    init(_ text: String) {
        var number = 0, seconds = 0.0, title = "", fresh = false, stream: String?
        for raw in text.components(separatedBy: .newlines) {
            let l = raw.trimmingCharacters(in: .whitespaces)
            if l.isEmpty { continue }
            func value(_ tag: String) -> String? { l.hasPrefix(tag + ":") ? String(l.dropFirst(tag.count + 1)) : nil }
            if let v = value("#EXT-X-STREAM-INF") {
                stream = v
            } else if let v = value("#EXT-X-MEDIA") {
                if Self.attribute("TYPE", v) == "AUDIO", audio == nil { audio = Self.attribute("URI", v) }
            } else if let v = value("#EXT-X-TARGETDURATION") {
                target = max(1, Double(v.trimmingCharacters(in: .whitespaces)) ?? 6)
            } else if let v = value("#EXT-X-MEDIA-SEQUENCE") {
                number = Int(v.trimmingCharacters(in: .whitespaces)) ?? 0
            } else if let v = value("#EXT-X-KEY") {
                if let m = Self.attribute("METHOD", v), m != "NONE" { unsupported = true }
            } else if l.hasPrefix("#EXT-X-MAP") {
                unsupported = true
            } else if l == "#EXT-X-DISCONTINUITY" {
                fresh = true
            } else if l == "#EXT-X-ENDLIST" {
                ended = true
            } else if let v = value("#EXTINF") {
                let parts = v.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
                seconds = parts.first.flatMap { Double($0.trimmingCharacters(in: .whitespaces)) } ?? 0
                title = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            } else if !l.hasPrefix("#") {
                if let s = stream {
                    let codecs = Self.attribute("CODECS", s) ?? ""
                    let video = Self.attribute("RESOLUTION", s) != nil || codecs.contains("avc") || codecs.contains("hvc") || codecs.contains("hev")
                    variants.append(Variant(uri: l, bandwidth: Self.attribute("BANDWIDTH", s).flatMap { Int($0) } ?? 0, video: video))
                    stream = nil
                } else {
                    segments.append(Segment(number: number, uri: l, seconds: seconds, title: title, fresh: fresh))
                    number += 1
                    (seconds, title, fresh) = (0, "", false)
                }
            }
        }
    }

    private static func attribute(_ key: String, _ line: String) -> String? {
        var rest = Substring(line)
        while !rest.isEmpty {
            guard let eq = rest.firstIndex(of: "=") else { return nil }
            let name = rest[..<eq].trimmingCharacters(in: CharacterSet(charactersIn: ", "))
            rest = rest[rest.index(after: eq)...]
            let value: Substring
            if rest.first == "\"" {
                rest = rest.dropFirst()
                let end = rest.firstIndex(of: "\"") ?? rest.endIndex
                value = rest[..<end]
                rest = end < rest.endIndex ? rest[rest.index(after: end)...] : ""
            } else {
                let end = rest.firstIndex(of: ",") ?? rest.endIndex
                value = rest[..<end]
                rest = rest[end...]
            }
            if name == key { return String(value) }
        }
        return nil
    }

    /// The best sound that is not a waste of traffic; a picture only when there is no other way.
    var best: String? {
        let sound = variants.filter { !$0.video }
        if sound.isEmpty, let audio { return audio }
        if !sound.isEmpty {
            let fit = sound.filter { $0.bandwidth <= 400_000 }
            return (fit.isEmpty ? sound.min { $0.bandwidth < $1.bandwidth } : fit.max { $0.bandwidth < $1.bandwidth })?.uri
        }
        return variants.min { $0.bandwidth < $1.bandwidth }?.uri
    }

    /// Where a live broadcast is joined: near its end, but with `seconds` of sound in hand.
    func start(with seconds: Double) -> Int {
        if ended { return segments.first?.number ?? 0 }
        var have = 0.0
        for s in segments.reversed() {
            have += s.seconds > 0 ? s.seconds : target
            if have >= max(seconds, target * 3) { return s.number }
        }
        return segments.first?.number ?? 0
    }
}

/// Takes the sound out of a transport stream (.ts).
struct TSDemuxer {
    private var tablePid = -1
    private(set) var soundPid = -1
    private(set) var type = ""
    /// There is a sound track, but of a kind that cannot be played.
    private(set) var foreign = false

    static func isTS(_ d: Data) -> Bool {
        d.count >= 188 && d[d.startIndex] == 0x47 && (d.count < 376 || d[d.startIndex + 188] == 0x47)
    }

    mutating func sound(_ d: Data) -> Data {
        let b = [UInt8](d)
        var out = Data(), i = 0
        while i + 188 <= b.count {
            guard b[i] == 0x47 else {
                i += 1 // out of step: look for the next packet
                continue
            }
            packet(b, i, &out)
            i += 188
        }
        return out
    }

    private mutating func packet(_ b: [UInt8], _ at: Int, _ out: inout Data) {
        let end = at + 188, first = b[at + 1] & 0x40 != 0
        let pid = Int(b[at + 1] & 0x1F) << 8 | Int(b[at + 2])
        let control = b[at + 3] >> 4 & 3
        guard control & 1 != 0 else { return } // no payload
        var p = at + 4
        if control == 3 { p += 1 + Int(b[p]) }
        guard p < end else { return }
        if pid == 0 || pid == tablePid {
            guard first else { return }
            p += 1 + Int(b[p])
            guard p + 12 < end else { return }
            let length = Int(b[p + 1] & 0x0F) << 8 | Int(b[p + 2])
            let stop = min(end, p + 3 + length - 4)
            if pid == 0, b[p] == 0 {
                var q = p + 8
                while q + 4 <= stop {
                    if Int(b[q]) << 8 | Int(b[q + 1]) != 0 { // 0 = network information
                        tablePid = Int(b[q + 2] & 0x1F) << 8 | Int(b[q + 3])
                        return
                    }
                    q += 4
                }
            } else if pid == tablePid, b[p] == 2 {
                var q = p + 12 + (Int(b[p + 10] & 0x0F) << 8 | Int(b[p + 11]))
                while q + 5 <= stop {
                    let kind = b[q], track = Int(b[q + 1] & 0x1F) << 8 | Int(b[q + 2])
                    if [0x0F, 0x03, 0x04].contains(kind) {
                        soundPid = track
                        type = kind == 0x0F ? "audio/aac" : "audio/mpeg"
                        return
                    }
                    if [0x11, 0x81, 0x87].contains(kind) { foreign = true }
                    q += 5 + (Int(b[q + 3] & 0x0F) << 8 | Int(b[q + 4]))
                }
            }
            return
        }
        guard pid == soundPid else { return }
        if first {
            guard p + 9 <= end, b[p] == 0, b[p + 1] == 0, b[p + 2] == 1 else { return }
            p += 9 + Int(b[p + 8])
        }
        if p < end { out.append(contentsOf: b[p..<end]) }
    }
}

/// Plays an HLS broadcast: follows the list, downloads the pieces in order and decodes them one after another.
final class HLSReader: SoundSource, @unchecked Sendable {
    private let url: URL
    private let reserve: Double
    private let onEvent: @MainActor (StreamReader.Event) -> Void
    private let session: URLSession
    /// Touched on the main thread only.
    private var stopped = false
    private var task: Task<Void, Never>?
    private let lock = NSLock()
    private var held = false

    // the rest belongs to the task
    private var decoder: SoundDecoder?
    private var decoderType = ""
    private var ts = TSDemuxer()
    private var kbps: Double?
    private var total: Double?
    private var lastTitle = ""

    /// How long one reader tries before it reports the loss.
    private static let patience = 30.0

    @MainActor
    init(_ url: URL, reserve: Double, onEvent: @escaping @MainActor (StreamReader.Event) -> Void) {
        self.url = url
        self.reserve = reserve
        self.onEvent = onEvent
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 10
        c.timeoutIntervalForResource = 40
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.networkServiceType = .avStreaming
        session = URLSession(configuration: c)
    }

    @MainActor
    func start() {
        task = Task.detached(priority: .userInitiated) { [self] in
            do {
                try await run()
                send(.end(nil))
            } catch let e as StreamError {
                send(.end(e))
            } catch is CancellationError {
            } catch {
                send(.end(.network(error.localizedDescription)))
            }
        }
    }

    @MainActor
    func stop() {
        stopped = true
        task?.cancel()
        task = nil
        session.invalidateAndCancel()
    }

    @MainActor
    func hold(_ on: Bool) { lock.withLock { held = on } }

    private func send(_ e: StreamReader.Event) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { if !self.stopped { self.onEvent(e) } }
        }
    }

    private func get(_ u: URL) async throws -> (Data, URL) {
        let (d, r) = try await session.data(from: u)
        if let code = (r as? HTTPURLResponse)?.statusCode, !(200..<300).contains(code) { throw StreamError.status(code) }
        return (d, r.url ?? u)
    }

    private func playlist(_ u: URL) async throws -> (HLSPlaylist, URL) {
        let (d, base) = try await get(u)
        let text = StationList.text(d)
        if !StationList.isStream(text) {
            guard !StationList.parse(text).stations.isEmpty else { throw StreamError.notRadio }
            send(.list(text)) // a usual list of stations with an unusual name
            throw CancellationError()
        }
        return (HLSPlaylist(text), base)
    }

    private func run() async throws {
        var (list, base) = try await playlist(url)
        var media = url
        if list.segments.isEmpty, let best = list.best {
            guard let u = URL(string: best, relativeTo: base)?.absoluteURL else { throw StreamError.notRadio }
            media = u
            (list, base) = try await playlist(u)
        }
        if list.unsupported { throw StreamError.hls }
        var next = list.start(with: reserve + list.target), fine = Date(), missing = 0
        while true {
            try Task.checkCancellation()
            // the broadcast went on without us, or the server began to count anew
            if let first = list.segments.first?.number, let last = list.segments.last?.number, next < first || next > last + 20 {
                next = list.start(with: reserve + list.target)
                decoder = nil
            }
            for s in list.segments where s.number >= next {
                while lock.withLock({ held }) { try await Task.sleep(for: .milliseconds(300)) }
                try Task.checkCancellation()
                guard let u = URL(string: s.uri, relativeTo: base)?.absoluteURL else { throw StreamError.notRadio }
                let data: Data
                do {
                    data = try await get(u).0
                } catch let e as StreamError {
                    // this piece is gone already, the next one may be there
                    next = s.number + 1
                    missing += 1
                    if missing > 4 { throw e }
                    continue
                } catch {
                    if decoder == nil || Date().timeIntervalSince(fine) > Self.patience { throw error }
                    try await Task.sleep(for: .seconds(1))
                    break // look at a fresh list first
                }
                next = s.number + 1
                missing = 0
                fine = Date()
                try play(data, s)
            }
            if list.ended, next > (list.segments.last?.number ?? -1) { return }
            try await Task.sleep(for: .seconds(max(1, list.target / 2)))
            do {
                (list, base) = try await playlist(media)
            } catch let e as StreamError where e.final {
                throw e
            } catch {
                if Task.isCancelled || Date().timeIntervalSince(fine) > Self.patience { throw error }
            }
        }
    }

    private func play(_ data: Data, _ s: HLSPlaylist.Segment) throws {
        let sound: Data, type: String
        if TSDemuxer.isTS(data) {
            ts = TSDemuxer()
            sound = ts.sound(data)
            type = ts.type
            if sound.isEmpty { throw ts.foreign ? StreamError.hls : StreamError.format }
        } else {
            sound = Self.withoutTags(data)
            guard sound.count > 2, sound[sound.startIndex] == 0xFF, sound[sound.startIndex + 1] & 0xE0 == 0xE0 else { throw StreamError.hls }
            // the two bits of the layer are zero in AAC only
            type = sound[sound.startIndex + 1] & 0x06 == 0 ? "audio/aac" : "audio/mpeg"
        }
        if s.title.contains(" - "), s.title != lastTitle {
            lastTitle = s.title
            send(.title(s.title))
        }
        if kbps == nil, s.seconds > 0.5 {
            kbps = StationFacts.standard(Double(sound.count) * 8 / s.seconds / 1000)
            total = (Double(data.count) * 8 / s.seconds / 1000).rounded()
        }
        if decoder == nil || s.fresh || type != decoderType { open(type) }
        decoder?.parse(sound)
        if decoder?.failed == true { throw StreamError.format }
    }

    private func open(_ type: String) {
        let d = SoundDecoder(type: type)
        d.onFormat = { [weak self] f in
            guard let self else { return }
            self.send(.info(StreamInfo(kind: f.kind, kbps: self.kbps ?? f.kbps, rate: f.rate, channels: f.channels, name: nil, total: self.total)))
        }
        d.onSound = { [weak self] b in self?.send(.sound(b)) }
        decoder = d
        decoderType = type
    }

    /// Pieces of plain AAC begin with a tag (ID3) that keeps the time.
    static func withoutTags(_ d: Data) -> Data {
        var d = Data(d)
        while d.count > 10, d.starts(with: Array("ID3".utf8)) {
            let size = (6..<10).reduce(0) { $0 << 7 | Int(d[$1] & 0x7F) } + 10
            d = size < d.count ? Data(d.dropFirst(size)) : Data()
        }
        return d
    }
}
