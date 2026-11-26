import AVFoundation
import MediaPlayer
import UIKit
import WidgetKit

/// Playback position, published separately so that the whole screen does not redraw four times a second.
@MainActor
final class PlaybackClock: ObservableObject {
    @Published var time: Double = 0
}

enum RepeatMode: String { case off, all, one }

/// Queue, transport, crossfade, sleep timer and the lock screen. The sound itself is in AudioGraph.
@MainActor
final class Player: ObservableObject {
    @Published private(set) var queue: [UUID] = []
    @Published private(set) var qi = -1
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: Double = 0
    @Published private(set) var shuffle = false
    @Published private(set) var repeatMode = RepeatMode.off
    @Published private(set) var sleepAt: Date?
    @Published private(set) var sleepAfterTrack = false
    /// Set while the radio is on (or paused); the queue of songs waits meanwhile.
    @Published private(set) var radio: Station?
    let live: Radio
    let extras: RadioExtras
    private var radioList: [UUID] = []
    private let stations: Stations
    private let headphones: Headphones

    let clock = PlaybackClock()
    let graph = AudioGraph()
    let analyzer: Analyzer

    private let library: Library
    private let settings: Settings
    private let stats: Stats
    private let covers: CoverFinder
    private let nowPlaying = NowPlaying()

    private var orig: [UUID] = []
    private var active = 0
    private var savedTime: Double = 0
    private var timer: Timer?
    private var resumeAfterInterruption = false
    private var failures = 0
    private var fadeTask: Task<Void, Never>?
    private var sleepFade: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var lastSave = Date.distantPast
    private var chainIndex: Int?
    private var chainTried: UUID?
    private var chainGain: Task<Void, Never>?
    /// An Ogg song being decoded before it can play.
    private var decoding: Task<Void, Never>?

    private var deck: Deck { graph.decks[active] }
    private var spare: Deck { graph.decks[1 - active] }

    init(library: Library, settings: Settings, stats: Stats, covers: CoverFinder, stations: Stations, headphones: Headphones) {
        self.stations = stations
        self.headphones = headphones
        live = Radio(graph: graph)
        extras = RadioExtras(covers: covers, settings: settings)
        self.library = library
        self.settings = settings
        self.stats = stats
        self.covers = covers
        analyzer = Analyzer(library: library)
        graph.apply(settings.v)
        settings.onChange = { [weak self] in self?.settingsChanged() }
        graph.correct(headphones.active, direct: settings.v.direct)
        headphones.onChange = { [weak self] in
            guard let self else { return }
            self.graph.correct(self.headphones.active, direct: self.settings.v.direct)
        }
        library.onRemove = { [weak self] in self?.removed($0) }
        analyzer.onDone = { [weak self] in self?.analyzed($0) }
        covers.onChange = { [weak self] in self?.publish() }
        for d in graph.decks {
            d.onEnd = { [weak self, weak d] in
                guard let self, let d, d === self.deck else { return }
                self.ended()
            }
            d.onChained = { [weak self, weak d] in
                guard let self, let d, d === self.deck else { return }
                self.chained()
            }
        }
        live.onInfo = { [weak self] in self?.matchRadio($0) }
        live.onFacts = { [weak self] f in
            guard let self, let s = self.radio else { return }
            self.stations.learn(s.id, f)
        }
        live.onTitle = { [weak self] in self?.radioTitleChanged() }
        extras.onChange = { [weak self] in if self?.radio != nil { self?.publish() } }
        live.onEnd = { [weak self] in self?.radioEnded($0) }
        stations.onChange = { [weak self] in self?.stationsChanged() }
        Logos.shared.onChange = { [weak self] in if self?.radio != nil { self?.publish() } }
        observe()
        restore()
        PlayerBridge.toggle = { [weak self] in self?.toggle() }
        PlayerBridge.next = { [weak self] in self?.next() }
        PlayerBridge.previous = { [weak self] in self?.previous() }
        PlayerBridge.nextPreset = { [weak self] in self?.settings.nextPreset() }
        publishWidget()
    }

    /// The song; none while the radio is on.
    var current: Track? { radio == nil ? queued : nil }
    private var queued: Track? { qi >= 0 && qi < queue.count ? library.track(queue[qi]) : nil }

