import AVFoundation
import Foundation

/// What every decoder of a radio flow can do.
protocol StreamDecoding: AnyObject {
    var onFormat: ((SoundDecoder.Format) -> Void)? { get set }
    var onSound: ((AVAudioPCMBuffer) -> Void)? { get set }
    var onMeasured: ((Double) -> Void)? { get set }
    var gotSound: Bool { get }
    var failed: Bool { get }
    func parse(_ d: Data)
}

extension SoundDecoder: StreamDecoding {}

// MARK: - Pages

/// Cuts an Ogg flow into pages and the pages into packets.
struct OggPages {
    struct Page {
        /// 1: the first packet began on the page before, 2: the first page of a stream, 4: the last one.
        var flags: UInt8
        var granule: Int64
        var serial: UInt32
        /// Packets that end on this page.
        var packets: [Data]
        /// The whole page, the way stb_vorbis wants it.
        var raw: Data
        var first: Bool { flags & 2 != 0 }
    }

    private var buffer = [UInt8]()
    private var at = 0
    private var partial: [UInt32: Data] = [:]
    /// Bytes that were not part of any page.
    private(set) var junk = 0
    private(set) var pages = 0

    mutating func feed(_ d: Data) -> [Page] {
        buffer.append(contentsOf: d)
        var out: [Page] = []
        while true {
            guard let start = find() else {
                // keep what may be the beginning of the mark
                let keep = min(3, buffer.count - at)
                junk += buffer.count - at - keep
                at = buffer.count - keep
                break
            }
            junk += start - at
            at = start
            guard buffer.count - at >= 27 else { break }
            let n = Int(buffer[at + 26])
            guard buffer.count - at >= 27 + n else { break }
            let lacing = Array(buffer[(at + 27)..<(at + 27 + n)])
            let size = lacing.reduce(0) { $0 + Int($1) }
            let total = 27 + n + size
            guard buffer.count - at >= total else { break }
            guard buffer[at + 4] == 0 else {
                // not a real page: look further
                at += 1
                continue
            }
            let flags = buffer[at + 5]
            let granule = (0..<8).reduce(Int64(0)) { $0 | Int64(buffer[at + 6 + $1]) << (8 * Int64($1)) }
            let serial = (0..<4).reduce(UInt32(0)) { $0 | UInt32(buffer[at + 14 + $1]) << (8 * UInt32($1)) }
            var packets: [Data] = [], body = at + 27 + n
            var current: Data? = flags & 1 != 0 ? partial[serial] : Data()
            partial[serial] = nil
            for l in lacing {
                let len = Int(l)
                current?.append(contentsOf: buffer[body..<(body + len)])
                body += len
                if l < 255 {
                    // a packet that began before we joined is thrown away
                    if let c = current { packets.append(c) }
                    current = Data()
                }
            }
            if let c = current, !c.isEmpty || lacing.last == 255 { partial[serial] = c }
            out.append(Page(flags: flags, granule: granule, serial: serial, packets: packets, raw: Data(buffer[at..<(at + total)])))
            pages += 1
            at += total
        }
        if at > 65536 {
            buffer.removeFirst(at)
            at = 0
        }
        return out
    }

    private func find() -> Int? {
        var i = at
        while i + 4 <= buffer.count {
            if buffer[i] == 0x4F, buffer[i + 1] == 0x67, buffer[i + 2] == 0x67, buffer[i + 3] == 0x53 { return i }
            i += 1
        }
        return nil
    }
}

// MARK: - Tags

