import SwiftUI

enum VizMode: String, Codable, CaseIterable, Identifiable {
    case bars, peaks, mirror, led, dots, area, ribbons, wave, scope, ridges, flows, kaleido, tiles, drop, aurora, sparks, confetti, pulse, stars, flower, ring, vu, off
    var id: String { rawValue }

    /// A saved mode that no longer exists must not spoil the rest of the settings.
    init(from decoder: Decoder) throws {
        self = VizMode(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .bars
    }

    var name: String {
        switch self {
        case .bars: tr("Столбики")
        case .peaks: tr("Пики")
        case .mirror: tr("Зеркало")
        case .led: tr("Индикатор")
        case .dots: tr("Точки")
        case .area: tr("Спектр")
        case .ribbons: tr("Ленты")
        case .wave: tr("Осциллограф")
        case .scope: tr("Стереофигура")
        case .ridges: tr("Горы")
        case .flows: tr("Потоки")
        case .kaleido: tr("Калейдоскоп")
        case .tiles: tr("Мозаика")
        case .drop: tr("Капля")
        case .aurora: tr("Сияние")
        case .confetti: tr("Конфетти")
        case .sparks: tr("Искры")
        case .pulse: tr("Пульс")
        case .stars: tr("Звёзды")
        case .flower: tr("Лепестки")
        case .ring: tr("Круг")
        case .vu: tr("Стрелки L/R")
        case .off: tr("Выключено")
        }
    }

    /// Needs a taller strip on the main screen.
    var tall: Bool { [.vu, .scope, .ridges, .flows, .kaleido, .tiles, .drop, .aurora, .pulse, .flower].contains(self) }
    /// Takes the whole screen as the screensaver.
    var wholeScreen: Bool { [.flows, .kaleido, .tiles, .aurora, .sparks, .confetti, .pulse, .stars].contains(self) }
}

struct EQPreset: Identifiable {
    let id: String
    let name: String
    let bands: [Double]

    static let all: [EQPreset] = [
        EQPreset(id: "flat", name: "Ровно", bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        EQPreset(id: "bass", name: "Бас", bands: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]),
        EQPreset(id: "rock", name: "Рок", bands: [5, 4, 2, -1, -2, -1, 2, 3, 4, 4]),
        EQPreset(id: "pop", name: "Поп", bands: [-1, 1, 3, 4, 3, 0, -1, -1, 1, 2]),
        EQPreset(id: "vocal", name: "Вокал", bands: [-2, -2, -1, 1, 3, 4, 3, 1, 0, -1]),
        EQPreset(id: "jazz", name: "Джаз", bands: [3, 2, 1, 2, -1, -1, 0, 1, 2, 3]),
        EQPreset(id: "classic", name: "Классика", bands: [4, 3, 2, 1, -1, -1, 0, 2, 3, 4]),
        EQPreset(id: "electro", name: "Электроника", bands: [5, 4, 1, 0, -2, 1, 0, 1, 4, 5]),
        EQPreset(id: "treble", name: "Верха", bands: [0, 0, 0, 0, 0, 1, 3, 5, 6, 7]),
    ]
}

@MainActor
final class Settings: ObservableObject {
    struct Values: Codable, Equatable {
        var eqOn = true
        var bands: [Double] = Array(repeating: 0, count: 10)
        var preamp: Double = 0
        var bass: Double = 0
        var balance: Double = 0
        var limiter = true
        var normalize = false
        var crossfade: Double = 0
        var rate: Double = 1
        var keepPitch = true
        /// Up or down in semitones, the speed stays.
        var semitones: Double = 0
        var haptics = true
        /// Skip the silence at the start and the end of songs.
        var trimSilence = true
        var onlineArt = true
        /// Cover and lyrics of the song on the radio, from the internet.
        var radioExtras = false
        var themeMode = "system"
        var accent = "amber"
        var viz = VizMode.bars
        var vizPalette = VizColors.level
        var lyricsOn = false
        /// Look for the lyrics of every song that starts.
        var lyricsAuto = false
        /// The same sound in both ears.
        var mono = false
        var sort = "added"
        var gapless = true
        var matchRate = true
        var direct = false
        var refreshFolders = true
        var language = "system"
        /// Seconds of sound the radio collects before it plays.
        var radioBuffer: Double = 2
        var saverOn = true
        /// Seconds without touches before the screensaver.
        var saver = 10
        /// `.off` = the same as on the main screen.
        var saverViz = VizMode.off
        var saverAwake = false

