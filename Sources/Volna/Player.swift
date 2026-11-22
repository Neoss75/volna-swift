import AVFoundation
import MediaPlayer
import UIKit

/// Playback position, published separately so that the song list does not redraw four times a second.
@MainActor
final class PlaybackClock: ObservableObject {
    @Published var time: Double = 0
}

struct EQPreset: Identifiable {
    let name: String
    let gains: [Float]
    var id: String { name }

    static let all: [EQPreset] = [
        EQPreset(name: "Ровно", gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        EQPreset(name: "Басы", gains: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]),
        EQPreset(name: "Громкость", gains: [5, 4, 2, 0, -1, -1, 0, 2, 4, 5]),
        EQPreset(name: "Вокал", gains: [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1]),
        EQPreset(name: "Высокие", gains: [0, 0, 0, 0, 0, 1, 2, 4, 5, 6]),
        EQPreset(name: "Рок", gains: [4, 3, 1, -1, -2, -1, 1, 3, 4, 4]),
        EQPreset(name: "Электроника", gains: [5, 4, 1, 0, -2, 1, 0, 1, 4, 5]),
    ]
}

/// Plays one file at a time through AVAudioEngine: player → 10-band EQ → mixer → output.
@MainActor
final class Player: ObservableObject {
    static let frequencies: [Float] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    static let bandLabels = ["31", "62", "125", "250", "500", "1к", "2к", "4к", "8к", "16к"]
    static let gainRange: ClosedRange<Float> = -12...12

    @Published private(set) var currentID: UUID?
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: Double = 0
    @Published var errorMessage: String?
    @Published var eqEnabled: Bool { didSet { applyEQ(); saveEQ() } }
    @Published var eqGains: [Float] { didSet { applyEQ(); saveEQ() } }

    let clock = PlaybackClock()
    private(set) var currentTime: Double = 0 { didSet { clock.time = currentTime } }

