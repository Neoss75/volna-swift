import Foundation

struct Lyrics: Codable, Equatable {
    var text: String
    var source: String
}

struct LyricLine: Identifiable, Equatable {
    let id: Int
    let time: Double
    let text: String
}

/// Lyrics live in Application Support/Lyrics/<track id>.json.
@MainActor
enum LyricsStore {
    private static let folder: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Lyrics", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func url(_ id: UUID) -> URL { folder.appendingPathComponent(id.uuidString + ".json") }

    static func load(_ id: UUID) -> Lyrics? {
        guard let data = try? Data(contentsOf: url(id)) else { return nil }
        return try? JSONDecoder().decode(Lyrics.self, from: data)
    }

    static func save(_ l: Lyrics, id: UUID) {
        if let data = try? JSONEncoder().encode(l) { try? data.write(to: url(id), options: .atomic) }
    }

    static func delete(_ id: UUID) { try? FileManager.default.removeItem(at: url(id)) }
}

enum LyricsParser {
    /// Lines like [01:23.45]text; nil when the text has no timing.
    static func lines(_ text: String) -> [LyricLine]? {
        guard let tag = try? NSRegularExpression(pattern: #"\[(\d{1,3}):(\d{1,2}(?:[.:]\d{1,3})?)\]"#) else { return nil }
        var found: [(Double, String)] = []
        var offset = 0.0
        for raw in text.components(separatedBy: .newlines) {
            if let r = raw.range(of: #"^\s*\[offset:\s*[+-]?\d+\s*\]"#, options: [.regularExpression, .caseInsensitive]) {
                let digits = raw[r].filter { $0.isNumber || $0 == "-" }
                offset = (Double(String(digits)) ?? 0) / 1000
                continue
            }
            let ns = raw as NSString
            let marks = tag.matches(in: raw, range: NSRange(location: 0, length: ns.length))
            if marks.isEmpty { continue }
            let words = raw.replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            for m in marks {
                let min = Double(ns.substring(with: m.range(at: 1))) ?? 0
                let sec = Double(ns.substring(with: m.range(at: 2)).replacingOccurrences(of: ":", with: ".")) ?? 0
                found.append((min * 60 + sec - offset, words))
            }
        }
        guard found.count >= 3 else { return nil }
        return found.sorted { $0.0 < $1.0 }.enumerated().map { LyricLine(id: $0.offset, time: $0.element.0, text: $0.element.1) }
    }

    static func plain(_ text: String) -> String {
        text.replacingOccurrences(of: #"\[[a-z]+:[^\]]*\]"#, with: "", options: [.regularExpression, .caseInsensitive]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Notification.Name {
    /// The lyrics of a song (its id is the object) were found or changed.
    static let lyricsChanged = Notification.Name("lyricsChanged")
}

/// With the switch on, lrclib.net is asked once about every song that starts and has no lyrics.
@MainActor
enum LyricsAuto {
    /// The test build puts its own answer here.
    static var finder: (Track) async throws -> Lyrics? = { try await LyricsSearch.find($0) }

    static func look(_ t: Track, library: Library) {
        guard t.lyricsTried != true, LyricsStore.load(t.id) == nil else { return }
        Task {
            let found: Lyrics?
            do {
                found = try await finder(t)
            } catch {
                return // no internet: ask again next time
            }
            library.update(t.id) { $0.lyricsTried = true }
            guard let found, LyricsStore.load(t.id) == nil else { return }
            LyricsStore.save(found, id: t.id)
            NotificationCenter.default.post(name: .lyricsChanged, object: t.id)
        }
    }
}

/// Search on lrclib.net; only the title, artist and duration are sent.
enum LyricsSearch {
    private struct Hit: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
        var text: String? { [syncedLyrics, plainLyrics].compactMap { $0 }.first { !$0.isEmpty } }
        var synced: Bool { syncedLyrics?.isEmpty == false }
    }

    static func find(_ t: Track) async throws -> Lyrics? {
        var title = SongReading.cleanForSearch(t.title), artist = SongReading.cleanForSearch(t.artist)
        if artist.isEmpty, let d = SongReading.splitDash(title) {
            artist = d.0
            title = d.1
        }
        var query = ["track_name": title, "artist_name": artist]
        if t.duration > 0 { query["duration"] = String(Int(t.duration.rounded())) }
        var hit: Hit?
        if let data = try await get("https://lrclib.net/api/get", query) { hit = try? JSONDecoder().decode(Hit.self, from: data) }
        if hit?.text == nil, let data = try await get("https://lrclib.net/api/search", ["q": (artist.isEmpty ? "" : artist + " ") + title]) {
            let all = (try? JSONDecoder().decode([Hit].self, from: data)) ?? []
            hit = all.first { $0.synced } ?? all.first { $0.text != nil }
        }
        guard let hit, let text = hit.text else { return nil }
        return Lyrics(text: text, source: "lrclib.net" + (hit.synced ? " · синхронный" : ""))
    }

    private static func get(_ base: String, _ query: [String: String]) async throws -> Data? {
        guard var c = URLComponents(string: base) else { return nil }
        c.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        c.percentEncodedQuery = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = c.url else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)
        return (response as? HTTPURLResponse)?.statusCode == 200 ? data : nil
    }
}
