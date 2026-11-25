import SwiftUI

enum VizMode: String, Codable, CaseIterable, Identifiable {
    case bars, peaks, mirror, led, dots, area, ribbons, wave, scope, ridges, falls, sparks, pulse, stars, flower, ring, vu, off
    var id: String { rawValue }
    var name: String {
        switch self {
        case .bars: "Столбики"
        case .peaks: "Пики"
        case .mirror: "Зеркало"
        case .led: "Индикатор"
        case .dots: "Точки"
        case .area: "Спектр"
        case .ribbons: "Ленты"
        case .wave: "Осциллограф"
        case .scope: "Стереофигура"
        case .ridges: "Горы"
        case .falls: "Водопад"
        case .sparks: "Искры"
        case .pulse: "Пульс"
        case .stars: "Звёзды"
        case .flower: "Лепестки"
        case .ring: "Круг"
        case .vu: "Стрелки L/R"
        case .off: "Выключено"
        }
    }

    /// Needs a taller strip on the main screen.
    var tall: Bool { [.vu, .scope, .ridges, .falls, .pulse, .flower].contains(self) }
    /// Takes the whole screen as the screensaver.
    var wholeScreen: Bool { [.falls, .sparks, .pulse, .stars].contains(self) }
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
        var onlineArt = true
        var themeMode = "system"
        var accent = "amber"
        var viz = VizMode.bars
        var vizPalette = VizColors.level
        var lyricsOn = false
        var sort = "added"
        var gapless = true
        var matchRate = true
        var direct = false
        var refreshFolders = true
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
            save()
            onChange?()
        }
    }

    var onChange: (() -> Void)?
    private static let key = "settings"

    init() {
        // saved values are laid over the defaults, so new options can be added later
        let base = Values()
        var merged = Self.dictionary(try? JSONEncoder().encode(base))
        for (k, x) in Self.dictionary(UserDefaults.standard.data(forKey: Self.key)) { merged[k] = x }
        if let data = try? JSONSerialization.data(withJSONObject: merged),
           let decoded = try? JSONDecoder().decode(Values.self, from: data), decoded.bands.count == 10 {
            v = decoded
        } else {
            v = base
        }
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
    var fxActive: Bool { v.direct || v.bass != 0 || v.balance != 0 || v.rate != 1 || v.normalize || v.crossfade > 0 }
    var eqActive: Bool { v.eqOn && !v.direct && preset?.id != "flat" }

    func cycleColors() {
        let all = VizColors.allCases, i = all.firstIndex(of: v.vizPalette) ?? 0
        v.vizPalette = all[(i + 1) % all.count]
        toast("Цвета: " + v.vizPalette.name)
    }

    func cycleViz() {
        let modes = VizMode.allCases.filter { $0 != .off }
        let i = modes.firstIndex(of: v.viz) ?? -1
        v.viz = modes[(i + 1) % modes.count]
        toast("Визуализация: " + v.viz.name)
    }
}
