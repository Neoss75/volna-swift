import AVFoundation
import Foundation
import Network

/// Plays one station through a deck of the player: keeps a store of sound, connects again when the connection is lost.
@MainActor
final class Radio: ObservableObject {
    enum State: Equatable { case idle, connecting, buffering, playing, waiting }

    @Published private(set) var state = State.idle
    @Published private(set) var info = StreamInfo()
    /// What the station says is playing now.
    @Published private(set) var title = ""
    /// Seconds of sound in store.
    @Published private(set) var stored: Double = 0

    var onInfo: ((Double) -> Void)?
    var onTitle: (() -> Void)?
    var onEnd: ((String?) -> Void)?

    private let graph: AudioGraph
    private var deck: Deck?
    private var reader: SoundSource?
    /// The link turned out to be a broadcast in pieces.
    private var pieces = false
    private var link: URL?
    private var format: AVAudioFormat?
    private var hops = 0
    private var lostSince: Date?
    private var tries = 0
    private var retry: Task<Void, Never>?
    private var finished = false
    /// More than a minute of sound is in store already.
    private var held = false
    /// Grows after every stop caused by a slow network.
    private var need = 2.0
    /// How much the user wants in store before the sound starts.
    var reserve = 2.0 { didSet { if reserve != oldValue { reserveChanged() } } }
    /// What is being waited for now.
    var target: Double { need }
    private let monitor = NWPathMonitor()
    private var online = true

    static let giveUp = 150.0

    init(graph: AudioGraph) {
        self.graph = graph
        monitor.pathUpdateHandler = { [weak self] path in
            let ok = path.status == .satisfied
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.network(ok) } }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    var artistAndSong: (artist: String, title: String)? {
        guard !title.isEmpty else { return nil }
        guard let (a, t) = SongReading.splitDash(title) else { return ("", title) }
        return (a.trimmingCharacters(in: .whitespaces), t.trimmingCharacters(in: .whitespaces))
    }

    /// The engine must be running.
    func start(_ url: URL, on deck: Deck) {
        stop()
        self.deck = deck
        link = url
        info = StreamInfo()
        title = ""
        hops = 0
        pieces = false
        tries = 0
        need = reserve
        lostSince = Date()
        state = .connecting
        connect(url)
    }

    func stop() {
        retry?.cancel()
        retry = nil
        reader?.stop()
        reader = nil
        deck?.unload()
        deck = nil
        format = nil
        finished = false
        held = false
        stored = 0
        state = .idle
    }

    private func connect(_ url: URL) {
        retry?.cancel()
        retry = nil
        reader?.stop()
        let take: @MainActor (StreamReader.Event) -> Void = { [weak self] in self?.handle($0) }
        let r: SoundSource
        if pieces || StationList.isHLS(url.absoluteString) {
            r = HLSReader(url, reserve: reserve, onEvent: take)
        } else {
            r = StreamReader(url, onEvent: take)
        }
        reader = r
        r.start()
    }

    private func handle(_ e: StreamReader.Event) {
        guard let deck else { return }
        switch e {
        case .info(let i):
            info = i
            guard let f = AVAudioFormat(standardFormatWithSampleRate: i.rate, channels: AVAudioChannelCount(max(1, i.channels))) else { return }
            if f != format {
                format = f
                onInfo?(i.rate)
                graph.openStream(f, into: deck)
                if state == .playing { state = .buffering }
            }
        case .sound(let b):
            lostSince = nil
            tries = 0
            deck.feed(b)
            tick()
        case .title(let t):
            guard t != title else { return }
            title = t
            onTitle?()
        case .list(let text):
            hops += 1
            if StationList.isStream(text), hops < 4, let link {
                pieces = true
                return connect(link)
            }
            guard hops < 4, let s = StationList.parse(text).stations.first, let url = URL(string: s.url) else { return fail(.notRadio) }
            link = url
            connect(url)
        case .end(nil):
            finished = true // a file on a server: play what is left
            reader = nil
        case .end(let error?):
            reader?.stop()
            reader = nil
            lost(error)
        }
    }

    private func lost(_ error: StreamError) {
        if error.final { return fail(error) }
        if lostSince == nil { lostSince = Date() }
        // nothing has been heard yet and the network is fine: the address is wrong, no point in trying for long
        let patience = format == nil ? 20 : Self.giveUp
        if Date().timeIntervalSince(lostSince ?? Date()) > patience { return fail(error) }
        if state != .playing { state = .waiting }
        tries += 1
        let delay = min(10, pow(1.7, Double(tries - 1)) * 0.5)
        retry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, let link = self.link else { return }
            self.retry = nil
            if self.state == .waiting { self.state = .connecting }
            self.connect(link)
        }
    }

    private func fail(_ error: StreamError) {
        let text = error.text
        stop()
        onEnd?(text)
    }

    /// Back from a tunnel, or from Wi-Fi to the mobile network: do not wait for the next try.
    private func network(_ ok: Bool) {
        defer { online = ok }
        guard ok, !online, retry != nil, let link else { return }
        tries = 0
        if state == .waiting { state = .connecting }
        connect(link)
    }

    /// A bigger store is collected at once: a live broadcast does not come faster than it plays, so the sound has to wait.
    private func reserveChanged() {
        need = reserve
        guard state == .playing, !finished, let deck, deck.queued < need - 0.5 else { return }
        deck.pauseStream()
        state = .buffering
    }

    func tick() {
        guard let deck, format != nil else { return }
        let have = deck.queued
        if abs(have - stored) >= 0.2 { stored = have }
        if have > 60 { held = true } else if have < 30 { held = false }
        reader?.hold(held)
        switch state {
        case .playing:
            guard have < 0.12 else { return }
            if finished {
                stop()
                onEnd?(nil)
                return
            }
            deck.pauseStream()
            need = max(reserve, min(6, need + 1.5))
            state = reader == nil ? .waiting : .buffering
        case .connecting, .buffering, .waiting:
            guard have >= need || finished && have > 0, graph.engine.isRunning else { return }
            deck.playStream()
            state = .playing
        case .idle:
            break
        }
    }
}
