import Foundation
import UIKit

/// The song list. Files are referenced through security-scoped bookmarks, never copied.
@MainActor
final class Library: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var isImporting = false
    @Published var notice: String?

    private let storeURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storeURL = dir.appendingPathComponent("library.json")
        if let data = try? Data(contentsOf: storeURL),
           let saved = try? JSONDecoder().decode([Track].self, from: data) {
            tracks = saved
        }
    }

    /// Adds files picked in the system document picker.
    func add(urls: [URL]) async {
        isImporting = true
        defer { isImporting = false }
        var added = 0, duplicates = 0, failed = 0
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }

            let path = url.standardizedFileURL.path
            if tracks.contains(where: { $0.path == path }) { duplicates += 1; continue }
            guard let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else {
                failed += 1; continue
            }

            let meta = await MetadataReader.read(url: url)
            let id = UUID()
            var hasArtwork = false
            if let art = meta.artwork { hasArtwork = ArtworkStore.save(art, id: id) }
            let guess = MetadataReader.guess(fromFileName: url.deletingPathExtension().lastPathComponent)
            tracks.append(Track(
                id: id,
                bookmark: bookmark,
                path: path,
                title: meta.title ?? guess.title,
                artist: meta.artist ?? guess.artist ?? "",
                album: meta.album ?? "",
                duration: meta.duration,
                hasArtwork: hasArtwork
            ))
            added += 1
        }
        save()
        var parts: [String] = []
        if duplicates > 0 { parts.append("уже в списке: \(duplicates)") }
        if failed > 0 { parts.append("не удалось добавить: \(failed)") }
        if !parts.isEmpty { notice = "Добавлено: \(added). " + parts.joined(separator: ", ") + "." }
    }

    /// Opens the bookmark again. Refreshes it if iOS says it is out of date (file was moved or renamed).
    func resolve(_ track: Track) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: track.bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        if stale, let i = tracks.firstIndex(where: { $0.id == track.id }) {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                tracks[i].bookmark = fresh
                tracks[i].path = url.standardizedFileURL.path
                save()
            }
        }
        return url
    }

    func remove(id: UUID) {
        tracks.removeAll { $0.id == id }
        ArtworkStore.delete(id: id)
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
