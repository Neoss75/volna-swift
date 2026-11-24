import SwiftUI

/// Draws one frame of every visualisation except «Круг» (see RingCover).
@MainActor
struct VizDraw {
    let state: VizState
    let paint: VizPaint
    let live: Bool
    /// The big picture of the screensaver.
    let big: Bool

    private var line: CGFloat { big ? 3 : 2 }

    func draw(_ mode: VizMode, _ g: GraphicsContext, _ size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        switch mode {
        case .bars: bars(g, size)
        case .peaks: peaks(g, size)
        case .mirror: mirror(g, size)
        case .led: led(g, size)
        case .dots: dots(g, size)
        case .area: area(g, size)
        case .ribbons: ribbons(g, size)
        case .wave: wave(g, size)
        case .scope: scope(g, size)
        case .ridges: ridges(g, size)
        case .falls: falls(g, size)
        case .sparks: sparks(g, size)
        case .pulse: pulse(g, size)
        case .stars: stars(g, size)
        case .flower: flower(g, size)
        case .vu: vu(g, size)
        case .ring, .off: break
        }
    }

    private func fill(_ g: GraphicsContext, _ p: Path, _ s: GraphicsContext.Shading, _ alpha: Double) {
        var c = g
        c.opacity = alpha
        c.fill(p, with: s)
    }

    // MARK: Spectrum

    private func bars(_ g: GraphicsContext, _ z: CGSize) {
        let n = 40, s = state.spectrum.bands(n, live: live), gap: CGFloat = 3
        let bw = (z.width - gap * CGFloat(n - 1)) / CGFloat(n)
        let shade = paint.shade(bottom: z.height, top: 0, width: z.width)
        for i in 0..<n {
            let v = Double(s.v[i]), h = max(2, CGFloat(v) * z.height)
            let p = Path(CGRect(x: CGFloat(i) * (bw + gap), y: z.height - h, width: bw, height: h))
            fill(g, p, v > 0.02 ? shade : .color(Theme.line), v > 0.02 ? paint.alpha(v) : 0.35)
        }
    }

    private func peaks(_ g: GraphicsContext, _ z: CGSize) {
        let n = 32, s = state.spectrum.bands(n, live: live, fall: 0.88), gap: CGFloat = big ? 5 : 4
        let bw = (z.width - gap * CGFloat(n - 1)) / CGFloat(n), cap: CGFloat = big ? 5 : 3, room = z.height - cap * 2
        let shade = paint.shade(bottom: z.height, top: 0, width: z.width)
        var body = Path()
        for i in 0..<n {
            let x = CGFloat(i) * (bw + gap), h = max(2, CGFloat(s.v[i]) * room)
            body.addRoundedRect(in: CGRect(x: x, y: z.height - h, width: bw, height: h), cornerSize: CGSize(width: bw / 3, height: min(bw / 3, h / 2)))
            let pk = Double(s.peak[i])
            if pk > 0.02 {
                let r = CGRect(x: x, y: z.height - CGFloat(pk) * room - cap * 1.7, width: bw, height: cap)
                g.fill(Path(roundedRect: r, cornerRadius: cap / 2), with: .color(paint.many ? paint.color(pk, Double(i) / Double(n)) : Theme.fg))
            }
        }
        fill(g, body, shade, 0.85)
    }

    private func mirror(_ g: GraphicsContext, _ z: CGSize) {
        let n = 48, s = state.spectrum.bands(n, live: live), gap: CGFloat = 2
        let bw = (z.width - gap * CGFloat(n - 1)) / CGFloat(n), mid = z.height / 2
        let up = paint.shade(bottom: mid, top: 0, width: z.width), down = paint.shade(bottom: mid, top: z.height, width: z.width)
        for i in 0..<n {
            let j = i < n / 2 ? n / 2 - 1 - i : i - n / 2
            let v = Double(s.v[min(n - 1, j * 2)]), h = max(1.5, CGFloat(v) * (mid - 1)), x = CGFloat(i) * (bw + gap)
            let a = v > 0.02 ? paint.alpha(v, 0.3) : 0.3, idle = v <= 0.02
            fill(g, Path(CGRect(x: x, y: mid - h, width: bw, height: h)), idle ? .color(Theme.line) : up, a)
            fill(g, Path(CGRect(x: x, y: mid, width: bw, height: h)), idle ? .color(Theme.line) : down, a * 0.45)
        }
    }

