import SwiftUI

/// The strip under the title; a tap switches the visualisation.
struct VizStrip: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @State private var state = VizState()
    @State private var moving = true
    var compact = false

    var body: some View {
        let mode = settings.v.viz
        if mode != .off && mode != .ring {
            let accent = settings.accent, playing = player.isPlaying
            TimelineView(.animation(minimumInterval: 1 / 45, paused: !moving)) { line in
                Canvas { ctx, size in
                    state.step(line.date, player.graph.tap)
                    draw(mode, ctx, size, accent, playing)
                }
            }
            .frame(height: compact ? 44 : mode == .vu ? 120 : 64)
            .contentShape(Rectangle())
            .onTapGesture { settings.cycleViz() }
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

    private func draw(_ mode: VizMode, _ g: GraphicsContext, _ size: CGSize, _ A: Color, _ live: Bool) {
        let W = size.width, H = size.height, L = Theme.line
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: Color, _ a: Double) {
            g.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(c.opacity(a)))
        }
        switch mode {
        case .bars:
            let n = 40, s = state.spectrum.bands(n, live: live), gap: CGFloat = 3, bw = (W - gap * CGFloat(n - 1)) / CGFloat(n)
            for i in 0..<n {
                let v = CGFloat(s.v[i]), h = max(2, v * H)
                rect(CGFloat(i) * (bw + gap), H - h, bw, h, v > 0.02 ? A : L, 0.35 + 0.65 * Double(v))
            }
        case .mirror:
            let n = 48, s = state.spectrum.bands(n, live: live), gap: CGFloat = 2, bw = (W - gap * CGFloat(n - 1)) / CGFloat(n), mid = H / 2
            for i in 0..<n {
                let j = i < n / 2 ? n / 2 - 1 - i : i - n / 2
                let v = CGFloat(s.v[min(n - 1, j * 2)]), h = max(1.5, v * (mid - 1)), x = CGFloat(i) * (bw + gap), a = 0.3 + 0.7 * Double(v)
                rect(x, mid - h, bw, h, v > 0.02 ? A : L, a)
                rect(x, mid, bw, h, v > 0.02 ? A : L, a * 0.45)
            }
        case .led:
            let n = 24, rows = 10, s = state.spectrum.bands(n, live: live, fall: 0.86)
            let gx: CGFloat = 4, gy: CGFloat = 2, bw = (W - gx * CGFloat(n - 1)) / CGFloat(n), bh = (H - gy * CGFloat(rows - 1)) / CGFloat(rows)
            for i in 0..<n {
                let lit = Int((s.v[i] * Float(rows)).rounded()), pk = min(rows - 1, Int((s.peak[i] * Float(rows)).rounded()))
                for r in 0..<rows {
                    let y = H - CGFloat(r + 1) * bh - CGFloat(r) * gy, x = CGFloat(i) * (bw + gx)
                    if r < lit {
                        rect(x, y, bw, bh, r >= rows - 2 ? Theme.fg : A, 0.55 + 0.45 * Double(r) / Double(rows))
                    } else if live, r == pk, pk > 0 {
                        rect(x, y, bw, bh, Theme.fg, 0.8)
                    } else {
                        rect(x, y, bw, bh, L, 0.5)
                    }
                }
            }
        case .area:
            let n = 96, s = state.spectrum.bands(n, live: live, fall: 0.88)
            let pts = (0..<n).map { CGPoint(x: CGFloat($0) / CGFloat(n - 1) * W, y: H - max(1, CGFloat(s.v[$0]) * (H - 3))) }
            var line = Path()
            line.move(to: pts[0])
            for i in 1..<n {
                line.addQuadCurve(to: CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2), control: pts[i - 1])
            }
            line.addLine(to: pts[n - 1])
            var fill = line
            fill.addLine(to: CGPoint(x: W, y: H))
            fill.addLine(to: CGPoint(x: 0, y: H))
            fill.closeSubpath()
            g.fill(fill, with: .linearGradient(Gradient(colors: [A.opacity(0.45), A.opacity(0)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: H)))
            g.stroke(line, with: .color(A), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        case .wave:
            let mid = H / 2
            rect(0, mid - 0.5, W, 1, L, 1)
            let x = state.spectrum.samples
            guard live, x.count > 1100 else { return }
            // start at a rising zero crossing so the trace holds still
            var st = 0
            for i in 1..<(x.count / 2) where x[i - 1] < 0 && x[i] >= 0 {
                st = i
                break
            }
            let n = min(1024, x.count - st)
            var p = Path()
            for i in stride(from: 0, to: n, by: 2) {
                let pt = CGPoint(x: CGFloat(i) / CGFloat(n - 1) * W, y: mid - CGFloat(max(-1, min(1, x[st + i]))) * (mid - 2))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            g.stroke(p, with: .color(A), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        case .vu:
            let gap: CGFloat = 10, w = (W - gap) / 2
            meter(g, CGRect(x: 0, y: 0, width: w, height: H), state.vuL, "L", state.hotL, A)
            meter(g, CGRect(x: w + gap, y: 0, width: w, height: H), state.vuR, "R", state.hotR, A)
        case .ring, .off:
            break
        }
    }

    private func meter(_ base: GraphicsContext, _ r: CGRect, _ pos: Double, _ label: String, _ hot: Bool, _ A: Color) {
        var g = base
        let box = Path(roundedRect: r, cornerRadius: 10)
        g.clip(to: box)
        g.fill(box, with: .color(Theme.raise))
        g.fill(box, with: .radialGradient(Gradient(colors: [A.opacity(0.22), A.opacity(0)]), center: CGPoint(x: r.midX, y: r.maxY), startRadius: 0, endRadius: r.height * 1.1))
        let px = r.midX, py = r.minY + r.height * 1.16, rs = r.height * 0.86
        let sweep = min(0.9, asin(min(1, Double(r.width * 0.42 / rs))))
        func ang(_ p: Double) -> Double { -sweep + 2 * sweep * p }
        func pt(_ th: Double, _ rad: CGFloat) -> CGPoint { CGPoint(x: px + rad * CGFloat(sin(th)), y: py - rad * CGFloat(cos(th))) }
        func arc(_ a: Double, _ b: Double, _ rad: CGFloat) -> Path {
            var p = Path()
            p.addArc(center: CGPoint(x: px, y: py), radius: rad, startAngle: .radians(a - .pi / 2), endAngle: .radians(b - .pi / 2), clockwise: false)
            return p
        }
        let zero = VizState.vuPos(0)
        g.stroke(arc(ang(0), ang(zero), rs), with: .color(Theme.fg.opacity(0.55)), lineWidth: 1.2)
        g.stroke(arc(ang(zero), ang(1), rs + 1.2), with: .color(Theme.danger), lineWidth: 3.5)
        for db in [-20, -10, -7, -5, -3, -2, -1, 0, 1, 2, 3] {
            let th = ang(VizState.vuPos(Double(db))), major = [-20, -10, -5, -3, 0, 3].contains(db)
            let c = db > 0 ? Theme.danger : Theme.fg.opacity(0.7)
            var tick = Path()
            tick.move(to: pt(th, rs))
            tick.addLine(to: pt(th, rs - (major ? 8 : 5)))
            g.stroke(tick, with: .color(c), lineWidth: major ? 1.4 : 1)
            if major {
                g.draw(Text(db > 0 ? "+\(db)" : "\(abs(db))").font(.mono(9, .medium)).foregroundStyle(c), at: pt(th, rs - 17))
            }
        }
        g.draw(Text("VU").font(.display(11, .medium)).foregroundStyle(Theme.muted), at: CGPoint(x: px, y: r.minY + r.height * 0.76))
        g.draw(Text(label).font(.mono(10, .medium)).foregroundStyle(Theme.muted), at: CGPoint(x: r.minX + 13, y: r.maxY - 12))
        g.fill(Path(ellipseIn: CGRect(x: r.maxX - 14.5, y: r.minY + 7.5, width: 7, height: 7)), with: .color(hot ? Theme.danger : Theme.line))
        var needle = Path()
        needle.move(to: CGPoint(x: px, y: py))
        needle.addLine(to: pt(ang(pos), rs + 5))
        g.stroke(needle, with: .color(Theme.fg), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        let hub = r.height * 0.13
        g.fill(Path(ellipseIn: CGRect(x: px - hub, y: r.maxY - hub, width: hub * 2, height: hub * 2)), with: .color(Theme.line))
    }
}

/// Moving parts of the visualisation that live between frames.
@MainActor
final class VizState {
    let spectrum = SpectrumAnalyzer()
    private(set) var vuL = 0.0
    private(set) var vuR = 0.0
    private(set) var angle = 0.0
    private var peakL = Date.distantPast
    private var peakR = Date.distantPast
    private var last: Date?

    var hotL: Bool { peakL > Date() }
    var hotR: Bool { peakR > Date() }

    func step(_ now: Date, _ tap: VizTap) {
        spectrum.update(tap)
        func meter(_ x: [Float], _ old: Double, _ peak: inout Date) -> Double {
            let m = SpectrumAnalyzer.level(x)
            if m.peak > 0.89 { peak = Date().addingTimeInterval(0.45) }
            let target = m.rms > 1e-6 ? Self.vuPos(20 * log10(m.rms) + 14) : 0 // 0 VU = −14 dBFS
            return old + (target - old) * (target > old ? 0.2 : 0.09)
        }
        vuL = meter(spectrum.left, vuL, &peakL)
        vuR = meter(spectrum.right, vuR, &peakR)
        if let last { angle += min(0.1, max(0, now.timeIntervalSince(last))) * 12 }
        last = now
    }

    func rest() { last = nil }

    static func vuPos(_ db: Double) -> Double {
        let a = pow(10, db / 20), lo = 0.1, hi = pow(10, 3.0 / 20)
        return min(1, max(0, (a - lo) / (hi - lo)))
    }
}

/// «Круг»: a spinning round cover with the spectrum around it.
struct RingCover: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @State private var state = VizState()
    @State private var moving = true
    let track: Track?
    let side: CGFloat

    var body: some View {
        let accent = settings.accent, playing = player.isPlaying
        TimelineView(.animation(minimumInterval: 1 / 45, paused: !moving)) { line in
            ZStack {
                Canvas { ctx, size in
                    state.step(line.date, player.graph.tap)
                    draw(ctx, size, accent, playing)
                }
                CoverView(track: track, corner: side, letter: side * 0.16)
                    .frame(width: side * 0.58, height: side * 0.58)
                    .rotationEffect(.degrees(state.angle))
                    .overlay(Circle().stroke(Theme.line, lineWidth: 1).padding(-4))
            }
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

    private func draw(_ g: GraphicsContext, _ size: CGSize, _ A: Color, _ live: Bool) {
        let c = size.width / 2, R0 = size.width * 0.29 + 7, maxL = c - R0 - 3, n = 64, N = 128
        let s = state.spectrum.bands(n, live: live, fall: 0.88)
        let bass = Double(s.v.prefix(6).reduce(0, +)) / 6
        g.stroke(Path(ellipseIn: CGRect(x: c - R0 + 4, y: c - R0 + 4, width: (R0 - 4) * 2, height: (R0 - 4) * 2)),
                 with: .color(A.opacity(0.12 + 0.5 * bass)), lineWidth: 2 + 6 * bass)
        let lw = max(1.5, 2 * .pi * R0 / CGFloat(N) * 0.5)
        for k in 0..<N {
            let v = CGFloat(s.v[k < n ? k : N - 1 - k]), th = -Double.pi / 2 + (Double(k) + 0.5) / Double(N) * 2 * .pi
            let len = 2 + v * maxL, co = CGFloat(cos(th)), si = CGFloat(sin(th))
            var p = Path()
            p.move(to: CGPoint(x: c + co * R0, y: c + si * R0))
            p.addLine(to: CGPoint(x: c + co * (R0 + len), y: c + si * (R0 + len)))
            g.stroke(p, with: .color((v > 0.02 ? A : Theme.line).opacity(0.35 + 0.65 * Double(v))), style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
    }
}
