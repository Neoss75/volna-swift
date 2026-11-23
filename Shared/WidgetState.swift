import AppIntents
import SwiftUI
import UIKit

/// What the app tells the widget: kept in the folder both of them can open (the app group).
struct WidgetState: Codable, Equatable {
    var title = ""
    var artist = ""
    var playing = false
    var accent = "amber"
    var coverVersion = ""

    static let group = "group.com.neoss75.volna"

    static var folder: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) }

    static func load() -> WidgetState {
        guard let f = folder, let data = try? Data(contentsOf: f.appendingPathComponent("widget.json")),
              let s = try? JSONDecoder().decode(WidgetState.self, from: data) else { return WidgetState() }
        return s
    }

    func save() {
        guard let f = Self.folder, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: f.appendingPathComponent("widget.json"), options: .atomic)
    }

    static func saveCover(_ image: UIImage?) {
        guard let url = folder?.appendingPathComponent("cover.jpg") else { return }
        if let data = image?.preparingThumbnail(of: CGSize(width: 320, height: 320))?.jpegData(compressionQuality: 0.85) {
            try? data.write(to: url, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func cover() -> UIImage? { folder.flatMap { UIImage(contentsOfFile: $0.appendingPathComponent("cover.jpg").path) } }

    var accentColor: Color {
        switch accent {
        case "mint": Color(red: 0.37, green: 0.86, blue: 0.68)
        case "coral": Color(red: 1, green: 0.56, blue: 0.44)
        case "lavender": Color(red: 0.73, green: 0.64, blue: 1)
        case "sky": Color(red: 0.42, green: 0.78, blue: 1)
        case "rose": Color(red: 1, green: 0.51, blue: 0.7)
        default: Color(red: 1, green: 0.71, blue: 0.28)
        }
    }
}

/// The app fills these in when it starts; the buttons of the widget run inside the app.
@MainActor
enum PlayerBridge {
    static var toggle: (() -> Void)?
    static var next: (() -> Void)?
    static var previous: (() -> Void)?
}

struct ToggleIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Играть или пауза"

    func perform() async throws -> some IntentResult {
        await MainActor.run { PlayerBridge.toggle?() }
        return .result()
    }
}

struct NextIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Следующая песня"

    func perform() async throws -> some IntentResult {
        await MainActor.run { PlayerBridge.next?() }
        return .result()
    }
}

struct PreviousIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Предыдущая песня"

    func perform() async throws -> some IntentResult {
        await MainActor.run { PlayerBridge.previous?() }
        return .result()
    }
}