enum OggTags {
    /// The list of "KEY=value" lines, after `skip` bytes of the packet ("OpusTags" or "\u{3}vorbis").
    static func parse(_ p: Data, skip: Int) -> [String: String] {
        let b = [UInt8](p)
        var o = skip
        func le32() -> Int? {
            guard o + 4 <= b.count else { return nil }
            defer { o += 4 }
            return Int(b[o]) | Int(b[o + 1]) << 8 | Int(b[o + 2]) << 16 | Int(b[o + 3]) << 24
        }
        guard let vendor = le32(), o + vendor <= b.count else { return [:] }
        o += vendor
        guard let count = le32() else { return [:] }
        var out: [String: String] = [:]
        for _ in 0..<min(count, 10000) {
            guard let len = le32(), len >= 0, o + len <= b.count else { break }
            let line = String(decoding: b[o..<(o + len)], as: UTF8.self)
            o += len
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].uppercased(), value = String(line[line.index(after: eq)...])
            // a cover is big: keep only the first one
            if out[key] == nil { out[key] = value }
        }
        return out
    }

    /// "Artist - Title" for the radio.
    static func title(_ t: [String: String]) -> String? {
        let title = t["TITLE"]?.trimmingCharacters(in: .whitespaces) ?? "", artist = t["ARTIST"]?.trimmingCharacters(in: .whitespaces) ?? ""
        if title.isEmpty { return nil }
        return artist.isEmpty ? title : artist + " - " + title
    }

    /// METADATA_BLOCK_PICTURE: a FLAC picture block in base64.
    static func picture(_ t: [String: String]) -> Data? {
        guard let s = t["METADATA_BLOCK_PICTURE"], let d = Data(base64Encoded: s, options: .ignoreUnknownCharacters) else { return nil }
        let b = [UInt8](d)
        var o = 4
        func be32() -> Int? {
            guard o + 4 <= b.count else { return nil }
            defer { o += 4 }
            return Int(b[o]) << 24 | Int(b[o + 1]) << 16 | Int(b[o + 2]) << 8 | Int(b[o + 3])
        }
        guard let mime = be32() else { return nil }
        o += mime
        guard let desc = be32() else { return nil }
        o += desc + 16
        guard let len = be32(), len > 0, o + len <= b.count else { return nil }
        return Data(b[o..<(o + len)])
    }
}

// MARK: - Decoder

/// Ogg Vorbis (through stb_vorbis) and Ogg Opus (through the decoder of iOS), for files and for the radio.
/// A new stream inside the flow (the radio does that with every song) starts over.
final class OggDecoder: StreamDecoding {
    enum Codec { case vorbis, opus }

    var onFormat: ((SoundDecoder.Format) -> Void)?
    var onSound: ((AVAudioPCMBuffer) -> Void)?
    var onMeasured: ((Double) -> Void)?
    var onTags: (([String: String]) -> Void)?
    /// No more frames than this (the end of a file is padded).
    var limit: Int?
    private(set) var gotSound = false
    private(set) var failed = false
    private(set) var codec: Codec?
    private(set) var emitted = 0

    private var pages = OggPages()
    private var serial: UInt32?
    private var output: AVAudioFormat?

    // Vorbis
    private var vorbis: OpaquePointer?
    private var vbuf = [UInt8]()

    // Opus
    private var headers = 0
    private var channels = 1
    private var skip = 0
    private var gain: Float = 1
    private var converter: AVAudioConverter?
    private var input: AVAudioFormat?
    private var perPacket: UInt32 = 0

    private var bytes = 0
    private var measuredFrames = 0
    private var measured = false

    init() {}

    deinit { if let vorbis { stb_vorbis_close(vorbis) } }

    func parse(_ d: Data) {
        guard !failed, !d.isEmpty else { return }
        bytes += d.count
        for page in pages.feed(d) {
            if page.first { begin(page) }
            guard page.serial == serial, let codec else { continue }
            switch codec {
            case .vorbis: vorbisPage(page)
            case .opus: opusPage(page)
            }
            if failed { return }
        }
        // not an Ogg flow at all
        if !gotSound, pages.junk > 64000 { failed = true }
    }

