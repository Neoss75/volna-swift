import SwiftUI

/// The strip under the title; a tap switches the visualisation. With `height` it is the big picture of the screensaver.
struct VizStrip: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @Environment(\.covered) private var covered
    @State private var state = VizState()
    @State private var moving = true
    var compact = false
    var mode: VizMode?
    var height: CGFloat?
    var colors: VizColors?

    var body: some View {
        let mode = mode ?? settings.v.viz
        if mode != .off && mode != .ring {
            let paint = VizPaint(colors: colors ?? settings.v.vizColors, accent: settings.accent), playing = player.isPlaying
            TimelineView(.animation(minimumInterval: 1 / 45, paused: covered || !moving)) { line in
                Canvas { ctx, size in
                    state.step(line.date, player.graph.tap)
                    VizDraw(state: state, paint: paint, live: playing, big: height != nil).draw(mode, ctx, size)
                }
            }
            .frame(height: height ?? (mode.tall ? (compact ? 84 : 120) : compact ? 58 : 64))
            .contentShape(Rectangle())
            .onTapGesture { settings.cycleViz() }
            .allowsHitTesting(height == nil)
            .accessibilityHidden(true)
            .task(id: playing) {
                moving = true
                if !playing {
                    try? await Task.sleep(for: .seconds(2)) // let the bars fall
                    if !Task.isCancelled { moving = false }
                }
            }
            .id(mode)
        }
    }
}

/// Moving parts of the visualisation that live between frames.
@MainActor
final class VizState {
    struct Spark {
        var x, y, vx, vy, age, life, size: Double
    }

    struct Pulse {
        var age, power: Double
    }

    struct Star {
        var x, y, z: Double
        let tinted: Bool
    }

    #if DEBUG
        static var frames = 0
    #endif
    static let historySize = 110
    static let historyBands = 60
    static let pulseLife = 1.8

    let spectrum = SpectrumAnalyzer()
    private(set) var vuL = 0.0
    private(set) var vuR = 0.0
    private(set) var angle = 0.0
    /// Seconds of movement so far and since the last frame.
    private(set) var clock = 0.0
    private(set) var dt = 0.0
    private(set) var sparks: [Spark] = []
    private(set) var pulses: [Pulse] = []
    private(set) var stars: [Star] = []
    private var rows: [[Float]] = []
    private var rowTime = 0.0
    private var owed = 0.0
    private var calm = 0.0
    private var sinceBeat = 1.0
    private var zoom = 1.0
    private var peakL = Date.distantPast
    private var peakR = Date.distantPast
    private var last: Date?
    private var lastTurn: Date?

    var hotL: Bool { peakL > Date() }
    var hotR: Bool { peakR > Date() }

    func step(_ now: Date, _ tap: VizTap) {
        spectrum.update(tap)
        #if DEBUG
            Self.frames += 1
        #endif
        func meter(_ x: [Float], _ old: Double, _ peak: inout Date) -> Double {
            let m = SpectrumAnalyzer.level(x)
            if m.peak > 0.89 { peak = Date().addingTimeInterval(0.45) }
            let target = m.rms > 1e-6 ? Self.vuPos(20 * log10(m.rms) + 14) : 0 // 0 VU = −14 dBFS
            return old + (target - old) * (target > old ? 0.2 : 0.09)
        }
        vuL = meter(spectrum.left, vuL, &peakL)
        vuR = meter(spectrum.right, vuR, &peakR)
        dt = last.map { min(0.1, max(0, now.timeIntervalSince($0))) } ?? 0
        clock += dt
        last = now
    }

    func rest() {
        last = nil
        lastTurn = nil
    }

    /// The cover turns by 12° a second.
    func turn(_ now: Date) -> Double {
        if let lastTurn { angle += min(0.1, max(0, now.timeIntervalSince(lastTurn))) * 12 }
        lastTurn = now
        return angle
    }

