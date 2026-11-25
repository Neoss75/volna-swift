import AVFoundation
import Foundation

/// One filter of a parametric equaliser.
struct EQFilter: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable { case low, peak, high }

    var kind = Kind.peak
    var hz = 1000.0
    var db = 0.0
    var q = 1.0

    /// What the filter does at frequency `f`, in dB (the usual "cookbook" formulas).
    func response(_ f: Double, rate: Double = 48000) -> Double {
        if db == 0 { return 0 }
        let w0 = 2 * .pi * min(hz, rate * 0.49) / rate, A = pow(10, db / 40), c = cos(w0), al = sin(w0) / (2 * max(q, 0.05)), w = 2 * .pi * f / rate
        switch kind {
        case .peak:
            return Self.magnitude([1 + al * A, -2 * c, 1 - al * A], [1 + al / A, -2 * c, 1 - al / A], w)
        case .low, .high:
            let k: Double = kind == .low ? 1 : -1, cc = k * c, s = 2 * A.squareRoot() * al
            let b = [A * ((A + 1) - (A - 1) * cc + s), k * 2 * A * ((A - 1) - (A + 1) * cc), A * ((A + 1) - (A - 1) * cc - s)]
            let a = [(A + 1) + (A - 1) * cc + s, k * -2 * ((A - 1) + (A + 1) * cc), (A + 1) + (A - 1) * cc - s]
            return Self.magnitude(b, a, w)
        }
    }

    private static func magnitude(_ b: [Double], _ a: [Double], _ w: Double) -> Double {
        func part(_ c: [Double]) -> Double {
            let re = c[0] + c[1] * cos(w) + c[2] * cos(2 * w), im = c[1] * sin(w) + c[2] * sin(2 * w)
            return re * re + im * im
        }
        return 10 * log10(max(part(b), 1e-12) / max(part(a), 1e-12))
    }
}

/// A correction for one model of headphones.
struct HeadphoneProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    /// Who measured it; empty for a profile made by hand.
    var source = ""
    var preamp = 0.0
    var filters: [EQFilter] = []

    static let maxFilters = 20

    func response(_ f: Double) -> Double { preamp + filters.reduce(0) { $0 + $1.response(f) } }

    /// The loudest point: more than 0 dB may distort.
    var peak: Double { (0..<120).map { response(20 * pow(1000, Double($0) / 119)) }.max() ?? 0 }

    /// A text of AutoEq or Equalizer APO: "Filter 1: ON PK Fc 931 Hz Gain -1.8 dB Q 0.18".
    init?(text: String, name: String) {
        self.name = name
        for line in text.components(separatedBy: .newlines) {
            let w = line.replacingOccurrences(of: ",", with: ".").split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            func after(_ key: String) -> Double? {
                guard let i = w.firstIndex(where: { $0.caseInsensitiveCompare(key) == .orderedSame }), i + 1 < w.count else { return nil }
                return Double(w[i + 1])
            }
            if w.first?.lowercased().hasPrefix("preamp") == true {
                preamp = after("Preamp:") ?? 0
            } else if w.first?.lowercased().hasPrefix("filter") == true, w.contains("ON"), let hz = after("Fc"), let db = after("Gain"), filters.count < Self.maxFilters {
                let kind: EQFilter.Kind? = w.contains("PK") || w.contains("PEQ") ? .peak : w.contains("LSC") || w.contains("LS") ? .low
                    : w.contains("HSC") || w.contains("HS") ? .high : nil
                if let kind, hz > 0 { filters.append(EQFilter(kind: kind, hz: hz, db: db, q: after("Q") ?? 0.7)) }
            }
        }
        if filters.isEmpty { return nil }
    }

    init(name: String, source: String = "", preamp: Double = 0, filters: [EQFilter] = []) {
        self.name = name
        self.source = source
        self.preamp = preamp
        self.filters = filters
    }
}

/// Measurements of thousands of models, made by the AutoEq project (MIT licence), inside the app.
enum HeadphoneBase {
    struct Model: Identifiable, Equatable {
        let id: Int
        let name: String
        let source: String
        fileprivate let words: String
        fileprivate let data: Substring
        fileprivate let preamp: Double