    private func begin(_ page: Page) {
        guard let p = page.packets.first else { return }
        let b = [UInt8](p.prefix(8))
        let found: Codec? = b.count >= 7 && b[0] == 1 && String(decoding: b[1..<7], as: UTF8.self) == "vorbis" ? .vorbis
            : b.count == 8 && String(decoding: b, as: UTF8.self) == "OpusHead" ? .opus : nil
        guard let found else { return } // a stream of something else: pictures, a skeleton
        if let vorbis { stb_vorbis_close(vorbis) }
        vorbis = nil
        vbuf = []
        converter = nil
        headers = 0
        serial = page.serial
        codec = found
        if found == .opus { opusHead(p) }
    }

    private typealias Page = OggPages.Page

    private func announce(_ kind: String, rate: Double, channels: Int) {
        let changed = output?.sampleRate != rate || output?.channelCount != AVAudioChannelCount(channels)
        guard changed, let f = AVAudioFormat(standardFormatWithSampleRate: rate, channels: AVAudioChannelCount(channels)) else { return }
        output = f
        onFormat?(SoundDecoder.Format(kind: kind, rate: rate, channels: channels, kbps: nil))
    }

    private func emit(_ b: AVAudioPCMBuffer) {
        if let limit {
            let room = limit - emitted
            if room <= 0 { return }
            if Int(b.frameLength) > room { b.frameLength = AVAudioFrameCount(room) }
        }
        guard b.frameLength > 0 else { return }
        emitted += Int(b.frameLength)
        gotSound = true
        if !measured {
            measuredFrames += Int(b.frameLength)
            let seconds = Double(measuredFrames) / b.format.sampleRate
            if seconds > 4 {
                measured = true
                onMeasured?(StationFacts.standard(Double(bytes) * 8 / seconds / 1000))
            }
        }
        onSound?(b)
    }

    // MARK: Vorbis