    private func led(_ g: GraphicsContext, _ z: CGSize) {
        let n = 24, rows = big ? 22 : 10, s = state.spectrum.bands(n, live: live, fall: 0.86)
        let gx: CGFloat = 4, gy: CGFloat = 2
        let bw = (z.width - gx * CGFloat(n - 1)) / CGFloat(n), bh = (z.height - gy * CGFloat(rows - 1)) / CGFloat(rows)
        var idle = Path()
        for i in 0..<n {
            let lit = Int((s.v[i] * Float(rows)).rounded()), pk = min(rows - 1, Int((s.peak[i] * Float(rows)).rounded()))
            for r in 0..<rows {
                let y = z.height - CGFloat(r + 1) * bh - CGFloat(r) * gy
                let box = CGRect(x: CGFloat(i) * (bw + gx), y: y, width: bw, height: bh)
                let lev = Double(r) / Double(rows - 1), c = paint.color(lev, Double(i) / Double(n))
                if r < lit {
                    let col = !paint.many && r >= rows - 2 ? Theme.fg : c
                    fill(g, Path(box), .color(col), paint.many ? 0.95 : 0.55 + 0.45 * lev)
                } else if live, r == pk, pk > 0 {
                    fill(g, Path(box), .color(paint.many ? c : Theme.fg), 0.8)
                } else {
                    idle.addRect(box)
                }
            }
        }
        fill(g, idle, .color(Theme.line), 0.5)
    }

    private func dots(_ g: GraphicsContext, _ z: CGSize) {
        let n = 28, s = state.spectrum.bands(n, live: live, fall: 0.87), cell = z.width / CGFloat(n)
        let rows = max(3, Int(z.height / cell)), r = cell * 0.36
        var idle = Path(), lit = [Path](repeating: Path(), count: VizColors.steps)
        for i in 0..<n {
            let on = Int((s.v[i] * Float(rows)).rounded())
            for k in 0..<rows {
                let c = CGPoint(x: (CGFloat(i) + 0.5) * cell, y: z.height - (CGFloat(k) + 0.5) * cell)
                let box = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                if k < on {
                    lit[paint.index(Double(k) / Double(max(1, rows - 1)), Double(i) / Double(n))].addEllipse(in: box)
                } else {
                    idle.addEllipse(in: box.insetBy(dx: r * 0.55, dy: r * 0.55))
                }
            }
        }
        fill(g, idle, .color(Theme.line), 0.6)
        for (i, p) in lit.enumerated() where !p.isEmpty { g.fill(p, with: .color(paint.at(i))) }
    }

    private func area(_ g: GraphicsContext, _ z: CGSize) {
        let n = 96, s = state.spectrum.bands(n, live: live, fall: 0.88)
        let pts = (0..<n).map { CGPoint(x: CGFloat($0) / CGFloat(n - 1) * z.width, y: z.height - max(1, CGFloat(s.v[$0]) * (z.height - 3))) }
        let curve = smooth(pts)
        var under = curve
        under.addLine(to: CGPoint(x: z.width, y: z.height))
        under.addLine(to: CGPoint(x: 0, y: z.height))
        under.closeSubpath()
        if paint.many {
            fill(g, under, paint.shade(bottom: z.height, top: 0, width: z.width), 0.4)
        } else {
            g.fill(under, with: .linearGradient(Gradient(colors: [paint.accent.opacity(0.45), paint.accent.opacity(0)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: z.height)))
        }
        g.stroke(curve, with: paint.shade(bottom: z.height, top: 0, width: z.width), style: StrokeStyle(lineWidth: line, lineJoin: .round))
    }

    private func smooth(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first, let last = pts.last else { return p }
        p.move(to: first)
        for i in 1..<pts.count {
            p.addQuadCurve(to: CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2), control: pts[i - 1])
        }
        p.addLine(to: last)
        return p
    }

    // MARK: Lines