        var profile: HeadphoneProfile {
            let filters = data.split(separator: ";").compactMap { f -> EQFilter? in
                let n = f.dropFirst().split(separator: ",").compactMap { Double($0) }
                guard n.count == 3, let k = f.first else { return nil }
                return EQFilter(kind: k == "L" ? .low : k == "H" ? .high : .peak, hz: n[0], db: n[1], q: n[2])
            }
            return HeadphoneProfile(name: name, source: source, preamp: preamp, filters: filters)
        }
    }

    static let all: [Model] = {
        guard let url = Bundle.main.url(forResource: "headphones", withExtension: "txt"), let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").enumerated().compactMap { i, line in
            let p = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard p.count == 4 else { return nil }
            return Model(id: i, name: String(p[0]), source: String(p[1]), words: plain(String(p[0])), data: p[3], preamp: Double(p[2]) ?? 0)
        }
    }()

    static func plain(_ s: String) -> String {
        s.lowercased().folding(options: .diacriticInsensitive, locale: nil)
            .map { $0.isLetter || $0.isNumber ? String($0) : " " }.joined()
            .split(separator: " ").joined(separator: " ")
    }

    /// Every word of the query has to be there; the shortest names first.
    static func search(_ query: String, limit: Int = 40) -> [Model] {
        let words = plain(query).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        return Array(all.filter { m in words.allSatisfy { m.words.contains($0) } }
            .sorted { ($0.name.count, $0.name) < ($1.name.count, $1.name) }.prefix(limit))
    }

    /// Models that may be the connected device: its own name without what is in brackets, such as the owner's.
    static func guess(_ device: String, limit: Int = 4) -> [Model] {
        var name = device
        while let a = name.firstIndex(of: "("), let b = name[a...].firstIndex(of: ")") { name.removeSubrange(a...b) }
        let words = plain(name)
        // "AirPods Pro" of somebody: the name may stand before or after the model
        for key in [words, words.components(separatedBy: " ").suffix(2).joined(separator: " ")] where key.count > 4 {
            let found = search(key, limit: limit)
            if !found.isEmpty { return found }
        }
        if words.contains("airpods") { return search("airpods", limit: limit) }
        return []
    }
}

/// Which correction each device has; switched by itself when another device is connected.
@MainActor
final class Headphones: ObservableObject {
    struct Device: Codable, Identifiable, Equatable {
        /// Bluetooth headphones and USB devices have their own mark, the rest is told by the kind of the output.
        var id: String
        var name: String
        var port: String
        var profile: UUID?
        var last = Date()
    }

    struct Saved: Codable {
        var on = true
        var profiles: [HeadphoneProfile] = []
        var devices: [Device] = []
    }

    @Published private(set) var data = Saved()
    @Published private(set) var current = Device(id: "Speaker", name: "", port: AVAudioSession.Port.builtInSpeaker.rawValue)
    var onChange: (() -> Void)?

    private let file: URL
    private var observer: NSObjectProtocol?
    private var saving: Task<Void, Never>?

