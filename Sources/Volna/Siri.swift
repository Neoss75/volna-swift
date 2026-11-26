import AppIntents
import Foundation

/// What Siri and the Shortcuts app can ask the player to do. The texts here are translated by iOS itself
/// (Shared/*.lproj/Localizable.strings, Resources/*.lproj/AppShortcuts.strings), the answers by tr().
@MainActor
enum SiriBridge {
    static var library: Library?
    static var player: Player?
    static var stations: Stations?
    static var settings: Settings?
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

struct StationEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Радиостанция")
    static let defaultQuery = StationQuery()
    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    @MainActor
    static var all: [StationEntity] { (SiriBridge.stations?.ordered ?? []).map { StationEntity(id: $0.id, name: $0.name) } }
}

struct StationQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [StationEntity] { StationEntity.all.filter { identifiers.contains($0.id) } }

    @MainActor
    func entities(matching string: String) async throws -> [StationEntity] { Array(SiriSearch.best(StationEntity.all, string) { $0.name }.prefix(20)) }

    @MainActor
    func suggestedEntities() async throws -> [StationEntity] { Array(StationEntity.all.prefix(200)) }
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

struct PlayStationIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Включить радио"
    @Parameter(title: "Радиостанция") var station: StationEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let stations = SiriBridge.stations, let player = SiriBridge.player, !stations.all.isEmpty else { return .result(dialog: "\(tr("Станций в плеере пока нет"))") }
        guard let s = stations.station(station.id) else { return .result(dialog: "\(tr("Такой станции нет"))") }
        player.play(s, from: stations.ordered.map(\.id))
        return .result(dialog: "\(tr("Играю «{}»", s.name))")
    }
}

struct SleepTimerIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Таймер сна"
    @Parameter(title: "Время") var time: SleepChoice

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let player = SiriBridge.player else { return .result(dialog: "\(tr("Плеер ещё не готов"))") }
        switch time {
        case .off:
            player.sleep(minutes: nil)
            return .result(dialog: "\(tr("Таймер сна выключен"))")
        case .song:
            player.sleepAfterThisTrack()
            return .result(dialog: "\(tr("Остановлю в конце песни"))")
        default:
            player.sleep(minutes: time.minutes)
            return .result(dialog: "\(tr("Остановлю через {} минут", "\(time.minutes)"))")
        }
    }
}

enum SleepChoice: String, AppEnum {
    case m15, m30, m45, m60, song, off

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Время")
    static let caseDisplayRepresentations: [SleepChoice: DisplayRepresentation] = [
        .m15: DisplayRepresentation(title: "15 минут", synonyms: ["пятнадцать минут"]),
        .m30: DisplayRepresentation(title: "30 минут", synonyms: ["полчаса", "тридцать минут"]),
        .m45: DisplayRepresentation(title: "45 минут", synonyms: ["сорок пять минут"]),
        .m60: DisplayRepresentation(title: "час", synonyms: ["1 час", "60 минут"]),
        .song: DisplayRepresentation(title: "конец песни", synonyms: ["после песни"]),
        .off: DisplayRepresentation(title: "выключить", synonyms: ["выкл"]),
    ]

    var minutes: Int { ["m15": 15, "m30": 30, "m45": 45, "m60": 60][rawValue] ?? 0 }
}

struct PresetIntent: AppIntent {
    static let title: LocalizedStringResource = "Настройка эквалайзера"
    static let openAppWhenRun = false
    @Parameter(title: "Настройка") var preset: PresetChoice

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let settings = SiriBridge.settings else { return .result(dialog: "\(tr("Плеер ещё не готов"))") }
        if preset == .off {
            settings.v.eqOn = false
            return .result(dialog: "\(tr("Эквалайзер выключен"))")
        }
        guard let p = EQPreset.all.first(where: { $0.id == preset.rawValue }) else { return .result(dialog: "\(tr("Такой настройки нет"))") }
        settings.v.bands = p.bands
        settings.v.eqOn = true
        return .result(dialog: "\(tr("Эквалайзер: ") + tr(p.name))")
    }
}

/// The same names as the chips on the equaliser screen.
enum PresetChoice: String, AppEnum {
    case flat, bass, rock, pop, vocal, jazz, classic, electro, treble, off

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Настройка")
    static let caseDisplayRepresentations: [PresetChoice: DisplayRepresentation] = [
        .flat: DisplayRepresentation(title: "Ровно", synonyms: ["ровный", "обычный"]),
        .bass: DisplayRepresentation(title: "Бас", synonyms: ["басы"]),
        .rock: DisplayRepresentation(title: "Рок"),
        .pop: DisplayRepresentation(title: "Поп"),
        .vocal: DisplayRepresentation(title: "Вокал", synonyms: ["голос"]),
        .jazz: DisplayRepresentation(title: "Джаз"),
        .classic: DisplayRepresentation(title: "Классика"),
        .electro: DisplayRepresentation(title: "Электроника"),
        .treble: DisplayRepresentation(title: "Верха", synonyms: ["высокие"]),
        .off: DisplayRepresentation(title: "выключить", synonyms: ["выкл"]),
    ]
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
        AppShortcut(intent: PlayStationIntent(), phrases: [
            "Включи радио \(\.$station) в \(.applicationName)",
            "Включи радио в \(.applicationName)",
        ], shortTitle: "Радио", systemImageName: "dot.radiowaves.left.and.right")
        AppShortcut(intent: SleepTimerIntent(), phrases: [
            "Таймер сна \(\.$time) в \(.applicationName)",
            "Выключи музыку через \(\.$time) в \(.applicationName)",
            "Таймер сна в \(.applicationName)",
        ], shortTitle: "Таймер сна", systemImageName: "moon.zzz")
        AppShortcut(intent: PresetIntent(), phrases: [
            "Эквалайзер \(\.$preset) в \(.applicationName)",
            "Включи эквалайзер \(\.$preset) в \(.applicationName)",
            "Эквалайзер в \(.applicationName)",
        ], shortTitle: "Эквалайзер", systemImageName: "slider.vertical.3")
        AppShortcut(intent: LikeIntent(), phrases: [
            "Добавь в избранное в \(.applicationName)",
            "Мне нравится эта песня в \(.applicationName)",
            "Лайк в \(.applicationName)",
        ], shortTitle: "В избранное", systemImageName: "heart")
    }
}
