import SwiftUI

/// A full-height window with a title, like the windows of the web version.
struct PanelView: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var ui: UIState
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var stations: Stations
    let panel: Panel

    var body: some View {
        Group {
            if panel == .fx {
                SettingsPanel()
            } else {
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 10) {
                        Text(title).font(.display(18, .semibold)).foregroundStyle(Theme.fg)
                        if panel == .radio { Text("\(stations.all.count)").font(.mono(12)).foregroundStyle(Theme.muted) }
                        if panel == .list { Text("\(library.tracks.count)").font(.mono(12)).foregroundStyle(Theme.muted) }
                        Spacer()
                        if panel == .radio {
                            addButton(tr("Добавить по ссылке"), "link") { ui.stationSheet = StationSheet() }
                            addButton(tr("Добавить список станций"), "plus") { ui.add(.stations) }
                        }
                        if panel == .list {
                            addButton(tr("Передача по Wi-Fi"), "wifi") {
                                ui.panel = .fx
                                ui.settingsPath = [.wifi]
                            }
                            addButton(tr("Добавить папку"), "folder.badge.plus") { ui.add(.folder) }
                            addButton(tr("Добавить файлы"), "plus") { ui.add(.files) }
                        }
                        Button { ui.panel = nil } label: {
                            Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.fg).frame(width: 26, height: 26)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel(tr("Закрыть"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 10)
                    Divider().overlay(Theme.line)
                    switch panel {
                    case .list: ListPanel()
                    case .queue: QueuePanel()
                    case .radio: RadioPanel()
                    case .eq: EQPanel()
                    case .fx: EmptyView()
                    case .stats: StatsPanel()
                    }
                }
            }
        }
        .id(settings.v.language)
        .background(Theme.surface.ignoresSafeArea())
        .overlay(alignment: .bottom) { ToastView().padding(.bottom, 12) }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(settings.colorScheme)
        .tint(settings.accent)
        .modifier(Dialogs(active: true))
    }

    private func addButton(_ label: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(settings.accent).frame(width: 26, height: 26)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
    }

    private var title: String {
        switch panel {
        case .list: tr("Список песен")
        case .queue: tr("Очередь")
        case .radio: tr("Радио")
        case .eq: tr("Эквалайзер")
        case .fx: tr("Настройки")
        case .stats: tr("Статистика")
        }
    }
}

// MARK: - Small pieces

struct Chip: View {
    @EnvironmentObject private var settings: Settings
    let text: String
    var count: Int?
    var dot: Color?
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let dot { Circle().fill(dot).frame(width: 10, height: 10) }
                Text(text).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                if let count { Text("\(count)").font(.mono(11)).opacity(0.7) }
            }
            .foregroundStyle(on ? Theme.accentInk : Theme.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(on ? settings.accent : .clear))
            .overlay(Capsule().stroke(on ? .clear : Theme.line, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Wraps chips onto several lines.
struct Flow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        return CGSize(width: width, height: place(subviews, width).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (i, p) in place(subviews, bounds.width).points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: ProposedViewSize(width: bounds.width, height: nil))
        }
    }

    private func place(_ subviews: Subviews, _ width: CGFloat) -> (points: [CGPoint], height: CGFloat) {
        var points: [CGPoint] = [], x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0, x + size.width > width {
                x = 0
                y += row + spacing
                row = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            row = max(row, size.height)
        }
        return (points, y + row)
    }
}

struct Hint: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 13)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        HStack(spacing: 12) {
            Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.fg).frame(width: 128, alignment: .leading)
            Slider(value: $value, in: range, step: step) { Text(label) }
            Text(format(value)).font(.mono(12).monospacedDigit()).foregroundStyle(Theme.muted).frame(width: 62, alignment: .trailing)
        }
    }
}

struct SwitchRow: View {
    let label: String
    @Binding var on: Bool

    var body: some View {
        Toggle(isOn: $on) { Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.fg) }
    }
}

