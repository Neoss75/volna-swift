import AVFoundation
import AudioToolbox

/// One player of the two: node → fade (and conversion of the song's format) → speed → loudness → shared chain. Two decks make the crossfade possible.
@MainActor
final class Deck {
    let node = AVAudioPlayerNode()
    let pitch = AVAudioUnitTimePitch()
    let mixer = AVAudioMixerNode()
    let gain = AVAudioUnitEQ(numberOfBands: 1)

    fileprivate(set) var file: AVAudioFile?
    fileprivate var access: FileAccess?
    fileprivate var format: AVAudioFormat?
    /// The part of the file that is this song: all of it, or a piece named by a .cue sheet.
    fileprivate(set) var first: AVAudioFramePosition = 0
    fileprivate(set) var count: AVAudioFramePosition = 0
    private var startFrame: AVAudioFramePosition = 0
    private var generation = 0
    private(set) var scheduled = false
    private(set) var running = false
    private var rest: Double = 0
    private var segment = 0
    private var framesQueued: AVAudioFramePosition = 0
    private var following: (file: AVAudioFile, access: FileAccess, first: AVAudioFramePosition, count: AVAudioFramePosition)?

    var onEnd: (() -> Void)?
    /// The song scheduled with `chain` has begun.
    var onChained: (() -> Void)?

    var duration: Double {
        guard let f = file else { return 0 }
        return Double(count) / f.processingFormat.sampleRate
    }

    var fade: Float = 1 { didSet { mixer.outputVolume = fade } }
    var gainDb: Double = 0 { didSet { gain.globalGain = Float(gainDb) } }

    /// Every successful reading is remembered: another app (a video, a call) stops the engine before it tells us,
    /// and a stopped engine does not know the place any more.
    var position: Double {
        guard running, node.engine?.isRunning == true, let f = file, let rt = node.lastRenderTime, rt.isSampleTimeValid,
              let pt = node.playerTime(forNodeTime: rt) else { return rest }
        rest = min(max(Double(startFrame + pt.sampleTime) / f.processingFormat.sampleRate, 0), duration)
        return rest
    }

    /// Starts from `time`; the engine must be running.
    func play(from time: Double) {
        guard let f = file else { return }
        halt()
        // a player node crashes the app when started while the engine is stopped (e.g. the output just changed)
        guard node.engine?.isRunning == true else {
            rest = time
            return
        }
        generation += 1
        let gen = generation
        let frame = min(max(AVAudioFramePosition(time * f.processingFormat.sampleRate), 0), count)
        startFrame = frame
        rest = time
        let left = count - frame
        framesQueued = left
        segment = 0
        guard left > 0 else {
            Task { @MainActor [weak self] in self?.finished(gen, 0) }
            running = true
            return
        }
        node.scheduleSegment(f, startingFrame: first + frame, frameCount: AVAudioFrameCount(left), at: nil,
                             completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.finished(gen, 0) }
        }
        node.play()
        running = true
    }

    /// Stops and remembers the position.
    func halt() {
        rest = position
        generation += 1
        node.stop()
        queued = 0
        running = false
        following = nil
    }

    func rewind(to time: Double) { rest = time }

    /// Puts the next song right behind the current one, with no gap. Only possible when both have the same format.
    func chain(_ access: FileAccess, _ next: AVAudioFile, _ t: Track) -> Bool {
        let part = Self.part(of: next, t)
        guard running, following == nil, let f = file, part.count > 0, next.processingFormat == f.processingFormat else { return false }
        following = (next, access, part.first, part.count)
        let gen = generation, seg = segment + 1
        node.scheduleSegment(next, startingFrame: part.first, frameCount: AVAudioFrameCount(part.count), at: nil,
                             completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.finished(gen, seg) }
        }
        return true
    }

    /// Settings → Playback: silence at the start and the end of a song is skipped.
    static var trimSilence = true

    static func part(of f: AVAudioFile, _ t: Track?) -> (first: AVAudioFramePosition, count: AVAudioFramePosition) {
        guard let t else { return (0, f.length) }
        let rate = f.processingFormat.sampleRate
        var from = t.cueStart ?? 0, to = t.cueEnd ?? Double(f.length) / rate
        // only a real pause is cut, and never most of the song
        if trimSilence, let s = t.soundStart, let e = t.soundEnd, e - s > 1 {
            let length = to - from
            if e < length - 0.3 { to = from + e }
            if s > 0.2 { from += s }
        }
        let first = min(AVAudioFramePosition((from * rate).rounded()), f.length)
        let end = min(AVAudioFramePosition((to * rate).rounded()), f.length)
        return (first, max(0, end - first))
    }

    private func finished(_ gen: Int, _ seg: Int) {
        guard gen == generation, seg == segment, running else { return } // stale callbacks carry an older generation
        guard let next = following else {
            onEnd?()
            return
        }
        following = nil
        segment += 1
        startFrame = -framesQueued
        framesQueued += next.count
        file = next.file
        first = next.first
        count = next.count
        access = next.access
        rest = 0
        onChained?()
    }

    // MARK: Sound that comes in pieces (radio)

    /// Seconds of sound given to the node and not heard yet.
    private(set) var queued: Double = 0

    func feed(_ b: AVAudioPCMBuffer) {
        guard b.format == format else { return }
        let gen = generation, seconds = Double(b.frameLength) / b.format.sampleRate
        queued += seconds
        node.scheduleBuffer(b, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == gen else { return }
                self.queued = max(0, self.queued - seconds)
            }
        }
    }

    func playStream() {
        guard node.engine?.isRunning == true else { return }
        node.play()
    }

    func pauseStream() { node.pause() }

    func unload() {
        halt()
        file = nil
        access = nil
        rest = 0
    }
}

