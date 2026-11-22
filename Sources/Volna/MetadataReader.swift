import AVFoundation
import UIKit

struct TrackMeta: Sendable {
    var title: String?
    var artist: String?
    var album: String?
    var duration: Double = 0
    var artwork: Data?
}

/// Reads tags and the embedded cover with AVFoundation (ID3, iTunes/MP4 and others it understands).
enum MetadataReader {
    static func read(url: URL) async -> TrackMeta {
        let asset = AVURLAsset(url: url)
        var meta = TrackMeta()
        if let d = try? await asset.load(.duration), d.isNumeric, d.seconds > 0 {
            meta.duration = d.seconds
        }

        var items: [AVMetadataItem] = (try? await asset.load(.commonMetadata)) ?? []
        if let formats = try? await asset.load(.availableMetadataFormats) {
            for format in formats {
                items += (try? await asset.loadMetadata(for: format)) ?? []
            }
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
                if meta.artwork == nil, let data = try? await item.load(.dataValue) {
                    meta.artwork = downscale(data)
                }
            default:
                break
            }
        }

        if meta.duration == 0, let file = try? AVAudioFile(forReading: url) {
            meta.duration = Double(file.length) / file.processingFormat.sampleRate
        }
        return meta
    }

    /// "01 - Artist - Song" → artist "Artist", title "Song".
    static func guess(fromFileName name: String) -> (title: String, artist: String?) {
        var s = name.replacingOccurrences(of: "_", with: " ")
        if let r = s.range(of: #"^\s*\d{1,3}\s*[.\-–—)]\s+"#, options: .regularExpression) {
            s.removeSubrange(r)
        }
        for sep in [" - ", " – ", " — "] {
            let parts = s.components(separatedBy: sep)
            if parts.count >= 2 {
                let artist = parts[0].trimmingCharacters(in: .whitespaces)
                let title = parts.dropFirst().joined(separator: sep).trimmingCharacters(in: .whitespaces)
                if !artist.isEmpty, !title.isEmpty { return (title, artist) }
            }
        }
        let title = s.trimmingCharacters(in: .whitespaces)
        return (title.isEmpty ? name : title, nil)
    }

    private static func clean(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    /// Covers are kept at most 600 px: enough for the screen and the lock screen.
    private static func downscale(_ data: Data, limit: CGFloat = 600) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(1, limit / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let out = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return out.jpegData(compressionQuality: 0.85)
    }
}

/// Covers live in Application Support/Artwork/<track id>.jpg.
@MainActor
enum ArtworkStore {
    private static var cache: [UUID: UIImage] = [:]
    private static let folder: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func save(_ data: Data, id: UUID) -> Bool {
        do {
            try data.write(to: fileURL(id), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func image(for id: UUID) -> UIImage? {
        if let cached = cache[id] { return cached }
        guard let image = UIImage(contentsOfFile: fileURL(id).path) else { return nil }
        cache[id] = image
        return image
    }

    static func delete(id: UUID) {
        cache[id] = nil
        try? FileManager.default.removeItem(at: fileURL(id))
    }

    private static func fileURL(_ id: UUID) -> URL {
        folder.appendingPathComponent(id.uuidString + ".jpg")
    }
}