/// Everything behind the "⋯" button of a song.
struct TrackActions: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var ui: UIState
    let track: Track

    var body: some View {
        Button(tr("Играть следующей"), systemImage: "text.line.first.and.arrowtriangle.forward") { player.playNext(track.id) }
        Button(tr("В конец очереди"), systemImage: "text.append") { player.enqueue(track.id) }
        let fav = library.isFavourite(track.id)
        Button(fav ? tr("Убрать из избранного") : tr("В избранное"), systemImage: fav ? "heart.slash" : "heart") { library.toggleFavourite(track.id) }
        Menu(tr("Добавить в плейлист"), systemImage: "music.note.list") {
            ForEach(library.playlists) { p in Button(p.name) { library.add(track.id, to: p.id) } }
            Button(tr("Новый плейлист"), systemImage: "plus") { ui.prompt = .newPlaylist(track.id) }
        }
        if let p = library.playlists.first(where: { ui.collection == .playlist($0.id) }) {
            Button(tr("Убрать из «{}»", "\(p.name)"), systemImage: "minus.circle") { library.remove(track.id, from: p.id) }
        }
        if !track.hasArtwork || track.artOnline == true {
            Button(track.artOnline == true && track.hasArtwork ? tr("Найти другую обложку") : tr("Найти обложку в интернете"), systemImage: "photo") { ui.coverFor = track.id }
        }
        if track.hasArtwork, track.artOnline == true {
            Button(tr("Убрать найденную обложку"), systemImage: "photo.badge.minus") { library.dropCover(track.id) }
        }
        Button(tr("Изменить название…"), systemImage: "pencil") { ui.editing = track.id }
        Divider()
        Button(tr("Удалить из плеера"), systemImage: "trash", role: .destructive) { library.remove([track.id]) }
    }
}

// MARK: - Song row

struct SongRow: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var settings: Settings
    let track: Track
    let on: Bool
    let play: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button(action: play) {
                HStack(spacing: 12) {
                    CoverView(track: track, corner: 9, letter: 16, thumbnail: true).frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(track.bad == true ? Theme.danger : on ? settings.accent : Theme.fg)
                        Text(track.bad == true ? tr("файл не открывается") : track.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                    }
                    .lineLimit(1)
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(formatTime(track.duration)).font(.mono(12).monospacedDigit())
                        Text(track.rowQuality).font(.mono(10)).opacity(0.85)
                        if track.isLossless {
                            Text("LOSSLESS")
                                .font(.system(size: 8, weight: .heavy))
                                .kerning(0.4)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .overlay(Capsule().stroke(Theme.muted.opacity(0.7), lineWidth: 1))
                                .padding(.top, 2)
                                .accessibilityLabel(tr("без потерь"))
                        }
                    }
                    .foregroundStyle(Theme.muted)
                    .fixedSize()
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            let fav = library.isFavourite(track.id)
            Button { library.toggleFavourite(track.id) } label: {
                Image(systemName: fav ? "heart.fill" : "heart")
                    .font(.system(size: 16))
                    .foregroundStyle(fav ? Theme.danger : Theme.muted)
                    .frame(width: 34, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(fav ? tr("Убрать из избранного") : tr("В избранное"))
            Menu { TrackActions(track: track) } label: {
                Image(systemName: "ellipsis").font(.system(size: 16)).foregroundStyle(Theme.muted).frame(width: 34, height: 40)
            }
            .accessibilityLabel(tr("Действия с песней"))
        }
    }
}

// MARK: - Queue