        /// With direct output the song goes out untouched, whatever the other options say.
        var effectiveRate: Double { direct ? 1 : rate }
        var effectiveNormalize: Bool { normalize && !direct }
    }

    @Published var v: Values {
        didSet {
            guard v != oldValue else { return }
            if v.language != oldValue.language { Lang.apply(v.language) }
            Haptic.on = v.haptics
            Deck.trimSilence = v.trimSilence
            save()
            onChange?()
        }
    }

    static let radioBuffers: [Double] = [2, 5, 10, 20, 30]

    var onChange: (() -> Void)?
    private static let key = "settings"

    init() {
        // saved values are laid over the defaults, so new options can be added later
        v = Self.merged(UserDefaults.standard.data(forKey: Self.key)) ?? Values()
        Lang.apply(v.language)
        Haptic.on = v.haptics
        Deck.trimSilence = v.trimSilence
    }

    private static func merged(_ saved: Data?) -> Values? {
        var merged = dictionary(try? JSONEncoder().encode(Values()))
        for (k, x) in dictionary(saved) { merged[k] = x }
        guard let data = try? JSONSerialization.data(withJSONObject: merged),
              let decoded = try? JSONDecoder().decode(Values.self, from: data), decoded.bands.count == 10 else { return nil }
        return decoded
    }

    /// For the backup file.
    var exported: Data? { try? JSONEncoder().encode(v) }

    /// Settings from a backup, possibly of an older build: what it does not know keeps its default.
    func restore(_ data: Data) {
        guard let values = Self.merged(data) else { return }
        v = values
    }

    private static func dictionary(_ data: Data?) -> [String: Any] {
        guard let data else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    private func save() {
        if let data = try? JSONEncoder().encode(v) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    var accent: Color { (Accent.all.first { $0.id == v.accent } ?? Accent.all[0]).color }

    var colorScheme: ColorScheme? {
        switch v.themeMode {
        case "dark": .dark
        case "light": .light
        default: nil
        }
    }

    var preset: EQPreset? { EQPreset.all.first { $0.bands == v.bands } }

    /// Anything on the settings screen that changes the sound, for the mark under the icon.
    var fxActive: Bool { v.direct || v.bass != 0 || v.balance != 0 || v.mono || v.rate != 1 || v.semitones != 0 || v.normalize || v.crossfade > 0 }
    var eqActive: Bool { v.eqOn && !v.direct && preset?.id != "flat" }

    /// The next preset of the equaliser, from the widget and the Control Centre.
    func nextPreset() {
        let all = EQPreset.all, i = preset.flatMap { p in all.firstIndex { $0.id == p.id } } ?? 0
        v.bands = all[(i + 1) % all.count].bands
        v.eqOn = true
        toast(tr("Эквалайзер: ") + tr(all[(i + 1) % all.count].name))
    }

    /// What the widget writes under the buttons.
    var presetName: String {
        guard v.eqOn, !v.direct else { return tr("выключен") }
        return preset.map { tr($0.name) } ?? tr("Свой")
    }

    func cycleColors() {
        let all = VizColors.allCases, i = all.firstIndex(of: v.vizPalette) ?? 0
        v.vizPalette = all[(i + 1) % all.count]
        toast(tr("Цвета: ") + v.vizPalette.name)
    }

    func cycleViz() {
        let modes = VizMode.allCases.filter { $0 != .off }
        let i = modes.firstIndex(of: v.viz) ?? -1
        v.viz = modes[(i + 1) % modes.count]
        toast(tr("Визуализация: ") + v.viz.name)
    }
}