    private func vorbisPage(_ page: Page) {
        vbuf.append(contentsOf: page.raw)
        if vorbis == nil {
            var used: Int32 = 0, error: Int32 = 0
            let v = vbuf.withUnsafeBufferPointer { stb_vorbis_open_pushdata($0.baseAddress, Int32($0.count), &used, &error, nil) }
            guard let v else {
                // 1: VORBIS_need_more_data, the three headers are not here yet
                if error != 1 || vbuf.count > 4_000_000 {
                    if !gotSound { failed = true }
                    vbuf = []
                }
                return
            }
            vorbis = v
            vbuf.removeFirst(Int(used))
            let info = stb_vorbis_get_info(v)
            announce("Vorbis", rate: Double(info.sample_rate), channels: Int(info.channels))
            let c = stb_vorbis_get_comment(v)
            var tags: [String: String] = [:]
            if let list = c.comment_list {
                for i in 0..<Int(c.comment_list_length) {
                    guard let line = list[i].map({ String(cString: $0) }), let eq = line.firstIndex(of: "=") else { continue }
                    let key = line[..<eq].uppercased()
                    if tags[key] == nil { tags[key] = String(line[line.index(after: eq)...]) }
                }
            }
            if !tags.isEmpty { onTags?(tags) }
        }
        guard let v = vorbis, let format = output else { return }
        while !vbuf.isEmpty {
            var ch: Int32 = 0, samples: Int32 = 0
            var out: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>?
            let used = vbuf.withUnsafeBufferPointer { stb_vorbis_decode_frame_pushdata(v, $0.baseAddress, Int32($0.count), &ch, &out, &samples) }
            if used == 0, samples == 0 { break }
            vbuf.removeFirst(min(Int(used), vbuf.count))
            guard samples > 0, let out, Int(ch) == Int(format.channelCount),
                  let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples)), let dst = b.floatChannelData else { continue }
            for c in 0..<Int(ch) {
                if let src = out[c] { memcpy(dst[c], src, Int(samples) * MemoryLayout<Float>.size) }
            }
            b.frameLength = AVAudioFrameCount(samples)
            emit(b)
        }
    }

    // MARK: Opus

    private func opusHead(_ p: Data) {
        let b = [UInt8](p)
        guard b.count >= 19 else { return failed = true }
        channels = Int(b[9])
        skip = Int(b[10]) | Int(b[11]) << 8
        let g = Int16(bitPattern: UInt16(b[16]) | UInt16(b[17]) << 8)
        gain = powf(10, Float(g) / 256 / 20)
        // more than two channels need a map of channels: not for a music player
        guard b[18] == 0, (1...2).contains(channels) else { return failed = true }
        announce("Opus", rate: 48000, channels: channels)
    }

    private func opusPage(_ page: Page) {
        for p in page.packets {
            headers += 1
            if headers == 1 { continue } // OpusHead, read already
            if headers == 2 {
                let tags = OggTags.parse(p, skip: 8)
                if !tags.isEmpty { onTags?(tags) }
                continue
            }
            opusPacket(p)
            if failed { return }
        }
    }

    /// How many samples (at 48 kHz) a packet holds, from its first byte.
    static func opusFrames(_ p: Data) -> UInt32 {
        guard let toc = p.first else { return 0 }
        let config = Int(toc >> 3)
        let size = config < 12 ? [480, 960, 1920, 2880][config & 3] : config < 16 ? [480, 960][config & 1] : [120, 240, 480, 960][config & 3]
        let count: Int
        switch toc & 3 {
        case 0: count = 1
        case 1, 2: count = 2
        default: count = p.count > 1 ? Int(p[p.startIndex + 1] & 0x3F) : 0
        }
        return UInt32(size * count)
    }

    private func opusPacket(_ p: Data) {
        let frames = Self.opusFrames(p)
        guard frames > 0, let output else { return }
        if converter == nil || frames != perPacket {
            var asbd = AudioStreamBasicDescription(mSampleRate: 48000, mFormatID: kAudioFormatOpus, mFormatFlags: 0, mBytesPerPacket: 0,
                                                   mFramesPerPacket: frames, mBytesPerFrame: 0, mChannelsPerFrame: UInt32(channels),
                                                   mBitsPerChannel: 0, mReserved: 0)
            guard let from = AVAudioFormat(streamDescription: &asbd), let c = AVAudioConverter(from: from, to: output) else {
                if !gotSound { failed = true }
                return
            }
            input = from
            converter = c
            perPacket = frames
        }
        guard let converter, let input else { return }
        let packed = AVAudioCompressedBuffer(format: input, packetCapacity: 1, maximumPacketSize: max(1, p.count))
        p.withUnsafeBytes { if let base = $0.baseAddress { memcpy(packed.data, base, p.count) } }
        packed.packetDescriptions?[0] = AudioStreamPacketDescription(mStartOffset: 0, mVariableFramesInPacket: 0, mDataByteSize: UInt32(p.count))
        packed.byteLength = UInt32(p.count)
        packed.packetCount = 1
        guard let out = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: frames + 960) else { return }
        var fed = false, error: NSError?
        let status = converter.convert(to: out, error: &error) { _, state in
            if fed {
                state.pointee = .noDataNow
                return nil
            }
            fed = true
            state.pointee = .haveData
            return packed
        }
        if status == .error {
            converter.reset()
            return
        }
        guard out.frameLength > 0 else { return }
        // the first samples only warm the decoder up
        if skip > 0 {
            let drop = min(skip, Int(out.frameLength))
            skip -= drop
            guard let tail = Self.tail(out, from: drop) else { return }
            if gain != 1 { Self.scale(tail, gain) }
            return emit(tail)
        }
        if gain != 1 { Self.scale(out, gain) }
        emit(out)
    }

    static func tail(_ b: AVAudioPCMBuffer, from: Int) -> AVAudioPCMBuffer? {
        let n = Int(b.frameLength) - from
        guard n > 0, let out = AVAudioPCMBuffer(pcmFormat: b.format, frameCapacity: AVAudioFrameCount(n)), let src = b.floatChannelData, let dst = out.floatChannelData else { return nil }
        for c in 0..<Int(b.format.channelCount) { memcpy(dst[c], src[c] + from, n * MemoryLayout<Float>.size) }
        out.frameLength = AVAudioFrameCount(n)
        return out
    }

    private static func scale(_ b: AVAudioPCMBuffer, _ k: Float) {
        guard let d = b.floatChannelData else { return }
        for c in 0..<Int(b.format.channelCount) {
            for i in 0..<Int(b.frameLength) { d[c][i] *= k }
        }
    }
}

