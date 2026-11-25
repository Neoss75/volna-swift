import Accelerate
import AVFoundation
import QuartzCore

/// Collects the sound after the equaliser and limiter. The audio thread writes, the screen reads.
final class VizTap: @unchecked Sendable {
    private let lock = NSLock()
    private let size = 32768
    private var left = [Float](repeating: 0, count: 32768)
    private var right = [Float](repeating: 0, count: 32768)
    private var written = 0
    private var lastChunk = 0
    private var lastTime: Double = 0
    private var rate: Double = 44100
    private var installed = false

    func install(on node: AVAudioNode) {
        guard !installed else { return }
        installed = true
        node.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in self?.push(buffer) }
    }

    func remove(from node: AVAudioNode) {
        guard installed else { return }
        installed = false
        node.removeTap(onBus: 0)
    }

    private func push(_ b: AVAudioPCMBuffer) {
        guard let data = b.floatChannelData else { return }
        let n = min(Int(b.frameLength), size)
        let stereo = b.format.channelCount > 1
        lock.lock()
        for i in 0..<n {
            let k = (written + i) % size
            left[k] = data[0][i]
            right[k] = stereo ? data[1][i] : data[0][i]
        }
        written += n
        lastChunk = n
        lastTime = CACurrentMediaTime()
        rate = b.format.sampleRate
        lock.unlock()
    }

    #if DEBUG
        /// Puts a ready sound in, for the self-test.
        func feed(_ x: [Float], rate r: Double) {
            lock.lock()
            for (i, v) in x.enumerated() where i < size {
                left[i] = v
                right[i] = v
            }
            written = min(size, x.count)
            lastChunk = 0
            lastTime = CACurrentMediaTime()
            rate = r
            lock.unlock()
        }
    #endif

    /// The last `n` samples up to "now". Buffers arrive in lumps of about 0.1 s, so the reading
    /// point moves through the latest lump in real time and the picture stays smooth.
    func window(_ n: Int) -> (l: [Float], r: [Float], rate: Double) {
        lock.lock()
        defer { lock.unlock() }
        var l = [Float](repeating: 0, count: n), r = l
        let age = CACurrentMediaTime() - lastTime
        guard written > 0, age < 0.6 else { return (l, r, rate) }
        let end = written - lastChunk + min(lastChunk, Int(age * rate))
        for i in 0..<n {
            let k = end - n + i
            if k >= 0, k > written - size {
                l[i] = left[k % size]
                r[i] = right[k % size]
            }
        }
        return (l, r, rate)
    }
}

/// Spectrum with the same behaviour as the web version: 2048 points, smoothing 0.78, −85…−12 dB.
@MainActor
final class SpectrumAnalyzer {
    private let n = 2048
    private let setup: FFTSetup?
    private var window: [Float]
    private var smooth: [Float]
    private(set) var bins: [Float]
    private(set) var samples: [Float]
    private(set) var left: [Float] = []
    private(set) var right: [Float] = []
    private var rate: Double = 44100

    final class Bands {
        var v: [Float]
        var peak: [Float]
        init(_ n: Int) {
            v = [Float](repeating: 0, count: n)
            peak = v
        }
    }

    private var cache: [Int: Bands] = [:]
    private var fineV: [Float] = []

    init() {
        setup = vDSP_create_fftsetup(11, FFTRadix(kFFTRadix2))
        window = [Float](repeating: 0, count: 2048)
        vDSP_blkman_window(&window, 2048, 0)
        smooth = [Float](repeating: 0, count: 1024)
        bins = smooth
        samples = window
    }

    func update(_ tap: VizTap) {
        let w = tap.window(n)
        left = w.l
        right = w.r
        rate = w.rate
        samples = zip(w.l, w.r).map { ($0 + $1) / 2 }
        guard let setup else { return }
        var x = [Float](repeating: 0, count: n)
        vDSP_vmul(samples, 1, window, 1, &x, 1, vDSP_Length(n))
        var re = [Float](repeating: 0, count: n / 2), im = re, mag = re
        re.withUnsafeMutableBufferPointer { rp in
            im.withUnsafeMutableBufferPointer { ip in
                guard let rb = rp.baseAddress, let ib = ip.baseAddress else { return }
                var split = DSPSplitComplex(realp: rb, imagp: ib)
                x.withUnsafeBytes { raw in
                    guard let base = raw.bindMemory(to: DSPComplex.self).baseAddress else { return }
                    vDSP_ctoz(base, 2, &split, 1, vDSP_Length(n / 2))
                }
                vDSP_fft_zrip(setup, &split, 1, 11, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &mag, 1, vDSP_Length(n / 2))
            }
        }
        let scale = 1 / Float(2 * n)
        for i in 0..<(n / 2) {
            smooth[i] = 0.78 * smooth[i] + 0.22 * mag[i] * scale
            let db = 20 * log10(max(smooth[i], 1e-9))
            bins[i] = min(1, max(0, (db + 85) / 73))
        }
    }

    /// Log-spaced bands, 35 Hz – 16 kHz, with fast attack and slow release.
    func bands(_ count: Int, live: Bool, fall: Float = 0.9) -> Bands {
        let c = cache[count] ?? Bands(count)
        cache[count] = c
        func bin(_ f: Double) -> Int { min(bins.count - 1, Int((f / (rate / 2) * Double(bins.count)).rounded())) }
        for i in 0..<count {
            var v: Float = 0
            if live {
                let a = bin(35 * pow(16000.0 / 35, Double(i) / Double(count)))
                let b = max(bin(35 * pow(16000.0 / 35, Double(i + 1) / Double(count))), a + 1)
                for k in a..<min(b, bins.count) { v = max(v, bins[k]) }
            }
            c.v[i] = max(v, c.v[i] * fall) // never below the real level, or it would jump back on the next frame
            c.peak[i] = c.v[i] > c.peak[i] ? c.v[i] : max(0, c.peak[i] - 0.012)
        }
        return c
    }

    /// Like `bands`, but without steps at the bottom: between two lines of the spectrum the level is interpolated.
    func fine(_ count: Int, live: Bool) -> [Float] {
        if fineV.count != count { fineV = [Float](repeating: 0, count: count) }
        let perHz = Double(bins.count) / (rate / 2), last = bins.count - 2
        var row = [Float](repeating: 0, count: count)
        if live {
            for i in 0..<count {
                let a = 40 * pow(14000.0 / 40, Double(i) / Double(count)) * perHz
                let b = 40 * pow(14000.0 / 40, Double(i + 1) / Double(count)) * perHz
                if b - a < 1.5 {
                    let x = min(Double(last), (a + b) / 2), k = Int(x), t = Float(x - Double(k))
                    let s = t * t * (3 - 2 * t)
                    row[i] = bins[k] * (1 - s) + bins[k + 1] * s
                } else {
                    for k in min(last, Int(a))...min(last, Int(b)) { row[i] = max(row[i], bins[k]) }
                }
            }
        }
        for i in 0..<count {
            let v = (row[max(0, i - 1)] + 2 * row[i] + row[min(count - 1, i + 1)]) / 4
            fineV[i] = max(v, fineV[i] * 0.86)
        }
        return fineV
    }

    static func level(_ x: [Float]) -> (rms: Double, peak: Double) {
        var s: Float = 0, p: Float = 0
        let part = Array(x.suffix(1024))
        guard !part.isEmpty else { return (0, 0) }
        vDSP_rmsqv(part, 1, &s, vDSP_Length(part.count))
        vDSP_maxmgv(part, 1, &p, vDSP_Length(part.count))
        return (Double(s), Double(p))
    }
}
