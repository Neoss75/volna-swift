import AVFoundation
import UIKit

struct AudioHeader: Sendable {
    var ext = ""
    var size = 0
    var sampleRate: Double?
    var bits: Int?
    var kbps: Double?
    var vbr = false
    var tagBytes = 0
}

struct TrackMeta: Sendable {
    var title: String?
    var artist: String?
    var album: String?
    var duration: Double = 0
    var artwork: Data?
    var lyrics: String?
    var trackNo: Int?
    var header = AudioHeader()
}

/// Reads tags and the embedded cover with AVFoundation, plus the format details from the file header.
enum MetadataReader {
    static func read(url: URL) async -> TrackMeta {
        let asset = AVURLAsset(url: url)
        var meta = TrackMeta()
        meta.header = header(of: url)
        if let d = try? await asset.load(.duration), d.isNumeric, d.seconds > 0 { meta.duration = d.seconds }

        var items: [AVMetadataItem] = (try? await asset.load(.commonMetadata)) ?? []
        if let formats = try? await asset.load(.availableMetadataFormats) {
            for format in formats { items += (try? await asset.loadMetadata(for: format)) ?? [] }
        }
        for item in items {
            switch item.commonKey {
            case .commonKeyTitle?:
                if meta.title == nil { meta.title = clean(try? await item.load(.stringValue)) }
            case .commonKeyArtist?:
                if meta.artist == nil { meta.artist = clean(try? await item.load(.stringValue)) }
            case .commonKeyAlbumName?:
                if meta.album == nil { meta.album = clean(try? await item.load(.stringValue)) }
            case .commonKeyArtwork?:
                if meta.artwork == nil, let data = try? await item.load(.dataValue) { meta.artwork = downscale(data) }
            default:
                break
            }
        }
        for item in items where meta.trackNo == nil {
            if item.identifier == .id3MetadataTrackNumber, let s = try? await item.load(.stringValue) {
                meta.trackNo = Int(s.prefix { $0.isNumber }) // "3/12"
            } else if item.identifier == .iTunesMetadataTrackNumber, let d = try? await item.load(.dataValue), d.count >= 4 {
                meta.trackNo = Int(d[d.startIndex + 2]) << 8 | Int(d[d.startIndex + 3])
            }
        }
        if meta.trackNo == 0 { meta.trackNo = nil }
        if let text = try? await asset.load(.lyrics), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { meta.lyrics = text }

        if let file = try? AVAudioFile(forReading: url) {
            let f = file.fileFormat
            if meta.duration == 0, f.sampleRate > 0 { meta.duration = Double(file.length) / file.processingFormat.sampleRate }
            if meta.header.sampleRate == nil { meta.header.sampleRate = f.sampleRate }
            let d = f.streamDescription.pointee
            if d.mFormatID == kAudioFormatAppleLossless {
                meta.header.ext = "ALAC"
                meta.header.bits = [1: 16, 2: 20, 3: 24, 4: 32][Int(d.mFormatFlags)]
            } else if d.mFormatID == kAudioFormatLinearPCM, meta.header.bits == nil, d.mBitsPerChannel > 0 {
                meta.header.bits = Int(d.mBitsPerChannel) // AIFF, CAF
            }
        }
        return meta
    }

    private static func clean(_ s: String?) -> String? {
        guard let s else { return nil }
        let t = TagCleaner.clean(s.trimmingCharacters(in: .whitespacesAndNewlines))
        return t.isEmpty ? nil : t
    }

