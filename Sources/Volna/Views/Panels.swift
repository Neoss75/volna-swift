import SwiftUI

/// A full-height window with a title, like the windows of the web version.
struct PanelView: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var ui: UIState
    @EnvironmentObject private var library: Library
    let panel: Panel

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title).font(.display(18, .semibold)).foregroundStyle(Theme.fg)
                if panel == .list { Text("\(library.tracks.count)").font(.mono(12)).foregroundStyle(Theme.muted) }
                Spacer()
                Button { ui.panel = nil } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.fg).frame(width: 26, height: 26)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Закрыть")
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 10)
            Divider().overlay(Theme.line)
            switch panel {
            case .list: ListPanel()
            case .queue: QueuePanel()
            case .eq: EQPanel()
            case .fx: FXPanel()
            case .stats: StatsPanel()
            }
        }
        .background(Theme.surface.ignoresSafeArea())
        .overlay(alignment: .bottom) { ToastView().padding(.bottom, 12) }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(settings.colorScheme)
        .tint(settings.accent)
        .modifier(Dialogs(active: true))
    }

    private var title: String {
        switch panel {
        case .list: "Список песен"
        case .queue: "Очередь"
        case .eq: "Эквалайзер"
        case .fx: "Настройки"
        case .stats: "Статистика"
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
        Button("Играть следующей", systemImage: "text.line.first.and.arrowtriangle.forward") { player.playNext(track.id) }
        Button("В конец очереди", systemImage: "text.append") { player.enqueue(track.id) }
        let fav = library.isFavourite(track.id)
        Button(fav ? "Убрать из избранного" : "В избранное", systemImage: fav ? "heart.slash" : "heart") { library.toggleFavourite(track.id) }
        Menu("Добавить в плейлист", systemImage: "music.note.list") {
            ForEach(library.playlists) { p in Button(p.name) { library.add(track.id, to: p.id) } }
            Button("Новый плейлист", systemImage: "plus") { ui.prompt = .newPlaylist(track.id) }
        }
        if let p = library.playlists.first(where: { $0.id.uuidString == ui.collection }) {
            Button("Убрать из «\(p.name)»", systemImage: "minus.circle") { library.remove(track.id, from: p.id) }
        }
        if !track.hasArtwork || track.artOnline == true {
            Button(track.artOnline == true && track.hasArtwork ? "Найти другую обложку" : "Найти обложку в интернете", systemImage: "photo") { ui.coverFor = track.id }
        }
        if track.hasArtwork, track.artOnline == true {
            Button("Убрать найденную обложку", systemImage: "photo.badge.minus") { library.dropCover(track.id) }
        }
        Divider()
        Button("Удалить из плеера", systemImage: "trash", role: .destructive) { library.remove([track.id]) }
    }
}

// MARK: - Song list