    private let library: Library
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 10)
    private let nowPlaying = NowPlaying()

    private var file: AVAudioFile?
    private var scopedURL: URL?
    private var connectedFormat: AVAudioFormat?
    private var startFrame: AVAudioFramePosition = 0
    private var scheduled = false
    private var generation = 0
    private var timer: Timer?
    private var resumeAfterInterruption = false
    private var observers: [NSObjectProtocol] = []

    private enum Keys {
        static let eqOn = "eq.enabled"
        static let eqGains = "eq.gains"
        static let lastTrack = "player.lastTrack"
        static let lastTime = "player.lastTime"
    }

    init(library: Library) {
        self.library = library
        let defaults = UserDefaults.standard
        eqEnabled = defaults.object(forKey: Keys.eqOn) as? Bool ?? true
        if let saved = defaults.array(forKey: Keys.eqGains) as? [Double], saved.count == 10 {
            eqGains = saved.map { Float($0) }
        } else {
            eqGains = Array(repeating: 0, count: 10)
        }
        setUpEngine()
        observeSystem()
        restoreState()
    }

    var currentTrack: Track? {
        guard let id = currentID else { return nil }
        return library.tracks.first { $0.id == id }
    }

    private var currentIndex: Int? {
        guard let id = currentID else { return nil }
        return library.tracks.firstIndex { $0.id == id }
    }

    // MARK: - Controls

    func play(_ track: Track) {
        if track.id == currentID, file != nil {
            if !isPlaying { resume() }
            return
        }
        start(track, at: 0, autoplay: true)
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func resume() {
        guard file != nil else {
            // nothing loaded yet (fresh launch): open the last song, or the first one
            if let track = currentTrack {
                start(track, at: currentTime, autoplay: true)
            } else if let first = library.tracks.first {
                start(first, at: 0, autoplay: true)
            }
            return
        }
        guard !isPlaying else { return }
        activateSession()
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                errorMessage = "Не удалось включить звук: \(error.localizedDescription)"
                return
            }
        }
        if !scheduled { schedule(from: currentTime) }
        node.play()
        isPlaying = true
        // iOS ignores lock screen buttons registered before any sound plays, so this happens here
        nowPlaying.registerCommands(for: self)
        startTimer()
        publishNowPlaying()
    }

    func pause() {
        guard isPlaying else { return }
        currentTime = livePosition()
        stopNode()
        engine.pause()
        isPlaying = false
        stopTimer()
        publishNowPlaying()
        saveState()
    }

    func next() {
        step(1, autoplay: isPlaying)
    }

    func previous() {
        if livePosition() > 3 {
            seek(to: 0)
        } else {
            step(-1, autoplay: isPlaying)
        }
    }

    func seek(to time: Double) {
        let t = max(0, min(time, duration))
        guard file != nil else { currentTime = t; return }
        if isPlaying {
            stopNode()
            currentTime = t
            schedule(from: t)
            node.play()
        } else {
            stopNode()
            currentTime = t
        }
        publishNowPlaying()
    }

    func saveState() {
        let defaults = UserDefaults.standard
        defaults.set(currentID?.uuidString, forKey: Keys.lastTrack)
        defaults.set(livePosition(), forKey: Keys.lastTime)
    }

    // MARK: - Loading and scheduling

    private func step(_ delta: Int, autoplay: Bool) {
        let tracks = library.tracks
        guard !tracks.isEmpty else { return }
        var i = (currentIndex ?? (delta > 0 ? -1 : 0)) + delta
        if i >= tracks.count { i = 0 }
        if i < 0 { i = tracks.count - 1 }
        start(tracks[i], at: 0, autoplay: autoplay)
    }

    private func trackEnded() {
        let tracks = library.tracks
        if let i = currentIndex, i + 1 < tracks.count {
            start(tracks[i + 1], at: 0, autoplay: true)
        } else if let first = tracks.first {
            start(first, at: 0, autoplay: false) // end of the list: stop on the first song
        } else {
            pause()
        }
    }

    private func start(_ track: Track, at time: Double, autoplay: Bool) {
        stopNode()
        releaseFile()
        currentID = track.id
        duration = track.duration
        currentTime = time

        guard let url = library.resolve(track) else {
            fail("Файл «\(track.title)» не найден. Возможно, его переместили или удалили в «Файлах». Уберите песню из списка и добавьте заново.")
            return
        }
        let access = url.startAccessingSecurityScopedResource()
        do {
            let f = try AVAudioFile(forReading: url)
            file = f
            scopedURL = access ? url : nil
            duration = Double(f.length) / f.processingFormat.sampleRate
            connect(f.processingFormat)
        } catch {
            if access { url.stopAccessingSecurityScopedResource() }
            fail("Не получается открыть «\(track.title)»: \(error.localizedDescription)")
            return
        }
        if currentTime >= duration - 0.5 { currentTime = 0 }

        if autoplay {
            isPlaying = false
            resume()
        } else {
            if isPlaying {
                isPlaying = false
                engine.pause()
                stopTimer()
            }
            publishNowPlaying()
        }
        saveState()
    }

    private func fail(_ message: String) {
        isPlaying = false
        stopTimer()
        if engine.isRunning { engine.pause() }
        errorMessage = message
        publishNowPlaying()
    }

    private func schedule(from time: Double) {
        guard let f = file else { return }
        generation += 1
        let gen = generation
        let rate = f.processingFormat.sampleRate
        let frame = min(max(AVAudioFramePosition(time * rate), 0), f.length)
        startFrame = frame
        scheduled = true
        let count = f.length - frame
        guard count > 0 else {
            Task { @MainActor [weak self] in self?.segmentFinished(gen) }
            return
        }
        node.scheduleSegment(f, startingFrame: frame, frameCount: AVAudioFrameCount(count), at: nil,
                             completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.segmentFinished(gen) }
        }
    }

    private func segmentFinished(_ gen: Int) {
        // stale callbacks (after a seek, pause or track change) carry an older generation
        guard gen == generation, isPlaying else { return }
        trackEnded()
    }

    private func stopNode() {
        generation += 1
        node.stop()
        scheduled = false
    }

    private func releaseFile() {
        file = nil
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
    }

    private func livePosition() -> Double {
        guard isPlaying, let f = file,
              let renderTime = node.lastRenderTime,
              let playerTime = node.playerTime(forNodeTime: renderTime) else { return currentTime }
        let t = Double(startFrame + playerTime.sampleTime) / f.processingFormat.sampleRate
        return min(max(t, 0), duration)
    }

    // MARK: - Engine and EQ

    private func setUpEngine() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        engine.attach(node)
        engine.attach(eq)
        for (i, band) in eq.bands.enumerated() {
            band.filterType = .parametric
            band.frequency = Self.frequencies[i]
            band.bandwidth = 1.0 // octaves
            band.bypass = false
        }
        applyEQ()
        if let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2) {
            connect(format)
        }
        engine.prepare()
    }

    /// The chain is rebuilt with the song's own format, so the file is played as is
    /// and only the mixer converts it to what the speaker or headphones want.
    private func connect(_ format: AVAudioFormat) {
        if let current = connectedFormat, current == format { return }
        if engine.isRunning { engine.stop() }
        engine.disconnectNodeOutput(node)
        engine.disconnectNodeOutput(eq)
        engine.connect(node, to: eq, format: format)
        engine.connect(eq, to: engine.mainMixerNode, format: format)
        connectedFormat = format
    }

    private func applyEQ() {
        for (i, band) in eq.bands.enumerated() where i < eqGains.count {
            band.gain = eqGains[i]
        }
        eq.bypass = !eqEnabled
        // when bands are raised, the whole sound is lowered by the same amount so it does not distort
        eq.globalGain = eqEnabled ? -max(0, eqGains.max() ?? 0) : 0
    }

    private func saveEQ() {
        let defaults = UserDefaults.standard
        defaults.set(eqEnabled, forKey: Keys.eqOn)
        defaults.set(eqGains.map { Double($0) }, forKey: Keys.eqGains)
    }

    private func restoreState() {
        let defaults = UserDefaults.standard
        guard let raw = defaults.string(forKey: Keys.lastTrack), let id = UUID(uuidString: raw),
              let track = library.tracks.first(where: { $0.id == id }) else { return }
        currentID = id
        duration = track.duration
        currentTime = defaults.double(forKey: Keys.lastTime)
    }

    // MARK: - Audio session, interruptions, timer

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    private func observeSystem() {
        let center = NotificationCenter.default

        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let info = note.userInfo
            let type = (info?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            let options = AVAudioSession.InterruptionOptions(rawValue: info?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            MainActor.assumeIsolated { self?.handleInterruption(type, options) }
        })

        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
            let reason = AVAudioSession.RouteChangeReason(rawValue: raw)
            // headphones unplugged or Bluetooth gone: pause, like every player does
            if reason == .oldDeviceUnavailable {
                MainActor.assumeIsolated { self?.pause() }
            }
        })

        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleEngineReset() }
        })
    }

    private func handleInterruption(_ type: AVAudioSession.InterruptionType?, _ options: AVAudioSession.InterruptionOptions) {
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

    private func handleEngineReset() {
        // the output changed (e.g. AirPods connected): the engine stopped, start again from the same place
        guard isPlaying else { return }
        currentTime = livePosition()
        stopNode()
        isPlaying = false
        stopTimer()
        resume()
    }

    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        currentTime = livePosition()
    }

    private func publishNowPlaying() {
        let track = currentTrack
        let image = track.flatMap { $0.hasArtwork ? ArtworkStore.image(for: $0.id) : nil }
        nowPlaying.update(track: track, artwork: image, elapsed: livePosition(), duration: duration, playing: isPlaying)
    }
}