// MARK: - Files

/// What the beginning and the end of an Ogg file tell without decoding it.
struct OggInfo {
    var codec: OggDecoder.Codec
    var rate: Double
    var channels: Int
    /// Samples of the whole song; nil when the end could not be read.
    var frames: Int?
    var tags: [String: String] = [:]

    var duration: Double { frames.map { Double($0) / rate } ?? 0 }

    /// A flow of the radio: the codec and the rate from its first page.
    static func sniff(_ d: Data) -> OggInfo? {
        var pages = OggPages()
        for page in pages.feed(d) where page.first {
            guard let p = page.packets.first else { continue }
            if let i = head(p) { return i }
        }
        return nil
    }

    private static func head(_ p: Data) -> OggInfo? {
        let b = [UInt8](p)
        if b.count >= 16, b[0] == 1, String(decoding: b[1..<7], as: UTF8.self) == "vorbis" {
            let rate = Int(b[12]) | Int(b[13]) << 8 | Int(b[14]) << 16 | Int(b[15]) << 24
            return OggInfo(codec: .vorbis, rate: Double(rate), channels: Int(b[11]))
        }
        if b.count >= 19, String(decoding: b[0..<8], as: UTF8.self) == "OpusHead" {
            return OggInfo(codec: .opus, rate: 48000, channels: Int(b[9]))
        }
        return nil
    }

    static func read(_ url: URL) -> OggInfo? {
        guard let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }
        var pages = OggPages(), info: OggInfo?, serial: UInt32 = 0, packets = 0, preSkip = 0
        // the tags come right after the first page; a cover inside them may take megabytes
        read: while let chunk = try? file.read(upToCount: 262_144), !chunk.isEmpty {
            for page in pages.feed(chunk) {
                if info == nil, page.first, let p = page.packets.first, let i = head(p) {
                    info = i
                    serial = page.serial
                    if i.codec == .opus { preSkip = Int(p[p.startIndex + 10]) | Int(p[p.startIndex + 11]) << 8 }
                }
                guard let i = info, page.serial == serial else { continue }
                for p in page.packets {
                    packets += 1
                    if packets == 2 {
                        info?.tags = OggTags.parse(p, skip: i.codec == .opus ? 8 : 7)
                        break read
                    }
                }
            }
            if (try? file.offset()) ?? 0 > 16_000_000 { break }
        }
        guard var i = info else { return nil }
        // the last page tells how many samples there are
        let size = (try? file.seekToEnd()) ?? 0
        let tailSize = min(size, 131_072)
        try? file.seek(toOffset: size - tailSize)
        if let tail = try? file.read(upToCount: Int(tailSize)) {
            var last = OggPages()
            let granule = last.feed(tail).filter { $0.serial == serial && $0.granule > 0 }.last?.granule
            if let granule { i.frames = max(0, Int(granule) - preSkip) }
        }
        return i
    }

    /// Tags, length and cover the same way MetadataReader gives them for other files.
    static func meta(_ url: URL) -> TrackMeta? {
        guard let i = read(url) else { return nil }
        var m = TrackMeta()
        func tag(_ keys: String...) -> String? {
            for k in keys { if let v = i.tags[k]?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty { return v } }
            return nil
        }
        m.title = tag("TITLE")
        m.artist = tag("ARTIST", "ALBUMARTIST", "PERFORMER")
        m.album = tag("ALBUM")
        m.trackNo = tag("TRACKNUMBER").flatMap { Int($0.prefix { $0.isNumber }) }
        m.lyrics = tag("LYRICS", "UNSYNCEDLYRICS")
        m.artwork = OggTags.picture(i.tags).flatMap { MetadataReader.downscale($0) }
        m.duration = i.duration
        m.header.ext = i.codec == .opus ? "OPUS" : "OGG"
        m.header.size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        m.header.sampleRate = i.rate
        m.header.vbr = true
        if m.duration > 0 { m.header.kbps = (Double(m.header.size) * 8 / m.duration / 1000).rounded() }
        return m
    }
}