struct ListPanel: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var ui: UIState
    @State private var query = ""
    @State private var folder: String?
    @State private var confirmDelete = false
    @State private var confirmPlaylist = false

    private var playlist: Playlist? { library.playlists.first { $0.id.uuidString == ui.collection } }

    private var base: [Track] {
        if ui.collection == "fav" { return library.tracks.filter { library.isFavourite($0.id) } }
        if let p = playlist { return p.keys.compactMap { library.track($0) } }
        return library.tracks
    }

    private var shown: [Track] {
        let q = query.trimmingCharacters(in: .whitespaces)
        var l = base.filter { t in
            (ui.collection != "all" || folder == nil || t.folder == folder)
                && (q.isEmpty || [t.title, t.artist, t.album, t.folder ?? ""].joined(separator: " ").localizedCaseInsensitiveContains(q))
        }
        switch settings.v.sort {
        case "title": l.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case "artist": l.sort { ($0.artist.isEmpty ? "я" : $0.artist, $0.title) < ($1.artist.isEmpty ? "я" : $1.artist, $1.title) }
        default: break
        }
        return l
    }

    private var folders: [(String, Int)] {
        var n: [String: Int] = [:]
        for t in library.tracks { if let f = t.folder { n[f, default: 0] += 1 } }
        return n.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
    }

    var body: some View {
        let list = shown, ids = list.map(\.id)
        VStack(spacing: 0) {
            tools
            if list.isEmpty {
                Spacer()
                Text(emptyText).foregroundStyle(Theme.muted).multilineTextAlignment(.center).padding(24)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(list) { t in
                                SongRow(track: t, on: t.id == player.current?.id) { player.play(t.id, from: ids) }
                                    .id(t.id)
                                Divider().overlay(Theme.line)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .onAppear { if let id = player.current?.id, ids.contains(id) { proxy.scrollTo(id, anchor: .center) } }
                }
            }
            footer(list)
        }
    }

    private var tools: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    TextField("Поиск по названию, артисту…", text: $query)
                        .font(.system(size: 15))
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Очистить поиск")
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Theme.raise, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Menu {
                    Picker("Сортировка", selection: $settings.v.sort) {
                        Text("По добавлению").tag("added")
                        Text("По названию").tag("title")
                        Text("По исполнителю").tag("artist")
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(["title": "По названию", "artist": "По исполнителю"][settings.v.sort] ?? "По добавлению")
                            .font(.system(size: 14))
                            .lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Theme.fg)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Theme.raise, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Chip(text: "Все", count: library.tracks.count, on: ui.collection == "all") { ui.collection = "all" }
                    Chip(text: "♥ Избранное", count: library.tracks.filter { library.isFavourite($0.id) }.count, on: ui.collection == "fav") { ui.collection = "fav" }
                    ForEach(library.playlists) { p in
                        Chip(text: p.name, count: p.keys.filter { library.track($0) != nil }.count, on: ui.collection == p.id.uuidString) { ui.collection = p.id.uuidString }
                    }
                    Chip(text: "+ Плейлист", on: false) { ui.prompt = .newPlaylist(nil) }
                }
            }
            if ui.collection == "all", !folders.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Chip(text: "Все папки", on: folder == nil) { folder = nil }
                        ForEach(folders, id: \.0) { f in
                            Chip(text: f.0.components(separatedBy: " / ").last ?? f.0, count: f.1, on: folder == f.0) { folder = f.0 }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func footer(_ list: [Track]) -> some View {
        HStack {
            Text(list.count != base.count ? "Показано \(list.count) из \(base.count)" : plural(base.count, "песня", "песни", "песен"))
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            Spacer()
            if let p = playlist {
                Button("Переименовать") { ui.prompt = .rename(p.id, p.name) }.buttonStyle(.glass)
                Button("Удалить") { confirmPlaylist = true }.buttonStyle(.glass).tint(Theme.danger)
            } else {
                Menu {
                    Button("Добавить файлы", systemImage: "doc.badge.plus") { ui.add(.files) }
                    Button("Добавить папку", systemImage: "folder.badge.plus") { ui.add(.folder) }
                } label: { Text("Добавить") }
                .buttonStyle(.glass)
                Button(list.count == library.tracks.count ? "Удалить все" : "Удалить (\(list.count))") { confirmDelete = true }
                    .buttonStyle(.glass)
                    .tint(Theme.danger)
                    .disabled(list.isEmpty)
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Divider().overlay(Theme.line) }
        .confirmationDialog("Убрать из плеера: \(plural(list.count, "песня", "песни", "песен"))? Файлы останутся на месте.", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Убрать из плеера", role: .destructive) { library.remove(Set(list.map(\.id))) }
        }
        .confirmationDialog("Удалить плейлист «\(playlist?.name ?? "")»? Песни останутся.", isPresented: $confirmPlaylist, titleVisibility: .visible) {
            Button("Удалить плейлист", role: .destructive) {
                if let p = playlist {
                    ui.collection = "all"
                    library.deletePlaylist(p.id)
                }
            }
        }
    }

    private var emptyText: String {
        if ui.collection == "fav" { return "В избранном пока пусто. Нажмите ♥ у песни, чтобы добавить её сюда." }
        if playlist != nil { return "Плейлист пуст. Добавьте песни через «⋯» → «Добавить в плейлист»." }
        return library.tracks.isEmpty ? "Список пуст. Добавьте файлы или папку." : "Ничего не найдено"
    }
}

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
                        Text(track.bad == true ? "файл не открывается" : track.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                    }
                    .lineLimit(1)
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(formatTime(track.duration)).font(.mono(12).monospacedDigit())
                        Text(track.rowQuality).font(.mono(10)).opacity(0.85)
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
            .accessibilityLabel(fav ? "Убрать из избранного" : "В избранное")
            Menu { TrackActions(track: track) } label: {
                Image(systemName: "ellipsis").font(.system(size: 16)).foregroundStyle(Theme.muted).frame(width: 34, height: 40)
            }
            .accessibilityLabel("Действия с песней")
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
            Text("Очередь пуста. Откройте «Песни» и выберите трек.").foregroundStyle(Theme.muted).padding(24)
            Spacer()
        } else {
            ScrollViewReader { proxy in
                List {
                    Hint("Нажатие на песню в списке запускает весь список с этого места. Перетащите строку, чтобы поменять порядок; смахните, чтобы убрать.")
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
                    SwitchRow(label: "Эквалайзер включён", on: $settings.v.eqOn).fixedSize()
                    Spacer()
                    Button("Сбросить") {
                        settings.v.bands = EQPreset.all[0].bands
                        settings.v.preamp = 0
                    }
                    .buttonStyle(.glass)
                }
                Flow {
                    ForEach(EQPreset.all) { p in
                        Chip(text: p.name, on: settings.preset?.id == p.id) { settings.v.bands = p.bands }
                    }
                    if settings.preset == nil { Chip(text: "Свой", on: true) {} }
                }
                EQCurve(v: settings.v, accent: settings.accent)
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
                                .accessibilityLabel(AudioGraph.labels[i] + " герц")
                            Text(AudioGraph.labels[i]).font(.mono(10)).foregroundStyle(Theme.fg).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                SliderRow(label: "Предусилитель", value: $settings.v.preamp, range: -12...6, step: 0.5, format: formatDb)
                Hint("10 полос, ±12 дБ. Двойное нажатие на полосу сбрасывает её в ноль. Крайние полосы поднимают весь самый низ и весь верх, до 20 кГц.")
            }
            .padding(16)
        }
    }
}

