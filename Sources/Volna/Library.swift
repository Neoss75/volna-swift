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

    private nonisolated static let audioExtensions: Set<String> = ["mp3", "m4a", "m4b", "aac", "flac", "wav", "aif", "aiff", "alac", "caf", "opus", "ogg"]

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
        var added = 0, duplicates = 0, failed = 0
        var lyrics: [(String, String)] = []

        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true

            if isDir {
                guard let folder = remember(folder: url) else { failed += 1; continue }
                hidden = hidden.filter { !$0.hasPrefix(folder.id.uuidString) } // added again on purpose
                let files = await Task.detached { Self.scan(url) }.value
                for f in files {
                    if f.url.pathExtension.lowercased() == "lrc" {
                        if let text = Self.readText(f.url) { lyrics.append((f.url.deletingPathExtension().lastPathComponent, text)) }
                        continue
                    }
                    let label = ([folder.name] + f.rel.split(separator: "/").dropLast().map(String.init)).joined(separator: " / ")
                    switch await addFile(f.url, bookmark: Data(), folder: folder, relPath: f.rel, label: label) {
                    case .added: added += 1
                    case .duplicate: duplicates += 1
                    case .failed: failed += 1
                    }
                }
            } else if url.pathExtension.lowercased() == "lrc" {
                if let text = Self.readText(url) { lyrics.append((url.deletingPathExtension().lastPathComponent, text)) }
            } else {
                guard let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else { failed += 1; continue }
                switch await addFile(url, bookmark: bookmark, folder: nil, relPath: nil, label: nil) {
                case .added: added += 1
                case .duplicate: duplicates += 1
                case .failed: failed += 1
                }
            }
        }

        for (name, text) in lyrics {
            for t in tracks where t.baseName.caseInsensitiveCompare(name) == .orderedSame {
                LyricsStore.save(Lyrics(text: text, source: "файл .lrc"), id: t.id)
            }
        }
        var parts = ["Добавлено: " + plural(added, "песня", "песни", "песен")]
        if duplicates > 0 { parts.append("уже в списке: \(duplicates)") }
        if failed > 0 { parts.append("не удалось: \(failed)") }
        toast(parts.joined(separator: ", "))
    }

    private enum AddResult { case added, duplicate, failed }

    private func addFile(_ url: URL, bookmark: Data, folder: FolderRef?, relPath: String?, label: String?) async -> AddResult {
        let path = url.resolvingSymlinksInPath().path
        if tracks.contains(where: { $0.path == path }) { return .duplicate }
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
        t.trackNo = meta.trackNo
        if meta.duration > 0 { t.duration = meta.duration }
        if let art = meta.artwork { t.hasArtwork = ArtworkStore.save(art, id: t.id); t.artOnline = false }
        t.ext = meta.header.ext
        t.size = meta.header.size
        t.sampleRate = meta.header.sampleRate
        t.bits = meta.header.bits
        t.kbps = meta.header.kbps
        t.vbr = meta.header.vbr
        t.tagBytes = meta.header.tagBytes
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

    /// Looks for new songs in the folders added earlier.
    func refreshFolders(quiet: Bool) async {
        guard !refreshing, !importing, !folders.isEmpty else {
            if !quiet, folders.isEmpty { toast("Папок пока нет. Добавьте папку целиком") }
            return
        }
        refreshing = true
        defer { refreshing = false }
        var added = 0
        for folder in folders {
            var stale = false
            guard let root = try? URL(resolvingBookmarkData: folder.bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { continue }
            let access = FileAccess(url: root, scope: root)
            let files = await Task.detached(priority: .utility) { Self.scan(access.url) }.value
            let known = Set(tracks.filter { $0.folderID == folder.id }.compactMap(\.relPath))
            for f in files where f.url.pathExtension.lowercased() != "lrc" {
                if known.contains(f.rel) || hidden.contains(Self.hiddenKey(folder.id, f.rel)) { continue }
                let label = ([folder.name] + f.rel.split(separator: "/").dropLast().map(String.init)).joined(separator: " / ")
                if await addFile(f.url, bookmark: Data(), folder: folder, relPath: f.rel, label: label) == .added { added += 1 }
            }
            withExtendedLifetime(access) {}
        }
        if added > 0 {
            saveNow()
            toast("Новые песни в папках: \(added)")
        } else if !quiet {
            toast("Новых песен в папках нет")
        }
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
        toast("Сохранено")
    }

    func restoreTags(_ id: UUID) async {
        guard let t = track(id), let access = open(t) else {
            toast("Файл не открывается")
            return
        }
        let meta = await MetadataReader.read(url: access.url)
        update(id) {
            $0.edited = false
            self.apply(meta, to: &$0)
        }
        toast("Возвращено из файла")
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
            guard audioExtensions.contains(ext) || ext == "lrc" else { continue }
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
                  let root = try? URL(resolvingBookmarkData: folders[i].bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
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
        let text = removed.count == 1 ? "Удалено: «\(removed[0].element.title)»" : "Удалено " + plural(removed.count, "песня", "песни", "песен")
        Toaster.shared.show(text, action: "Отменить") { [weak self] in
            guard let self else { return }
            for (i, t) in removed { self.tracks.insert(t, at: min(i, self.tracks.count)) }
            self.hidden.subtract(hiddenNow)
            self.reindex()
            self.scheduleSave()
            toast("Возвращено")
        }
    }

    // MARK: - Favourites and playlists

    func isFavourite(_ id: UUID) -> Bool { favourites.contains(id) }

    func toggleFavourite(_ id: UUID) {
        if favourites.remove(id) != nil {
            toast("Убрано из избранного")
        } else {
            favourites.insert(id)
            toast("Добавлено в избранное")
        }
        scheduleSave()
    }

    @discardableResult
    func createPlaylist(_ name: String, with ids: [UUID] = []) -> Playlist {
        let p = Playlist(id: UUID(), name: name, keys: ids)
        playlists.append(p)
        scheduleSave()
        toast(ids.isEmpty ? "Плейлист создан. Добавляйте песни через «⋯»" : "Добавлено в «\(name)»")
        return p
    }

    func add(_ id: UUID, to playlist: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist }) else { return }
        if playlists[i].keys.contains(id) {
            toast("Уже есть в «\(playlists[i].name)»")
        } else {
            playlists[i].keys.append(id)
            toast("Добавлено в «\(playlists[i].name)»")
            scheduleSave()
        }
    }

    func remove(_ id: UUID, from playlist: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist }) else { return }
        playlists[i].keys.removeAll { $0 == id }
        scheduleSave()
        toast("Убрано из плейлиста")
    }

    func rename(_ playlist: UUID, to name: String) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist }) else { return }
        playlists[i].name = name
        scheduleSave()
    }

    func deletePlaylist(_ id: UUID) {
        playlists.removeAll { $0.id == id }
        scheduleSave()
        toast("Плейлист удалён, песни остались")
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
        toast("Обложка убрана")
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
