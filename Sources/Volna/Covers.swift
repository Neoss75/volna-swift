import Foundation
import UIKit

/// Who is singing what, read in several ways: from the tags, from a title like "Artist - Song", from the file name.
struct SongReading: Equatable {
    var artist: String
    var title: String
    var album: String

    private static let letters: [Character: String] = [
        "а": "a", "б": "b", "в": "v", "г": "g", "ґ": "g", "д": "d", "е": "e", "є": "e", "ж": "zh", "з": "z", "и": "i", "і": "i", "ї": "i", "й": "i",
        "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f", "х": "h", "ц": "ts", "ч": "ch",
        "ш": "sh", "щ": "sch", "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya",
    ]

    /// Names are compared loosely: case, brackets, "feat.", punctuation and Cyrillic/Latin spelling don't matter.
    static func normal(_ s: String) -> String {
        var t = s.lowercased().replacingOccurrences(of: "ё", with: "е")
        t = TagCleaner.replace(t, #"\(.*?\)|\[.*?\]"#, " ")
        t = TagCleaner.replace(t, #"\s(feat|ft|featuring|при участии)\.?\s.*$"#, " ")
        t = TagCleaner.replace(t, #"\s[-–—]\s.*(remaster|version|edit|mix|live|версия).*$"#, " ")
        t = t.replacingOccurrences(of: "&", with: " and ")
        t = TagCleaner.replace(t, #"[^\p{L}\p{N}]+"#, " ")
        t = TagCleaner.replace(t, #"\bthe\b"#, " ")
        return TagCleaner.replace(t, #"\s+"#, " ").trimmingCharacters(in: .whitespaces)
    }

    static func score(_ a: String, _ b: String) -> Double {
        let x = normal(a).map { letters[$0] ?? String($0) }.joined(), y = normal(b).map { letters[$0] ?? String($0) }.joined()
        if x.isEmpty || y.isEmpty { return 0 }
        if x == y { return 1 }
        let A = x.split(separator: " "), B = y.split(separator: " ")
        let common = A.filter { B.contains($0) }.count
        return Double(common) / Double(min(A.count, B.count)) * (x.hasPrefix(y) || y.hasPrefix(x) ? 1 : 0.85)
    }

    static func match(_ a: String, _ b: String) -> Bool { score(a, b) >= 0.7 }

    private static func test(_ s: String, _ pattern: String) -> Bool { s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }

    /// Tags that name a collection or a website rather than the real artist or album.
    private static let junkArtist = #"^(va|v\.a\.|various( artists)?|unknown( artist)?|неизвестн\S*( исполнитель)?|исполнитель|artist|сборник\S*|хиты?\b.*|hits?\b.*|top\b.*|топ\b.*|new\b.*|новинки\b.*|музыка\b.*|music\b.*|радио\b.*|radio\b.*|\d{4})$"#
    private static let junkAlbum = #"(хит|hits?\b|сборник|compilation|various|новинк|\btop\b|\bтоп\b|best of 20\d\d|playlist|плейлист|радио|radio|музыка в машину|^\d{4}$|^new\b|^music\b|singles?$|^сингл)"#

    static func cleanForSearch(_ s: String) -> String {
        var t = TagCleaner.replace(s, #"[\(\[][^)\]]*(official|audio|video|lyric|clip|remaster|премьер|клип|текст)[^)\]]*[\)\]]"#)
        t.unicodeScalars.removeAll { (0x1F000...0x1FAFF).contains($0.value) || (0x2600...0x27BF).contains($0.value) || $0.value == 0xFE0F }
        return TagCleaner.replace(t, #"\s{2,}"#, " ").trimmingCharacters(in: .whitespaces)
    }

    static func splitDash(_ s: String) -> (String, String)? {
        guard let r = s.range(of: #"\s[-–—]\s"#, options: .regularExpression), r.lowerBound > s.startIndex, r.upperBound < s.endIndex else { return nil }
        return (String(s[..<r.lowerBound]), String(s[r.upperBound...]))
    }

    private static func tidy(_ artist: String, _ title: String, _ album: String) -> SongReading {
        var t = TagCleaner.replace(title, #"^\s*\d{1,3}\s*[.\-_)]\s*"#)
        t = TagCleaner.replace(t, #"[\(\[].*?[\)\]]"#, " ")
        t = TagCleaner.replace(t, #"\s(feat|ft)\.?\s.*$"#)
        t = TagCleaner.replace(t, #"["«»]"#)
        t = TagCleaner.replace(t, #"\s{2,}"#, " ").trimmingCharacters(in: .whitespaces)
        var a = TagCleaner.replace(artist, #"^\s*\d{1,3}\s*[.\-_)]\s*"#).trimmingCharacters(in: .whitespaces)
        if test(a, junkArtist) { a = "" }
        if let r = a.range(of: #"\s*(?:,|;|/|\sfeat\.?\s|\sft\.?\s|\sx\s|\s&\s|\sи\s)\s*"#, options: [.regularExpression, .caseInsensitive]), r.lowerBound > a.startIndex {
            a = String(a[..<r.lowerBound])
        }
        var al = TagCleaner.replace(album, #"[\(\[].*?[\)\]]"#, " ").trimmingCharacters(in: .whitespaces)
        if test(al, junkAlbum) { al = "" }
        return SongReading(artist: a, title: t, album: al)
    }

    static func all(_ t: Track) -> [SongReading] {
        var out: [SongReading] = []
        func push(_ w: SongReading) {
            if w.title.isEmpty && w.artist.isEmpty { return }
            if !out.contains(where: { normal($0.artist) == normal(w.artist) && normal($0.title) == normal(w.title) }) { out.append(w) }
        }
        let title = cleanForSearch(t.title), artist = cleanForSearch(t.artist), album = cleanForSearch(t.album)
        let dash = splitDash(title)
        let fromTitle = dash.map { tidy($0.0, $0.1, album) }
        // a title with "Artist - Song" in it is usually more trustworthy than the artist tag
        if let fromTitle, !artist.isEmpty { push(fromTitle) }
        push(artist.isEmpty ? tidy(dash?.0 ?? "", dash?.1 ?? title, album) : tidy(artist, title, album))
        if let fromTitle { push(fromTitle) }
        let f = TagCleaner.split(fileName: t.fileName)
        push(tidy(cleanForSearch(f.artist), cleanForSearch(f.title), album))
        return out
    }
}

struct CoverCandidate: Identifiable {
    let art: String
    let album: String
    let artist: String
    var score: Double
    var sure: Bool
    var id: String { art }

    func url(_ side: Int) -> URL? {
        URL(string: art.replacingOccurrences(of: #"/\d+x\d+bb\."#, with: "/\(side)x\(side)bb.", options: .regularExpression))
    }
}

/// Album covers from the iTunes catalogue, only for songs without their own. Only artist and title are sent.
@MainActor
final class CoverFinder: ObservableObject {
    static let version = 2

    @Published private(set) var left = 0
    var onChange: (() -> Void)?

    private let library: Library
    private let settings: Settings
    private var queue: [UUID] = []
    private var running = false
    private var lastRequest = Date.distantPast
    private var memo: [URL: [Item]] = [:]

    struct Item: Decodable {
        let artworkUrl100: String?
        let artistName: String?
        let collectionName: String?
        let trackName: String?
    }

    private struct Answer: Decodable { let results: [Item] }

    enum Failure: Error { case limit, network }

    init(library: Library, settings: Settings) {
        self.library = library
        self.settings = settings
    }

    /// Looks up the playing song and the next one quietly, one request at a time.
    func auto(_ t: Track) {
        guard settings.v.onlineArt, !t.hasArtwork, t.artTried != Self.version, !queue.contains(t.id) else { return }
        queue.append(t.id)
        run()
    }

    func findAll() {
        let list = library.tracks.filter { !$0.hasArtwork && $0.bad != true }
        guard !list.isEmpty else { toast("У всех песен уже есть обложки"); return }
        for t in list {
            library.update(t.id) { $0.artTried = nil }
            if !queue.contains(t.id) { queue.append(t.id) }
        }
        toast("Ищу обложки: " + plural(list.count, "песня", "песни", "песен"))
        run()
    }

    private func run() {
        left = queue.count
        guard !running else { return }
        running = true
        Task {
            while !queue.isEmpty {
                let id = queue.removeFirst()
                if let t = library.track(id), !t.hasArtwork, t.artTried != Self.version { await search(t) }
                left = queue.count
            }
            running = false
        }
    }

    private func search(_ t: Track) async {
        do {
            let list = try await candidates(t, thorough: false)
            guard let best = list.first(where: \.sure) else {
                library.update(t.id) { $0.artTried = Self.version }
                return
            }
            try await set(best, for: t)
        } catch {
            // no internet or iTunes asked to wait: try again some other time
        }
    }

    func set(_ c: CoverCandidate, for t: Track) async throws {
        guard let url = c.url(600) else { throw Failure.network }
        let (raw, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, let data = MetadataReader.downscale(raw) else { throw Failure.network }
        // the same picture goes to every song of that album that has no cover of its own
        let album = SongReading.normal(t.album), artist = SongReading.normal(t.artist)
        var ids = [t.id]
        if !album.isEmpty {
            ids += library.tracks.filter {
                $0.id != t.id && SongReading.normal($0.album) == album && SongReading.normal($0.artist) == artist && (!$0.hasArtwork || $0.artOnline == true)
            }.map(\.id)
        }
        library.setCover(data, for: ids)
        onChange?()
    }

    /// Best first: same artist and album, then same artist and song, then any album of that artist.
    func candidates(_ t: Track, thorough: Bool) async throws -> [CoverCandidate] {
        let readings = SongReading.all(t)
        var out: [CoverCandidate] = []
        func add(_ x: Item, _ score: Double, _ sure: Bool) {
            guard let art = x.artworkUrl100 else { return }
            if let i = out.firstIndex(where: { $0.art == art }) {
                out[i].score = max(out[i].score, score)
                out[i].sure = out[i].sure || sure
            } else {
                out.append(CoverCandidate(art: art, album: x.collectionName ?? "", artist: x.artistName ?? "", score: score, sure: sure))
            }
        }
        func best() -> Double { out.map(\.score).max() ?? 0 }

        for w in readings {
            if !w.album.isEmpty, !w.artist.isEmpty {
                let points: (Item) -> Double = { (SongReading.match($0.artistName ?? "", w.artist) ? 2 : 0) + (SongReading.match($0.collectionName ?? "", w.album) ? 2 : 0) }
                for x in try await search(w.artist + " " + w.album, "album", good: { points($0) >= 4 }) { add(x, points(x), points(x) >= 4) }
            }
            if !w.title.isEmpty, thorough || best() < 3 {
                let points: (Item) -> Double = {
                    (!w.artist.isEmpty && SongReading.match($0.artistName ?? "", w.artist) ? 2 : 0)
                        + (SongReading.match($0.trackName ?? "", w.title) ? 1 : 0)
                        + (!w.album.isEmpty && SongReading.match($0.collectionName ?? "", w.album) ? 2 : 0)
                }
                let sure: (Item) -> Bool = { w.artist.isEmpty ? SongReading.match($0.trackName ?? "", w.title) : points($0) >= 3 }
                let term = (w.artist.isEmpty ? "" : w.artist + " ") + w.title
                for x in try await search(term, "song", good: sure) { add(x, points(x), sure(x)) }
                if !w.artist.isEmpty, best() < 3 {
                    for x in try await search(w.title, "song", good: sure) { add(x, points(x), sure(x)) }
                }
            }
            if !thorough, out.contains(where: { $0.sure && $0.score >= 3 }) { break }
        }
        if thorough || !out.contains(where: \.sure), let w = readings.first(where: { !$0.artist.isEmpty }) {
            let ok: (Item) -> Bool = { SongReading.match($0.artistName ?? "", w.artist) }
            for x in try await search(w.artist, "album", good: ok) { add(x, ok(x) ? 2 : 0, ok(x)) }
        }
        return out.sorted { $0.sure != $1.sure ? $0.sure : $0.score > $1.score }
    }

    private func search(_ term: String, _ entity: String, good: (Item) -> Bool) async throws -> [Item] {
        let has = { (p: String) in term.range(of: p, options: [.regularExpression, .caseInsensitive]) != nil }
        let countries = has("[іїєґ]") ? ["ua", "us"] : has("[а-яё]") ? ["ua", "ru", "us"] : ["us", "ua"]
        var all: [Item] = []
        for country in countries {
            let r = try await fetch(term, entity, country)
            all += r
            if r.contains(where: good) { break }
        }
        return all
    }

    /// iTunes allows about 20 searches a minute: space them out, wait and retry once when refused.
    private func fetch(_ term: String, _ entity: String, _ country: String) async throws -> [Item] {
        var c = URLComponents(string: "https://itunes.apple.com/search")
        c?.queryItems = [URLQueryItem(name: "term", value: term), URLQueryItem(name: "entity", value: entity),
                         URLQueryItem(name: "limit", value: "15"), URLQueryItem(name: "country", value: country)]
        guard let url = c?.url else { return [] }
        if let known = memo[url] { return known }
        for attempt in 0..<2 {
            let wait = lastRequest.addingTimeInterval(3.1).timeIntervalSinceNow
            lastRequest = max(Date(), lastRequest.addingTimeInterval(3.1))
            if wait > 0 { try await Task.sleep(for: .seconds(wait)) }
            let (data, response) = try await URLSession.shared.data(from: url)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 403 || code == 429 {
                if attempt > 0 { throw Failure.limit }
                lastRequest = Date().addingTimeInterval(60)
                continue
            }
            guard code == 200, let answer = try? JSONDecoder().decode(Answer.self, from: data) else { throw Failure.network }
            let items = answer.results.filter { $0.artworkUrl100 != nil }
            memo[url] = items
            return items
        }
        return []
    }
}