    /// Exact position, for the waveform that moves every frame.
    var position: Double { deck.file == nil ? savedTime : deck.position }

    // MARK: - A-B repeat

    /// A part of the song played round and round: A is marked first, then B.
    @Published private(set) var loopA: Double?
    @Published private(set) var loopB: Double?
    private var loopJump: DispatchWorkItem?

    /// One button: the start, then the end, then off.
    func markLoop() {
        guard radio == nil, current != nil, duration > 0 else { return }
        let now = position
        if loopB != nil {
            clearLoop()
            toast(tr("Повтор отрезка выключен"))
            return
        }
        guard let a = loopA else {
            loopA = now
            toast(tr("Начало отрезка: {}. Нажмите ещё раз в конце", formatTime(now)))
            return
        }
        // went back before A: the two marks change places
        let start = min(a, now), end = min(max(a, now), duration - 0.05)
        guard end - start >= 1 else {
            toast(tr("Отрезок слишком короткий, нужна хотя бы секунда"))
            return
        }
        loopA = start
        loopB = end
        toast(tr("Повтор отрезка {}–{}", formatTime(start), formatTime(end)))
        Haptic.tap()
        seek(to: start)
    }

    func clearLoop() {
        loopJump?.cancel()
        loopJump = nil
        loopA = nil
        loopB = nil
    }

