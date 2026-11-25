import AudioToolbox
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
        case .hls: tr("потоки HLS (.m3u8) пока не поддерживаются")
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
final class StreamReader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
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
    private var gotSound = false

    private var icy = IcySplitter(interval: 0)

    private var stream: AudioFileStreamID?
    private var input: AVAudioFormat?
    private var converter: AVAudioConverter?

    @MainActor
    init(_ url: URL, onEvent: @escaping @MainActor (Event) -> Void) {
        self.url = url
        self.onEvent = onEvent
        super.init()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
    }

    deinit { if let stream { AudioFileStreamClose(stream) } }

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
            icy = IcySplitter(interval: header("icy-metaint").flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0)
            info.kbps = header("icy-br")?.split(separator: ",").first.flatMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            info.name = header("icy-name").map(Self.repair)
            open(type)
        }
        completionHandler(ended ? .cancel : .allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !ended else { return }
        if kind == .list {
            listData.append(data)
            let text = StationList.text(listData)
            if StationList.isStream(text) { return finish(.hls) }
            if listData.count > 2_000_000 { finish(.notRadio) }
            return
        }
        received += data.count
        for part in icy.feed(data) {
            switch part {
            case .sound(let d): parse(d)
            case .title(let t): send(.title(t))
            }
        }
        if !gotSound, received > 400_000 { finish(.format) }
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
        let hint: AudioFileTypeID = type.contains("aac") ? kAudioFileAAC_ADTSType : type.contains("mpeg") || type.contains("mp3") ? kAudioFileMP3Type : 0
        let me = Unmanaged.passUnretained(self).toOpaque()
        AudioFileStreamOpen(me, { me, _, property, _ in
            Unmanaged<StreamReader>.fromOpaque(me).takeUnretainedValue().property(property)
        }, { me, _, count, data, packets in
            Unmanaged<StreamReader>.fromOpaque(me).takeUnretainedValue().packets(Int(count), data, packets)
        }, hint, &stream)
        if stream == nil { finish(.format) }
    }

    private func parse(_ d: Data) {
        guard let stream, !d.isEmpty else { return }
        let status = d.withUnsafeBytes { p in
            p.baseAddress.map { AudioFileStreamParseBytes(stream, UInt32(d.count), $0, []) } ?? noErr
        }
        if status != noErr, !gotSound { finish(.format) }
    }

    private func property(_ id: AudioFileStreamPropertyID) {
        guard id == kAudioFileStreamProperty_ReadyToProducePackets, let stream else { return }
        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout.size(ofValue: asbd))
        guard AudioFileStreamGetProperty(stream, kAudioFileStreamProperty_DataFormat, &size, &asbd) == noErr else { return finish(.format) }
        // AAC+ is described as plain AAC first; the list names the full version, the best one first
        var listSize: UInt32 = 0
        if AudioFileStreamGetPropertyInfo(stream, kAudioFileStreamProperty_FormatList, &listSize, nil) == noErr, listSize > 0 {
            var list = [AudioFormatListItem](repeating: AudioFormatListItem(), count: Int(listSize) / MemoryLayout<AudioFormatListItem>.stride)
            if AudioFileStreamGetProperty(stream, kAudioFileStreamProperty_FormatList, &listSize, &list) == noErr,
               let best = list.first(where: { [kAudioFormatMPEG4AAC_HE_V2, kAudioFormatMPEG4AAC_HE].contains($0.mASBD.mFormatID) }) {
                asbd = best.mASBD
            }
        }
        guard asbd.mSampleRate > 0, asbd.mFormatID != kAudioFormatLinearPCM,
              let from = AVAudioFormat(streamDescription: &asbd),
              let to = AVAudioFormat(standardFormatWithSampleRate: asbd.mSampleRate, channels: max(1, asbd.mChannelsPerFrame)),
              let c = AVAudioConverter(from: from, to: to) else { return finish(.format) }
        var cookieSize: UInt32 = 0
        if AudioFileStreamGetPropertyInfo(stream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, nil) == noErr, cookieSize > 0 {
            var cookie = Data(count: Int(cookieSize))
            let ok = cookie.withUnsafeMutableBytes { AudioFileStreamGetProperty(stream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, $0.baseAddress!) }
            if ok == noErr { c.magicCookie = cookie }
        }
        input = from
        converter = c
        info.kind = Self.name(asbd.mFormatID)
        info.rate = asbd.mSampleRate
        info.channels = Int(asbd.mChannelsPerFrame)
        if info.kbps == nil {
            var rate: UInt32 = 0
            size = 4
            if AudioFileStreamGetProperty(stream, kAudioFileStreamProperty_BitRate, &size, &rate) == noErr, rate > 0 {
                info.kbps = rate < 1000 ? Double(rate) : (Double(rate) / 1000).rounded()
            }
        }
        send(.info(info))
    }

    private static func name(_ id: AudioFormatID) -> String {
        switch id {
        case kAudioFormatMPEGLayer3: "MP3"
        case kAudioFormatMPEGLayer2: "MP2"
        case kAudioFormatMPEG4AAC: "AAC"
        case kAudioFormatMPEG4AAC_HE, kAudioFormatMPEG4AAC_HE_V2: "AAC+"
        case kAudioFormatFLAC: "FLAC"
        default: "AUDIO"
        }
    }

    private func packets(_ count: Int, _ data: UnsafeRawPointer, _ descriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?) {
        guard let converter, let input, let descriptions, count > 0 else { return }
        let sizes = (0..<count).map { Int(descriptions[$0].mDataByteSize) }
        let packed = AVAudioCompressedBuffer(format: input, packetCapacity: AVAudioPacketCount(count), maximumPacketSize: max(1, sizes.max() ?? 1))
        guard let to = packed.packetDescriptions else { return }
        var offset = 0
        for i in 0..<count {
            memcpy(packed.data + offset, data + Int(descriptions[i].mStartOffset), sizes[i])
            to[i] = AudioStreamPacketDescription(mStartOffset: Int64(offset), mVariableFramesInPacket: 0, mDataByteSize: UInt32(sizes[i]))
            offset += sizes[i]
        }
        packed.byteLength = UInt32(offset)
        packed.packetCount = AVAudioPacketCount(count)

        let perPacket = input.streamDescription.pointee.mFramesPerPacket
        let capacity = AVAudioFrameCount(max(perPacket, 1152)) * AVAudioFrameCount(count + 2)
        var fed = false
        while let out = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) {
            var error: NSError?
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
                converter.reset() // a damaged piece: go on with the next one
                return
            }
            if out.frameLength > 0 {
                gotSound = true
                send(.sound(out))
            }
            if status != .haveData || out.frameLength == 0 { return }
        }
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
