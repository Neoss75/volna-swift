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

    private var deck: Deck { graph.decks[active] }
    private var spare: Deck { graph.decks[1 - active] }

    init(library: Library, settings: Settings, stats: Stats, covers: CoverFinder) {
        self.library = library
        self.settings = settings
        self.stats = stats
        self.covers = covers
        analyzer = Analyzer(library: library)
        graph.apply(settings.v)
        settings.onChange = { [weak self] in self?.settingsChanged() }
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
        observe()
        restore()
        PlayerBridge.toggle = { [weak self] in self?.toggle() }
        PlayerBridge.next = { [weak self] in self?.next() }
        PlayerBridge.previous = { [weak self] in self?.previous() }
        updateWidget(current, current.flatMap { $0.hasArtwork ? ArtworkStore.image(for: $0.id) : nil })
    }

    var current: Track? { qi >= 0 && qi < queue.count ? library.track(queue[qi]) : nil }

    /// Exact position, for the waveform that moves every frame.
    var position: Double { deck.file == nil ? savedTime : deck.position }

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
        toast("Сыграет следующей")
        save()
    }

    func enqueue(_ id: UUID) {
        dropChain()
        queue.append(id)
        orig.append(id)
        toast("Добавлено в очередь")
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
        toast(shuffle ? "Перемешивание включено" : "Перемешивание выключено")
        save()
    }

    func cycleRepeat() {
        dropChain()
        repeatMode = repeatMode == .off ? .all : repeatMode == .all ? .one : .off
        toast("Повтор: " + (repeatMode == .off ? "выключен" : repeatMode == .all ? "вся очередь" : "один трек"))
        save()
    }

    private func removed(_ ids: Set<UUID>) {
        dropChain()
        let now = qi >= 0 && qi < queue.count ? queue[qi] : nil
        queue.removeAll { ids.contains($0) }
        orig.removeAll { ids.contains($0) }
        if let now, ids.contains(now) {
            pause()
            endFade()
            deck.unload()
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
        guard current != nil else {
            if let first = library.tracks.first {
                play(first.id, from: library.tracks.map(\.id))
            } else {
                toast("Сначала добавьте музыку: «Песни» → «+»")
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
            toast("Не удалось включить звук: \(error.localizedDescription)")
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
        deck.halt()
        graph.engine.pause()
        isPlaying = false
        stopTimer()
        clock.time = deck.position
        publish()
        save()
    }

    func next() { advance(auto: false) }

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

    func previousTrack() {
        guard !queue.isEmpty else { return }
        qi = qi > 0 ? qi - 1 : queue.count - 1 // from the first to the last, as next() goes from the last to the first
        load(play: true)
    }

    func previous() {
        if position > 3 { seek(to: 0) } else { previousTrack() }
    }

    func seek(to time: Double) {
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
        guard let t = current else { return }
        endFade()
        forgetChain()
        deck.unload()
        duration = t.duration
        savedTime = time
        clock.time = time
        do {
            try graph.load(library.open(t), into: deck)
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
        if qi + 1 < queue.count, let n = library.track(queue[qi + 1]) { covers.auto(n) }
    }

    private func markBad(_ t: Track, _ error: Error) {
        deck.halt()
        library.update(t.id) { $0.bad = true }
        toast("«\(t.title)»: \(error is OpenError ? error.localizedDescription : "не удалось открыть файл")")
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
        stats.flush()
        if sleepAfterTrack {
            sleepAfterTrack = false
            pause()
            deck.rewind(to: 0)
            clock.time = 0
            toast("Таймер сна: воспроизведение остановлено")
            return
        }
        advance(auto: true)
    }

    // MARK: - No gaps

    /// Shortly before the end puts the next song right behind the current one. Skipped when the formats differ
    /// (then the song is loaded the usual way) and when crossfade is on.
    private func maybeChain() {
        guard settings.v.gapless, settings.v.crossfade == 0, isPlaying, chainIndex == nil, !sleepAfterTrack,
              queue.indices.contains(qi), duration - deck.position < 10, chainTried != queue[qi] else { return }
        chainTried = queue[qi]
        let ni = repeatMode == .one ? qi : qi + 1 < queue.count ? qi + 1 : repeatMode == .all ? 0 : -1
        guard ni >= 0, let t = library.track(queue[ni]), t.bad != true, let access = library.open(t),
              let file = try? AVAudioFile(forReading: access.url), deck.chain(access, file) else { return }
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
        guard xf > 0, isPlaying, fadeTask == nil, !sleepAfterTrack, repeatMode != .one, !queue.isEmpty else { return }
        guard duration >= xf * 2 + 4 else { return }
        let left = (duration - deck.position) / settings.v.effectiveRate
        guard left <= xf, left > 0.4 else { return }
        let ni = qi + 1 < queue.count ? qi + 1 : (repeatMode == .all ? 0 : -1)
        guard ni >= 0, let t = library.track(queue[ni]), t.bad != true else { return }

        let old = deck, new = spare
        do { try graph.load(library.open(t), into: new) } catch { return } // the song just ends normally
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
            toast("Таймер сна: воспроизведение остановлено")
        }
    }

    // MARK: - Settings, analysis, lock screen

    private func settingsChanged() {
        graph.apply(settings.v)
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

    func publish() {
        let t = current
        let image = t.flatMap { $0.hasArtwork ? ArtworkStore.image(for: $0.id) : nil }
        nowPlaying.update(track: t, artwork: image, elapsed: position, duration: duration, rate: isPlaying ? settings.v.effectiveRate : 0)
        updateWidget(t, image)
    }

    private var widgetState = WidgetState.load()

    private func updateWidget(_ t: Track?, _ image: UIImage?) {
        var s = WidgetState()
        s.title = t?.title ?? ""
        s.artist = t?.artist ?? ""
        s.playing = isPlaying
        s.accent = settings.v.accent
        if let t, let image { s.coverVersion = "\(t.id) \(ObjectIdentifier(image).hashValue)" }
        guard s != widgetState else { return }
        if s.coverVersion != widgetState.coverVersion { WidgetState.saveCover(image) }
        widgetState = s
        s.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Session

    func save() {
        let d = UserDefaults.standard
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
        clock.time = position
        if let t = current { stats.tick(t) }
        maybeCrossfade()
        maybeChain()
        checkSleep()
        if Date().timeIntervalSince(lastSave) > 5 { save() }
    }
}