    #if DEBUG
        static var fake: (port: AVAudioSession.Port, name: String, uid: String)?
    #endif

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        file = dir.appendingPathComponent("headphones.json")
        if let d = try? Data(contentsOf: file), let s = try? JSONDecoder().decode(Saved.self, from: d) { data = s }
        observer = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.look() }
        }
        look()
    }

    var on: Bool { data.on }
    func profile(_ id: UUID?) -> HeadphoneProfile? { id.flatMap { id in data.profiles.first { $0.id == id } } }
    var chosen: HeadphoneProfile? { profile(current.profile) }
    /// What is heard now.
    var active: HeadphoneProfile? { data.on ? chosen : nil }

    /// What is the sound going to?
    func look() {
        var port = AVAudioSession.sharedInstance().currentRoute.outputs.first.map { (port: $0.portType, name: $0.portName, uid: $0.uid) }
        #if DEBUG
            if let fake = Self.fake { port = fake }
        #endif
        guard let port else { return }
        let own: Set<AVAudioSession.Port> = [.bluetoothA2DP, .bluetoothLE, .bluetoothHFP, .usbAudio]
        // the same headphones have other marks for music and for calls
        let mark = port.uid.replacingOccurrences(of: "-tacl", with: "").replacingOccurrences(of: "-tsco", with: "")
        let id = own.contains(port.port) && !port.uid.isEmpty ? mark : port.port.rawValue
        var d = data.devices.first { $0.id == id } ?? Device(id: id, name: port.name, port: port.port.rawValue)
        d.name = port.name
        d.last = Date()
        guard d.id != current.id || d.name != current.name || d.profile != current.profile else { return }
        current = d
        if own.contains(port.port) || d.profile != nil { remember(d) }
        onChange?()
    }

    private func remember(_ d: Device) {
        if let i = data.devices.firstIndex(where: { $0.id == d.id }) { data.devices[i] = d } else { data.devices.append(d) }
        save()
    }

    func turn(_ on: Bool) {
        data.on = on
        save()
        onChange?()
    }

    func assign(_ profile: UUID?, to device: String) {
        var d = device == current.id ? current : data.devices.first { $0.id == device }
        d?.profile = profile
        guard let d else { return }
        remember(d)
        if device == current.id { current = d }
        if profile != nil, device == current.id { data.on = true }
        save()
        onChange?()
    }

    /// A model taken twice is not kept twice.
    @discardableResult
    func add(_ p: HeadphoneProfile) -> UUID {
        if !p.source.isEmpty, let old = data.profiles.first(where: { $0.name == p.name && $0.source == p.source }) { return old.id }
        data.profiles.append(p)
        save()
        return p.id
    }

    func update(_ p: HeadphoneProfile) {
        guard let i = data.profiles.firstIndex(where: { $0.id == p.id }), data.profiles[i] != p else { return }
        data.profiles[i] = p
        save()
        if active?.id == p.id { onChange?() }
    }

    func remove(_ id: UUID) {
        data.profiles.removeAll { $0.id == id }
        for i in data.devices.indices where data.devices[i].profile == id { data.devices[i].profile = nil }
        if current.profile == id { current.profile = nil }
        save()
        onChange?()
    }

    func forget(_ device: String) {
        data.devices.removeAll { $0.id == device }
        if current.id == device { current.profile = nil }
        save()
        onChange?()
    }

    func add(file url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        var name = url.deletingPathExtension().lastPathComponent
        if name.lowercased().hasSuffix(" parametriceq") { name = String(name.dropLast(13)) }
        guard let d = try? Data(contentsOf: url), d.count < 200_000, let p = HeadphoneProfile(text: StationList.text(d), name: name) else {
            return toast(tr("В этом файле нет фильтров. Подходит файл ParametricEQ из AutoEq."))
        }
        assign(add(p), to: current.id)
        toast(tr("Профиль «{}» добавлен", "\(name)"))
    }

    /// The sliders change the profile many times a second.
    private func save() {
        saving?.cancel()
        saving = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            if !Task.isCancelled { self?.write() }
        }
    }

    func write() {
        if let d = try? JSONEncoder().encode(data) { try? d.write(to: file, options: .atomic) }
    }
}

extension AVAudioUnitEQ {
    /// Puts the filters of a profile into the bands.
    func load(_ p: HeadphoneProfile?) {
        globalGain = Float(min(24, max(-60, p?.preamp ?? 0)))
        for (i, b) in bands.enumerated() {
            guard let p, i < p.filters.count else {
                b.bypass = true
                continue
            }
            let f = p.filters[i]
            switch f.kind {
            case .peak:
                b.filterType = .parametric
                b.bandwidth = Float(min(5, max(0.05, 2 * asinh(1 / (2 * max(f.q, 0.05))) / log(2))))
            case .low: b.filterType = .lowShelf
            case .high: b.filterType = .highShelf
            }
            b.frequency = Float(min(20000, max(20, f.hz)))
            b.gain = Float(min(24, max(-24, f.db)))
            b.bypass = false
        }
    }
}