    /// Three bands that sway: low, middle and high notes.
    private func ribbons(_ g: GraphicsContext, _ z: CGSize) {
        let e = state.energy(live: live), mid = z.height / 2, n = 120
        let parts: [(v: Double, waves: Double, speed: Double)] = [(e.low, 1.5, 0.9), (e.mid, 2.5, -1.3), (e.high * 1.4, 4, 1.9)]
        for (k, part) in parts.enumerated() {
            let amp = CGFloat(min(1, 0.06 + part.v)) * mid * 0.95
            var top: [CGPoint] = [], bottom: [CGPoint] = []
            for i in 0...n {
                let x = Double(i) / Double(n), env = CGFloat(sin(.pi * x))
                let ph = x * 2 * .pi * part.waves + state.clock * part.speed
                let px = CGFloat(x) * z.width, lag: Double = 0.9 + 0.5 * sin(state.clock * 0.6)
                top.append(CGPoint(x: px, y: mid + amp * env * CGFloat(sin(ph))))
                bottom.append(CGPoint(x: px, y: mid + amp * env * CGFloat(sin(ph + lag))))
            }
            var p = smooth(top)
            for q in bottom.reversed() { p.addLine(to: q) }
            p.closeSubpath()
            let place = (Double(k) + 0.5) / 3
            let shade: GraphicsContext.Shading = paint.colors == .rainbow
                ? paint.shade(bottom: 0, top: 0, width: z.width) : .color(paint.color(place, place))
            fill(g, p, shade, paint.many ? 0.5 : 0.3 + 0.15 * Double(k))
            g.stroke(smooth(top), with: shade, lineWidth: line * 0.7)
        }
    }

    private func wave(_ g: GraphicsContext, _ z: CGSize) {
        let mid = z.height / 2
        g.fill(Path(CGRect(x: 0, y: mid - 0.5, width: z.width, height: 1)), with: .color(Theme.line))
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
            let pt = CGPoint(x: CGFloat(i) / CGFloat(n - 1) * z.width, y: mid - CGFloat(max(-1, min(1, x[st + i]))) * (mid - 2))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        let shade: GraphicsContext.Shading
        switch paint.colors {
        case .accent, .rainbow: shade = paint.shade(bottom: mid, top: 0, width: z.width)
        default: // quiet in the middle, loud at both edges
            let up = paint.colors.gradient
            let both = Gradient(colors: up.stops.reversed().map(\.color) + up.stops.map(\.color))
            shade = .linearGradient(both, startPoint: .zero, endPoint: CGPoint(x: 0, y: z.height))
        }
        g.stroke(p, with: shade, style: StrokeStyle(lineWidth: line, lineJoin: .round))
    }

