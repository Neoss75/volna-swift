import MediaPlayer
import SwiftUI
import UniformTypeIdentifiers

/// The one main screen, laid out like the web version: cover, title, visualisation, wave, buttons, menu.
struct PlayerScreen: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var ui: UIState

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                let i = geo.safeAreaInsets
                landscape(CGSize(width: geo.size.width + i.leading + i.trailing, height: geo.size.height + i.top + i.bottom))
                    .ignoresSafeArea()
            } else {
                portrait
            }
        }
        .id(settings.v.language)
        .background(Theme.bg.ignoresSafeArea())
        .overlay(alignment: .top) {
            if library.importing {
                ProgressView(tr("Читаю песни…"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.top, 8)
            }
        }
        .overlay(alignment: .bottom) { ToastView().padding(.bottom, 86) }
        .sheet(item: $ui.panel) { panel in
            PanelView(panel: panel)
        }
        .modifier(Dialogs(active: ui.panel == nil))
        .modifier(SaverControl())
        #if DEBUG
            .overlay { if ProcessInfo.processInfo.arguments.contains("-widgets") { WidgetGallery(player: player) } }
            .overlay { if ProcessInfo.processInfo.arguments.contains("-vizgallery") { VizGallery() } }
        #endif
    }

    private var portrait: some View {
        VStack(spacing: 10) {
            header
            CoverArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            TitleBlock().modifier(SwipeUp())
            VizStrip().modifier(SwipeUp(overButtons: false))
            if player.radio == nil { SeekBlock() } else { LiveBlock() }
            Transport().modifier(SwipeUp())
            SleepNote()
            MenuBar()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    /// The cover takes the whole height, the rest stretches along it. Laid out in the full screen: the system margins
    /// are much larger than needed, only the camera cut-out (on either side) has to stay clear.
    private func landscape(_ size: CGSize) -> some View {
        let side = min(size.height - 28, size.width * 0.45)
        return HStack(spacing: 30) {
            CoverArea()
                .frame(width: side, height: side)
            VStack(spacing: 0) {
                TitleBlock(compact: true).modifier(SwipeUp())
                Spacer(minLength: 4)
                VizStrip(compact: true).modifier(SwipeUp(overButtons: false))
                Spacer(minLength: 4)
                if player.radio == nil { SeekBlock() } else { LiveBlock() }
                Spacer(minLength: 2)
                Transport(compact: true).modifier(SwipeUp())
                SleepNote()
                Spacer(minLength: 4)
                MenuBar()
            }
            .frame(height: size.height - 44)
        }
        .padding(.horizontal, 60)
        .frame(width: size.width, height: size.height)
    }

    /// With all the marks on there may be not enough room for the rate.
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            headerRow(rate: true)
            headerRow(rate: false)
        }
    }

    @ViewBuilder private var airPlay: some View {
        let look = ButtonLook.of(settings.v.buttons)
        if look == .classic {
            AirPlayButton(tint: UIColor(Theme.muted), active: UIColor(settings.accent))
                .frame(width: 30, height: 30)
        } else {
            Orb(look: look, clearness: settings.v.glass, size: 32) {
                AirPlayButton(tint: UIColor(look.ink), active: UIColor(settings.accent))
                    .frame(width: 22, height: 22)
            }
        }
    }

    private func headerRow(rate: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(tr("Волна"))
                .font(.display(18))
                .foregroundStyle(Theme.fg)
                .fixedSize()
            Spacer(minLength: 0)
            OutputBadges(rate: rate)
            airPlay
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
                .accessibilityLabel(tr("AirPlay и другие колонки"))
        }
    }
}