struct EQCurve: View {
    let v: Settings.Values
    let accent: Color

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
                let p = CGPoint(x: X(f), y: Y(min(15, max(-15, AudioGraph.response(v, at: f)))))
                if i == 0 { curve.move(to: p) } else { curve.addLine(to: p) }
            }
            var area = curve
            area.addLine(to: CGPoint(x: X(20000), y: Y(0)))
            area.addLine(to: CGPoint(x: X(20), y: Y(0)))
            area.closeSubpath()
            g.fill(area, with: .color(accent.opacity(0.16)))
            g.stroke(curve, with: .color(accent), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
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

// MARK: - Settings

struct FXPanel: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var covers: CoverFinder
    @EnvironmentObject private var analyzer: Analyzer
    @EnvironmentObject private var stats: Stats
    @EnvironmentObject private var ui: UIState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                group("Обработка") {
                    SliderRow(label: "Усиление баса", value: $settings.v.bass, range: 0...12, step: 0.5, format: formatDb)
                    SliderRow(label: "Баланс", value: $settings.v.balance, range: -100...100, step: 5) {
                        $0 == 0 ? "центр" : ($0 < 0 ? "Л " : "П ") + "\(Int(abs($0)))%"
                    }
                    SwitchRow(label: "Лимитер (убирает хрип при сильном усилении)", on: $settings.v.limiter)
                    SwitchRow(label: "Выравнивать громкость между песнями", on: $settings.v.normalize)
                    Hint(normInfo)
                    Button("Измерить всю библиотеку") { measureAll() }.buttonStyle(.glass)
                }
                group("Обложки") {
                    SwitchRow(label: "Искать обложки альбомов в интернете", on: $settings.v.onlineArt)
                    Hint(artInfo)
                    Button("Найти для всей библиотеки") { covers.findAll() }.buttonStyle(.glass)
                }
                group("Переход между песнями") {
                    SliderRow(label: "Кроссфейд", value: $settings.v.crossfade, range: 0...12, step: 1) { $0 == 0 ? "выкл" : "\(Int($0)) с" }
                    Hint("Конец песни плавно затухает, а следующая песня плавно нарастает поверх него. Работает при автоматическом переходе. Кнопки «вперёд» и «назад» и свайп по обложке переключают сразу.")
                }
                group("Скорость") {
                    SliderRow(label: "Скорость", value: $settings.v.rate, range: 0.5...2, step: 0.05) { String(format: "%.2f×", $0) }
                    SwitchRow(label: "Сохранять высоту тона", on: $settings.v.keepPitch)
                }
                group("Таймер сна") {
                    Flow {
                        Chip(text: "Выключен", on: player.sleepAt == nil && !player.sleepAfterTrack) { player.sleep(minutes: nil) }
                        ForEach([15, 30, 45, 60], id: \.self) { m in
                            Chip(text: m == 60 ? "1 час" : "\(m) минут", on: false) { player.sleep(minutes: m); toast("Таймер сна: \(m) минут") }
                        }
                        Chip(text: "После трека", on: player.sleepAfterTrack) { player.sleepAfterThisTrack() }
                    }
                    SleepNote()
                }
                group("Оформление") {
                    Flow {
                        ForEach([("system", "Как в системе"), ("dark", "Тёмная"), ("light", "Светлая")], id: \.0) { m in
                            Chip(text: m.1, on: settings.v.themeMode == m.0) { settings.v.themeMode = m.0 }
                        }
                    }
                    Flow {
                        ForEach(Accent.all) { a in
                            Chip(text: a.name, dot: a.color, on: settings.v.accent == a.id) { settings.v.accent = a.id }
                        }
                    }
                }
                group("Визуализация") {
                    Flow {
                        ForEach(VizMode.allCases) { m in
                            Chip(text: m.name, on: settings.v.viz == m) { settings.v.viz = m }
                        }
                    }
                    Hint("Режим также переключается нажатием на визуализацию под обложкой.")
                }
                group("Статистика") {
                    Hint(stats.summary)
                    Button("Открыть статистику") { ui.panel = .stats }.buttonStyle(.glass)
                }
                group("Файлы", last: true) {
                    Hint("Песни не копируются: плеер играет их там, где они лежат в «Файлах». Удаление из списка сами файлы не трогает. Если переместить или удалить файл, песня перестанет открываться.")
                }
            }
            .padding(16)
        }
    }

    private func group<C: View>(_ title: String, last: Bool = false, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.display(14, .semibold)).foregroundStyle(Theme.fg)
            content()
            if !last { Divider().overlay(Theme.line) }
        }
    }

    private var normInfo: String {
        guard settings.v.normalize else {
            return "Плеер один раз измеряет громкость каждой песни и подстраивает её, чтобы тихие и громкие треки звучали одинаково."
        }
        let done = library.tracks.filter { $0.gainDb != nil }.count
        var s = "Измерено \(done) из \(library.tracks.count)"
        if analyzer.left > 0 { s += " · идёт измерение…" }
        if let g = player.current?.gainDb { s += " · текущая песня: " + formatDb(g) }
        return s
    }

    private var artInfo: String {
        var s = settings.v.onlineArt
            ? "Для песен без своей обложки плеер ищет её в каталоге iTunes по исполнителю и альбому. Туда отправляются только эти названия."
            : "Поиск выключен."
        let found = library.tracks.filter { $0.artOnline == true && $0.hasArtwork }.count, no = library.tracks.filter { !$0.hasArtwork }.count
        if found > 0 { s += " Найдено обложек: \(found)." }
        if no > 0 { s += " Без обложки: " + plural(no, "песня", "песни", "песен") + "." }
        if covers.left > 0 { s += " Идёт поиск, осталось \(covers.left). iTunes отвечает не чаще раза в 3 секунды, так что это займёт несколько минут." }
        return s
    }

    private func measureAll() {
        let l = library.tracks.filter { ($0.gainDb == nil || $0.wave == nil) && $0.bad != true }
        if l.isEmpty { toast("Вся библиотека уже измерена"); return }
        for t in l { analyzer.request(t, first: false) }
        toast("Измеряю громкость: " + plural(l.count, "песня", "песни", "песен"))
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
                    tile(formatSpan(stats.data.total), "всего прослушано")
                    tile("\(stats.plays)", pluralWord(stats.plays, "прослушивание", "прослушивания", "прослушиваний"))
                    tile("\(songs)", pluralWord(songs, "песня", "разные песни", "разных песен"))
                    tile(formatSpan(stats.today), "сегодня")
                }
                Text("Последние 7 дней, минут в день").font(.display(14, .semibold)).foregroundStyle(Theme.fg)
                week
                Text("Чаще всего").font(.display(14, .semibold)).foregroundStyle(Theme.fg)
                if stats.topSongs.isEmpty { Hint("Здесь появятся песни, которые вы слушаете чаще всего.") }
                ForEach(Array(stats.topSongs.enumerated()), id: \.offset) { i, e in
                    line(i, e.title, e.artist.isEmpty ? "Неизвестный исполнитель" : e.artist, plural(e.plays, "раз", "раза", "раз") + "\n" + formatSpan(e.seconds))
                }
                Text("Исполнители").font(.display(14, .semibold)).foregroundStyle(Theme.fg)
                if stats.topArtists.isEmpty { Hint("Пока пусто.") }
                ForEach(Array(stats.topArtists.enumerated()), id: \.offset) { i, a in line(i, a.name, nil, formatSpan(a.seconds)) }
                Button("Сбросить статистику") { confirm = true }.buttonStyle(.glass).tint(Theme.danger)
            }
            .padding(16)
        }
        .onAppear { stats.flush(keepTicking: true) }
        .confirmationDialog("Сбросить всю статистику прослушиваний? Это нельзя отменить.", isPresented: $confirm, titleVisibility: .visible) {
            Button("Сбросить статистику", role: .destructive) { stats.reset() }
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
                            Text(i == 6 ? "сег." : Self.weekday(d.date)).font(.mono(10)).foregroundStyle(i == 6 ? Theme.fg : Theme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 150)
            Hint(selected.map { Self.long(days[$0].date) + ": " + formatSpan(days[$0].minutes * 60) } ?? "Нажмите на столбик, чтобы увидеть точное значение.")
        }
    }

    private static func weekday(_ d: Date) -> String {
        ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"][Calendar.current.component(.weekday, from: d) - 1]
    }

    private static func long(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
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
    @State private var message = "Ищу обложку…"

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
            .navigationTitle("Выберите обложку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
        }
        .task { await search() }
    }

    private func search() async {
        guard let t = library.track(id) else { return }
        do {
            let found = try await covers.candidates(t, thorough: true)
            message = "Обложка не найдена"
            list = Array(found.prefix(9))
        } catch is CancellationError {
        } catch {
            if case CoverFinder.Failure.limit = error {
                message = "iTunes просит подождать минуту, попробуйте позже"
            } else {
                message = "Не удалось связаться с iTunes. Проверьте интернет"
            }
            list = []
        }
    }

    private func choose(_ c: CoverCandidate) {
        guard let t = library.track(id) else { return }
        Task {
            do {
                try await covers.set(c, for: t)
                toast("Обложка сохранена")
            } catch {
                toast("Не удалось скачать обложку")
            }
            dismiss()
        }
    }
}
