import Foundation

/// One song as the backup remembers it: enough to recognise the file on another phone.
struct BackupSong: Codable, Identifiable, Equatable {
    var id: UUID
    var file: String
    var size: Int?
    var cueStart: Double?
    var duration: Double
    var title: String
    var artist: String
    var album: String
    var edited: Bool?
    var lyrics: Lyrics?
}

/// Everything of Volna in one small file, without the music itself.
/// Every part is optional: a file from an older or newer build still opens.
struct Backup: Codable {
    static let kind = "volna-backup"

    var kind = Backup.kind
    var version = 1
    var made = Date()
    var app: String?
    /// The settings as their own JSON, so options added later fall back to their defaults.
    var settings: Data?
    var stations: [Station]?
    var headphones: Headphones.Saved?
    var stats: Stats.Data?
    var favourites: [UUID]?
    var playlists: [Playlist]?
    var songs: [BackupSong]?
}

@MainActor
enum BackupFile {
    enum Failure: Error { case notBackup, unreadable }

    struct Restored {
        /// Songs of the backup found in the player now.
        let found: Int
        let total: Int
    }

    static func make(library: Library, settings: Settings, stations: Stations, headphones: Headphones, stats: Stats) -> Backup {
        stats.flush(keepTicking: true)
        let here = library.tracks.map {
            BackupSong(id: $0.id, file: $0.fileName, size: $0.size, cueStart: $0.cueStart, duration: $0.duration,
                       title: $0.title, artist: $0.artist, album: $0.album, edited: $0.edited, lyrics: LyricsStore.load($0.id))
        }
        // songs still waiting for their files stay in the next backup too
        let songs = here + library.waiting.filter { w in !here.contains { $0.id == w.id } }
        return Backup(app: AppInfo.version, settings: settings.exported, stations: stations.all, headphones: headphones.data, stats: stats.data,
                      favourites: Array(library.favourites), playlists: library.playlists, songs: songs)
    }

    /// The file goes to a temporary folder; the system window then moves it where the user wants.
    static func write(_ b: Backup) throws -> URL {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("backup", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(tr("Волна, копия") + " " + f.string(from: b.made) + ".json")
        try e.encode(b).write(to: url, options: .atomic)
        return url
    }

    static func read(_ url: URL) throws -> Backup {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw Failure.unreadable }
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> Backup {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        guard let b = try? d.decode(Backup.self, from: data), b.kind == Backup.kind else { throw Failure.notBackup }
        return b
    }

    /// Settings, stations, headphone profiles and statistics are replaced; favourites and playlists are added.
    @discardableResult
    static func restore(_ b: Backup, library: Library, settings: Settings, stations: Stations, headphones: Headphones, stats: Stats) -> Restored {
        if let s = b.settings { settings.restore(s) }
        if let s = b.stations { stations.replace(s) }
        if let h = b.headphones { headphones.replace(h) }
        if let s = b.stats { stats.replace(s) }
        let songs = b.songs ?? []
        let found = library.restore(favourites: b.favourites ?? [], playlists: b.playlists ?? [], songs: songs)
        return Restored(found: found, total: songs.count)
    }
}