/// «LOSSLESS»: the file itself is lossless, whatever it is heard through.
/// «HI-RES»: filled when the song really reaches a DAC at its own rate, outlined when the mode is only switched on.
/// A tap opens the page that explains where the sound goes.
struct OutputBadges: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var ui: UIState
    var rate = true

    var body: some View {
        let lossless = player.current?.isLossless == true
        if settings.v.matchRate || settings.v.direct || lossless {
            TimelineView(.periodic(from: .now, by: 2)) { _ in
                let out = OutputInfo.now()
                let live = settings.v.matchRate && out.plays(player.current)
                Button {
                    ui.settingsPath = [.path]
                    ui.panel = .fx
                } label: {
                    HStack(spacing: 6) {
                        if rate, out.digital, settings.v.matchRate || settings.v.direct {
                            Text(out.rateText).font(.mono(11)).foregroundStyle(Theme.muted)
                        }
                        if lossless { badge("LOSSLESS", true) }
                        if settings.v.direct { badge(tr("ПРЯМОЙ"), true) }
                        if settings.v.matchRate { badge("HI-RES", live) }
                    }
                    .fixedSize()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel([
                    lossless ? tr("Файл без потерь") : nil,
                    settings.v.direct ? tr("Прямой вывод") : nil,
                    settings.v.matchRate ? (live ? tr("Hi-Res: песня идёт без пересчёта частоты") : tr("Режим Hi-Res включён, сейчас не используется")) : nil,
                ].compactMap { $0 }.joined(separator: ". "))
            }
        }
    }

    @ViewBuilder private func badge(_ text: String, _ on: Bool) -> some View {
        let look = ButtonLook.of(settings.v.buttons)
        if look == .classic {
            plainBadge(text, on)
        } else {
            Text(text)
                .font(.system(size: 10, weight: .heavy))
                .kerning(0.5)
                .foregroundStyle(on ? look.tintedInk(settings.v.glass) : look.ink.opacity(look == .chrome ? 0.7 : 0.55))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(GlassBody(look: look, clearness: settings.v.glass, shape: Capsule(), tint: on ? settings.accent : nil))
        }
    }

    private func plainBadge(_ text: String, _ on: Bool) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .kerning(0.5)
            .foregroundStyle(on ? Theme.accentInk : Theme.muted)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(on ? settings.accent : .clear))
            .overlay(Capsule().stroke(on ? .clear : Theme.muted.opacity(0.7), lineWidth: 1))
    }
}

/// A swipe up on the main screen opens the settings (a swipe down closes them, the system does that).
/// Not on the lyrics, which scroll, and not on the wave, which is dragged.
struct SwipeUp: ViewModifier {
    @EnvironmentObject private var ui: UIState
    /// The button under the finger must not be pressed by the swipe. Taps and long presses without buttons need no such care.
    var overButtons = true

    func body(content: Content) -> some View {
        let drag = DragGesture(minimumDistance: 20).onEnded { g in
            if Self.isUp(g.translation), ui.panel == nil { ui.panel = .fx }
        }
        if overButtons {
            content.contentShape(Rectangle()).highPriorityGesture(drag)
        } else {
            content.simultaneousGesture(drag)
        }
    }

    static func isUp(_ t: CGSize) -> Bool { t.height < -50 && -t.height > abs(t.width) * 1.4 }
}

// MARK: - Cover

struct CoverArea: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var ui: UIState
    @EnvironmentObject private var library: Library
    @State private var shift: CGFloat = 0
    @State private var fadeOut = false
    /// The heart over the cover after a double tap: filled when liked, crossed out when not.
    @State private var heart: Bool?

    var body: some View {
        if settings.v.lyricsOn, player.radio != nil {
            RadioLyricsView()
        } else if settings.v.lyricsOn {
            LyricsView()
        } else {
            GeometryReader { geo in
                let side = max(60, min(geo.size.width, geo.size.height))
                ZStack {
                    if settings.v.viz == .ring {
                        RingCover(track: player.current, station: player.radio, side: side)
                    } else {
                        cover(side)
                            .frame(width: side, height: side)
                            .shadow(color: .black.opacity(0.3), radius: 22, y: 14)
                    }
                }
                .offset(x: shift)
                .opacity(fadeOut ? 0 : 1)
                .overlay {
                    if let heart {
                        Image(systemName: heart ? "heart.fill" : "heart.slash.fill")
                            .font(.system(size: min(110, side * 0.4)))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 12)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { like() }
                .gesture(DragGesture(minimumDistance: 20)
                    .onEnded { g in
                        let dx = g.translation.width
                        if SwipeUp.isUp(g.translation) { return ui.panel = .fx }
                        guard abs(dx) > 50, abs(dx) > abs(g.translation.height) * 1.4, player.radio != nil || !player.queue.isEmpty else { return }
                        if dx < 0 {
                            Haptic.tap()
                            swipe(-1)
                            player.next()
                        } else if player.previousTrack() {
                            Haptic.tap()
                            swipe(1)
                        }
                    })
            }
            .accessibilityElement()
            .accessibilityLabel(tr("Обложка. Смахивание переключает песню"))
            .accessibilityHint(player.current == nil ? "" : tr("Двойное нажатие: в избранное"))
            .accessibilityAction { like() }
        }
    }

    /// Double tap on the cover: the song goes to the favourites or leaves them.
    private func like() {
        guard player.radio == nil, let t = player.current else { return }
        library.toggleFavourite(t.id)
        let on = library.isFavourite(t.id)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { heart = on }
        Task {
            try? await Task.sleep(for: .seconds(0.7))
            withAnimation(.easeOut(duration: 0.25)) { heart = nil }
        }
    }

    @ViewBuilder private func cover(_ side: CGFloat) -> some View {
        if let s = player.radio {
            RadioCover(station: s, corner: 24, letter: side * 0.27, badge: true)
        } else {
            CoverView(track: player.current, corner: 24, letter: side * 0.27)
        }
    }

    private func swipe(_ dir: CGFloat) {
        withAnimation(.easeOut(duration: 0.16)) {
            shift = dir * 70
            fadeOut = true
        } completion: {
            shift = -dir * 50
            withAnimation(.easeOut(duration: 0.2)) {
                shift = 0
                fadeOut = false
            }
        }
    }
}