    /// Follows the loudness slowly, at most 5 times.
    func scopeZoom() -> Double {
        let p = max(SpectrumAnalyzer.level(spectrum.left).peak, SpectrumAnalyzer.level(spectrum.right).peak)
        let target = min(5, 0.95 / max(0.05, p))
        zoom += (target - zoom) * min(1, dt * (target < zoom ? 8 : 0.8))
        return zoom
    }

    static func vuPos(_ db: Double) -> Double {
        let a = pow(10, db / 20), lo = 0.1, hi = pow(10, 3.0 / 20)
        return min(1, max(0, (a - lo) / (hi - lo)))
    }

    /// How loud the low, middle and high notes are. Call once per frame: the bands fall on every call.
    func energy(live: Bool) -> (low: Double, mid: Double, high: Double) {
        let v = spectrum.bands(30, live: live).v
        func mean(_ r: Range<Int>) -> Double { Double(v[r].reduce(0, +)) / Double(r.count) }
        return (mean(0..<7), mean(7..<18), mean(18..<30))
    }

    /// The last spectra, the newest at the end.
    func history(live: Bool) -> [[Float]] {
        rowTime += dt
        if rowTime >= 1 / 30.0 || rows.isEmpty {
            rowTime = 0
            rows.append(spectrum.bands(Self.historyBands, live: live, fall: 0.8).v)
            if rows.count > Self.historySize { rows.removeFirst(rows.count - Self.historySize) }
        }
        return rows
    }

    func moveSparks(live: Bool, many: Int) {
        for i in sparks.indices {
            sparks[i].age += dt
            sparks[i].vy -= 0.3 * dt
            sparks[i].x += sparks[i].vx * dt
            sparks[i].y += sparks[i].vy * dt
        }
        sparks.removeAll { $0.age >= $0.life || $0.y < -0.05 }
        guard live else { return }
        let bands = spectrum.bands(20, live: live).v
        owed += dt * Double(bands.reduce(0, +)) / 20 * Double(many) * 2.6
        while owed >= 1, sparks.count < many {
            owed -= 1
            let k = Int.random(in: 0..<20), v = Double(bands[k])
            guard Double.random(in: 0...1) < v + 0.1 else { continue }
            sparks.append(Spark(x: (Double(k) + .random(in: 0...1)) / 20, y: 0, vx: .random(in: -0.06...0.06),
                                vy: 0.3 + 0.85 * v * .random(in: 0.6...1.15), age: 0, life: .random(in: 0.9...1.9), size: .random(in: 1...2.4)))
        }
        owed = min(owed, 6)
    }

    func movePulses(live: Bool, low: Double) {
        for i in pulses.indices { pulses[i].age += dt }
        pulses.removeAll { $0.age >= Self.pulseLife }
        sinceBeat += dt
        if live, low > 0.12, low > calm * 1.12, sinceBeat > 0.22, pulses.count < 8 {
            sinceBeat = 0
            pulses.append(Pulse(age: 0, power: min(1, low)))
        }
        calm += (low - calm) * min(1, dt * 4)
    }

    func moveStars(live: Bool, speed: Double) {
        if stars.isEmpty {
            stars = (0..<260).map { _ in Self.star(.random(in: 0.05...1)) }
        }
        guard live else { return }
        for i in stars.indices {
            stars[i].z -= dt * speed * 0.7
            if stars[i].z < 0.04 { stars[i] = Self.star(1) }
        }
    }

    private static func star(_ z: Double) -> Star {
        Star(x: .random(in: -1...1), y: .random(in: -1...1), z: z, tinted: .random())
    }
}