/// iOS does not open Ogg files: a song is decoded once into the cache (Apple Lossless) and played from there.
enum OggFile {
    static let extensions: Set<String> = ["ogg", "oga", "opus"]
    /// The cache stays under this size; the songs not played for the longest go first.
    static let budget = 2_000_000_000

    static func handles(_ path: String) -> Bool { extensions.contains((path as NSString).pathExtension.lowercased()) }

    static var folder: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Decoded", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func cached(_ id: UUID) -> URL? {
        let u = folder.appendingPathComponent(id.uuidString + ".caf")
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    /// The file itself, or its decoded copy; decodes right now when there is none yet.
    static func playable(_ url: URL, id: UUID) throws -> URL {
        guard handles(url.path) else { return url }
        if let c = cached(id) {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: c.path)
            return c
        }
        let dest = folder.appendingPathComponent(id.uuidString + ".caf")
        try decode(url, to: dest)
        prune(keeping: dest)
        return dest
    }

    /// Without decoding: nil when the song still has to be decoded.
    static func ready(_ url: URL, id: UUID) -> URL? {
        handles(url.path) ? cached(id) : url
    }

    enum Failure: LocalizedError {
        case unreadable
        var errorDescription: String? { tr("не удалось разобрать файл OGG") }
    }

    static func decode(_ url: URL, to dest: URL) throws {
        let info = OggInfo.read(url)
        let d = OggDecoder()
        d.limit = info?.frames
        let tmp = dest.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".caf")
        var out: AVAudioFile?, writeError: Error?
        d.onSound = { b in
            guard writeError == nil else { return }
            do {
                if out == nil {
                    let settings: [String: Any] = [AVFormatIDKey: kAudioFormatAppleLossless, AVSampleRateKey: b.format.sampleRate,
                                                   AVNumberOfChannelsKey: b.format.channelCount, AVEncoderBitDepthHintKey: 16]
                    out = try AVAudioFile(forWriting: tmp, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
                }
                try out?.write(from: b)
            } catch {
                writeError = error
            }
        }
        guard let file = try? FileHandle(forReadingFrom: url) else { throw Failure.unreadable }
        defer { try? file.close() }
        while let chunk = try? file.read(upToCount: 262_144), !chunk.isEmpty, !d.failed, writeError == nil {
            d.parse(chunk)
        }
        out = nil // closes the file
        guard d.gotSound, writeError == nil else {
            try? FileManager.default.removeItem(at: tmp)
            throw writeError ?? Failure.unreadable
        }
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmp, to: dest)
    }

    static func prune(keeping: URL) {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let all = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys) else { return }
        var items = all.compactMap { u -> (URL, Int, Date)? in
            guard let v = try? u.resourceValues(forKeys: Set(keys)) else { return nil }
            return (u, v.fileSize ?? 0, v.contentModificationDate ?? .distantPast)
        }
        var total = items.reduce(0) { $0 + $1.1 }
        items.sort { $0.2 < $1.2 }
        for (u, size, _) in items where total > budget && u != keeping {
            try? FileManager.default.removeItem(at: u)
            total -= size
        }
    }

    static func forget(_ id: UUID) {
        if let c = cached(id) { try? FileManager.default.removeItem(at: c) }
    }
}
