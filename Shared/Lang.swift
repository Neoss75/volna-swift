import Foundation

/// The language of the texts. Can be changed in the settings while the app runs.
enum Lang: String, CaseIterable {
    case ru, uk, en

    static var current = system

    /// Also follows Settings → Volna → Language of the iPhone.
    static var system: Lang {
        for code in Locale.preferredLanguages {
            if let l = Lang.allCases.first(where: { code.hasPrefix($0.rawValue) }) { return l }
        }
        return .en
    }

    /// "system" or the code of a language.
    static func apply(_ code: String) { current = Lang(rawValue: code) ?? system }

    var name: String {
        switch self {
        case .ru: "Русский"
        case .uk: "Українська"
        case .en: "English"
        }
    }

    var locale: Locale {
        switch self {
        case .ru: Locale(identifier: "ru_RU")
        case .uk: Locale(identifier: "uk_UA")
        case .en: Locale(identifier: "en_GB")
        }
    }
}

extension Translations {
    static let table: [String: [String]] = {
        var t: [String: [String]] = [:]
        for line in text.split(separator: "\n") {
            let p = line.components(separatedBy: "‖")
            guard p.count == 3 else { continue }
            // a space at the end is taken from the Russian text: editors like to cut it off
            t[p[0]] = p[1...].map { p[0].hasSuffix(" ") && !$0.hasSuffix(" ") ? $0 + " " : $0 }
        }
        return t
    }()
}

/// The text in the current language; the Russian text is the key. Every {} is replaced by the next value.
func tr(_ key: String, _ values: String...) -> String {
    let s: String
    switch Lang.current {
    case .ru: s = key.contains("#") ? String(key.prefix { $0 != "#" }) : key
    case .uk: s = Translations.table[key]?[0] ?? key
    case .en: s = Translations.table[key]?[1] ?? key
    }
    guard !values.isEmpty else { return s }
    let parts = s.components(separatedBy: "{}")
    var out = parts[0]
    for (i, p) in parts.dropFirst().enumerated() {
        out += (i < values.count ? values[i] : "") + p
    }
    return out
}