/// «Круг»: a spinning round cover with the spectrum around it.
struct RingCover: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @Environment(\.covered) private var covered
    @State private var state = VizState()
    @State private var moving = true
    let track: Track?
    let side: CGFloat

    var body: some View {
        let paint = VizPaint(colors: settings.v.vizColors, accent: settings.accent), playing = player.isPlaying
        ZStack {
            TimelineView(.animation(minimumInterval: 1 / 45, paused: covered || !moving)) { line in
                Canvas { ctx, size in
                    state.step(line.date, player.graph.tap)
                    draw(ctx, size, paint, playing)
                }
            }
            // a picture of its own that only turns: building the cover again for every frame is slow
            TimelineView(.animation(minimumInterval: 1 / 45, paused: covered || !moving)) { line in
                cover.rotationEffect(.degrees(state.turn(line.date)))
            }
            .frame(width: side * 0.58, height: side * 0.58)
            Circle().stroke(Theme.line, lineWidth: 1).frame(width: side * 0.58 + 8, height: side * 0.58 + 8)
        }
        .frame(width: side, height: side)
        .task(id: playing) {
            moving = true
            if !playing {
                try? await Task.sleep(for: .seconds(0.4))
                if !Task.isCancelled {
                    moving = false
                    state.rest()
                }
            }
        }
    }

    private var cover: some View {
        CoverView(track: track, corner: side, letter: side * 0.16)
            .frame(width: side * 0.58, height: side * 0.58)
            .drawingGroup()
    }

    private func draw(_ g: GraphicsContext, _ size: CGSize, _ paint: VizPaint, _ live: Bool) {
        let c = size.width / 2, R0 = size.width * 0.29 + 7, maxL = c - R0 - 3, n = 64, N = 128
        let s = state.spectrum.bands(n, live: live, fall: 0.88)
        let bass = Double(s.v.prefix(6).reduce(0, +)) / 6
        g.stroke(Path(ellipseIn: CGRect(x: c - R0 + 4, y: c - R0 + 4, width: (R0 - 4) * 2, height: (R0 - 4) * 2)),
                 with: .color(paint.color(bass, 0.6).opacity(0.12 + 0.5 * bass)), lineWidth: 2 + 6 * bass)
        let lw = max(1.5, 2 * .pi * R0 / CGFloat(N) * 0.5)
        let shade = paint.shade(center: CGPoint(x: c, y: c), from: R0, to: R0 + maxL)
        var idle = Path(), rays = [Path](repeating: Path(), count: 8) // rays of about the same brightness are drawn together
        for k in 0..<N {
            let v = CGFloat(s.v[k < n ? k : N - 1 - k]), th = -Double.pi / 2 + (Double(k) + 0.5) / Double(N) * 2 * .pi
            let len = 2 + v * maxL, co = CGFloat(cos(th)), si = CGFloat(sin(th))
            let from = CGPoint(x: c + co * R0, y: c + si * R0), to = CGPoint(x: c + co * (R0 + len), y: c + si * (R0 + len))
            if v > 0.02 {
                let q = min(7, Int(v * 8))
                rays[q].move(to: from)
                rays[q].addLine(to: to)
            } else {
                idle.move(to: from)
                idle.addLine(to: to)
            }
        }
        let style = StrokeStyle(lineWidth: lw, lineCap: .round)
        for (q, p) in rays.enumerated() where !p.isEmpty {
            var ctx = g
            ctx.opacity = paint.alpha((Double(q) + 0.5) / 8)
            ctx.stroke(p, with: shade, style: style)
        }
        g.stroke(idle, with: .color(Theme.line.opacity(0.35)), style: style)
    }
}

#if DEBUG
/// Every visualisation at once, only to take a picture of them.
struct VizGallery: View {
    var body: some View {
        let modes = VizMode.allCases.filter { $0 != .off && $0 != .ring }
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(modes.enumerated()), id: \.1) { i, m in
                    VStack(alignment: .leading, spacing: 2) {
                        VizStrip(mode: m, colors: VizColors.allCases[i % VizColors.allCases.count])
                        Text(m.name).font(.mono(9)).foregroundStyle(Theme.muted)
                    }
                }
            }
            .padding(12)
        }
        .background(Theme.bg)
    }
}
#endif
