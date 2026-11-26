import Foundation
import UIKit

/// Keeps a security-scoped file open for reading; closes the access when released.
final class FileAccess: @unchecked Sendable {
    let url: URL
    private let scope: URL?

    init(url: URL, scope: URL) {
        self.url = url
        self.scope = scope.startAccessingSecurityScopedResource() ? scope : nil
    }

    deinit { scope?.stopAccessingSecurityScopedResource() }
}

/// The song list, favourites and playlists. Files are referenced through security-scoped bookmarks, never copied.
@MainActor
final class Library: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var favourites: Set<UUID> = []
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var importing = false

    private(set) var folders: [FolderRef] = []
    /// Songs of a watched folder that the user took out of the player: a refresh must not bring them back.
    private var hidden: Set<String> = []
    @Published private(set) var refreshing = false
    private var index: [UUID: Int] = [:]
    private let dir: URL
    private var saveTask: Task<Void, Never>?

    var onRemove: ((Set<UUID>) -> Void)?

    nonisolated static let audioExtensions: Set<String> = ["mp3", "m4a", "m4b", "aac", "flac", "wav", "aif", "aiff", "alac", "caf", "opus", "ogg"]

    /// Songs sent from a computer over Wi-Fi live inside the player, in «Files» → «On My iPhone» → «Volna» → «Wi-Fi».
    static let wifiID = UUID(uuidString: "5A1F0000-0000-4000-8000-00000000F1F1")!
    nonisolated static var wifiFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Wi-Fi", isDirectory: true)
    }

    init() {
        dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tracks = load("library.json") ?? []
        favourites = load("favourites.json") ?? []
        playlists = load("playlists.json") ?? []
        folders = load("folders.json") ?? []
        hidden = load("hidden.json") ?? []
        reindex()
        Task { await refreshOldEntries() }
    }

    func track(_ id: UUID?) -> Track? {
        guard let id, let i = index[id], i < tracks.count else { return nil }
        return tracks[i]
    }

    func update(_ id: UUID, _ change: (inout Track) -> Void) {
        guard let i = index[id] else { return }
        change(&tracks[i])
        scheduleSave()
    }

    private func reindex() {
        index = Dictionary(tracks.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    // MARK: - Adding

    /// Files and folders picked in the system document picker; .lrc files become lyrics of the song with the same name.
    func add(urls: [URL]) async {
        importing = true
        defer { importing = false; saveNow() }
        var added = 0, duplicates = 0, failed = 0, cut = 0, lonely = 0
        var lyrics: [(String, String)] = []

        func count(_ r: AddResult) {
            switch r {
            case .added: added += 1
            case .duplicate: duplicates += 1
            case .failed: failed += 1
            case .cut(let n):
                added += n
                cut += 1
            }
        }
        // .cue sheets picked together with their files
        var sheets: [String: (CueSheet, CueSheet.File)] = [:]
        let names = urls.map(\.lastPathComponent).filter { !$0.lowercased().hasSuffix(".cue") }
        for url in urls where url.pathExtension.lowercased() == "cue" {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let d = try? Data(contentsOf: url) else {
                failed += 1
                continue
            }
            let sheet = CueSheet(CueSheet.text(d)), found = sheet.match(names, sheet: url.lastPathComponent)
            for m in found { sheets[m.name] = (sheet, m.file) }
            if found.isEmpty {
                // the long file may be in the player already
                let here = tracks.filter { $0.cueStart == nil }
                let known = sheet.match(here.map(\.fileName), sheet: url.lastPathComponent)
                if known.isEmpty { lonely += 1 }
                for m in known {
                    if let t = here.first(where: { $0.fileName == m.name }) {
                        let file = open(t)
                        if let file, let folder = t.folderID { count(await addCue(sheet, m.file, file.url, bookmark: Data(), folder: folder, relPath: t.relPath, label: t.folder)) }
                        else if let file { count(await addCue(sheet, m.file, file.url, bookmark: t.bookmark, folder: nil, relPath: nil, label: nil)) }
                    }
                }
            }
        }

        for url in urls where url.pathExtension.lowercased() != "cue" {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true

            if isDir {
                guard let folder = remember(folder: url) else { failed += 1; continue }
                hidden = hidden.filter { !$0.hasPrefix(folder.id.uuidString) } // added again on purpose
                let files = await Task.detached { Self.scan(url) }.value, cues = Self.cues(files)
                for f in files where f.url.pathExtension.lowercased() != "cue" {
                    if f.url.pathExtension.lowercased() == "lrc" {
                        if let text = Self.readText(f.url) { lyrics.append((f.url.deletingPathExtension().lastPathComponent, text)) }
                        continue
                    }
                    let label = ([folder.name] + f.rel.split(separator: "/").dropLast().map(String.init)).joined(separator: " / ")
                    if let (sheet, part) = cues[f.rel], sheet.songs(of: part) != nil {
                        count(await addCue(sheet, part, f.url, bookmark: Data(), folder: folder.id, relPath: f.rel, label: label))
                    } else {
                        count(await addFile(f.url, bookmark: Data(), folder: folder, relPath: f.rel, label: label))
                    }
                }
            } else if url.pathExtension.lowercased() == "lrc" {
                if let text = Self.readText(url) { lyrics.append((url.deletingPathExtension().lastPathComponent, text)) }
            } else {
                guard let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else { failed += 1; continue }
                if let (sheet, part) = sheets[url.lastPathComponent], sheet.songs(of: part) != nil {
                    count(await addCue(sheet, part, url, bookmark: bookmark, folder: nil, relPath: nil, label: nil))
                } else {
                    count(await addFile(url, bookmark: bookmark, folder: nil, relPath: nil, label: nil))
                }
            }
        }

        for (name, text) in lyrics {
            for t in tracks where t.cueStart == nil && t.baseName.caseInsensitiveCompare(name) == .orderedSame {
                LyricsStore.save(Lyrics(text: text, source: "файл .lrc"), id: t.id)
            }
        }
        var parts = [tr("Добавлено: ") + plural(added, tr("песня"), tr("песни"), tr("песен"))]
        if duplicates > 0 { parts.append(tr("уже в списке: {}", "\(duplicates)")) }
        if failed > 0 { parts.append(tr("не удалось: {}", "\(failed)")) }
        if cut > 0 { parts.append(tr("разбито по .cue: {}", "\(cut)")) }
        if lonely > 0, added == 0 { return toast(tr("Выберите вместе с .cue сам музыкальный файл или добавьте папку целиком")) }
        toast(parts.joined(separator: ", "))
    }

    private enum AddResult: Equatable { case added, duplicate, failed, cut(Int) }

    /// The .cue sheets of a folder: which file each of them describes.
    private nonisolated static func cues(_ files: [(url: URL, rel: String)]) -> [String: (CueSheet, CueSheet.File)] {
        func dir(_ rel: String) -> String { (rel as NSString).deletingLastPathComponent }
        var out: [String: (CueSheet, CueSheet.File)] = [:]
        for c in files where c.url.pathExtension.lowercased() == "cue" {
            guard let d = try? Data(contentsOf: c.url), d.count < 1_000_000 else { continue }
            let near = files.filter { audioExtensions.contains($0.url.pathExtension.lowercased()) && dir($0.rel) == dir(c.rel) }
            let sheet = CueSheet(CueSheet.text(d))
            for m in sheet.match(near.map(\.url.lastPathComponent), sheet: c.url.lastPathComponent) {
                if let f = near.first(where: { $0.url.lastPathComponent == m.name }) { out[f.rel] = (sheet, m.file) }
            }
        }
        return out
    }

    /// One long file becomes several songs. If the whole file was a song before, they take its place.
    private func addCue(_ sheet: CueSheet, _ part: CueSheet.File, _ url: URL, bookmark: Data, folder: UUID?, relPath: String?, label: String?) async -> AddResult {
        guard let songs = sheet.songs(of: part) else { return .failed }
        let path = url.resolvingSymlinksInPath().path
        if tracks.contains(where: { $0.path == path && $0.cueStart != nil }) { return .duplicate }
        let meta = await MetadataReader.read(url: url)
        guard meta.duration > 0, !tracks.contains(where: { $0.path == path && $0.cueStart != nil }) else { return meta.duration > 0 ? .duplicate : .failed }
        let list = songs.filter { $0.start < meta.duration - 0.5 }
        guard list.count > 1 else { return .failed }
        var fresh: [Track] = []
        for (i, s) in list.enumerated() {
            let end = i + 1 < list.count ? list[i + 1].start : nil
            var t = Track(id: UUID(), bookmark: bookmark, path: path, title: "", artist: "", album: "", duration: (end ?? meta.duration) - s.start, hasArtwork: false)
            t.folderID = folder
            t.relPath = relPath
            t.folder = label
            t.addedAt = Date()
            t.cueStart = s.start
            t.cueEnd = end
            t.cueTitle = s.title.isEmpty ? tr("Дорожка {}", "\(s.number)") : TagCleaner.clean(s.title)
            t.cueArtist = TagCleaner.clean(s.artist.isEmpty ? (sheet.artist.isEmpty ? meta.artist ?? "" : sheet.artist) : s.artist)
            t.cueAlbum = TagCleaner.clean(sheet.title.isEmpty ? meta.album ?? "" : sheet.title)
            t.trackNo = s.number
            apply(meta, to: &t)
            fresh.append(t)
        }
        let whole = Set(tracks.filter { $0.path == path && $0.cueStart == nil }.map(\.id))
        let at = tracks.firstIndex { whole.contains($0.id) } ?? tracks.count
        tracks.removeAll { whole.contains($0.id) }
        tracks.insert(contentsOf: fresh, at: min(at, tracks.count))
        reindex()
        if !whole.isEmpty { onRemove?(whole) }
        scheduleSave()
        return .cut(fresh.count)
    }

    private func addFile(_ url: URL, bookmark: Data, folder: FolderRef?, relPath: String?, label: String?) async -> AddResult {
        let path = url.resolvingSymlinksInPath().path
        if tracks.contains(where: { $0.path == path }) { return .duplicate }
        if let sheet = await Task.detached(operation: { CueSheet.embedded(in: url) }).value, let part = sheet.files.first, sheet.songs(of: part) != nil {
            return await addCue(sheet, part, url, bookmark: bookmark, folder: folder?.id, relPath: relPath, label: label)
        }
        let meta = await MetadataReader.read(url: url)
        // the same file could have been added while its tags were being read
        if tracks.contains(where: { $0.path == path }) { return .duplicate }
        var t = Track(id: UUID(), bookmark: bookmark, path: path, title: "", artist: "", album: "", duration: 0, hasArtwork: false)
        t.folderID = folder?.id
        t.relPath = relPath
        t.folder = label
        t.addedAt = Date()
        apply(meta, to: &t)
        tracks.append(t)
        index[t.id] = tracks.count - 1
        if let text = meta.lyrics { LyricsStore.save(Lyrics(text: text, source: "из файла"), id: t.id) }
        scheduleSave()
        return .added
    }

    private func apply(_ meta: TrackMeta, to t: inout Track) {
        let guess = TagCleaner.split(fileName: t.fileName)
        if t.edited != true {
            t.title = meta.title ?? guess.title
            t.artist = meta.artist ?? guess.artist
            t.album = meta.album ?? t.folder?.components(separatedBy: " / ").last ?? ""
            (t.title, t.artist) = SongReading.separate(title: t.title, artist: t.artist)
        }
        if t.cueStart != nil {
            // one song of a long file: the tags of the file are about all of it
            if t.edited != true {
                t.title = t.cueTitle ?? t.title
                t.artist = t.cueArtist ?? ""
                t.album = t.cueAlbum ?? ""
            }
        } else {
            t.trackNo = meta.trackNo
            if meta.duration > 0 { t.duration = meta.duration }
        }
        if let art = meta.artwork { t.hasArtwork = ArtworkStore.save(art, id: t.id); t.artOnline = false }
        t.ext = meta.header.ext
        t.size = t.cueStart != nil && meta.duration > 0 ? Int(Double(meta.header.size) * t.duration / meta.duration) : meta.header.size
        t.sampleRate = meta.header.sampleRate
        t.bits = meta.header.bits
        t.kbps = meta.header.kbps
        t.vbr = meta.header.vbr
        t.tagBytes = t.cueStart != nil ? 0 : meta.header.tagBytes
        t.metaVersion = Track.currentMeta
    }

    /// Songs saved by an older build: read their tags again to fill in the format line and clean the titles.
    private func refreshOldEntries() async {
        for t in tracks where t.metaVersion != Track.currentMeta {
            guard let access = open(t) else { continue }
            let meta = await MetadataReader.read(url: access.url)
            update(t.id) { self.apply(meta, to: &$0) }
            if let text = meta.lyrics, LyricsStore.load(t.id) == nil { LyricsStore.save(Lyrics(text: text, source: "из файла"), id: t.id) }
        }
    }

    /// Looks for new songs in the folders added earlier (or only in one of them); says how many were added.
    @discardableResult
    func refreshFolders(quiet: Bool, only: UUID? = nil) async -> Int {
        guard !refreshing, !importing, !folders.isEmpty else {
            if !quiet, folders.isEmpty { toast(tr("Папок пока нет. Добавьте папку целиком")) }
            return 0
        }
        refreshing = true
        defer { refreshing = false }
        var added = 0
        for folder in folders where only == nil || folder.id == only {
            var stale = false
            guard let root = folderURL(folder, stale: &stale) else { continue }
            let access = FileAccess(url: root, scope: root)
            let files = await Task.detached(priority: .utility) { Self.scan(access.url) }.value
            let known = Set(tracks.filter { $0.folderID == folder.id }.compactMap(\.relPath)), cues = Self.cues(files)
            let cutAlready = Set(tracks.filter { $0.folderID == folder.id && $0.cueStart != nil }.compactMap(\.relPath))
            for f in files where !["lrc", "cue"].contains(f.url.pathExtension.lowercased()) {
                let sheet = cues[f.rel].flatMap { $0.0.songs(of: $0.1) != nil ? $0 : nil }
                // a sheet has appeared next to a long file
                let toCut = sheet != nil && !cutAlready.contains(f.rel)
                if known.contains(f.rel) && !toCut || hidden.contains(Self.hiddenKey(folder.id, f.rel)) { continue }
                let label = ([folder.name] + f.rel.split(separator: "/").dropLast().map(String.init)).joined(separator: " / ")
                let result: AddResult
                if let sheet {
                    result = await addCue(sheet.0, sheet.1, f.url, bookmark: Data(), folder: folder.id, relPath: f.rel, label: label)
                } else {
                    result = await addFile(f.url, bookmark: Data(), folder: folder, relPath: f.rel, label: label)
                }
                switch result {
                case .added: added += 1
                case .cut(let n): added += n
                default: break
                }
            }
            withExtendedLifetime(access) {}
        }
        if added > 0 {
            saveNow()
            if only == nil { toast(tr("Новые песни в папках: {}", "\(added)")) }
        } else if !quiet {
            toast(tr("Новых песен в папках нет"))
        }
        return added
    }

    /// Takes the songs that came over Wi-Fi into the list: their folder is watched like any other.
    @discardableResult
    func addReceived() async -> Int {
        if !folders.contains(where: { $0.id == Self.wifiID }) {
            folders.append(FolderRef(id: Self.wifiID, bookmark: Data(), path: Self.wifiFolder.path, name: "Wi-Fi"))
            saveNow()
        }
        while refreshing || importing { try? await Task.sleep(for: .milliseconds(300)) }
        return await refreshFolders(quiet: true, only: Self.wifiID)
    }

    /// A song removed earlier is sent again: it comes back.
    func unhideReceived(_ rel: String) {
        hidden.remove(Self.hiddenKey(Self.wifiID, rel))
    }

    private func folderURL(_ folder: FolderRef, stale: inout Bool) -> URL? {
        if folder.id == Self.wifiID { return Self.wifiFolder }
        return try? URL(resolvingBookmarkData: folder.bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    private static func hiddenKey(_ folder: UUID, _ rel: String) -> String { folder.uuidString + "/" + rel }

    // MARK: - Corrections by hand (only in the player, the file is not changed)

    func edit(_ id: UUID, title: String, artist: String, album: String) {
        update(id) {
            $0.title = title
            $0.artist = artist
            $0.album = album
            $0.edited = true
        }
        toast(tr("Сохранено"))
    }

    func restoreTags(_ id: UUID) async {
        guard let t = track(id), let access = open(t) else {
            toast(tr("Файл не открывается"))
            return
        }
        let meta = await MetadataReader.read(url: access.url)
        update(id) {
            $0.edited = false
            self.apply(meta, to: &$0)
        }
        toast(tr("Возвращено из файла"))
    }

    private func remember(folder url: URL) -> FolderRef? {
        let path = url.resolvingSymlinksInPath().path
        if let known = folders.first(where: { $0.path == path }) { return known }
        guard let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else { return nil }
        let ref = FolderRef(id: UUID(), bookmark: bookmark, path: path, name: url.lastPathComponent)
        folders.append(ref)
        return ref
    }

    private nonisolated static func scan(_ root: URL) -> [(url: URL, rel: String)] {
        let base = root.resolvingSymlinksInPath().path
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var out: [(url: URL, rel: String)] = []
        while let u = e.nextObject() as? URL {
            let ext = u.pathExtension.lowercased()
            guard audioExtensions.contains(ext) || ext == "lrc" || ext == "cue" else { continue }
            let p = u.resolvingSymlinksInPath().path
            guard p.hasPrefix(base + "/") else { continue }
            out.append((u, String(p.dropFirst(base.count + 1))))
        }
        return out.sorted { $0.rel.localizedStandardCompare($1.rel) == .orderedAscending }
    }

    private nonisolated static func readText(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251)
    }

    // MARK: - Opening

    /// Opens the song's bookmark (or its folder's). Refreshes it if iOS says it is out of date.
    func open(_ track: Track) -> FileAccess? {
        var stale = false
        if let fid = track.folderID, let rel = track.relPath {
            guard let i = folders.firstIndex(where: { $0.id == fid }),
                  let root = folderURL(folders[i], stale: &stale) else { return nil }
            let access = FileAccess(url: root.appendingPathComponent(rel), scope: root)
            if stale, let fresh = try? root.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                folders[i].bookmark = fresh
                scheduleSave()
            }
            return access
        }
        guard let url = try? URL(resolvingBookmarkData: track.bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        let access = FileAccess(url: url, scope: url)
        if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            update(track.id) {
                $0.bookmark = fresh
                $0.path = url.resolvingSymlinksInPath().path
            }
        }
        return access
    }

    // MARK: - Removing

    /// Only the entries are removed, the files stay in «Файлы». Undo within 6 seconds.
    func remove(_ ids: Set<UUID>) {
        let removed = tracks.enumerated().filter { ids.contains($0.element.id) }
        guard !removed.isEmpty else { return }
        tracks.removeAll { ids.contains($0.id) }
        let hiddenNow = removed.compactMap { r in r.element.folderID.map { Self.hiddenKey($0, r.element.relPath ?? "") } }
        hidden.formUnion(hiddenNow)
        reindex()
        onRemove?(ids)
        scheduleSave()
        // a song sent over Wi-Fi takes room inside the player: its file goes too (and comes back with Undo)
        var moved: [(from: URL, to: URL)] = []
        let bin = FileManager.default.temporaryDirectory.appendingPathComponent("removed", isDirectory: true)
        let wifiRels = Set(removed.filter { $0.element.folderID == Self.wifiID }.compactMap(\.element.relPath))
        for rel in wifiRels where !tracks.contains(where: { $0.folderID == Self.wifiID && $0.relPath == rel }) {
            let from = Self.wifiFolder.appendingPathComponent(rel), to = bin.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
            if (try? FileManager.default.moveItem(at: from, to: to)) != nil { moved.append((from, to)) }
        }
        let text = removed.count == 1 ? tr("Удалено: «{}»", "\(removed[0].element.title)") : tr("Удалено ") + plural(removed.count, tr("песня"), tr("песни"), tr("песен"))
        Toaster.shared.show(text, action: tr("Отменить")) { [weak self] in
            guard let self else { return }
            for (i, t) in removed { self.tracks.insert(t, at: min(i, self.tracks.count)) }
            for m in moved { try? FileManager.default.moveItem(at: m.to, to: m.from) }
            self.hidden.subtract(hiddenNow)
            self.reindex()
            self.scheduleSave()
            toast(tr("Возвращено"))
        }
    }

    // MARK: - Favourites and playlists

    func isFavourite(_ id: UUID) -> Bool { favourites.contains(id) }

    func toggleFavourite(_ id: UUID) {
        if favourites.remove(id) != nil {
            toast(tr("Убрано из избранного"))
        } else {
            favourites.insert(id)
            toast(tr("Добавлено в избранное"))
        }
        scheduleSave()
    }

    @discardableResult
    func createPlaylist(_ name: String, with ids: [UUID] = []) -> Playlist {
        let p = Playlist(id: UUID(), name: name, keys: ids)
        playlists.append(p)
        scheduleSave()
        toast(ids.isEmpty ? tr("Плейлист создан. Добавляйте песни через «⋯»") : tr("Добавлено в «{}»", "\(name)"))
        return p
    }

    func add(_ id: UUID, to playlist: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist }) else { return }
        if playlists[i].keys.contains(id) {
            toast(tr("Уже есть в «{}»", "\(playlists[i].name)"))
        } else {
            playlists[i].keys.append(id)
            toast(tr("Добавлено в «{}»", "\(playlists[i].name)"))
            scheduleSave()
        }
    }

    func remove(_ id: UUID, from playlist: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist }) else { return }
        playlists[i].keys.removeAll { $0 == id }
        scheduleSave()
        toast(tr("Убрано из плейлиста"))
    }

    func rename(_ playlist: UUID, to name: String) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist }) else { return }
        playlists[i].name = name
        scheduleSave()
    }

    func deletePlaylist(_ id: UUID) {
        playlists.removeAll { $0.id == id }
        scheduleSave()
        toast(tr("Плейлист удалён, песни остались"))
    }

    // MARK: - Covers

    func setCover(_ data: Data, for ids: [UUID]) {
        for id in ids {
            let ok = ArtworkStore.save(data, id: id)
            update(id) {
                $0.hasArtwork = ok
                $0.artOnline = true
                $0.artTried = CoverFinder.version
            }
        }
    }

    func dropCover(_ id: UUID) {
        ArtworkStore.delete(id: id)
        update(id) {
            $0.hasArtwork = false
            $0.artOnline = false
            $0.artTried = CoverFinder.version
        }
        toast(tr("Обложка убрана"))
    }

    // MARK: - Saving

    private func load<T: Decodable>(_ name: String) -> T? {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, _ name: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: dir.appendingPathComponent(name), options: .atomic)
    }

    private func scheduleSave() {
        guard saveTask == nil else { return }
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        write(tracks, "library.json")
        write(favourites, "favourites.json")
        write(playlists, "playlists.json")
        write(folders, "folders.json")
        write(hidden, "hidden.json")
    }
}