struct QueuePanel: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings

    var body: some View {
        if player.queue.isEmpty {
            Spacer()
            Text(tr("Очередь пуста. Откройте «Песни» и выберите трек.")).foregroundStyle(Theme.muted).padding(24)
            Spacer()
        } else {
            ScrollViewReader { proxy in
                List {
                    Hint(tr("Нажатие на песню в списке запускает весь список с этого места. Перетащите строку, чтобы поменять порядок; смахните, чтобы убрать."))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    ForEach(Array(player.queue.enumerated()), id: \.offset) { i, id in
                        if let t = library.track(id) { row(i, t).id(i) }
                    }
                    .onMove { player.move(from: $0, to: $1) }
                    .onDelete { $0.forEach { player.removeFromQueue(at: $0) } }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onAppear { if player.qi > 0 { proxy.scrollTo(player.qi, anchor: .center) } }
            }
        }
    }

    private func row(_ i: Int, _ t: Track) -> some View {
        Button { player.jump(to: i) } label: {
            HStack(spacing: 12) {
                Text(i == player.qi ? "▶" : "\(i + 1)").font(.mono(12)).foregroundStyle(Theme.muted).frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(i == player.qi ? settings.accent : Theme.fg)
                    Text(t.subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                .lineLimit(1)
                Spacer(minLength: 6)
                Text(formatTime(t.duration)).font(.mono(12).monospacedDigit()).foregroundStyle(Theme.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparatorTint(Theme.line)
        .deleteDisabled(i == player.qi)
    }
}

// MARK: - Equaliser

struct EQPanel: View {
    @EnvironmentObject private var settings: Settings

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    SwitchRow(label: tr("Эквалайзер включён"), on: $settings.v.eqOn).fixedSize()
                    Spacer()
                    Button(tr("Сбросить")) {
                        settings.v.bands = EQPreset.all[0].bands
                        settings.v.preamp = 0
                    }
                    .buttonStyle(.glass)
                }
                Flow {
                    ForEach(EQPreset.all) { p in
                        Chip(text: tr(p.name), on: settings.preset?.id == p.id) { settings.v.bands = p.bands }
                    }
                    if settings.preset == nil { Chip(text: tr("Свой"), on: true) {} }
                }
                EQCurve(accent: settings.accent) { AudioGraph.response(settings.v, at: $0) }
                    .frame(height: 150)
                    .background(Theme.raise, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                HStack(spacing: 2) {
                    ForEach(0..<10, id: \.self) { i in
                        VStack(spacing: 6) {
                            Text((settings.v.bands[i] > 0 ? "+" : "") + String(format: "%.1f", settings.v.bands[i]))
                                .font(.mono(9.5).monospacedDigit())
                                .foregroundStyle(Theme.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            BandSlider(value: $settings.v.bands[i], accent: settings.accent, dim: !settings.v.eqOn)
                                .frame(height: 170)
                                .accessibilityLabel(AudioGraph.labels[i] + tr(" герц"))
                            Text(AudioGraph.labels[i]).font(.mono(10)).foregroundStyle(Theme.fg).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                SliderRow(label: tr("Предусилитель"), value: $settings.v.preamp, range: -12...6, step: 0.5, format: formatDb)
                Hint(tr("10 полос, ±12 дБ. Двойное нажатие на полосу сбрасывает её в ноль. Крайние полосы поднимают весь самый низ и весь верх, до 20 кГц."))
            }
            .padding(16)
        }
    }
}

struct EQCurve: View {
    let accent: Color
    var dim = false
    let response: (Double) -> Double

    var body: some View {
        Canvas { g, size in
            let l: CGFloat = 34, r: CGFloat = 10, t: CGFloat = 12, b: CGFloat = 20, iw = size.width - l - r, ih = size.height - t - b
            func X(_ f: Double) -> CGFloat { l + CGFloat(log(f / 20) / log(1000)) * iw }
            func Y(_ db: Double) -> CGFloat { t + ih / 2 - CGFloat(db / 15) * ih / 2 }
            func line(_ a: CGPoint, _ c: CGPoint, _ w: CGFloat) {
                var p = Path()
                p.move(to: a)
                p.addLine(to: c)
                g.stroke(p, with: .color(Theme.line), lineWidth: w)
            }
            for db in [-12.0, -6, 0, 6, 12] {
                line(CGPoint(x: l, y: Y(db)), CGPoint(x: size.width - r, y: Y(db)), db == 0 ? 1.5 : 1)
                g.draw(Text((db > 0 ? "+" : "") + String(Int(db))).font(.mono(10)).foregroundStyle(Theme.muted), at: CGPoint(x: l - 6, y: Y(db)), anchor: .trailing)
            }
            for (f, name) in [(31.0, "31"), (125, "125"), (500, "500"), (2000, "2k"), (8000, "8k"), (16000, "16k")] {
                line(CGPoint(x: X(f), y: t), CGPoint(x: X(f), y: t + ih), 1)
                g.draw(Text(name).font(.mono(10)).foregroundStyle(Theme.muted), at: CGPoint(x: X(f), y: size.height - 9))
            }
            var curve = Path()
            for i in 0..<160 {
                let f = 20 * pow(1000, Double(i) / 159)
                let p = CGPoint(x: X(f), y: Y(min(15, max(-15, response(f)))))
                if i == 0 { curve.move(to: p) } else { curve.addLine(to: p) }
            }
            var area = curve
            area.addLine(to: CGPoint(x: X(20000), y: Y(0)))
            area.addLine(to: CGPoint(x: X(20), y: Y(0)))
            area.closeSubpath()
            g.fill(area, with: .color(accent.opacity(dim ? 0.06 : 0.16)))
            g.stroke(curve, with: .color(accent.opacity(dim ? 0.35 : 1)), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

struct BandSlider: View {
    @Binding var value: Double
    let accent: Color
    let dim: Bool

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height, mid = geo.size.width / 2, y = h * CGFloat((12 - value) / 24)
            ZStack {
                Capsule().fill(Theme.line).frame(width: 4).position(x: mid, y: h / 2)
                Rectangle().fill(Theme.muted.opacity(0.5)).frame(width: geo.size.width * 0.5, height: 1).position(x: mid, y: h / 2)
                Capsule().fill(accent.opacity(dim ? 0.35 : 1)).frame(width: 4, height: abs(h / 2 - y)).position(x: mid, y: (h / 2 + y) / 2)
                Circle().fill(Theme.fg.opacity(dim ? 0.35 : 1)).frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .position(x: mid, y: y)
            }
            .contentShape(Rectangle())
            .highPriorityGesture(TapGesture(count: 2).onEnded { value = 0 })
            .gesture(DragGesture(minimumDistance: 2).onChanged { g in
                let v = ((12 - Double(g.location.y / h) * 24) * 2).rounded() / 2
                value = min(12, max(-12, v))
            })
        }
        .accessibilityElement()
        .accessibilityValue(formatDb(value))
        .accessibilityAdjustableAction { value = min(12, max(-12, value + ($0 == .increment ? 0.5 : -0.5))) }
    }
}

// MARK: - Statistics

struct StatsPanel: View {
    @EnvironmentObject private var stats: Stats
    @EnvironmentObject private var settings: Settings
    @State private var selected: Int?
    @State private var confirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                let songs = stats.data.songs.values.filter { $0.plays > 0 }.count
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                    tile(formatSpan(stats.data.total), tr("всего прослушано"))
                    tile("\(stats.plays)", pluralWord(stats.plays, tr("прослушивание"), tr("прослушивания"), tr("прослушиваний")))
                    tile("\(songs)", pluralWord(songs, tr("песня"), tr("разные песни"), tr("разных песен")))
                    tile(formatSpan(stats.today), tr("сегодня"))
                }
                Text(tr("Последние 7 дней, минут в день")).font(.display(14, .semibold)).foregroundStyle(Theme.fg)
                week
                Text(tr("Чаще всего")).font(.display(14, .semibold)).foregroundStyle(Theme.fg)
                if stats.topSongs.isEmpty { Hint(tr("Здесь появятся песни, которые вы слушаете чаще всего.")) }
                ForEach(Array(stats.topSongs.enumerated()), id: \.offset) { i, e in
                    line(i, e.title, e.artist.isEmpty ? tr("Неизвестный исполнитель") : e.artist, plural(e.plays, tr("раз"), tr("раза"), tr("раз#мн")) + "\n" + formatSpan(e.seconds))
                }
                Text(tr("Исполнители")).font(.display(14, .semibold)).foregroundStyle(Theme.fg)
                if stats.topArtists.isEmpty { Hint(tr("Пока пусто.")) }
                ForEach(Array(stats.topArtists.enumerated()), id: \.offset) { i, a in line(i, a.name, nil, formatSpan(a.seconds)) }
                Button(tr("Сбросить статистику")) { confirm = true }.buttonStyle(.glass).tint(Theme.danger)
            }
            .padding(16)
        }
        .onAppear { stats.flush(keepTicking: true) }
        .confirmationDialog(tr("Сбросить всю статистику прослушиваний? Это нельзя отменить."), isPresented: $confirm, titleVisibility: .visible) {
            Button(tr("Сбросить статистику"), role: .destructive) { stats.reset() }
        }
    }

    private func tile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.display(19, .semibold)).foregroundStyle(Theme.fg).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.raise, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var week: some View {
        let days = stats.week, top = max(1, days.map(\.minutes).max() ?? 1)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                    Button { selected = i } label: {
                        VStack(spacing: 4) {
                            Spacer(minLength: 0)
                            if d.minutes >= 0.5, i == 6 || d.minutes == top { Text("\(Int(d.minutes.rounded()))").font(.mono(10)).foregroundStyle(Theme.fg) }
                            RoundedRectangle(cornerRadius: 4).fill(d.minutes < 0.5 ? Theme.line : settings.accent)
                                .frame(width: 28, height: max(2, 110 * d.minutes / top))
                            Text(i == 6 ? tr("сег.") : Self.weekday(d.date)).font(.mono(10)).foregroundStyle(i == 6 ? Theme.fg : Theme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 150)
            Hint(selected.map { Self.long(days[$0].date) + ": " + formatSpan(days[$0].minutes * 60) } ?? tr("Нажмите на столбик, чтобы увидеть точное значение."))
        }
    }

    private static func weekday(_ d: Date) -> String {
        [tr("Вс"), tr("Пн"), tr("Вт"), tr("Ср"), tr("Чт"), tr("Пт"), tr("Сб")][Calendar.current.component(.weekday, from: d) - 1]
    }

    private static func long(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Lang.current.locale
        f.dateFormat = "EEEE, d MMMM"
        let s = f.string(from: d)
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    private func line(_ i: Int, _ title: String, _ sub: String?, _ right: String) -> some View {
        HStack(spacing: 10) {
            Text("\(i + 1)").font(.mono(12)).foregroundStyle(Theme.muted).frame(width: 22, alignment: .trailing)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.fg)
                if let sub { Text(sub).font(.system(size: 13)).foregroundStyle(Theme.muted) }
            }
            .lineLimit(1)
            Spacer(minLength: 6)
            Text(right).font(.mono(12)).foregroundStyle(Theme.muted).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Cover picker

struct CoverPicker: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var covers: CoverFinder
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var list: [CoverCandidate]?
    @State private var message = tr("Ищу обложку…")

    var body: some View {
        NavigationStack {
            Group {
                if let list, !list.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 14) {
                            ForEach(list) { c in
                                Button { choose(c) } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        AsyncImage(url: c.url(200)) { $0.resizable().scaledToFill() } placeholder: { Theme.raise }
                                            .aspectRatio(1, contentMode: .fit)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        Text(c.album).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                } else {
                    VStack(spacing: 12) {
                        if list == nil { ProgressView() }
                        Text(message).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    }
                    .padding(24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.surface.ignoresSafeArea())
            .navigationTitle(tr("Выберите обложку"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Отмена")) { dismiss() } } }
        }
        .task { await search() }
    }

    private func search() async {
        guard let t = library.track(id) else { return }
        do {
            let found = try await covers.candidates(t, thorough: true)
            message = tr("Обложка не найдена")
            list = Array(found.prefix(9))
        } catch is CancellationError {
        } catch {
            if case CoverFinder.Failure.limit = error {
                message = tr("iTunes просит подождать минуту, попробуйте позже")
            } else {
                message = tr("Не удалось связаться с iTunes. Проверьте интернет")
            }
            list = []
        }
    }

    private func choose(_ c: CoverCandidate) {
        guard let t = library.track(id) else { return }
        Task {
            do {
                try await covers.set(c, for: t)
                toast(tr("Обложка сохранена"))
            } catch {
                toast(tr("Не удалось скачать обложку"))
            }
            dismiss()
        }
    }
}