struct CoverView: View {
    let track: Track?
    var corner: CGFloat = 10
    var letter: CGFloat = 16
    var thumbnail = false

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    let h = hue(track.map { $0.title + $0.artist } ?? "волна")
                    LinearGradient(colors: [Color(h: h, s: 0.55, l: 0.5), Color(h: h + 55, s: 0.6, l: 0.26)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(track?.letter ?? "♪")
                        .font(.display(letter, .semibold))
                        .foregroundStyle(.white)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    private var image: UIImage? {
        guard let t = track, t.hasArtwork else { return nil }
        return thumbnail ? ArtworkStore.thumbnail(for: t.id) : ArtworkStore.image(for: t.id)
    }
}

// MARK: - Title

struct TitleBlock: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var settings: Settings
    var compact = false

    var body: some View {
        if let s = player.radio { RadioTitle(station: s, compact: compact) } else { song }
    }

    private var song: some View {
        let t = player.current
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Text(t?.title ?? tr("Ничего не выбрано"))
                    .font(.display(compact ? 18 : 21, .semibold))
                    .foregroundStyle(Theme.fg)
                    .lineLimit(compact ? 1 : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let t {
                    let on = library.isFavourite(t.id)
                    Button { library.toggleFavourite(t.id) } label: {
                        Image(systemName: on ? "heart.fill" : "heart")
                            .font(.system(size: 22))
                            .foregroundStyle(on ? Theme.danger : Theme.muted)
                            .frame(width: 34, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(on ? tr("Убрать из избранного") : tr("Добавить в избранное"))
                }
            }
            HStack(spacing: 10) {
                Text(t.map { $0.artist.isEmpty ? tr("Неизвестный исполнитель") : $0.artist }
                    ?? (library.tracks.isEmpty ? tr("Откройте «Песни» и добавьте музыку") : tr("Откройте «Песни» и выберите трек")))
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                if compact {
                    Spacer(minLength: 0)
                    OutputBadges(rate: t?.isLossless != true)
                }
            }
            if let t {
                // the file on one line, its place in the queue on the next
                let place = placeLine(t)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.formatLine)
                    if !place.isEmpty { Text(place) }
                }
                .font(.mono(11))
                .kerning(0.3)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 2)
            }
        }
    }

    private func placeLine(_ t: Track) -> String {
        var p: [String] = []
        if player.qi >= 0 { p.append(tr("{} из {}", "\(player.qi + 1)", "\(player.queue.count)")) }
        if settings.v.effectiveNormalize, let g = t.gainDb, g != 0 { p.append(tr("выравн. ") + formatDb(g)) }
        return p.joined(separator: " · ")
    }
}

// MARK: - Wave

