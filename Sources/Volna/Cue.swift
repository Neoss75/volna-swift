import Foundation

/// A .cue sheet: where the songs begin inside one long file.
struct CueSheet: Equatable, Sendable {
    struct Song: Equatable, Sendable {
        var number: Int
        var title = ""
        var artist = ""
        /// Seconds from the beginning of the file.
        var start = 0.0
    }

    struct File: Equatable, Sendable {
        var name: String
        var songs: [Song] = []
    }

    var title = ""
    var artist = ""
    var files: [File] = []

    init(_ text: String) {
        var song: Song?
        func close(_ s: inout [File]) {
            if let done = song, !s.isEmpty { s[s.count - 1].songs.append(done) }
            song = nil
        }
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard let word = line.split(separator: " ").first?.uppercased() else { continue }
            let rest = line.dropFirst(word.count).trimmingCharacters(in: .whitespaces)
            switch word {
            case "FILE":
                close(&files)
                files.append(File(name: Self.quoted(rest, dropLast: true)))
            case "TRACK":
                close(&files)
                let p = rest.split(separator: " ")
                // data tracks of old discs are not music
                if p.count < 2 || p[1].uppercased() == "AUDIO", let n = p.first.flatMap({ Int($0) }) { song = Song(number: n) }
            case "TITLE":
                if song != nil { song?.title = Self.quoted(rest) } else if files.allSatisfy({ $0.songs.isEmpty }) { title = Self.quoted(rest) }
            case "PERFORMER":
                if song != nil { song?.artist = Self.quoted(rest) } else if files.allSatisfy({ $0.songs.isEmpty }) { artist = Self.quoted(rest) }
            case "INDEX":
                let p = rest.split(separator: " ")
                if p.count == 2, Int(p[0]) == 1, let t = Self.time(p[1]) { song?.start = t }
            default:
                break
            }
        }
        close(&files)
    }

    /// Minutes, seconds and frames, 75 in a second.
    private static func time(_ s: Substring) -> Double? {
        let n = s.split(separator: ":").compactMap { Double($0) }
        return n.count == 3 ? n[0] * 60 + n[1] + n[2] / 75 : nil
    }

    /// "Name.flac" WAVE
    private static func quoted(_ s: String, dropLast: Bool = false) -> String {
        if let a = s.firstIndex(of: "\""), let b = s.lastIndex(of: "\""), a < b { return s[s.index(after: a)..<b].trimmingCharacters(in: .whitespaces) }
        if dropLast, let space = s.lastIndex(of: " ") { return String(s[..<space]) }
        return s
    }

    /// The songs of one long file; nil when the sheet describes an album already cut into files.
    func songs(of file: File) -> [Song]? {
        let list = file.songs.sorted { $0.start < $1.start }
        guard list.count > 1, zip(list, list.dropFirst()).allSatisfy({ $0.start < $1.start }) else { return nil }
        return list
    }

    static func text(_ data: Data) -> String {
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) { return String(data: data, encoding: .utf16) ?? "" }
        return StationList.text(data)
    }

    /// Which of `names` the sheet speaks about: the very name, the same name in another format, or the name of the sheet itself.
    func match(_ names: [String], sheet: String) -> [(file: File, name: String)] {
        func base(_ s: String) -> String { (s as NSString).deletingPathExtension.lowercased() }
        func last(_ s: String) -> String { s.replacingOccurrences(of: "\\", with: "/").split(separator: "/").last.map(String.init) ?? s }
        return files.compactMap { f in
            let want = last(f.name)
            let found = names.first { $0.lowercased() == want.lowercased() } ?? names.first { base($0) == base(want) }
                ?? (files.count == 1 ? names.first { base($0) == base(sheet) } : nil)
            return found.map { (f, $0) }
        }
    }

    /// Some FLAC files carry the sheet inside.
    static func embedded(in url: URL) -> CueSheet? {
        guard url.pathExtension.lowercased() == "flac", let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        guard let d = try? h.read(upToCount: 1_500_000) else { return nil }
        return embedded(in: [UInt8](d))
    }

    static func embedded(in b: [UInt8]) -> CueSheet? {
        guard b.count > 8, b[0] == 0x66, b[1] == 0x4C, b[2] == 0x61, b[3] == 0x43 else { return nil }
        func le(_ o: Int) -> Int { o + 4 <= b.count ? Int(b[o]) | Int(b[o + 1]) << 8 | Int(b[o + 2]) << 16 | Int(b[o + 3]) << 24 : -1 }
        var at = 4
        while at + 4 <= b.count {
            let last = b[at] & 0x80 != 0, kind = b[at] & 0x7F, size = Int(b[at + 1]) << 16 | Int(b[at + 2]) << 8 | Int(b[at + 3])
            let start = at + 4, end = start + size
            if kind == 4, end <= b.count {
                var p = start
                let vendor = le(p)
                guard vendor >= 0 else { return nil }
                p += 4 + vendor
                let count = le(p)
                p += 4
                for _ in 0..<max(0, min(count, 2000)) {
                    let n = le(p)
                    guard n >= 0, p + 4 + n <= end else { return nil }
                    let tag = b[(p + 4)..<(p + 4 + n)]
                    if tag.count > 9, String(decoding: tag.prefix(9), as: UTF8.self).uppercased() == "CUESHEET=" {
                        return CueSheet(String(decoding: tag.dropFirst(9), as: UTF8.self))
                    }
                    p += 4 + n
                }
                return nil
            }
            if last { return nil }
            at = end
        }
        return nil
    }
}