    /// Left against right: a thin vertical line is mono, a cloud is a wide stereo.
    private func scope(_ g: GraphicsContext, _ z: CGSize) {
        let c = CGPoint(x: z.width / 2, y: z.height / 2), r = min(z.width, z.height) / 2
        var cross = Path()
        cross.move(to: CGPoint(x: c.x - r * 0.7, y: c.y - r * 0.7))
        cross.addLine(to: CGPoint(x: c.x + r * 0.7, y: c.y + r * 0.7))
        cross.move(to: CGPoint(x: c.x + r * 0.7, y: c.y - r * 0.7))
        cross.addLine(to: CGPoint(x: c.x - r * 0.7, y: c.y + r * 0.7))
        g.stroke(cross, with: .color(Theme.line.opacity(0.7)), lineWidth: 1)
        let L = state.spectrum.left, R = state.spectrum.right
        guard live, L.count == R.count, L.count > 800 else { return }
        // quiet music is enlarged, so that the figure is always readable
        let zoom = CGFloat(state.scopeZoom())
        var p = Path()
        for (k, i) in stride(from: L.count - 800, to: L.count, by: 1).enumerated() {
            let x = CGFloat(R[i] - L[i]) * r * 0.7 * zoom, y = CGFloat(R[i] + L[i]) * r * 0.48 * zoom
            let pt = CGPoint(x: c.x + max(-r, min(r, x)), y: c.y - max(-r, min(r, y)))
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        var ctx = g
        ctx.opacity = 0.85
        ctx.stroke(p, with: paint.shade(center: c, from: 0, to: r), style: StrokeStyle(lineWidth: big ? 1.6 : 1.1, lineJoin: .round))
    }

    // MARK: History

    /// The spectrum of the last moments, one line behind another.
    private func ridges(_ g: GraphicsContext, _ z: CGSize) {
        let hist = state.history(live: live)
        let rows = min(big ? 16 : 9, (hist.count + 2) / 3)
        guard rows > 0 else { return }
        g.drawLayer { layer in
            for r in stride(from: rows - 1, through: 0, by: -1) { // 0 is the newest, in front
                let row = hist[hist.count - 1 - r * 3], near = 1 - CGFloat(r) / CGFloat(max(1, rows))
                let inset = z.width * 0.16 * (1 - near), base = z.height * (0.3 + 0.7 * near) - 2
                let tall = z.height * 0.3 * (0.5 + 0.5 * near), w = z.width - inset * 2
                let pts = row.enumerated().map { k, v in
                    CGPoint(x: inset + CGFloat(k) / CGFloat(row.count - 1) * w, y: base - CGFloat(v) * tall)
                }
                let curve = smooth(pts)
                var under = curve
                under.addLine(to: CGPoint(x: inset + w, y: base + 3))
                under.addLine(to: CGPoint(x: inset, y: base + 3))
                under.closeSubpath()
                var hole = layer
                hole.blendMode = .destinationOut
                hole.fill(under, with: .color(.black))
                var c = layer
                c.opacity = 0.25 + 0.75 * Double(near)
                let shade = paint.shade(bottom: base, top: base - tall, width: z.width)
                fill(c, under, shade, 0.16 * Double(near))
                c.stroke(curve, with: shade, style: StrokeStyle(lineWidth: line * (0.5 + 0.4 * near), lineJoin: .round))
            }
        }
    }

    /// Time runs from right to left, low notes are at the bottom, bright means loud.
    private func falls(_ g: GraphicsContext, _ z: CGSize) {
        let hist = state.history(live: live), cols = VizState.historySize
        let cw = z.width / CGFloat(cols), rows = VizState.historyBands, ch = z.height / CGFloat(rows)
        var lit = [Path](repeating: Path(), count: 12)
        for (i, row) in hist.enumerated() {
            let x = (z.width - CGFloat(hist.count - i) * cw).rounded(), next = (z.width - CGFloat(hist.count - i - 1) * cw).rounded()
            for (k, v) in row.enumerated() where v > 0.12 {
                let q = min(11, Int((v - 0.12) / 0.88 * 12))
                let top = (z.height - CGFloat(k + 1) * ch).rounded(), bottom = (z.height - CGFloat(k) * ch).rounded()
                lit[q].addRect(CGRect(x: x, y: top, width: next - x, height: bottom - top))
            }
        }
        for (q, p) in lit.enumerated() where !p.isEmpty {
            let v = (Double(q) + 0.5) / 12
            fill(g, p, .color(paint.color(v, 1 - v)), 0.12 + 0.88 * v)
        }
    }

    // MARK: Moving things

    private func sparks(_ g: GraphicsContext, _ z: CGSize) {
        state.moveSparks(live: live, many: big ? 260 : 120)
        for p in state.sparks {
            let a = 1 - p.age / p.life
            let r = CGFloat(p.size) * (big ? 2.1 : 1) * CGFloat(0.4 + 0.6 * a)
            let c = CGPoint(x: CGFloat(p.x) * z.width, y: z.height * (1 - CGFloat(p.y)))
            let level = min(1, 0.3 + max(0, p.y))
            fill(g, Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), .color(paint.color(level, p.x)), a)
        }
        let e = state.energy(live: live)
        let glow = CGRect(x: 0, y: z.height * 0.7, width: z.width, height: z.height * 0.3)
        g.fill(Path(glow), with: .linearGradient(Gradient(colors: [paint.color(0, 0.5).opacity(0.45 * e.low), .clear]),
                                                 startPoint: CGPoint(x: 0, y: z.height), endPoint: CGPoint(x: 0, y: z.height * 0.7)))
    }

