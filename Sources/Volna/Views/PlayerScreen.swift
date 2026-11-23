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
                landscape(geo.size)
            } else {
                portrait
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .overlay(alignment: .top) {
            if library.importing {
                ProgressView("Читаю песни…")
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
    }

    private var portrait: some View {
        VStack(spacing: 10) {
            header
            CoverArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            TitleBlock()
            VizStrip()
            SeekBlock()
            Transport()
            SleepNote()
            MenuBar()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func landscape(_ size: CGSize) -> some View {
        HStack(spacing: 28) {
            CoverArea()
                .frame(width: min(size.height - 16, size.width * 0.44))
            VStack(spacing: 6) {
                Spacer(minLength: 0)
                TitleBlock(compact: true)
                VizStrip(compact: true)
                SeekBlock()
                Transport(compact: true)
                SleepNote()
                MenuBar()
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Волна")
                .font(.display(18))
                .foregroundStyle(Theme.fg)
            Text("СБОРКА \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")")
                .font(.mono(11))
                .kerning(0.9)
                .foregroundStyle(Theme.muted)
            Spacer()
        }
    }
}

// MARK: - Cover

struct CoverArea: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @State private var shift: CGFloat = 0
    @State private var fadeOut = false

    var body: some View {
        if settings.v.lyricsOn {
            LyricsView()
        } else {
            GeometryReader { geo in
                let side = max(60, min(geo.size.width, geo.size.height))
                ZStack {
                    if settings.v.viz == .ring {
                        RingCover(track: player.current, side: side)
                    } else {
                        CoverView(track: player.current, corner: 24, letter: side * 0.27)
                            .frame(width: side, height: side)
                            .shadow(color: .black.opacity(0.3), radius: 22, y: 14)
                    }
                }
                .offset(x: shift)
                .opacity(fadeOut ? 0 : 1)
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .onTapGesture { settings.v.lyricsOn = true }
                .gesture(DragGesture(minimumDistance: 20)
                    .onEnded { g in
                        let dx = g.translation.width
                        guard abs(dx) > 50, abs(dx) > abs(g.translation.height) * 1.4, !player.queue.isEmpty else { return }
                        swipe(dx < 0 ? -1 : 1)
                        if dx < 0 { player.next() } else { player.previousTrack() }
                    })
            }
            .accessibilityElement()
            .accessibilityLabel("Обложка. Нажатие открывает текст песни, смахивание переключает песню")
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
        let t = player.current
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Text(t?.title ?? "Ничего не выбрано")
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
                    .accessibilityLabel(on ? "Убрать из избранного" : "Добавить в избранное")
                }
            }
            Text(t.map { $0.artist.isEmpty ? "Неизвестный исполнитель" : $0.artist } ?? "Откройте «Песни» и выберите трек")
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            if let t {
                Text(formatLine(t))
                    .font(.mono(11))
                    .kerning(0.3)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(compact ? 1 : 2)
                    .padding(.top, 2)
            }
        }
    }

    private func formatLine(_ t: Track) -> String {
        var p = [t.formatLine]
        if settings.v.normalize, let g = t.gainDb, g != 0 { p.append("выравн. " + formatDb(g)) }
        if player.qi >= 0 { p.append("\(player.qi + 1) из \(player.queue.count)") }
        return p.joined(separator: " · ")
    }
}

// MARK: - Wave

struct SeekBlock: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var clock: PlaybackClock
    @State private var dragFrom: Double?
    @State private var dragging: Double?

    var body: some View {
        let t = player.current
        VStack(spacing: 2) {
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: 1 / 60, paused: !player.isPlaying || dragging != nil)) { _ in
                    let p = player.duration > 0 ? min(1, max(0, (dragging ?? player.position) / player.duration)) : 0
                    WaveCanvas(wave: t?.wave, hasTrack: t != nil, progress: p, accent: settings.accent)
                }
                .contentShape(Rectangle())
                .gesture(drag(span: WaveCanvas.span(geo.size.width)))
            }
            .frame(height: 48)
            .accessibilityElement()
            .accessibilityLabel("Позиция в треке")
            .accessibilityValue(formatTime(clock.time))
            .accessibilityAdjustableAction { dir in
                player.seek(to: player.position + (dir == .increment ? 10 : -10))
            }
            HStack {
                Text(formatTime(dragging ?? clock.time))
                    .foregroundStyle(dragging != nil ? settings.accent : Theme.muted)
                Spacer()
                Text(formatTime(player.duration)).foregroundStyle(Theme.muted)
            }
            .font(.mono(12).monospacedDigit())
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

