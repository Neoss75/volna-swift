import SwiftUI

/// Visualisations made of shapes and soft light.
extension VizDraw {
    /// One wedge of petals that answer to different notes, turned and mirrored around the centre.
    func kaleido(_ g: GraphicsContext, _ z: CGSize) {
        let rings = 8, s = state.spectrum.bands(rings * 3, live: live, fall: 0.9)
        let c = CGPoint(x: z.width / 2, y: z.height / 2)
        let far = big ? hypot(z.width, z.height) / 2 : min(z.width, z.height) / 2
        let sectors = 7, half = Double.pi / Double(sectors), clock = state.clock
        for k in stride(from: rings - 1, through: 0, by: -1) {
            let v = Double(max(s.v[k * 3], max(s.v[k * 3 + 1], s.v[k * 3 + 2])))
            let place = (Double(k) + 0.5) / Double(rings)
            let r = Double(far) * (place * 0.95 + 0.03 * sin(clock * 0.7 + Double(k)))
            let lean = half * 0.55 * sin(clock * (0.25 + 0.06 * Double(k)) + Double(k) * 1.3)
            let len = Double(far) * (0.05 + 0.17 * v), wide = Double(far) * (0.015 + 0.07 * v) * (0.5 + place)
            var shape = Path()
            let dx = cos(lean), dy = sin(lean)
            func at(_ along: Double, _ side: Double) -> CGPoint {
                CGPoint(x: (r + along) * dx - side * dy, y: (r + along) * dy + side * dx)
            }
            shape.move(to: at(-len, 0))
            shape.addQuadCurve(to: at(len, 0), control: at(0, wide * 2))
            shape.addQuadCurve(to: at(-len, 0), control: at(0, -wide * 2))
            shape.closeSubpath()
            var all = Path()
            for i in 0..<sectors {
                let turn = Double(i) * 2 * half + clock * 0.06 * (k % 2 == 0 ? 1 : -1)
                let spin = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: CGFloat(turn))
                all.addPath(shape, transform: spin)
                all.addPath(shape, transform: spin.scaledBy(x: 1, y: -1))
            }
            let color = GraphicsContext.Shading.color(paint.color(v, place))
            fill(g, all, color, 0.1 + 0.6 * v)
            var edge = g
            edge.opacity = 0.25 + 0.75 * v
            edge.stroke(all, with: color, lineWidth: line * 0.5)
        }
    }

    /// Many thin lines that flow, every line has its own notes.
    func flows(_ g: GraphicsContext, _ z: CGSize) {
        let n = big ? 34 : 18, s = state.spectrum.bands(34, live: live, fall: 0.92), points = 64
        for i in 0..<n {
            let t = Double(i) / Double(n - 1), v = Double(s.v[min(33, i * 34 / n)])
            let base = Double(z.height) * (0.12 + 0.76 * t)
            let amp = Double(z.height) * (0.012 + 0.2 * v)
            let waves = 1.1 + 0.9 * t, speed = 0.55 + 0.5 * t, shift = Double(i) * 0.31
            var pts: [CGPoint] = []
            for k in 0...points {
                let x = Double(k) / Double(points), env = 0.25 + 0.75 * sin(Double.pi * x)
                let a = x * 2 * Double.pi * waves + state.clock * speed + shift
                let y = base + amp * env * (sin(a) + 0.35 * sin(a * 2.3 - state.clock * 0.8))
                pts.append(CGPoint(x: CGFloat(x) * z.width, y: CGFloat(y)))
            }
            var c = g
            c.opacity = 0.18 + 0.82 * v
            let shade: GraphicsContext.Shading = paint.colors == .rainbow
                ? paint.shade(bottom: 0, top: 0, width: z.width) : .color(paint.color(v, t))
            c.stroke(smooth(pts), with: shade, style: StrokeStyle(lineWidth: line * CGFloat(0.4 + 0.5 * v), lineJoin: .round))
        }
    }

    /// Triangles that light up from the centre: low notes in the middle, high ones at the edges.
    func tiles(_ g: GraphicsContext, _ z: CGSize) {
        let bands = 26, s = state.spectrum.bands(bands, live: live, fall: 0.9)
        let side = z.width / (big ? (z.width > z.height ? 18 : 9) : 18), high = side * 0.866
        let rows = Int(z.height / high) + 2, cols = Int(z.width / side) + 2
        let c = CGPoint(x: z.width / 2, y: z.height / 2), far = Double(max(c.x, c.y))
        var lit = [[Path]](repeating: [Path](repeating: Path(), count: 8), count: VizColors.steps)
        for row in 0..<rows {
            let y = CGFloat(row) * high - high / 2, odd = row % 2 == 1 ? side / 2 : 0
            for col in 0..<(cols * 2) {
                let x = CGFloat(col / 2) * side - odd, up = col % 2 == 0
                let pts = up
                    ? [CGPoint(x: x, y: y + high), CGPoint(x: x + side, y: y + high), CGPoint(x: x + side / 2, y: y)]
                    : [CGPoint(x: x + side / 2, y: y), CGPoint(x: x + side * 1.5, y: y), CGPoint(x: x + side, y: y + high)]
                let mx = (pts[0].x + pts[1].x + pts[2].x) / 3, my = (pts[0].y + pts[1].y + pts[2].y) / 3
                let d = min(0.999, Double(hypot(mx - c.x, my - c.y)) / far)
                // a fixed little scatter, so that the rings are not perfect circles
                let scatter = Double((row * 7 + col * 13) % 10) / 10 - 0.5
                let k = min(bands - 1, max(0, Int((d + scatter * 0.1) * Double(bands))))
                let v = Double(s.v[k])
                guard v > 0.05 else { continue }
                let q = min(7, Int(v * 8))
                lit[paint.index(v, d)][q].addPath(triangle(pts, CGPoint(x: mx, y: my), 0.9))
            }
        }
        for (i, paths) in lit.enumerated() {
            for (q, p) in paths.enumerated() where !p.isEmpty {
                let v = (Double(q) + 0.5) / 8
                fill(g, p, .color(paint.at(i)), 0.08 + 0.85 * v * v)
            }
        }
    }

    private func triangle(_ pts: [CGPoint], _ m: CGPoint, _ k: CGFloat) -> Path {
        var p = Path()
        for (i, q) in pts.enumerated() {
            let a = CGPoint(x: m.x + (q.x - m.x) * k, y: m.y + (q.y - m.y) * k)
            if i == 0 { p.move(to: a) } else { p.addLine(to: a) }
        }
        p.closeSubpath()
        return p
    }

    /// A soft drop that breathes with the bass and ripples with the other notes.
    func drop(_ g: GraphicsContext, _ z: CGSize) {
        let e = state.energy(live: live), c = CGPoint(x: z.width / 2, y: z.height / 2)
        let R = Double(min(z.width, z.height)) / 2, count = 120, clock = state.clock
        for layer in stride(from: 3, through: 0, by: -1) {
            let l = Double(layer), size = R * (0.36 + 0.13 * l + 0.14 * e.low)
            var pts: [CGPoint] = []
            for i in 0..<count {
                let a = Double(i) / Double(count) * 2 * Double.pi
                let w1 = 0.10 * e.low * sin(2 * a + clock * 0.9 + l)
                let w2 = 0.16 * e.mid * sin(3 * a - clock * 1.3 + l * 1.7)
                let w3 = 0.14 * e.high * sin(7 * a + clock * 2.1 - l)
                let w4 = 0.03 * sin(5 * a - clock * 0.5 + l * 0.6)
                let r = min(R, size * (1 + w1 + w2 + w3 + w4))
                pts.append(CGPoint(x: c.x + CGFloat(cos(a) * r), y: c.y + CGFloat(sin(a) * r)))
            }
            var p = smooth(pts)
            p.closeSubpath()
            let place = l / 3.2, tint = paint.color(0.2 + 0.25 * l, place)
            let shade = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [tint.opacity(0.75), tint.opacity(0.18)]), center: c, startRadius: 0, endRadius: CGFloat(size * 1.15))
            fill(g, p, shade, 0.85 - 0.16 * l)
            var edge = g
            edge.opacity = 0.7 - 0.15 * l
            edge.stroke(p, with: .color(tint), lineWidth: line * 0.5)
        }
    }

    /// Paper pieces: a burst from the bottom corners on every beat.
    func confetti(_ g: GraphicsContext, _ z: CGSize) {
        let e = state.energy(live: live)
        state.movePapers(live: live, low: e.low, high: e.high, many: big ? 220 : 110)
        for p in state.papers {
            let a = min(1, (p.life - p.age) * 2), w = CGFloat(p.size) * (big ? 2.4 : 1.3)
            let flat = w * CGFloat(0.25 + 0.75 * abs(cos(p.angle * 1.7)))
            var c = g
            c.translateBy(x: CGFloat(p.x) * z.width, y: CGFloat(p.y) * z.height)
            c.rotate(by: .radians(p.angle))
            c.opacity = a
            let col = paint.many ? paint.color(p.tint, p.tint) : p.tint > 0.5 ? paint.accent : Theme.fg
            c.fill(Path(CGRect(x: -w / 2, y: -flat / 2, width: w, height: flat)), with: .color(col))
        }
    }

    /// Slow clouds of light.
    func aurora(_ g: GraphicsContext, _ z: CGSize) {
        let s = state.spectrum.bands(6, live: live, fall: 0.94), clock = state.clock
        for k in 0..<6 {
            let v = Double(s.v[k]), q = Double(k), place = (q + 0.5) / 6
            let x = 0.5 + 0.42 * sin(clock * (0.11 + 0.03 * q) + q * 1.9)
            let y = 0.5 + 0.42 * cos(clock * (0.13 + 0.02 * q) + q * 2.7)
            let r = CGFloat(0.22 + 0.4 * v) * max(z.width, z.height * 0.8)
            let c = CGPoint(x: CGFloat(x) * z.width, y: CGFloat(y) * z.height)
            let tint = paint.color(place, place), a = 0.08 + 0.62 * v
            g.fill(Path(CGRect(origin: .zero, size: z)),
                   with: .radialGradient(Gradient(colors: [tint.opacity(a), tint.opacity(a * 0.35), tint.opacity(0)]), center: c, startRadius: 0, endRadius: r))
        }
    }
}
