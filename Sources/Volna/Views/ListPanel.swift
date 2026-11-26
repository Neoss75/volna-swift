import SwiftUI

/// What the song list shows.
enum SongCollection: Hashable {
    case all, favourites
    case recent, often, forgotten, lossless
    case playlist(UUID)
    case album(String), artist(String), folder(String)

    /// Opened from the albums, artists or folders tab: shown with a header and a way back.
    var isGroup: Bool {
        switch self {
        case .album, .artist, .folder: true
        default: false
        }
    }
}

enum ListTab: String, CaseIterable {
    case songs = "Песни", albums = "Альбомы", artists = "Исполнители", folders = "Папки"
}

/// One album, artist or folder.
private struct SongGroup: Identifiable {
    let id: SongCollection
    let title: String
    let subtitle: String
    let tracks: [Track]

    var cover: Track? { tracks.first { $0.hasArtwork } ?? tracks.first }
}

extension Library {
    static func albumKey(_ t: Track) -> String { t.album.lowercased().trimmingCharacters(in: .whitespaces) }
    static func artistKey(_ t: Track) -> String { t.artist.lowercased().trimmingCharacters(in: .whitespaces) }

    func songs(in c: SongCollection, stats: Stats) -> [Track] {
        switch c {
        case .all: return tracks
        case .favourites: return tracks.filter { isFavourite($0.id) }
        case .recent:
            return Array(tracks.enumerated().sorted {
                let a = $0.element.addedAt ?? .distantPast, b = $1.element.addedAt ?? .distantPast
                return a != b ? a > b : $0.offset > $1.offset
            }.map(\.element).prefix(50))
        case .often:
            return Array(tracks.filter { (stats.entry($0.id)?.plays ?? 0) > 0 }
                .sorted { (stats.entry($0.id)?.plays ?? 0, stats.entry($0.id)?.seconds ?? 0) > (stats.entry($1.id)?.plays ?? 0, stats.entry($1.id)?.seconds ?? 0) }
                .prefix(50))
        case .forgotten:
            return Array(tracks.sorted { (stats.entry($0.id)?.last ?? .distantPast) < (stats.entry($1.id)?.last ?? .distantPast) }.prefix(50))
        case .lossless: return tracks.filter(\.isLossless)
        case .playlist(let id):
            return (playlists.first { $0.id == id }?.keys ?? []).compactMap { track($0) }
        case .album(let key):
            return tracks.filter { Self.albumKey($0) == key }.sorted {
                let a = $0.trackNo ?? .max, b = $1.trackNo ?? .max
                return a != b ? a < b : $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        case .artist(let key):
            return tracks.filter { Self.artistKey($0) == key }.sorted {
                $0.album != $1.album ? $0.album.localizedStandardCompare($1.album) == .orderedAscending
                    : ($0.trackNo ?? .max, $0.title) < ($1.trackNo ?? .max, $1.title)
            }
        case .folder(let name):
            return tracks.filter { $0.folder == name }.sorted {
                let order = $0.fileName.localizedStandardCompare($1.fileName)
                return order != .orderedSame ? order == .orderedAscending : ($0.cueStart ?? 0) < ($1.cueStart ?? 0)
            }
        }
    }
}

struct ListPanel: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var stats: Stats
    @EnvironmentObject private var ui: UIState
    @State private var query = ""
    @State private var confirmDelete = false
    @State private var confirmPlaylist = false

    private var playlist: Playlist? { library.playlists.first { ui.collection == .playlist($0.id) } }
    private var search: String { query.trimmingCharacters(in: .whitespaces) }
    /// The tab shows groups until one is opened or something is typed in the search field.
    private var showsGroups: Bool { ui.listTab != .songs && !ui.collection.isGroup && search.isEmpty }

    private var base: [Track] {
        library.songs(in: ui.listTab != .songs && !ui.collection.isGroup ? .all : ui.collection, stats: stats)
    }

    private func shown(_ base: [Track]) -> [Track] {
        var l = search.isEmpty ? base : base.filter {
            [$0.title, $0.artist, $0.album, $0.folder ?? ""].joined(separator: " ").localizedCaseInsensitiveContains(search)
        }
        if [.all, .favourites, .lossless].contains(ui.collection) || ui.listTab != .songs && !ui.collection.isGroup {
            switch settings.v.sort {
            case "title": l.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            case "artist": l.sort { ($0.artist.isEmpty ? "я" : $0.artist, $0.title) < ($1.artist.isEmpty ? "я" : $1.artist, $1.title) }
            default: break
            }
        }
        return l
    }