enum OpenError: LocalizedError {
    case notFound
    var errorDescription: String? { tr("файл не найден: его переместили или удалили в «Файлах»") }
}

@MainActor
final class AudioGraph {
    static let frequencies: [Double] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    static let labels = ["31", "62", "125", "250", "500", "1k", "2k", "4k", "8k", "16k+"]
    static let lowShelf = 45.0, highShelf = 12000.0, bassShelf = 90.0

    let engine = AVAudioEngine()
    let decks = [Deck(), Deck()]
    let tap = VizTap()
    private let bus = AVAudioMixerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 11)
    /// The correction of the headphones, before the equaliser.
    private let correction = AVAudioUnitEQ(numberOfBands: HeadphoneProfile.maxFilters)
    private var corrected = false
    private let limiter = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
        componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_PeakLimiter,
        componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
    private let out = AVAudioMixerNode()
    private var busFormat: AVAudioFormat?
    /// The rate the shared part of the chain works at.
    var rate: Double { busFormat?.sampleRate ?? 0 }

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        for d in decks {
            engine.attach(d.node)
            engine.attach(d.pitch)
            engine.attach(d.mixer)
            engine.attach(d.gain)
            d.gain.bands[0].bypass = true
        }
        engine.attach(bus)
        engine.attach(correction)
        correction.bypass = true
        engine.attach(eq)
        engine.attach(limiter)
        engine.attach(out)
        for i in 0..<11 {
            let b = eq.bands[i]
            switch i {
            case 0: b.filterType = .lowShelf; b.frequency = Float(Self.lowShelf)
            case 9: b.filterType = .highShelf; b.frequency = Float(Self.highShelf)
            case 10: b.filterType = .lowShelf; b.frequency = Float(Self.bassShelf)
            default: b.filterType = .parametric; b.frequency = Float(Self.frequencies[i]); b.bandwidth = 1
            }
            b.bypass = false
        }
        rebuild()
    }

    /// The shared part of the chain runs at the rate of the current output (speaker, headphones, Bluetooth).
    func rebuild(rate: Double? = nil) {
        let hw = rate ?? AVAudioSession.sharedInstance().sampleRate
        guard let format = AVAudioFormat(standardFormatWithSampleRate: hw > 0 ? hw : 44100, channels: 2) else { return }
        if busFormat == format { return }
        tap.remove(from: limiter)
        engine.stop() // also when only paused: a paused engine refuses a chain with another sample rate and the app crashes
        for (i, d) in decks.enumerated() {
            for n in [d.mixer, d.pitch, d.gain] as [AVAudioNode] { engine.disconnectNodeOutput(n) }
            engine.connect(d.mixer, to: d.pitch, format: format)
            engine.connect(d.pitch, to: d.gain, format: format)
            engine.connect(d.gain, to: bus, fromBus: 0, toBus: i, format: format)
            if d.format == nil { connect(d, format) }
        }
        for n in [bus, correction, eq, limiter, out, engine.mainMixerNode] as [AVAudioNode] { engine.disconnectNodeOutput(n) }
        engine.connect(bus, to: correction, format: format)
        engine.connect(correction, to: eq, format: format)
        engine.connect(eq, to: limiter, format: format)
        engine.connect(limiter, to: out, format: format)
        connectOut(format)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)
        busFormat = format
        tap.install(on: limiter)
        engine.prepare()
    }

    /// Mono: the last link carries one channel, the output puts it into both ears.
    private(set) var mono = false

    func setMono(_ on: Bool) {
        guard on != mono else { return }
        mono = on
        if let f = busFormat { connectOut(f) }
    }

    private func connectOut(_ format: AVAudioFormat) {
        engine.disconnectNodeOutput(out)
        let one = mono ? AVAudioFormat(standardFormatWithSampleRate: format.sampleRate, channels: 1) : nil
        engine.connect(out, to: engine.mainMixerNode, format: one ?? format)
    }

    /// Channels on the way to the output now.
    var outChannels: AVAudioChannelCount { out.outputFormat(forBus: 0).channelCount }

    private func connect(_ d: Deck, _ format: AVAudioFormat) {
        if let f = d.format, f == format { return }
        // only this link changes from song to song: a mixer takes any sample rate and folds surround down to stereo
        engine.disconnectNodeOutput(d.node)
        engine.connect(d.node, to: d.mixer, format: format)
        d.format = format
    }

    func load(_ access: FileAccess?, _ t: Track, into d: Deck) throws {
        d.unload()
        guard let access else { throw OpenError.notFound }
        if !FileManager.default.fileExists(atPath: access.url.path) {
            // an iCloud file that is not on the phone yet: ask for it, it will open next time
            try? FileManager.default.startDownloadingUbiquitousItem(at: access.url)
        }
        let f = try AVAudioFile(forReading: OggFile.playable(access.url, id: t.id))
        d.access = access
        d.file = f
        (d.first, d.count) = Deck.part(of: f, t)
        connect(d, f.processingFormat)
    }

    /// The deck will get its sound in pieces of this format.
    func openStream(_ format: AVAudioFormat, into d: Deck) {
        d.unload()
        connect(d, format)
    }

    private var askedRate: (rate: Double, port: String)?

    /// Wired digital outputs (USB DAC, HDMI) can run at the song's own rate; the speaker and Bluetooth cannot.
    static var digitalPort: AVAudioSessionPortDescription? {
        AVAudioSession.sharedInstance().currentRoute.outputs.first { [.usbAudio, .HDMI, .thunderbolt].contains($0.portType) }
    }

    /// Asks the DAC for the song's sample rate, so that nothing is resampled on the way.
    func matchOutput(to d: Deck) {
        if let rate = d.file?.processingFormat.sampleRate { matchOutput(rate: rate) }
    }

    func matchOutput(rate: Double) {
        guard let port = Self.digitalPort else { return }
        let session = AVAudioSession.sharedInstance()
        guard abs(session.sampleRate - rate) > 1 else { return }
        if let asked = askedRate, asked.rate == rate, asked.port == port.uid { return } // this DAC cannot do it
        askedRate = (rate, port.uid)
        engine.stop()
        try? session.setPreferredSampleRate(rate)
        try? session.setActive(true)
        rebuild()
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        if !engine.isRunning {
            rebuild()
            try engine.start()
        }
    }

    /// Volume of everything, used only to fade out when the sleep timer fires.
    var master: Float {
        get { out.outputVolume }
        set { out.outputVolume = newValue }
    }

    func correct(_ p: HeadphoneProfile?, direct: Bool) {
        corrected = p != nil
        if p != nil { correction.load(p) }
        correction.bypass = !corrected || direct
    }

    /// For the test: what the bands of the correction do right now.
    var correctionOn: Bool { !correction.bypass }

    func apply(_ v: Settings.Values) {
        correction.bypass = !corrected || v.direct
        for i in 0..<10 { eq.bands[i].gain = v.eqOn ? Float(v.bands[i]) : 0 }
        eq.bands[10].gain = Float(v.bass)
        eq.globalGain = v.eqOn ? Float(v.preamp) : 0
        eq.bypass = v.direct
        limiter.bypass = !v.limiter || v.direct
        out.pan = v.direct ? 0 : Float(v.balance / 100)
        setMono(v.mono && !v.direct)
        let cents = v.direct ? 0 : (v.keepPitch ? 0 : 1200 * log2(v.rate)) + v.semitones * 100
        for d in decks {
            d.pitch.rate = Float(v.effectiveRate)
            d.pitch.pitch = Float(cents)
            d.pitch.bypass = v.effectiveRate == 1 && cents == 0
        }
    }

    // MARK: - Response curve for the equaliser screen

    /// Sum of all bands in dB at frequency `f`.
    static func response(_ v: Settings.Values, at f: Double) -> Double {
        var db = v.eqOn ? v.preamp : 0
        if v.eqOn {
            for i in 0..<10 {
                switch i {
                case 0: db += shelf(f, lowShelf, v.bands[i], low: true)
                case 9: db += shelf(f, highShelf, v.bands[i], low: false)
                default: db += peak(f, frequencies[i], v.bands[i])
                }
            }
        }
        return db + shelf(f, bassShelf, v.bass, low: true)
    }

    private static func magnitude(_ b: [Double], _ a: [Double], _ w: Double) -> Double {
        func part(_ c: [Double]) -> Double {
            let re = c[0] + c[1] * cos(w) + c[2] * cos(2 * w), im = c[1] * sin(w) + c[2] * sin(2 * w)
            return re * re + im * im
        }
        return 10 * log10(max(part(b), 1e-12) / max(part(a), 1e-12))
    }

    private static func peak(_ f: Double, _ f0: Double, _ gain: Double) -> Double {
        if gain == 0 { return 0 }
        let sr = 48000.0, w0 = 2 * .pi * f0 / sr, A = pow(10, gain / 40), al = sin(w0) / (2 * 1.414), c = cos(w0)
        return magnitude([1 + al * A, -2 * c, 1 - al * A], [1 + al / A, -2 * c, 1 - al / A], 2 * .pi * f / sr)
    }

    private static func shelf(_ f: Double, _ f0: Double, _ gain: Double, low: Bool) -> Double {
        if gain == 0 { return 0 }
        let sr = 48000.0, w0 = 2 * .pi * f0 / sr, A = pow(10, gain / 40), c = cos(w0) * (low ? 1 : -1)
        let s = 2 * A.squareRoot() * sin(w0) / 2 * 2.0.squareRoot()
        let k: Double = low ? 1 : -1
        let b = [A * ((A + 1) - (A - 1) * c + s), k * 2 * A * ((A - 1) - (A + 1) * c), A * ((A + 1) - (A - 1) * c - s)]
        let a = [(A + 1) + (A - 1) * c + s, k * -2 * ((A - 1) + (A + 1) * c), (A + 1) + (A - 1) * c - s]
        return magnitude(b, a, 2 * .pi * f / sr)
    }
}
