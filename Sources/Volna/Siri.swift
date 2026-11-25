import AppIntents
import Foundation

/// What Siri and the Shortcuts app can ask the player to do. The texts here are translated by iOS itself
/// (Shared/*.lproj/Localizable.strings, Resources/*.lproj/AppShortcuts.strings), the answers by tr().
@MainActor
enum SiriBridge {
    static var library: Library?
    static var player: Player?
}

// MARK: - What can be named

struct SongEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Песня")
    static let defaultQuery = SongQuery()
    let id: UUID
    let title: String
    let artist: String

    init(_ t: Track) {
        id = t.id
        title = t.title
        artist = t.artist
    }

    var displayRepresentation: DisplayRepresentation {
        artist.isEmpty ? DisplayRepresentation(title: "\(title)") : DisplayRepresentation(title: "\(title)", subtitle: "\(artist)")
    }
}

struct SongQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [SongEntity] {
        identifiers.compactMap { SiriBridge.library?.track($0) }.map(SongEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [SongEntity] {
        SiriSearch.best(SiriBridge.library?.tracks ?? [], string) { $0.title }.prefix(20).map(SongEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [SongEntity] {
        (SiriBridge.library?.tracks ?? []).prefix(400).map(SongEntity.init)
    }
}

struct ArtistEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Исполнитель")
    static let defaultQuery = ArtistQuery()
    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    @MainActor
    static var all: [ArtistEntity] {
        var seen: Set<String> = [], list: [ArtistEntity] = []
        for t in SiriBridge.library?.tracks ?? [] where !t.artist.isEmpty {
            let key = Library.artistKey(t)
            if seen.insert(key).inserted { list.append(ArtistEntity(id: key, name: t.artist)) }
        }
        return list
    }
}

struct ArtistQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [ArtistEntity] { ArtistEntity.all.filter { identifiers.contains($0.id) } }

    @MainActor
    func entities(matching string: String) async throws -> [ArtistEntity] { Array(SiriSearch.best(ArtistEntity.all, string) { $0.name }.prefix(20)) }

    @MainActor
    func suggestedEntities() async throws -> [ArtistEntity] { Array(ArtistEntity.all.prefix(200)) }
}

struct PlaylistEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Плейлист")
    static let defaultQuery = PlaylistQuery()
    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    @MainActor
    static var all: [PlaylistEntity] { (SiriBridge.library?.playlists ?? []).map { PlaylistEntity(id: $0.id, name: $0.name) } }
}

struct PlaylistQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [PlaylistEntity] { PlaylistEntity.all.filter { identifiers.contains($0.id) } }

    @MainActor
    func entities(matching string: String) async throws -> [PlaylistEntity] { SiriSearch.best(PlaylistEntity.all, string) { $0.name } }

    @MainActor
    func suggestedEntities() async throws -> [PlaylistEntity] { PlaylistEntity.all }
}

enum SiriSearch {
    /// The closest names first; spelling, brackets and Cyrillic or Latin letters do not matter.
    static func best<T>(_ list: [T], _ words: String, _ name: (T) -> String) -> [T] {
        list.map { (item: $0, score: max(SongReading.score(name($0), words), name($0).localizedCaseInsensitiveContains(words) ? 0.9 : 0)) }
            .filter { $0.score >= 0.7 }
            .sorted { $0.score > $1.score }
            .map(\.item)
    }
}

// MARK: - What can be done

struct PlayFavouritesIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Включить избранное"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let lib = SiriBridge.library, let player = SiriBridge.player else { return .result(dialog: "\(tr("Плеер ещё не готов"))") }
        let ids = lib.tracks.filter { lib.isFavourite($0.id) }.map(\.id)
        guard let first = ids.first else { return .result(dialog: "\(tr("В избранном пока пусто"))") }
        player.play(player.shuffle ? ids.randomElement() ?? first : first, from: ids)
        return .result(dialog: "\(tr("Играю избранное"))")
    }
}