    /// The timer comes five times a second: the exact jump is set up when B is near.
    private func checkLoop() {
        guard let a = loopA, let b = loopB, isPlaying, radio == nil else { return }
        let left = (b - position) / settings.v.effectiveRate
        if left <= 0.02 { return jumpLoop(a) }
        guard left < 0.3, loopJump == nil else { return }
        let w = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.loopJump = nil
                if self.loopB == b, self.loopA == a, self.isPlaying { self.jumpLoop(a) }
            }
        }
        loopJump = w
        DispatchQueue.main.asyncAfter(deadline: .now() + left, execute: w)
    }

    private func jumpLoop(_ a: Double) {
        loopJump?.cancel()
        loopJump = nil
        seek(to: a)
    }

    // MARK: - Queue

    func play(_ id: UUID, from list: [UUID]) {
        orig = list
        if shuffle {
            queue = [id] + list.filter { $0 != id }.shuffled()
            qi = 0
        } else {
            queue = list
            qi = list.firstIndex(of: id) ?? 0
        }
        failures = 0
        load(play: true)
    }

    func jump(to index: Int) {
        guard queue.indices.contains(index) else { return }
        qi = index
        failures = 0
        load(play: true)
    }

    func playShuffled(_ list: [UUID]) {
        guard let first = list.randomElement() else { return }
        shuffle = true
        play(first, from: list)
    }

    func playNext(_ id: UUID) {
        dropChain()
        guard qi >= 0, !queue.isEmpty else { play(id, from: [id]); return }
        let after = queue[qi]
        queue.insert(id, at: qi + 1)
        orig.insert(id, at: (orig.firstIndex(of: after) ?? orig.count - 1) + 1)
        toast(tr("Сыграет следующей"))
        save()
    }

    func enqueue(_ id: UUID) {
        dropChain()
        queue.append(id)
        orig.append(id)
        toast(tr("Добавлено в очередь"))
        save()
    }

    func move(from: IndexSet, to: Int) {
        dropChain()
        let playing = qi >= 0 ? qi : nil
        var marked = queue.enumerated().map { ($0.offset, $0.element) }
        marked.move(fromOffsets: from, toOffset: to)
        queue = marked.map(\.1)
        if let playing { qi = marked.firstIndex { $0.0 == playing } ?? -1 }
        if !shuffle { orig = queue }
        save()
    }

    func removeFromQueue(at index: Int) {
        guard queue.indices.contains(index), index != qi else { return }
        dropChain()
        let id = queue.remove(at: index)
        if let i = orig.firstIndex(of: id) { orig.remove(at: i) }
        if index < qi { qi -= 1 }
        save()
    }

    func toggleShuffle() {
        dropChain()
        shuffle.toggle()
        let now = qi >= 0 && qi < queue.count ? queue[qi] : nil
        if shuffle {
            orig = queue
            if let now {
                queue = [now] + queue.filter { $0 != now }.shuffled()
                qi = 0
            } else {
                queue.shuffle()
            }
        } else if !orig.isEmpty {
            queue = orig
            qi = now.flatMap { orig.firstIndex(of: $0) } ?? -1
        }
        toast(shuffle ? tr("Перемешивание включено") : tr("Перемешивание выключено"))
        save()
    }

    func cycleRepeat() {
        dropChain()
        repeatMode = repeatMode == .off ? .all : repeatMode == .all ? .one : .off
        toast(tr("Повтор: ") + (repeatMode == .off ? tr("выключен") : repeatMode == .all ? tr("вся очередь") : tr("один трек")))
        save()
    }

    private func removed(_ ids: Set<UUID>) {
        dropChain()
        let now = qi >= 0 && qi < queue.count ? queue[qi] : nil
        queue.removeAll { ids.contains($0) }
        orig.removeAll { ids.contains($0) }
        if let now, ids.contains(now) {
            if radio == nil {
                pause()
                endFade()
                deck.unload()
            }
            qi = -1
            savedTime = 0
            duration = 0
            clock.time = 0
            publish()
        } else {
            qi = now.flatMap { queue.firstIndex(of: $0) } ?? -1
        }
        save()
    }

    // MARK: - Transport

    func toggle() { isPlaying ? pause() : resume() }

    func resume() {
        guard !isPlaying else { return }
        if radio != nil { return startRadio() }
        guard current != nil else {
            if let first = library.tracks.first {
                play(first.id, from: library.tracks.map(\.id))
            } else {
                toast(tr("Сначала добавьте музыку: «Песни» → «+»"))
            }
            return
        }
        sleepFade?.cancel()
        sleepFade = nil
        graph.master = 1
        if deck.file == nil {
            load(play: true, at: savedTime)
            return
        }
        startDeck(at: deck.position)
    }

    private func startDeck(at time: Double) {
        forgetChain()
        if settings.v.matchRate, fadeTask == nil { graph.matchOutput(to: deck) }
        do { try graph.start() } catch {
            toast(tr("Не удалось включить звук: {}", "\(error.localizedDescription)"))
            isPlaying = false
            publish()
            return
        }
        deck.play(from: time)
        isPlaying = true
        // iOS ignores lock screen buttons registered before any sound plays, so this happens here
        nowPlaying.registerCommands(for: self)
        startTimer()
        publish()
    }

    func pause() {
        endFade()
        forgetChain()
        guard isPlaying else { return }
        live.stop()
        deck.halt()
        graph.engine.pause()
        isPlaying = false
        stopTimer()
        if radio == nil { clock.time = position }
        publish()
        save()
    }

    func next() {
        if radio != nil { step(1) } else { advance(auto: false) }
    }

    private func advance(auto: Bool) {
        guard !queue.isEmpty else { return }
        if auto, repeatMode == .one {
            startDeck(at: 0)
            return
        }
        if qi + 1 < queue.count {
            qi += 1
        } else if repeatMode == .all || !auto {
            qi = 0
        } else {
            pause()
            deck.rewind(to: 0)
            clock.time = 0
            publish()
            return
        }
        load(play: true)
    }

    /// Nothing before this song: the first one in the queue, unless the whole queue repeats.
    private var atStart: Bool { qi <= 0 && (repeatMode != .all || queue.count < 2) }

    /// The swipe. At the start of the queue the song goes on playing; returns false then.
    @discardableResult
    func previousTrack() -> Bool {
        if radio != nil {
            step(-1)
            return true
        }
        guard !queue.isEmpty else { return false }
        if atStart {
            toast(tr("Это начало списка"))
            return false
        }
        qi = qi > 0 ? qi - 1 : queue.count - 1
        load(play: true)
        return true
    }

    /// The button: back to the start of the song first, then to the previous one.
    func previous() {
        if radio != nil { return step(-1) }
        if position > 3 || atStart { seek(to: 0) } else { previousTrack() }
    }

    func seek(to time: Double) {
        guard radio == nil else { return }
        let t = max(0, min(time, max(0, duration)))
        endFade()
        forgetChain()
        if deck.file == nil {
            savedTime = t
        } else if isPlaying {
            deck.play(from: t)
        } else {
            deck.rewind(to: t)
        }
        clock.time = t
        publish()
        save()
    }

    private func load(play: Bool, at time: Double = 0) {
        closeRadio()
        clearLoop()
        guard let t = current else { return }
        endFade()
        forgetChain()
        deck.unload()
        duration = t.duration
        savedTime = time
        clock.time = time
        decoding?.cancel()
        if OggFile.handles(t.path), OggFile.cached(t.id) == nil, let access = library.open(t) {
            // the first time an Ogg song is decoded aside, so the screen does not stop meanwhile
            let id = t.id
            decoding = Task { [weak self] in
                let ok = await Task.detached(priority: .userInitiated) { (try? OggFile.playable(access.url, id: id)) != nil }.value
                guard let self, !Task.isCancelled, self.current?.id == id else { return }
                if ok { self.load(play: play, at: time) } else { self.markBad(t, OggFile.Failure.unreadable) }
            }
            return
        }
        do {
            try graph.load(library.open(t), t, into: deck)
        } catch {
            markBad(t, error)
            return
        }
        prepare(deck, t)
        duration = deck.duration
        if abs(t.duration - deck.duration) > 0.5 { library.update(t.id) { $0.duration = self.deck.duration } }
        failures = 0
        let start = time >= duration - 0.5 ? 0 : time
        deck.rewind(to: start)
        clock.time = start
        if play {
            startDeck(at: start)
        } else {
            publish()
        }
        save()
    }

    private func prepare(_ d: Deck, _ t: Track) {
        d.fade = 1
        d.gainDb = settings.v.effectiveNormalize ? (t.gainDb ?? 0) : 0
        stats.trackStarted()
        if t.bad == true { library.update(t.id) { $0.bad = false } }
        analyzer.request(t, first: true)
        covers.auto(t)
        if qi + 1 < queue.count, let n = library.track(queue[qi + 1]) {
            covers.auto(n)
            // its silence is found before it comes
            analyzer.request(n, first: false)
            // the next Ogg song is decoded in advance, then it follows without a gap
            if OggFile.handles(n.path), OggFile.cached(n.id) == nil, let a = library.open(n) {
                let id = n.id
                Task.detached(priority: .utility) { _ = try? OggFile.playable(a.url, id: id) }
            }
        }
    }

    private func markBad(_ t: Track, _ error: Error) {
        deck.halt()
        library.update(t.id) { $0.bad = true }
        toast("«\(t.title)»: \(error is OpenError ? error.localizedDescription : tr("не удалось открыть файл"))")
        failures += 1
        let wasPlaying = isPlaying
        if wasPlaying, queue.count > 1, failures < queue.count, qi + 1 < queue.count {
            let here = qi
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.2))
                guard let self, self.qi == here else { return }
                self.qi += 1
                self.load(play: true)
            }
        } else {
            isPlaying = false
            stopTimer()
        }
        publish()
    }

    private func ended() {
        // the end of the song is B: round again
        if let a = loopA, loopB != nil, current != nil {
            deck.play(from: a)
            clock.time = a
            return
        }
        stats.flush()
        if sleepAfterTrack {
            sleepAfterTrack = false
            pause()
            deck.rewind(to: 0)
            clock.time = 0
            toast(tr("Таймер сна: воспроизведение остановлено"))
            return
        }
        advance(auto: true)
    }

    // MARK: - Radio

    func play(_ s: Station, from list: [UUID]) {
        clearLoop()
        if radio == nil {
            // the song goes on from here later
            savedTime = position
            endFade()
            forgetChain()
            deck.unload()
            stats.flush()
        }
        radio = s
        radioList = list
        startRadio()
    }

    private func startRadio() {
        guard let s = radio else { return }
        guard let url = URL(string: s.url) else { return radioEnded(tr("Это не похоже на ссылку")) }
        sleepFade?.cancel()
        sleepFade = nil
        graph.master = 1
        live.stop()
        applyGraph()
        deck.fade = 1
        deck.gainDb = 0
        do { try graph.start() } catch {
            return radioEnded(error.localizedDescription)
        }
        isPlaying = true
        clock.time = 0
        live.start(url, on: deck)
        nowPlaying.registerCommands(for: self)
        startTimer()
        publish()
        save()
    }

    /// Back to the songs: the last one stays paused where it was.
    func leaveRadio() {
        guard radio != nil else { return }
        pause()
        closeRadio()
        duration = current?.duration ?? 0
        clock.time = savedTime
        publish()
        save()
    }

    private func closeRadio() {
        guard radio != nil else { return }
        live.stop()
        radio = nil
        applyGraph()
    }

    private func step(_ by: Int) {
        let list = radioList.filter { stations.station($0) != nil }
        guard let now = radio, !list.isEmpty else { return }
        let i = list.firstIndex(of: now.id) ?? 0
        if let s = stations.station(list[(i + by + list.count) % list.count]) { play(s, from: radioList) }
    }

    /// The place of the station in its list, from 1.
    var radioPlace: (Int, Int)? {
        guard let now = radio else { return nil }
        let list = radioList.filter { stations.station($0) != nil }
        return list.firstIndex(of: now.id).map { ($0 + 1, list.count) }
    }

    private func matchRadio(_ rate: Double) {
        guard settings.v.matchRate else { return }
        graph.matchOutput(rate: rate)
        try? graph.start()
    }

    private func radioTitleChanged() {
        if sleepAfterTrack, live.state == .playing {
            sleepAfterTrack = false
            pause()
            toast(tr("Таймер сна: воспроизведение остановлено"))
        }
        publish()
    }

    /// The station went silent for good; `why` is nil at the end of a file on a server.
    private func radioEnded(_ why: String?) {
        guard let s = radio else { return }
        stations.problems[s.id] = why
        if let why { toast("«\(s.name)»: \(why)") }
        if isPlaying {
            pause()
        } else {
            publish()
            save()
        }
    }

    private func stationsChanged() {
        guard let now = radio else { return }
        if let s = stations.station(now.id) {
            if s != now { radio = s }
            publish()
        } else {
            leaveRadio()
        }
    }

    /// Radio cannot play faster than it comes.
    private func applyGraph() {
        var v = settings.v
        if radio != nil { v.rate = 1 }
        graph.apply(v)
        live.reserve = v.radioBuffer
    }

    // MARK: - No gaps

    /// Shortly before the end puts the next song right behind the current one. Skipped when the formats differ
    /// (then the song is loaded the usual way) and when crossfade is on.
    private func maybeChain() {
        guard settings.v.gapless, settings.v.crossfade == 0, isPlaying, chainIndex == nil, !sleepAfterTrack, loopB == nil,
              queue.indices.contains(qi), duration - deck.position < 10, chainTried != queue[qi] else { return }
        chainTried = queue[qi]
        let ni = repeatMode == .one ? qi : qi + 1 < queue.count ? qi + 1 : repeatMode == .all ? 0 : -1
        guard ni >= 0, let t = library.track(queue[ni]), t.bad != true, let access = library.open(t), let url = OggFile.ready(access.url, id: t.id),
              let file = try? AVAudioFile(forReading: url), deck.chain(access, file, t) else { return }
        chainIndex = ni
        guard settings.v.effectiveNormalize, let gain = t.gainDb else { return }
        // the callback comes when the old song is heard to its end; the loudness has to change when the new one is mixed
        let wait = (duration - deck.position) / settings.v.effectiveRate
        chainGain = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, wait)))
            if !Task.isCancelled { self?.deck.gainDb = gain }
        }
    }

    private func chained() {
        guard let ni = chainIndex, queue.indices.contains(ni), let t = library.track(queue[ni]) else {
            forgetChain()
            load(play: true)
            return
        }
        forgetChain()
        stats.flush()
        qi = ni
        prepare(deck, t)
        duration = deck.duration
        clock.time = deck.position
        publish()
        save()
    }

    private func forgetChain() {
        chainGain?.cancel()
        chainGain = nil
        chainIndex = nil
        chainTried = nil
    }

    /// The order has changed while the next song was already scheduled: play the rest of this one anew.
    private func dropChain() {
        guard chainIndex != nil else {
            chainTried = nil
            return
        }
        forgetChain()
        deck.play(from: deck.position)
        applyLoudness()
    }

    // MARK: - Crossfade

    private func maybeCrossfade() {
        let xf = settings.v.crossfade
        guard xf > 0, isPlaying, fadeTask == nil, !sleepAfterTrack, repeatMode != .one, !queue.isEmpty, loopB == nil else { return }
        guard duration >= xf * 2 + 4 else { return }
        let left = (duration - deck.position) / settings.v.effectiveRate
        guard left <= xf, left > 0.4 else { return }
        let ni = qi + 1 < queue.count ? qi + 1 : (repeatMode == .all ? 0 : -1)
        guard ni >= 0, let t = library.track(queue[ni]), t.bad != true else { return }

        let old = deck, new = spare
        do { try graph.load(library.open(t), t, into: new) } catch { return } // the song just ends normally
        stats.flush()
        prepareNext(new, t, index: ni)
        new.fade = 0
        new.play(from: 0)
        publish()
        let length = max(0.5, left)
        fadeTask = Task { [weak self] in
            let t0 = Date()
            while !Task.isCancelled {
                let k = min(1, Date().timeIntervalSince(t0) / length)
                old.fade = Float(1 - k)
                new.fade = Float(k)
                if k >= 1 { break }
                try? await Task.sleep(for: .milliseconds(25))
            }
            guard !Task.isCancelled else { return }
            old.unload()
            old.fade = 1
            self?.fadeTask = nil
        }
    }

    private func prepareNext(_ d: Deck, _ t: Track, index: Int) {
        active = 1 - active
        qi = index
        prepare(d, t)
        duration = d.duration
        clock.time = 0
        save()
    }

    private func endFade() {
        guard let task = fadeTask else { return }
        task.cancel()
        fadeTask = nil
        spare.unload()
        spare.fade = 1
        deck.fade = 1
    }

    // MARK: - Sleep timer

    func sleep(minutes: Int?) {
        sleepAfterTrack = false
        sleepAt = minutes.map { Date().addingTimeInterval(Double($0) * 60) }
    }

    func sleepAfterThisTrack() {
        dropChain()
        sleepAt = nil
        sleepAfterTrack = true
    }

    private func checkSleep() {
        guard let at = sleepAt, at <= Date(), sleepFade == nil else { return }
        sleepAt = nil
        sleepFade = Task { [weak self] in
            for i in 0..<80 {
                try? await Task.sleep(for: .milliseconds(50))
                if Task.isCancelled { return }
                self?.graph.master = Float(1 - Double(i + 1) / 80)
            }
            guard let self else { return }
            self.sleepFade = nil
            self.pause()
            self.graph.master = 1
            toast(tr("Таймер сна: воспроизведение остановлено"))
        }
    }

    // MARK: - Settings, analysis, lock screen

    private func settingsChanged() {
        applyGraph()
        if settings.v.crossfade > 0 || !settings.v.gapless { dropChain() }
        applyLoudness()
        publish()
    }

    private func applyLoudness() {
        deck.gainDb = settings.v.effectiveNormalize ? (current?.gainDb ?? 0) : 0
    }

    private func analyzed(_ id: UUID) {
        if current?.id == id { applyLoudness() }
    }

    /// The profile of the headphones that is heard now.
    var headphoneProfile: String? { settings.v.direct ? nil : headphones.active?.name }

    /// The decoded song, before anything else happens to it.
    var sourceFormat: AVAudioFormat? {
        radio == nil ? deck.file?.processingFormat : AVAudioFormat(standardFormatWithSampleRate: live.info.rate, channels: AVAudioChannelCount(max(1, live.info.channels)))
    }

    func publish() {
        extras.update(radio == nil ? nil : live.artistAndSong)
        if let s = radio {
            let song = live.artistAndSong, image = extras.cover ?? Logos.shared.image(s)
            let title = song?.title ?? s.name, artist = song.map { $0.artist.isEmpty ? s.name : $0.artist } ?? tr("Радио")
            nowPlaying.update(station: s.name, title: title, artist: artist, artwork: image, playing: isPlaying)
            updateWidget(title, artist, image, "\(s.id)")
            return
        }
        let t = current
        let image = t.flatMap { $0.hasArtwork ? ArtworkStore.image(for: $0.id) : nil }
        nowPlaying.update(track: t, artwork: image, elapsed: position, duration: duration, rate: isPlaying ? settings.v.effectiveRate : 0)
        updateWidget(t?.title ?? "", t?.artist ?? "", image, t.map { "\($0.id)" } ?? "")
    }

    private var widgetState = WidgetState.load()

    private func updateWidget(_ title: String, _ artist: String, _ image: UIImage?, _ key: String) {
        var s = WidgetState()
        s.title = title
        s.artist = artist
        s.playing = isPlaying
        s.accent = settings.v.accent
        s.lang = Lang.current.rawValue
        s.preset = settings.presetName
        if !key.isEmpty, let image { s.coverVersion = "\(key) \(ObjectIdentifier(image).hashValue)" }
        guard s != widgetState else { return }
        if s.coverVersion != widgetState.coverVersion { WidgetState.saveCover(image) }
        widgetState = s
        s.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// At the start: the widget only, the lock screen still belongs to another app.
    private func publishWidget() {
        if let s = radio { return updateWidget(s.name, tr("Радио"), Logos.shared.image(s), "\(s.id)") }
        let t = current
        updateWidget(t?.title ?? "", t?.artist ?? "", t.flatMap { $0.hasArtwork ? ArtworkStore.image(for: $0.id) : nil }, t.map { "\($0.id)" } ?? "")
    }

    // MARK: - Session

    func save() {
        let d = UserDefaults.standard
        d.set(radio?.id.uuidString, forKey: "session.radio")
        d.set(radioList.map(\.uuidString), forKey: "session.radioList")
        lastSave = Date()
        d.set(queue.map(\.uuidString), forKey: "session.queue")
        d.set(orig.map(\.uuidString), forKey: "session.orig")
        d.set(qi, forKey: "session.qi")
        d.set(position, forKey: "session.time")
        d.set(shuffle, forKey: "session.shuffle")
        d.set(repeatMode.rawValue, forKey: "session.repeat")
    }

    private func restore() {
        let d = UserDefaults.standard
        func ids(_ key: String) -> [UUID] { (d.stringArray(forKey: key) ?? []).compactMap(UUID.init(uuidString:)).filter { library.track($0) != nil } }
        let saved = d.stringArray(forKey: "session.queue") ?? []
        let savedIndex = d.object(forKey: "session.qi") as? Int ?? -1
        queue = ids("session.queue")
        orig = ids("session.orig")
        shuffle = d.bool(forKey: "session.shuffle")
        repeatMode = RepeatMode(rawValue: d.string(forKey: "session.repeat") ?? "") ?? .off
        if saved.indices.contains(savedIndex), let id = UUID(uuidString: saved[savedIndex]), let i = queue.firstIndex(of: id) {
            qi = saved.count == queue.count ? savedIndex : i
            savedTime = d.double(forKey: "session.time")
            duration = current?.duration ?? 0
            clock.time = savedTime
            if let t = current { analyzer.request(t, first: true) }
        }
        radioList = (d.stringArray(forKey: "session.radioList") ?? []).compactMap(UUID.init(uuidString:))
        radio = stations.station(d.string(forKey: "session.radio").flatMap(UUID.init(uuidString:)))
    }

    // MARK: - Interruptions and the timer

    private func observe() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let info = note.userInfo
            let type = (info?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            let options = AVAudioSession.InterruptionOptions(rawValue: info?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            MainActor.assumeIsolated { self?.interruption(type, options) }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
            // headphones unplugged or Bluetooth gone: pause, like every player does
            if AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable {
                MainActor.assumeIsolated { self?.pause() }
            }
        })
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: graph.engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.outputChanged() }
        })
    }

    private func interruption(_ type: AVAudioSession.InterruptionType?, _ options: AVAudioSession.InterruptionOptions) {
        switch type {
        case .began?:
            if isPlaying {
                resumeAfterInterruption = true
                pause()
            }
        case .ended?:
            if resumeAfterInterruption, options.contains(.shouldResume) { resume() }
            resumeAfterInterruption = false
        default:
            break
        }
    }

    /// The output changed (e.g. AirPods connected): the engine stopped, go on from the same place.
    private func outputChanged() {
        guard isPlaying, !graph.engine.isRunning else { return }
        if radio != nil { return startRadio() }
        let t = clock.time
        endFade()
        deck.halt()
        isPlaying = false
        deck.rewind(to: t)
        startDeck(at: t)
    }

    private func startTimer() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        stats.flush()
    }

    private func tick() {
        guard isPlaying else { return }
        if radio != nil {
            live.tick()
            if live.state == .playing { clock.time += 0.2 }
            checkSleep()
            return
        }
        clock.time = position
        if let t = current { stats.tick(t) }
        checkLoop()
        maybeCrossfade()
        maybeChain()
        checkSleep()
        if Date().timeIntervalSince(lastSave) > 5 { save() }
    }
}