struct SeekBlock: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var clock: PlaybackClock
    @Environment(\.covered) private var covered
    @State private var dragFrom: Double?
    @State private var dragging: Double?

    var body: some View {
        let t = player.current
        VStack(spacing: 2) {
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: 1 / 60, paused: covered || !player.isPlaying || dragging != nil)) { _ in
                    let d = player.duration, p = d > 0 ? min(1, max(0, (dragging ?? player.position) / d)) : 0
                    let loop = d > 0 ? player.loopA.map { (a: $0 / d, b: player.loopB.map { $0 / d }) } : nil
                    WaveCanvas(wave: t?.wave, hasTrack: t != nil, progress: p, accent: settings.accent, loop: loop)
                }
                .contentShape(Rectangle())
                .gesture(drag(span: WaveCanvas.span(geo.size.width)))
            }
            .frame(height: 48)
            .accessibilityElement()
            .accessibilityLabel(tr("Позиция в треке"))
            .accessibilityValue(formatTime(clock.time))
            .accessibilityAdjustableAction { dir in
                player.seek(to: player.position + (dir == .increment ? 10 : -10))
            }
            ZStack {
                HStack {
                    Text(formatTime(dragging ?? clock.time))
                        .foregroundStyle(dragging != nil ? settings.accent : Theme.muted)
                    Spacer()
                    Text(formatTime(player.duration)).foregroundStyle(Theme.muted)
                }
                .font(.mono(12).monospacedDigit())
                if t != nil { LoopButton() }
            }
        }
    }

    /// Drag the wave like tape: pull left to go forward, right to go back; release to seek there.
    private func drag(span: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { g in
                guard player.current != nil, player.duration > 0 else { return }
                let from = dragFrom ?? player.position
                dragFrom = from
                dragging = min(player.duration, max(0, from - Double(g.translation.width / span) * player.duration))
            }
            .onEnded { _ in
                if let d = dragging { player.seek(to: d) }
                dragging = nil
                dragFrom = nil
            }
    }
}

