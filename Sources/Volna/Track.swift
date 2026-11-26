import Foundation

/// One song in the library. The file itself stays where it is in «Файлы»;
/// we only keep a bookmark that lets us open it again after the app restarts.
/// Everything after `hasArtwork` is optional so that libraries saved by build 7 still open.
struct Track: Identifiable, Codable, Equatable {
    let id: UUID
    var bookmark: Data
    var path: String
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var hasArtwork: Bool

    // songs added as part of a folder: the folder's bookmark plus a path inside it
    var folderID: UUID?
    var relPath: String?
    var folder: String?

    var ext: String?
    var size: Int?
    var sampleRate: Double?
    var bits: Int?
    var kbps: Double?
    var vbr: Bool?
    var tagBytes: Int?

    var wave: [Int]?
    var gainDb: Double?
    var artOnline: Bool?
    var artTried: Int?
    var metaVersion: Int?
    var bad: Bool?
    var trackNo: Int?
    var addedAt: Date?
    /// Title, artist and album were corrected by hand: tags from the file do not replace them.
    var edited: Bool?

    // a song inside one long file (.cue): where it begins and ends, in seconds; no end = to the end of the file
    var cueStart: Double?
    var cueEnd: Double?
    var cueTitle: String?
    var cueArtist: String?
    var cueAlbum: String?

    /// Where the sound begins and ends, in seconds from the start of the song; the rest is silence.
    var soundStart: Double?
    var soundEnd: Double?
    /// lrclib.net was asked about this song by itself already.
    var lyricsTried: Bool?

    static let currentMeta = 4

    /// Better than CD: more than 48 kHz or at least 24 bits.
    var isHiRes: Bool { (sampleRate ?? 0) > 48000 || (bits ?? 0) >= 24 }

    /// Nothing was thrown away when the file was made. WAV, AIFF and CAF may also hold compressed sound: then the bit depth is small or unknown.
    var isLossless: Bool {
        switch kind {
        case "FLAC", "ALAC": true
        case "WAV", "AIF", "AIFF", "CAF": (bits ?? 0) >= 16
        default: false
        }
    }

    var fileName: String { (path as NSString).lastPathComponent }
    var baseName: String { (fileName as NSString).deletingPathExtension }
    var kind: String { (ext ?? (fileName as NSString).pathExtension).uppercased() }
    var letter: String { title.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "♪" }

    var subtitle: String {
        let parts = [artist, album].filter { !$0.isEmpty }
        return parts.isEmpty ? [kind, sizeText].filter { !$0.isEmpty }.joined(separator: " · ") : parts.joined(separator: " · ")
    }

    var sizeText: String {
        guard let size, size > 0 else { return "" }
        return String(format: tr("%.1f МБ"), Double(size) / 1_048_576)
    }

    private static let standardRates: [Double] = [32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 192, 224, 256, 320]

    /// Exact where the file states it, otherwise the average: size ÷ duration.
    var bitrateText: String {
        if let kbps, kbps > 0 { return tr("{} кбит/с", "\(Int(kbps.rounded()))") }
        guard let size, size > 0, duration > 0 else { return "" }
        let avg = Double(max(0, size - (tagBytes ?? 0))) * 8 / duration / 1000
        if vbr == true { return tr("VBR ≈ {} кбит/с", "\(Int(avg.rounded()))") }
        if ["MP3", "M4A", "AAC"].contains(kind), let s = Self.standardRates.first(where: { abs($0 - avg) / $0 < 0.03 }) {
            return tr("{} кбит/с", "\(Int(s))")
        }
        return tr("≈ {} кбит/с", "\(Int(avg.rounded()))")
    }

    /// Compact form for list rows: "MP3 320", "FLAC ≈912".
    var rowQuality: String {
        let k = bitrateText.replacingOccurrences(of: tr(" кбит/с"), with: "").replacingOccurrences(of: "≈ ", with: "≈")
        return k.isEmpty ? kind : kind + " " + k
    }

    var formatLine: String {
        var p = [kind]
        if let sr = sampleRate, sr > 0 {
            let khz = String(format: tr("%g кГц"), (sr / 100).rounded() / 10)
            if let bits, bits > 0 { p.append(tr("{} бит / {}", "\(bits)", "\(khz)")) } else { p.append(khz) }
        }
        p.append(bitrateText)
        p.append(sizeText)
        if cueStart != nil { p.append("CUE") }
        return p.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct FolderRef: Identifiable, Codable {
    let id: UUID
    var bookmark: Data
    var path: String
    var name: String
}

struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var keys: [UUID]
}