/// The whole track is laid out twice as wide as the screen and slides left as it plays:
/// the centre line is "now", the played part is to its left in the accent colour.
struct WaveCanvas: View {
    let wave: [Int]?
    let hasTrack: Bool
    let progress: Double
    let accent: Color

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
    var compact = false

    var body: some View {
        HStack(spacing: 0) {
            small(player.shuffle ? "Перемешивание включено" : "Перемешать", "shuffle", on: player.shuffle) { player.toggleShuffle() }
            Spacer()
            side("Предыдущий", "backward.end.fill") { player.previous() }
            Spacer()
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: compact ? 24 : 30))
                    .foregroundStyle(Theme.accentInk)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: compact ? 58 : 76, height: compact ? 58 : 76)
                    .glassEffect(.regular.tint(settings.accent).interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Пауза" : "Играть")
            Spacer()
            side("Следующий", "forward.end.fill") { player.next() }
            Spacer()
            small("Повтор", player.repeatMode == .one ? "repeat.1" : "repeat", on: player.repeatMode != .off) { player.cycleRepeat() }
        }
    }

    private func small(_ label: String, _ icon: String, on: Bool, _ action: @escaping () -> Void) -> some View {
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

    private func side(_ label: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
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
            note("Таймер сна: остановка после этого трека")
        } else if let at = player.sleepAt {
            TimelineView(.periodic(from: .now, by: 1)) { c in
                note("Таймер сна: " + formatTime(max(0, at.timeIntervalSince(c.date))))
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
        HStack(spacing: 8) {
            ZStack {
                HStack(spacing: 0) {
                    item("Песни", "music.note", count: library.tracks.count) { ui.panel = .list }
                    item("Очередь", "list.bullet", count: player.queue.count) { ui.panel = .queue }
                    item("Текст песни", "text.bubble", on: settings.v.lyricsOn) { settings.v.lyricsOn.toggle() }
                    item("Эквалайзер", "slider.vertical.3", dot: settings.eqActive) { ui.panel = .eq }
                    item("Настройки", "gearshape", dot: settings.fxActive) { ui.panel = .fx }
                    item("Громкость", "speaker.wave.2") { showVolume() }
                    item("Выбрать папку", "folder") { ui.add(.folder) }
                }
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
                        .accessibilityLabel("Скрыть громкость")
                    }
                    .padding(.horizontal, 14)
                    .transition(.opacity)
                }
            }
            .frame(height: 52)
            .glassEffect(.regular, in: .capsule)

            Button { ui.add(.files) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.accentInk)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular.tint(settings.accent).interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Добавить файлы")
        }
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
                .foregroundStyle(on || dot ? settings.accent : Theme.fg.opacity(0.8))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay(alignment: .top) {
                    if count > 0 {
                        Text(count > 99 ? "99+" : "\(count)")
                            .font(.mono(9.5, .medium))
                            .foregroundStyle(Theme.fg)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 15)
                            .background(Capsule().fill(Theme.raise))
                            .offset(x: 13, y: 6)
                    }
                }
                .overlay(alignment: .bottom) {
                    if dot { Circle().fill(settings.accent).frame(width: 4, height: 4).padding(.bottom, 7) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
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
    @EnvironmentObject private var ui: UIState
    let active: Bool
    @State private var name = ""

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: Binding(get: { active && ui.importing != nil }, set: { if !$0 { ui.importing = nil } }),
                allowedContentTypes: ui.importing == .folder ? [.folder] : [.audio] + [UTType(filenameExtension: "lrc")].compactMap { $0 },
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result { Task { await library.add(urls: urls) } }
            }
            .alert(promptTitle, isPresented: Binding(get: { active && ui.prompt != nil }, set: { if !$0 { ui.prompt = nil } }), presenting: ui.prompt) { prompt in
                TextField("Название", text: $name)
                Button("Отмена", role: .cancel) {}
                Button("Сохранить") {
                    let n = name.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    switch prompt {
                    case .newPlaylist(let id):
                        let p = library.createPlaylist(n, with: id.map { [$0] } ?? [])
                        if id == nil { ui.collection = p.id.uuidString }
                    case .rename(let id, _):
                        library.rename(id, to: n)
                    }
                }
            }
            .onChange(of: ui.prompt) { _, p in
                switch p {
                case .newPlaylist?: name = "Плейлист \(library.playlists.count + 1)"
                case .rename(_, let old)?: name = old
                case nil: break
                }
            }
            .sheet(isPresented: Binding(get: { active && ui.coverFor != nil }, set: { if !$0 { ui.coverFor = nil } })) {
                if let id = ui.coverFor { CoverPicker(id: id) }
            }
    }

    private var promptTitle: String {
        if case .rename? = ui.prompt { return "Переименовать плейлист" }
        return "Новый плейлист"
    }
}