/// A-B repeat: the start, then the end, then off.
struct LoopButton: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings

    var body: some View {
        let on = player.loopB != nil, half = player.loopA != nil && !on
        button(on: on, half: half)
            .accessibilityLabel(tr("Повтор отрезка"))
            .accessibilityValue(on ? tr("включён") : half ? tr("начало отмечено, нажмите в конце") : tr("выключен"))
    }

    @ViewBuilder private func button(on: Bool, half: Bool) -> some View {
        let look = ButtonLook.of(settings.v.buttons)
        if look != .classic {
            Button { player.markLoop() } label: {
                Text(half ? "A–…" : "A–B")
                    .font(.mono(11, .semibold))
                    .foregroundStyle(on ? look.tintedInk(settings.v.glass) : half ? settings.accent : look.ink.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
            }
            .buttonStyle(GlassPillStyle(look: look, clearness: settings.v.glass, tint: on ? settings.accent : nil))
        } else {
            plain(on: on, half: half)
        }
    }

    private func plain(on: Bool, half: Bool) -> some View {
        Button { player.markLoop() } label: {
            Text(half ? "A–…" : "A–B")
                .font(.mono(11, .semibold))
                .foregroundStyle(on ? Theme.accentInk : half ? settings.accent : Theme.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background {
                    Capsule().fill(on ? settings.accent : Color.clear)
                    Capsule().stroke(on ? Color.clear : half ? settings.accent : Theme.line, lineWidth: 1)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// The whole track is laid out twice as wide as the screen and slides left as it plays:
/// the centre line is "now", the played part is to its left in the accent colour.
struct WaveCanvas: View {
    let wave: [Int]?
    let hasTrack: Bool
    let progress: Double
    let accent: Color
    /// A-B repeat as parts of the song; `b` is nil while only the start is marked.
    var loop: (a: Double, b: Double?)?

    static let step: CGFloat = 5

    static func span(_ width: CGFloat) -> CGFloat { CGFloat(max(16, Int(2 * width / step))) * step }

    var body: some View {
        Canvas { ctx, size in
            let n = max(16, Int(2 * size.width / Self.step))
            let span = CGFloat(n) * Self.step, cx = size.width / 2, mid = size.height / 2
            let shift = cx - CGFloat(progress) * span
            let first = max(0, Int((-shift - Self.step) / Self.step)), last = min(n - 1, Int((size.width - shift) / Self.step) + 1)
            var bars = Path()
            if first <= last {
                for i in first...last {
                    let h = max(2, CGFloat(level(i, n)) * (size.height - 2))
                    bars.addRoundedRect(in: CGRect(x: shift + CGFloat(i) * Self.step, y: mid - h / 2, width: 3, height: h), cornerSize: CGSize(width: 1.5, height: 1.5))
                }
            }
            var rest = ctx
            rest.clip(to: Path(CGRect(x: cx, y: 0, width: cx, height: size.height)))
            rest.fill(bars, with: .color(Theme.muted.opacity(0.45)))
            var played = ctx
            played.clip(to: Path(CGRect(x: 0, y: 0, width: cx, height: size.height)))
            played.fill(bars, with: .color(accent))
            if let loop {
                let xa = shift + CGFloat(loop.a) * span
                if let b = loop.b {
                    let xb = shift + CGFloat(b) * span
                    ctx.fill(Path(CGRect(x: xa, y: 0, width: max(0, xb - xa), height: size.height)), with: .color(accent.opacity(0.14)))
                    ctx.fill(Path(CGRect(x: xb - 1, y: 0, width: 2, height: size.height)), with: .color(accent))
                }
                ctx.fill(Path(CGRect(x: xa - 1, y: 0, width: 2, height: size.height)), with: .color(accent))
            }
        }
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                                   .init(color: .black, location: 0.88), .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing)
        }
        .overlay {
            if hasTrack { Theme.fg.frame(width: 2) }
        }
    }

    private func level(_ i: Int, _ n: Int) -> Double {
        guard let wave, !wave.isEmpty else { return hasTrack ? 0.12 : 0.06 } // not measured yet: a flat dotted line
        let a = Double(i) / Double(n) * Double(wave.count), b = max(a + 1, Double(i + 1) / Double(n) * Double(wave.count))
        var s = 0, k = 0
        var j = Int(a)
        while j < Int(b.rounded(.up)), j < wave.count {
            s += wave[j]
            k += 1
            j += 1
        }
        return k > 0 ? Double(s) / Double(k) / 100 : 0
    }
}

// MARK: - Buttons

struct Transport: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var ui: UIState
    var compact = false

    var body: some View {
        HStack(spacing: 0) {
            if player.radio != nil {
                small(tr("Станции"), "list.bullet", on: false) { ui.panel = .radio }
            } else {
                small(player.shuffle ? tr("Перемешивание включено") : tr("Перемешать"), "shuffle", on: player.shuffle) { player.toggleShuffle() }
            }
            Spacer()
            side(tr("Предыдущий"), "backward.end.fill") {
                Haptic.tap()
                player.previous()
            }
            Spacer()
            play
            Spacer()
            side(tr("Следующий"), "forward.end.fill") {
                Haptic.tap()
                player.next()
            }
            Spacer()
            if player.radio != nil {
                small(tr("Вернуться к песням"), "music.note", on: false) { player.leaveRadio() }
            } else {
                small(tr("Повтор"), player.repeatMode == .one ? "repeat.1" : "repeat", on: player.repeatMode != .off) { player.cycleRepeat() }
            }
        }
    }

    private var look: ButtonLook { ButtonLook.of(settings.v.buttons) }

    /// The ink of the icons on glass: dark on chrome, the usual text colour on clear and frosted glass.
    private var ink: Color { look == .chrome ? Color(white: 0.16) : Theme.fg }

    @ViewBuilder private var play: some View {
        let icon = player.isPlaying ? "pause.fill" : "play.fill"
        let label = player.isPlaying ? tr("Пауза") : tr("Играть")
        if look == .classic {
            Button {
                Haptic.tap()
                player.toggle()
            } label: {
                Image(systemName: icon)
                    .font(.system(size: compact ? 24 : 30))
                    .foregroundStyle(Theme.accentInk)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: compact ? 58 : 76, height: compact ? 58 : 76)
                    .glassEffect(.regular.tint(settings.accent).interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
        } else {
            orb(label, icon, size: compact ? 58 : 76, iconSize: compact ? 24 : 30, tint: settings.accent,
                color: look.tintedInk(settings.v.glass)) {
                Haptic.tap()
                player.toggle()
            }
        }
    }

    private func orb(_ label: String, _ icon: String, size: CGFloat, iconSize: CGFloat, tint: Color? = nil, color: Color,
                     _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(color)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(OrbButtonStyle(look: look, clearness: settings.v.glass, size: size, tint: tint))
        .accessibilityLabel(label)
    }

    @ViewBuilder private func small(_ label: String, _ icon: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        if look != .classic {
            orb(label, icon, size: compact ? 42 : 48, iconSize: compact ? 15 : 17, tint: on ? settings.accent : nil,
                color: on ? look.tintedInk(settings.v.glass) : ink, action)
        } else {
            smallPlain(label, icon, on: on, action)
        }
    }

    @ViewBuilder private func side(_ label: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        if look != .classic {
            orb(label, icon, size: compact ? 48 : 56, iconSize: compact ? 18 : 21, color: ink, action)
        } else {
            sidePlain(label, icon, action)
        }
    }

    private func smallPlain(_ label: String, _ icon: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(on ? settings.accent : Theme.muted)
                .frame(width: 52, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func sidePlain(_ label: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 25))
                .foregroundStyle(Theme.fg)
                .frame(width: 52, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct SleepNote: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings

    var body: some View {
        if player.sleepAfterTrack {
            note(tr("Таймер сна: остановка после этого трека"))
        } else if let at = player.sleepAt {
            TimelineView(.periodic(from: .now, by: 1)) { c in
                note(tr("Таймер сна: ") + formatTime(max(0, at.timeIntervalSince(c.date))))
            }
        }
    }

    private func note(_ s: String) -> some View {
        Text(s).font(.mono(11).monospacedDigit()).foregroundStyle(settings.accent)
    }
}

// MARK: - Menu

struct MenuBar: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var ui: UIState
    @State private var volume = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                item(tr("Песни"), "music.note", count: library.tracks.count) { ui.panel = .list }
                item(tr("Очередь"), "list.bullet", count: player.queue.count) { ui.panel = .queue }
                item(tr("Радио"), "dot.radiowaves.left.and.right", on: player.radio != nil) { ui.panel = .radio }
                item(tr("Текст песни"), "text.bubble", on: settings.v.lyricsOn) { settings.v.lyricsOn.toggle() }
                item(tr("Эквалайзер"), "slider.vertical.3", dot: settings.eqActive) { ui.panel = .eq }
                item(tr("Настройки"), "gearshape", dot: settings.fxActive) { ui.panel = .fx }
                item(tr("Громкость"), "speaker.wave.2") { showVolume() }
            }
            .modifier(SwipeUp())
            .opacity(volume ? 0 : 1)
            .allowsHitTesting(!volume)
            if volume {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.2").foregroundStyle(settings.accent)
                    SystemVolume(tint: UIColor(settings.accent)).frame(height: 30)
                    Button { hideVolume() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted).frame(width: 30, height: 40)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("Скрыть громкость"))
                }
                .padding(.horizontal, 14)
                .transition(.opacity)
            }
        }
        .frame(height: 52)
        .modifier(PlayerGlass(shape: Capsule()))
    }

    private func showVolume() {
        withAnimation(.easeOut(duration: 0.16)) { volume = true }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { hideVolume() }
        }
    }

    private func hideVolume() {
        hideTask?.cancel()
        withAnimation(.easeOut(duration: 0.16)) { volume = false }
    }

    private func item(_ label: String, _ icon: String, count: Int = 0, on: Bool = false, dot: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(on || dot ? settings.accent : look == .classic ? Theme.fg.opacity(0.8) : look.ink)
                .shadow(color: .black.opacity(look == .classic ? 0 : 0.2), radius: 0.8, y: 0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay(alignment: .top) {
                    if count > 0 {
                        Text(count > 99 ? "99+" : "\(count)")
                            .font(.mono(9.5, .medium))
                            .foregroundStyle(look == .classic ? Theme.fg : Theme.accentInk)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 15)
                            .background(Capsule().fill(look == .classic ? Theme.raise : settings.accent))
                            .offset(x: 13, y: 6)
                    }
                }
                .overlay(alignment: .bottom) {
                    if dot { Circle().fill(settings.accent).frame(width: 4, height: 4).padding(.bottom, 7) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(DimPress(look: look))
        .accessibilityLabel(label)
    }

    private var look: ButtonLook { ButtonLook.of(settings.v.buttons) }
}

/// The phone's own volume: follows the hardware buttons.
struct SystemVolume: UIViewRepresentable {
    let tint: UIColor

    func makeUIView(context: Context) -> MPVolumeView {
        let v = MPVolumeView(frame: .zero)
        v.tintColor = tint
        return v
    }

    func updateUIView(_ v: MPVolumeView, context: Context) { v.tintColor = tint }
}

// MARK: - Toast and dialogs

struct ToastView: View {
    @EnvironmentObject private var toaster: Toaster

    var body: some View {
        ZStack {
            if let m = toaster.message {
                HStack(spacing: 14) {
                    Text(m.text).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.fg)
                    if let a = m.action {
                        Button(a) {
                            toaster.dismiss()
                            m.run?()
                        }
                        .font(.system(size: 14, weight: .bold))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: toaster.message?.id)
    }
}

/// File picker, name prompts and the cover picker. Attached both to the main screen and to the open panel;
/// only the one on top is active.
struct Dialogs: ViewModifier {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var stations: Stations
    @EnvironmentObject private var headphones: Headphones
    @EnvironmentObject private var ui: UIState
    let active: Bool
    @State private var name = ""
    /// The picker closes before it tells what was picked.
    @State private var kind: ImportKind?

    func body(content: Content) -> some View {
        content
            .onChange(of: ui.importing) { _, k in if let k { kind = k } }
            .fileImporter(
                isPresented: Binding(get: { active && ui.importing != nil }, set: { if !$0 { ui.importing = nil } }),
                allowedContentTypes: types,
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                if kind == .profile { return urls.forEach { headphones.add(file: $0) } }
                let lists = urls.filter { StationList.extensions.contains($0.pathExtension.lowercased()) }
                if !lists.isEmpty { stations.add(files: lists) }
                let songs = urls.filter { !lists.contains($0) }
                if !songs.isEmpty { Task { await library.add(urls: songs) } }
            }
            .alert(promptTitle, isPresented: Binding(get: { active && ui.prompt != nil }, set: { if !$0 { ui.prompt = nil } }), presenting: ui.prompt) { prompt in
                TextField(tr("Название"), text: $name)
                Button(tr("Отмена"), role: .cancel) {}
                Button(tr("Сохранить")) {
                    let n = name.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    switch prompt {
                    case .newPlaylist(let id):
                        let p = library.createPlaylist(n, with: id.map { [$0] } ?? [])
                        if id == nil { ui.collection = .playlist(p.id) }
                    case .rename(let id, _):
                        library.rename(id, to: n)
                    }
                }
            }
            .onChange(of: ui.prompt) { _, p in
                switch p {
                case .newPlaylist?: name = tr("Плейлист {}", "\(library.playlists.count + 1)")
                case .rename(_, let old)?: name = old
                case nil: break
                }
            }
            .sheet(isPresented: Binding(get: { active && ui.coverFor != nil }, set: { if !$0 { ui.coverFor = nil } })) {
                if let id = ui.coverFor { CoverPicker(id: id) }
            }
            .sheet(isPresented: Binding(get: { active && ui.editing != nil }, set: { if !$0 { ui.editing = nil } })) {
                if let t = library.track(ui.editing) { TrackEditor(track: t) }
            }
            .sheet(item: Binding(get: { active ? ui.stationSheet : nil }, set: { if $0 == nil { ui.stationSheet = nil } })) { s in
                StationEditor(station: stations.station(s.station))
            }
    }

    private var types: [UTType] {
        func ext(_ list: [String]) -> [UTType] { list.compactMap { UTType(filenameExtension: $0) } }
        switch ui.importing {
        case .folder?: return [.folder]
        case .profile?: return [.plainText]
        case .stations?: return [.m3uPlaylist] + ext(["m3u", "m3u8", "pls"])
        default: return [.audio] + ext(["lrc", "cue", "ogg", "oga", "opus"])
        }
    }

    private var promptTitle: String {
        if case .rename? = ui.prompt { return tr("Переименовать плейлист") }
        return tr("Новый плейлист")
    }
}
