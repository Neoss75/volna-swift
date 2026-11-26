import Accelerate
import AVFoundation

/// One pass over the file gives both the loudness (for normalisation) and the waveform of the progress bar.
enum Analysis {
    struct Result: Sendable {
        var gainDb: Double
        var wave: [Int]
        /// Seconds from the start of the song to the first sound and to the end of the last one.
        var soundStart: Double = 0
        var soundEnd: Double = 0
    }

    /// Quieter than −50 dB counts as silence.
    static let quiet: Float = 0.0032

    static let points = 180
    private static let target = -16.0 // gated RMS, dBFS — roughly −14 LUFS for typical music

    /// `from` and `to` in seconds: one song of a long file.
    static func run(_ url: URL, from: Double? = nil, to: Double? = nil) -> Result? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let start = min(Int((from ?? 0) * format.sampleRate), Int(file.length))
        let total = min(to.map { Int($0 * format.sampleRate) } ?? Int(file.length), Int(file.length)) - start
        file.framePosition = AVAudioFramePosition(start)
        guard total > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32768) else { return nil }
        let channels = Int(format.channelCount)
        let block = max(2, Int(format.sampleRate * 0.4))

        var sums = [Double](repeating: 0, count: points), counts = [Int](repeating: 0, count: points)
        var peak: Float = 0, gated = 0.0, gatedBlocks = 0
        var blockSum = 0.0, blockCount = 0, inBlock = 0
        var pos = 0
        var firstLoud: Int?, lastLoud = 0

        while pos < total {
            if Task.isCancelled { return nil }
            do { try file.read(into: buffer, frameCount: AVAudioFrameCount(min(32768, total - pos))) } catch { break }
            let n = Int(buffer.frameLength)
            guard n > 0, let data = buffer.floatChannelData else { break }
            for c in 0..<channels {
                var m: Float = 0
                vDSP_maxmgv(data[c], 1, &m, vDSP_Length(n))
                peak = max(peak, m)
            }
            // where the sound is: windows of 1024 samples
            var w = 0
            while w < n {
                let len = min(1024, n - w)
                var loud = false
                for c in 0..<channels where !loud {
                    var m: Float = 0
                    vDSP_maxmgv(data[c] + w, 1, &m, vDSP_Length(len))
                    loud = m > quiet
                }
                if loud {
                    if firstLoud == nil { firstLoud = pos + w }
                    lastLoud = pos + w + len
                }
                w += len
            }
            // runs that stay inside one point of the waveform and one loudness block, each summed in one go
            var i = 0
            while i < n {
                let p = min(points - 1, (pos + i) * points / total)
                let pointEnd = ((p + 1) * total + points - 1) / points - pos
                let len = max(1, min(n - i, pointEnd - i, block - inBlock))
                for c in 0..<channels {
                    var e: Float = 0
                    vDSP_svesq(data[c] + i, 1, &e, vDSP_Length(len))
                    sums[p] += Double(e)
                    blockSum += Double(e)
                }
                counts[p] += len * channels
                blockCount += len * channels
                inBlock += len
                if inBlock >= block {
                    let e = blockSum / Double(max(1, blockCount))
                    if e > 1e-5 { gated += e; gatedBlocks += 1 } // skip near-silent blocks
                    blockSum = 0; blockCount = 0; inBlock = 0
                }
                i += len
            }
            pos += n
        }

        let raw = (0..<points).map { counts[$0] > 0 ? (sums[$0] / Double(counts[$0])).squareRoot() : 0 }
        let top = max(raw.max() ?? 0, 1e-4)
        let wave = raw.map { Int((pow($0 / top, 0.8) * 100).rounded()) }

        var gain = 0.0
        if gatedBlocks > 0 {
            gain = target - 10 * log10(gated / Double(gatedBlocks))
            if peak > 0 { gain = min(gain, 20 * log10(1.12 / Double(peak))) }
            gain = (min(8, max(-12, gain)) * 10).rounded() / 10
        }
        let rate = format.sampleRate
        return Result(gainDb: gain, wave: wave, soundStart: Double(firstLoud ?? 0) / rate, soundEnd: Double(firstLoud == nil ? pos : lastLoud) / rate)
    }
}

/// Measures songs one after another in the background.
@MainActor
final class Analyzer: ObservableObject {
    @Published private(set) var left = 0
    var onDone: ((UUID) -> Void)?

    private let library: Library
    private var queue: [UUID] = []
    private var running = false

    init(library: Library) { self.library = library }

    func request(_ t: Track, first: Bool) {
        guard t.wave == nil || t.gainDb == nil || t.soundEnd == nil, t.bad != true else { return }
        if let i = queue.firstIndex(of: t.id) {
            guard first else { return }
            queue.remove(at: i)
        }
        if first { queue.insert(t.id, at: 0) } else { queue.append(t.id) }
        left = queue.count
        if !running { Task { await work() } }
    }

    private func work() async {
        guard !running else { return }
        running = true
        while !queue.isEmpty {
            let id = queue.removeFirst()
            if let t = library.track(id), t.wave == nil || t.gainDb == nil || t.soundEnd == nil {
                var result: Analysis.Result?
                if let access = library.open(t) {
                    result = await Task.detached(priority: .userInitiated) { Analysis.run((try? OggFile.playable(access.url, id: t.id)) ?? access.url, from: t.cueStart, to: t.cueEnd) }.value
                }
                library.update(id) {
                    $0.wave = result?.wave ?? []
                    $0.gainDb = result?.gainDb ?? 0
                    $0.soundStart = result?.soundStart ?? 0
                    $0.soundEnd = result.map(\.soundEnd) ?? $0.duration
                }
                onDone?(id)
            }
            left = queue.count
        }
        running = false
    }
}