    /// A ring leaves the centre on every beat.
    private func pulse(_ g: GraphicsContext, _ z: CGSize) {
        let e = state.energy(live: live)
        state.movePulses(live: live, low: e.low)
        let c = CGPoint(x: z.width / 2, y: z.height / 2), far = hypot(z.width, z.height) / 2
        for p in state.pulses {
            let t = p.age / VizState.pulseLife, r = CGFloat(t) * far, a = (1 - t) * (0.35 + 0.65 * p.power)
            guard r > 1, a > 0.02 else { continue }
            let box = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
            var ctx = g
            ctx.opacity = a
            ctx.stroke(Path(ellipseIn: box), with: .color(paint.color(1 - t, t)), lineWidth: line * (1 + 2.5 * CGFloat(p.power * (1 - t))))
        }
        let r0 = min(z.width, z.height) * (0.12 + 0.2 * CGFloat(e.low))
        g.fill(Path(ellipseIn: CGRect(x: c.x - r0, y: c.y - r0, width: r0 * 2, height: r0 * 2)),
               with: .radialGradient(Gradient(colors: [paint.color(e.low, 0).opacity(0.95), paint.color(e.low, 0.15).opacity(0.25)]), center: c, startRadius: 0, endRadius: max(1, r0)))
    }

    /// A flight through stars, faster when it is louder.
    private func stars(_ g: GraphicsContext, _ z: CGSize) {
        let e = state.energy(live: live)
        state.moveStars(live: live, speed: 0.1 + 0.9 * (e.low * 0.6 + e.mid * 0.4))
        let c = CGPoint(x: z.width / 2, y: z.height / 2)
        for s in state.stars {
            let k = CGFloat(0.6 / s.z), x = c.x + CGFloat(s.x) * c.x * k, y = c.y + CGFloat(s.y) * c.y * k
            guard x > -4, x < z.width + 4, y > -4, y < z.height + 4 else { continue }
            let near = 1 - s.z, r = CGFloat(0.6 + 2.4 * near * near) * (big ? 1.6 : 0.8)
            let place = (atan2(s.y, s.x) / (2 * .pi)) + 0.5
            let col = paint.many ? paint.color(near, place) : s.tinted ? paint.accent : Theme.fg
            fill(g, Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), .color(col), min(1, 0.15 + near))
        }
    }

    private func flower(_ g: GraphicsContext, _ z: CGSize) {
        let n = 64, s = state.spectrum.bands(n, live: live, fall: 0.88), c = CGPoint(x: z.width / 2, y: z.height / 2)
        let R = min(z.width, z.height) / 2 - 2, e = state.energy(live: live)
        for (k, part) in [(scale: 1.0, turn: 0.12), (scale: 0.72, turn: -0.2), (scale: 0.45, turn: 0.3)].enumerated() {
            let petals = 6, count = 180
            var pts: [CGPoint] = []
            for i in 0..<count {
                let a = Double(i) / Double(count) * 2 * .pi
                let turn = Double(i) / Double(count) * Double(petals)
                let inPetal: Double = abs(turn.truncatingRemainder(dividingBy: 1) * 2 - 1) // 1 between petals, 0 at the tip
                let band = min(n - 1, Int(inPetal * 40) + k * 6)
                let v = Double(s.v[band])
                let still: Double = 0.22 + 0.16 * (1 - inPetal), grown: Double = 0.62 * v * (1 - 0.35 * inPetal)
                let rad: Double = Double(R) * part.scale * (still + grown)
                let th = a + state.clock * part.turn
                pts.append(CGPoint(x: c.x + CGFloat(cos(th) * rad), y: c.y + CGFloat(sin(th) * rad)))
            }
            var p = smooth(pts)
            p.closeSubpath()
            let shade = paint.shade(center: c, from: R * 0.1, to: R * CGFloat(part.scale))
            fill(g, p, shade, 0.16 + 0.14 * Double(k) + 0.1 * e.low)
            g.stroke(p, with: shade, style: StrokeStyle(lineWidth: line * 0.7, lineJoin: .round))
        }
    }

    // MARK: Needles

    private func vu(_ g: GraphicsContext, _ z: CGSize) {
        let gap: CGFloat = 10, w = (z.width - gap) / 2
        if z.height > z.width * 0.8 { // a tall picture: one above the other
            let h = min((z.height - gap * 2) / 2, z.width * 0.58), top = (z.height - h * 2 - gap * 2) / 2
            meter(g, CGRect(x: 0, y: top, width: z.width, height: h), state.vuL, "L", state.hotL)
            meter(g, CGRect(x: 0, y: top + h + gap * 2, width: z.width, height: h), state.vuR, "R", state.hotR)
            return
        }
        meter(g, CGRect(x: 0, y: 0, width: w, height: z.height), state.vuL, "L", state.hotL)
        meter(g, CGRect(x: w + gap, y: 0, width: w, height: z.height), state.vuR, "R", state.hotR)
    }

    private func meter(_ base: GraphicsContext, _ r: CGRect, _ pos: Double, _ label: String, _ hot: Bool) {
        var g = base
        let box = Path(roundedRect: r, cornerRadius: 10), tint = paint.color(pos, 0.5)
        g.clip(to: box)
        g.fill(box, with: .color(Theme.raise))
        g.fill(box, with: .radialGradient(Gradient(colors: [tint.opacity(0.22), tint.opacity(0)]), center: CGPoint(x: r.midX, y: r.maxY), startRadius: 0, endRadius: r.height * 1.1))
        let px = r.midX, py = r.minY + r.height * 1.16, rs = r.height * 0.86, k = max(1, r.height / 130)
        let sweep = min(0.9, asin(min(1, Double(r.width * 0.42 / rs))))
        func ang(_ p: Double) -> Double { -sweep + 2 * sweep * p }
        func pt(_ th: Double, _ rad: CGFloat) -> CGPoint { CGPoint(x: px + rad * CGFloat(sin(th)), y: py - rad * CGFloat(cos(th))) }
        func arc(_ a: Double, _ b: Double, _ rad: CGFloat) -> Path {
            var p = Path()
            p.addArc(center: CGPoint(x: px, y: py), radius: rad, startAngle: .radians(a - .pi / 2), endAngle: .radians(b - .pi / 2), clockwise: false)
            return p
        }
        let zero = VizState.vuPos(0)
        g.stroke(arc(ang(0), ang(zero), rs), with: .color(Theme.fg.opacity(0.55)), lineWidth: 1.2 * k)
        g.stroke(arc(ang(zero), ang(1), rs + 1.2 * k), with: .color(Theme.danger), lineWidth: 3.5 * k)
        for db in [-20, -10, -7, -5, -3, -2, -1, 0, 1, 2, 3] {
            let th = ang(VizState.vuPos(Double(db))), major = [-20, -10, -5, -3, 0, 3].contains(db)
            let c = db > 0 ? Theme.danger : Theme.fg.opacity(0.7), len: CGFloat = major ? 8 : 5, lw: CGFloat = major ? 1.4 : 1
            var tick = Path()
            tick.move(to: pt(th, rs))
            tick.addLine(to: pt(th, rs - len * k))
            g.stroke(tick, with: .color(c), lineWidth: lw * k)
            if major {
                g.draw(Text(db > 0 ? "+\(db)" : "\(abs(db))").font(.mono(9 * k, .medium)).foregroundStyle(c), at: pt(th, rs - 17 * k))
            }
        }
        g.draw(Text("VU").font(.display(11 * k, .medium)).foregroundStyle(Theme.muted), at: CGPoint(x: px, y: r.minY + r.height * 0.76))
        g.draw(Text(label).font(.mono(10 * k, .medium)).foregroundStyle(Theme.muted), at: CGPoint(x: r.minX + 13 * k, y: r.maxY - 12 * k))
        g.fill(Path(ellipseIn: CGRect(x: r.maxX - 14.5 * k, y: r.minY + 7.5 * k, width: 7 * k, height: 7 * k)), with: .color(hot ? Theme.danger : Theme.line))
        var needle = Path()
        needle.move(to: CGPoint(x: px, y: py))
        needle.addLine(to: pt(ang(pos), rs + 5 * k))
        g.stroke(needle, with: .color(Theme.fg), style: StrokeStyle(lineWidth: 1.6 * k, lineCap: .round))
        let hub = r.height * 0.13
        g.fill(Path(ellipseIn: CGRect(x: px - hub, y: r.maxY - hub, width: hub * 2, height: hub * 2)), with: .color(Theme.line))
    }
}