    /// Covers are kept at most 600 px: enough for the screen and the lock screen.
    static func downscale(_ data: Data, limit: CGFloat = 600) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(1, limit / max(image.size.width, image.size.height))
        let size = CGSize(width: max(1, (image.size.width * scale).rounded()), height: max(1, (image.size.height * scale).rounded()))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let out = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return out.jpegData(compressionQuality: 0.85)
    }

    // MARK: - File header (bit depth, sample rate, bitrate)

    static func header(of url: URL) -> AudioHeader {
        var h = AudioHeader()
        h.ext = url.pathExtension.uppercased()
        h.size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard let file = try? FileHandle(forReadingFrom: url) else { return h }
        defer { try? file.close() }
        guard let data = try? file.read(upToCount: 65536) else { return h }
        let d = [UInt8](data)
        func ascii(_ o: Int, _ n: Int) -> String { o + n <= d.count ? String(decoding: d[o..<(o + n)], as: UTF8.self) : "" }
        func le(_ o: Int, _ n: Int) -> Int { (0..<n).reduce(0) { $0 | Int(d[o + $1]) << (8 * $1) } }

        if ascii(0, 4) == "RIFF", ascii(8, 4) == "WAVE" {
            var o = 12
            while o + 24 <= d.count {
                if ascii(o, 4) == "fmt " {
                    let ch = le(o + 10, 2), sr = le(o + 12, 4), bits = le(o + 22, 2)
                    h.sampleRate = Double(sr)
                    h.bits = bits
                    h.kbps = Double(sr * bits * ch) / 1000
                    break
                }
                let size = le(o + 4, 4)
                o += 8 + size + (size & 1)
            }
        } else if ascii(0, 4) == "fLaC", d.count > 22 {
            h.sampleRate = Double(Int(d[18]) << 12 | Int(d[19]) << 4 | Int(d[20]) >> 4)
            h.bits = ((Int(d[20]) & 1) << 4 | Int(d[21]) >> 4) + 1
        } else if h.ext == "MP3" {
            var off = 0
            if ascii(0, 3) == "ID3", d.count > 10 {
                off = 10 + (Int(d[6] & 127) << 21 | Int(d[7] & 127) << 14 | Int(d[8] & 127) << 7 | Int(d[9] & 127)) + (d[5] & 16 != 0 ? 10 : 0)
            }
            h.tagBytes = off
            try? file.seek(toOffset: UInt64(off))
            let b = [UInt8]((try? file.read(upToCount: 8192)) ?? Data())
            var i = 0
            while i + 4 < b.count {
                defer { i += 1 }
                guard b[i] == 255, b[i + 1] & 0xE0 == 0xE0 else { continue }
                let ver = Int(b[i + 1] >> 3) & 3, layer = Int(b[i + 1] >> 1) & 3, bi = Int(b[i + 2] >> 4), si = Int(b[i + 2] >> 2) & 3
                if ver == 1 || layer != 1 || bi == 0 || bi == 15 || si == 3 { continue }
                let table: [Double] = ver == 3
                    ? [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320]
                    : [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160]
                h.sampleRate = [44100.0, 48000, 32000][si] / (ver == 3 ? 1 : ver == 2 ? 2 : 4)
                let frame = String(decoding: b[i..<min(b.count, i + 204)], as: UTF8.self)
                if frame.contains("Xing") || frame.contains("VBRI") { h.vbr = true } else { h.kbps = table[bi] }
                break
            }
        }
        return h
    }
}

/// Drops download-site stamps like "(SkySound.cc)", "[muzofond.fm]", "www.site.ru" from titles.
enum TagCleaner {
    private static let site = #"(?:www\.)?[\w-]+\.(?:cc|com|net|org|ru|su|fm|me|io|club|pro|info|biz|xyz|top|online|site|to|tv|ws|cz|ua|kz|by|mobi|co|link|live|music|zone)"#

    static func replace(_ s: String, _ pattern: String, _ with: String = "") -> String {
        s.replacingOccurrences(of: pattern, with: with, options: [.regularExpression, .caseInsensitive])
    }

    static func clean(_ s: String) -> String {
        var t = replace(s, #"\s*[\(\[\{]\s*[^()\[\]{}]*?"# + site + #"[^()\[\]{}]*?[\)\]\}]"#)
        t = replace(t, #"\s*[-–—|@]?\s*\b"# + site + #"\s*$"#)
        t = replace(t, #"^\s*"# + site + #"\b\s*[-–—|@]?\s*"#)
        t = replace(t, #"\s{2,}"#, " ").trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? s.trimmingCharacters(in: .whitespaces) : t
    }

    static func split(fileName: String) -> (artist: String, title: String) {
        let base = clean((fileName as NSString).deletingPathExtension.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces))
        if let r = base.range(of: #"\s+[-–—]\s+"#, options: .regularExpression), r.lowerBound > base.startIndex {
            let artist = replace(String(base[..<r.lowerBound]), #"^\d+[.\s-]+"#).trimmingCharacters(in: .whitespaces)
            let title = String(base[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !title.isEmpty { return (artist, title) }
        }
        let t = replace(base, #"^\d+[.\s-]+"#)
        return ("", t.isEmpty ? base : t)
    }
}

/// Covers live in Application Support/Artwork/<track id>.jpg.
@MainActor
enum ArtworkStore {
    private static let full = NSCache<NSString, UIImage>()
    private static let small = NSCache<NSString, UIImage>()
    private static let folder: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func save(_ data: Data, id: UUID) -> Bool {
        forget(id)
        return (try? data.write(to: fileURL(id), options: .atomic)) != nil
    }

    static func image(for id: UUID) -> UIImage? {
        let key = id.uuidString as NSString
        if let c = full.object(forKey: key) { return c }
        guard let image = UIImage(contentsOfFile: fileURL(id).path) else { return nil }
        full.countLimit = 12
        full.setObject(image, forKey: key)
        return image
    }

    static func thumbnail(for id: UUID) -> UIImage? {
        let key = id.uuidString as NSString
        if let c = small.object(forKey: key) { return c }
        guard let image = UIImage(contentsOfFile: fileURL(id).path) else { return nil }
        let side: CGFloat = 140
        let k = side / max(1, min(image.size.width, image.size.height))
        let thumb = image.preparingThumbnail(of: CGSize(width: image.size.width * k, height: image.size.height * k)) ?? image
        small.setObject(thumb, forKey: key)
        return thumb
    }

    static func delete(id: UUID) {
        forget(id)
        try? FileManager.default.removeItem(at: fileURL(id))
    }

    private static func forget(_ id: UUID) {
        full.removeObject(forKey: id.uuidString as NSString)
        small.removeObject(forKey: id.uuidString as NSString)
    }

    private static func fileURL(_ id: UUID) -> URL { folder.appendingPathComponent(id.uuidString + ".jpg") }
}
