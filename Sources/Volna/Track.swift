import Foundation

/// One song in the library. The file itself stays where it is in «Файлы»;
/// we only keep a bookmark that lets us open it again after the app restarts.
struct Track: Identifiable, Codable, Equatable {
    let id: UUID
    var bookmark: Data
    var path: String
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var hasArtwork: Bool

    var subtitle: String {
        let parts = [artist, album].filter { !$0.isEmpty }
        return parts.isEmpty ? "Неизвестный исполнитель" : parts.joined(separator: " · ")
    }
}