struct ShuffleAllIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Перемешать всю музыку"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let lib = SiriBridge.library, let player = SiriBridge.player, !lib.tracks.isEmpty else { return .result(dialog: "\(tr("В плеере пока нет песен"))") }
        player.playShuffled(lib.tracks.map(\.id))
        return .result(dialog: "\(tr("Играю вперемешку"))")
    }
}

struct ResumeIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Продолжить музыку"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let lib = SiriBridge.library, let player = SiriBridge.player, !lib.tracks.isEmpty else { return .result(dialog: "\(tr("В плеере пока нет песен"))") }
        player.resume()
        return .result(dialog: "\(tr("Продолжаю"))")
    }
}

struct PlaySongIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Включить песню"
    @Parameter(title: "Песня") var song: SongEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let lib = SiriBridge.library, let player = SiriBridge.player, lib.track(song.id) != nil else { return .result(dialog: "\(tr("Такой песни в плеере нет"))") }
        player.play(song.id, from: lib.tracks.map(\.id))
        return .result(dialog: "\(tr("Играю «{}»", song.title))")
    }
}

struct PlayArtistIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Включить исполнителя"
    @Parameter(title: "Исполнитель") var artist: ArtistEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let lib = SiriBridge.library, let player = SiriBridge.player,
              let ids = Optional(lib.tracks.filter { Library.artistKey($0) == artist.id }.map(\.id)), let first = ids.first else { return .result(dialog: "\(tr("Такого исполнителя в плеере нет"))") }
        player.play(player.shuffle ? ids.randomElement() ?? first : first, from: ids)
        return .result(dialog: "\(tr("Играю «{}»", artist.name))")
    }
}

struct PlayPlaylistIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Включить плейлист"
    @Parameter(title: "Плейлист") var playlist: PlaylistEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let lib = SiriBridge.library, let player = SiriBridge.player,
              let p = lib.playlists.first(where: { $0.id == playlist.id }) else { return .result(dialog: "\(tr("Такого плейлиста нет"))") }
        let ids = p.keys.filter { lib.track($0) != nil }
        guard let first = ids.first else { return .result(dialog: "\(tr("Плейлист пуст"))") }
        player.play(player.shuffle ? ids.randomElement() ?? first : first, from: ids)
        return .result(dialog: "\(tr("Играю «{}»", p.name))")
    }
}

// MARK: - What to say

struct VolnaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: PlayFavouritesIntent(), phrases: [
            "Включи избранное в \(.applicationName)",
            "Играй избранное в \(.applicationName)",
        ], shortTitle: "Избранное", systemImageName: "heart.fill")
        AppShortcut(intent: ShuffleAllIntent(), phrases: [
            "Перемешай музыку в \(.applicationName)",
            "Включи всё вперемешку в \(.applicationName)",
        ], shortTitle: "Вперемешку", systemImageName: "shuffle")
        AppShortcut(intent: ResumeIntent(), phrases: [
            "Включи музыку в \(.applicationName)",
            "Продолжи музыку в \(.applicationName)",
        ], shortTitle: "Продолжить", systemImageName: "play.fill")
        AppShortcut(intent: PlaySongIntent(), phrases: [
            "Включи песню \(\.$song) в \(.applicationName)",
            "Включи песню в \(.applicationName)",
        ], shortTitle: "Песня", systemImageName: "music.note")
        AppShortcut(intent: PlayArtistIntent(), phrases: [
            "Включи исполнителя \(\.$artist) в \(.applicationName)",
            "Включи исполнителя в \(.applicationName)",
        ], shortTitle: "Исполнитель", systemImageName: "music.mic")
        AppShortcut(intent: PlayPlaylistIntent(), phrases: [
            "Включи плейлист \(\.$playlist) в \(.applicationName)",
            "Включи плейлист в \(.applicationName)",
        ], shortTitle: "Плейлист", systemImageName: "music.note.list")
    }
}