    var body: some View {
        let base = base, list = shown(base), ids = list.map(\.id)
        VStack(spacing: 0) {
            tools
            if showsGroups {
                groups
            } else if list.isEmpty {
                if ui.collection.isGroup { header(base) }
                Spacer()
                Text(emptyText).foregroundStyle(Theme.muted).multilineTextAlignment(.center).padding(24)
                if library.tracks.isEmpty { addButtons }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if ui.collection.isGroup { header(base) }
                            ForEach(list) { t in
                                SongRow(track: t, on: t.id == player.current?.id) { player.play(t.id, from: ids) }
                                    .id(t.id)
                                Divider().overlay(Theme.line)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .onAppear {
                        if !ui.collection.isGroup, let id = player.current?.id, ids.contains(id) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
            if !showsGroups { footer(list, of: base.count) }
        }
        .onAppear { stats.flush(keepTicking: true) }
        .onChange(of: library.tracks.count) { _, _ in
            if ui.collection.isGroup, library.songs(in: ui.collection, stats: stats).isEmpty { ui.collection = .all }
        }
    }

    // MARK: Top

    private var tools: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(tr("Раздел"), selection: Binding(get: { ui.listTab }, set: {
                ui.listTab = $0
                if ui.collection.isGroup { ui.collection = .all }
            })) {
                ForEach(ListTab.allCases, id: \.self) { Text(tr($0.rawValue)).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    TextField(tr("Поиск по названию, артисту…"), text: $query)
                        .font(.system(size: 15))
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted) }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tr("Очистить поиск"))
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Theme.raise, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                if ui.listTab == .songs { sortMenu }
            }
            if ui.listTab == .songs {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Chip(text: tr("Все"), count: library.tracks.count, on: ui.collection == .all) { ui.collection = .all }
                        Chip(text: tr("♥ Избранное"), count: library.tracks.filter { library.isFavourite($0.id) }.count, on: ui.collection == .favourites) { ui.collection = .favourites }
                        Chip(text: tr("Без потерь"), count: library.tracks.filter(\.isLossless).count, on: ui.collection == .lossless) { ui.collection = .lossless }
                        Chip(text: tr("Недавние"), on: ui.collection == .recent) { ui.collection = .recent }
                        Chip(text: tr("Часто играют"), on: ui.collection == .often) { ui.collection = .often }
                        Chip(text: tr("Давно не слушали"), on: ui.collection == .forgotten) { ui.collection = .forgotten }
                        ForEach(library.playlists) { p in
                            Chip(text: p.name, count: p.keys.filter { library.track($0) != nil }.count, on: ui.collection == .playlist(p.id)) { ui.collection = .playlist(p.id) }
                        }
                        Chip(text: tr("+ Плейлист"), on: false) { ui.prompt = .newPlaylist(nil) }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var sortMenu: some View {
        Menu {
            Picker(tr("Сортировка"), selection: $settings.v.sort) {
                Text(tr("По добавлению")).tag("added")
                Text(tr("По названию")).tag("title")
                Text(tr("По исполнителю")).tag("artist")
            }
        } label: {
            HStack(spacing: 5) {
                Text(["title": tr("По названию"), "artist": tr("По исполнителю")][settings.v.sort] ?? tr("По добавлению"))
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

    // MARK: Albums, artists, folders

    private var allGroups: [SongGroup] {
        var order: [String] = [], byKey: [String: [Track]] = [:]
        for t in library.tracks {
            let key: String
            switch ui.listTab {
            case .albums: key = Library.albumKey(t)
            case .artists: key = Library.artistKey(t)
            default:
                guard let f = t.folder else { continue }
                key = f
            }
            if byKey[key] == nil { order.append(key) }
            byKey[key, default: []].append(t)
        }
        return order.compactMap { key -> SongGroup? in
            guard let list = byKey[key], let first = list.first else { return nil }
            let n = plural(list.count, tr("песня"), tr("песни"), tr("песен"))
            switch ui.listTab {
            case .albums:
                let who = Set(list.map { Library.artistKey($0) })
                let artist = who.count > 1 ? tr("Разные исполнители") : first.artist
                return SongGroup(id: .album(key), title: key.isEmpty ? tr("Без альбома") : first.album, subtitle: artist.isEmpty ? n : artist + " · " + n, tracks: list)
            case .artists:
                return SongGroup(id: .artist(key), title: key.isEmpty ? tr("Неизвестный исполнитель") : first.artist, subtitle: n, tracks: list)
            default:
                return SongGroup(id: .folder(key), title: key.components(separatedBy: " / ").last ?? key, subtitle: key.contains(" / ") ? key + " · " + n : n, tracks: list)
            }
        }
        .sorted {
            // "no album" and "unknown artist" go last
            let a = $0.id == .album("") || $0.id == .artist(""), b = $1.id == .album("") || $1.id == .artist("")
            return a != b ? b : $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    @ViewBuilder private var groups: some View {
        let list = allGroups
        if list.isEmpty {
            Spacer()
            Text(ui.listTab == .folders ? tr("Папок пока нет. Добавьте папку целиком, и новые песни из неё будут появляться сами.") : tr("Список пуст. Добавьте файлы или папку."))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(24)
            addButtons
            Spacer()
        } else if ui.listTab == .albums {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 18) {
                    ForEach(list) { g in
                        Button { ui.collection = g.id } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                CoverView(track: g.cover, corner: 16, letter: 44)
                                    .aspectRatio(1, contentMode: .fit)
                                Text(g.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.fg)
                                Text(g.subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted)
                            }
                            .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(list) { g in
                        Button { ui.collection = g.id } label: {
                            HStack(spacing: 12) {
                                if ui.listTab == .folders {
                                    Image(systemName: "folder.fill").font(.system(size: 22)).foregroundStyle(settings.accent).frame(width: 46, height: 46)
                                } else {
                                    CoverView(track: g.cover, corner: 23, letter: 16, thumbnail: true).frame(width: 46, height: 46)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(g.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.fg)
                                    Text(g.subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted)
                                }
                                .lineLimit(1)
                                Spacer(minLength: 6)
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Theme.line)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var addButtons: some View {
        HStack(spacing: 10) {
            Button(tr("Файлы"), systemImage: "plus") { ui.add(.files) }
            Button(tr("Папку"), systemImage: "folder.badge.plus") { ui.add(.folder) }
            Button("Wi-Fi", systemImage: "wifi") {
                ui.panel = .fx
                ui.settingsPath = [.wifi]
            }
        }
        .font(.system(size: 15, weight: .semibold))
        .buttonStyle(.glass)
    }

    private func header(_ list: [Track]) -> some View {
        let title: String, subtitle: String
        switch ui.collection {
        case .album(let k):
            title = k.isEmpty ? tr("Без альбома") : list.first?.album ?? ""
            subtitle = Set(list.map { Library.artistKey($0) }).count > 1 ? tr("Разные исполнители") : list.first?.artist ?? ""
        case .artist(let k):
            title = k.isEmpty ? tr("Неизвестный исполнитель") : list.first?.artist ?? ""
            subtitle = plural(Set(list.map { Library.albumKey($0) }.filter { !$0.isEmpty }).count, tr("альбом"), tr("альбома"), tr("альбомов"))
        case .folder(let f):
            title = f.components(separatedBy: " / ").last ?? f
            subtitle = f.contains(" / ") ? f : tr("Папка")
        default:
            title = ""
            subtitle = ""
        }
        let ids = list.map(\.id), total = list.reduce(0) { $0 + $1.duration }
        return VStack(alignment: .leading, spacing: 12) {
            Button { ui.collection = .all } label: {
                Label(tr(ui.listTab.rawValue), systemImage: "chevron.left").font(.system(size: 14, weight: .semibold)).foregroundStyle(settings.accent)
            }
            .buttonStyle(.plain)
            HStack(spacing: 14) {
                CoverView(track: list.first { $0.hasArtwork } ?? list.first, corner: 16, letter: 34).frame(width: 104, height: 104)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.display(17, .semibold)).foregroundStyle(Theme.fg).lineLimit(2)
                    if !subtitle.isEmpty { Text(subtitle).font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1) }
                    Text(plural(list.count, tr("песня"), tr("песни"), tr("песен")) + " · " + formatSpan(total)).font(.mono(11)).foregroundStyle(Theme.muted)
                    HStack(spacing: 8) {
                        Button { if let f = ids.first { player.play(f, from: ids) } } label: { Image(systemName: "play.fill").foregroundStyle(Theme.accentInk) }
                            .buttonStyle(.glassProminent)
                            .accessibilityLabel(tr("Играть"))
                        Button { player.playShuffled(ids) } label: { Image(systemName: "shuffle") }
                            .buttonStyle(.glass)
                            .accessibilityLabel(tr("Перемешать"))
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 12)
    }

    // MARK: Bottom

    private func footer(_ list: [Track], of total: Int) -> some View {
        HStack {
            Text(list.count != total ? tr("Показано {} из {}", "\(list.count)", "\(total)") : plural(total, tr("песня"), tr("песни"), tr("песен")))
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            Spacer()
            if let p = playlist, ui.listTab == .songs {
                Button(tr("Переименовать")) { ui.prompt = .rename(p.id, p.name) }.buttonStyle(.glass)
                Button(tr("Удалить")) { confirmPlaylist = true }.buttonStyle(.glass).tint(Theme.danger)
            } else {
                Button(list.count == library.tracks.count ? tr("Удалить все") : tr("Удалить ({})", "\(list.count)")) { confirmDelete = true }
                    .buttonStyle(.glass)
                    .tint(Theme.danger)
                    .disabled(list.isEmpty)
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Divider().overlay(Theme.line) }
        .confirmationDialog(tr("Убрать из плеера: {}? Файлы останутся на месте.", "\(plural(list.count, tr("песня"), tr("песни"), tr("песен")))"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(tr("Убрать из плеера"), role: .destructive) { library.remove(Set(list.map(\.id))) }
        }
        .confirmationDialog(tr("Удалить плейлист «{}»? Песни останутся.", "\(playlist?.name ?? "")"), isPresented: $confirmPlaylist, titleVisibility: .visible) {
            Button(tr("Удалить плейлист"), role: .destructive) {
                if let p = playlist {
                    ui.collection = .all
                    library.deletePlaylist(p.id)
                }
            }
        }
    }

    private var emptyText: String {
        if !search.isEmpty { return tr("Ничего не найдено") }
        switch ui.collection {
        case .favourites: return tr("В избранном пока пусто. Нажмите ♥ у песни, чтобы добавить её сюда.")
        case .playlist: return tr("Плейлист пуст. Добавьте песни через «⋯» → «Добавить в плейлист».")
        case .lossless: return tr("Песен без потерь пока нет. Это файлы FLAC, ALAC, WAV и AIFF.")
        case .often: return tr("Здесь появятся песни, которые вы слушаете чаще всего.")
        default: return tr("Список пуст. Добавьте файлы или папку.")
        }
    }
}

/// Corrects the title, artist and album in the player; the file itself stays as it is.
struct TrackEditor: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: Player
    @Environment(\.dismiss) private var dismiss
    let track: Track
    @State private var title: String
    @State private var artist: String
    @State private var album: String

    init(track: Track) {
        self.track = track
        _title = State(initialValue: track.title)
        _artist = State(initialValue: track.artist)
        _album = State(initialValue: track.album)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(tr("Название")) { TextField(tr("Название"), text: $title).multilineTextAlignment(.trailing) }
                    LabeledContent(tr("Исполнитель")) { TextField(tr("Исполнитель"), text: $artist).multilineTextAlignment(.trailing) }
                    LabeledContent(tr("Альбом")) { TextField(tr("Альбом"), text: $album).multilineTextAlignment(.trailing) }
                } footer: {
                    Text(tr("Меняется только в плеере, сам файл «{}» остаётся как есть.", "\(track.fileName)"))
                }
                Section {
                    Button(tr("Поменять местами название и исполнителя")) { (title, artist) = (artist, title) }
                    if track.edited == true {
                        Button(tr("Вернуть из файла")) {
                            Task {
                                await library.restoreTags(track.id)
                                player.publish()
                            }
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.surface.ignoresSafeArea())
            .navigationTitle(tr("Изменить"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("Отмена")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Сохранить")) {
                        func tidy(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }
                        library.edit(track.id, title: tidy(title), artist: tidy(artist), album: tidy(album))
                        player.publish()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
