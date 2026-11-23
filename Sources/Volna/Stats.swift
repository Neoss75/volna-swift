import Foundation

/// Listening statistics; kept only on the phone.
@MainActor
final class Stats: ObservableObject {
    struct Entry: Codable {
        var plays = 0
        var seconds: Double = 0
        var title = ""
        var artist = ""
        var last: Date? // optional: entries saved by older builds do not have it
    }

    struct Data: Codable {
        var songs: [String: Entry] = [:]
        var days: [String: Double] = [:]
        var total: Double = 0
    }

    @Published private(set) var data = Data()
    private var pending = Data()
    private var lastTick: Date?
    private var listened: Double = 0
    private var counted = false
    private var lastFlush = Date()

    init() {
        if let raw = UserDefaults.standard.data(forKey: "stats"), let d = try? JSONDecoder().decode(Data.self, from: raw) { data = d }
        pending = data
    }

    static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func trackStarted() {
        listened = 0
        counted = false
        lastTick = nil
    }

    func tick(_ t: Track) {
        let now = Date()
        defer { lastTick = now }
        guard let last = lastTick else { return }
        let dt = min(2, now.timeIntervalSince(last))
        var e = pending.songs[t.id.uuidString] ?? Entry()
        e.title = t.title
        e.artist = t.artist
        e.seconds += dt
        e.last = now
        pending.total += dt
        pending.days[Self.dayKey(), default: 0] += dt
        listened += dt
        if !counted, listened >= min(30, (t.duration > 0 ? t.duration : 60) * 0.5) {
            counted = true
            e.plays += 1
        }
        pending.songs[t.id.uuidString] = e
        if now.timeIntervalSince(lastFlush) > 10 { flush(keepTicking: true) }
    }

    func flush(keepTicking: Bool = false) {
        lastFlush = Date()
        if !keepTicking { lastTick = nil }
        for key in pending.days.keys.sorted().dropLast(90) { pending.days[key] = nil }
        data = pending
        if let raw = try? JSONEncoder().encode(data) { UserDefaults.standard.set(raw, forKey: "stats") }
    }

    func reset() {
        pending = Data()
        flush()
        toast("Статистика сброшена")
    }

    func entry(_ id: UUID) -> Entry? { data.songs[id.uuidString] }

    var plays: Int { data.songs.values.reduce(0) { $0 + $1.plays } }
    var today: Double { data.days[Self.dayKey()] ?? 0 }

    var summary: String {
        if data.total < 1 { return "Пока ничего не прослушано. Статистика копится сама, пока играет музыка." }
        return "Всего \(formatSpan(data.total)) · \(plural(plays, "прослушивание", "прослушивания", "прослушиваний")) · сегодня \(formatSpan(today))"
    }

    var topSongs: [Entry] {
        Array(data.songs.values.filter { $0.plays > 0 || $0.seconds >= 10 }
            .sorted { $0.plays != $1.plays ? $0.plays > $1.plays : $0.seconds > $1.seconds }.prefix(10))
    }

    var topArtists: [(name: String, seconds: Double)] {
        var sums: [String: Double] = [:]
        for e in data.songs.values { sums[e.artist.isEmpty ? "Неизвестный исполнитель" : e.artist, default: 0] += e.seconds }
        return Array(sums.map { (name: $0.key, seconds: $0.value) }.sorted { $0.seconds > $1.seconds }.prefix(5))
    }

    /// Last 7 days, oldest first.
    var week: [(date: Date, minutes: Double)] {
        (0..<7).reversed().compactMap { back in
            guard let d = Calendar.current.date(byAdding: .day, value: -back, to: Date()) else { return nil }
            return (date: d, minutes: (data.days[Self.dayKey(d)] ?? 0) / 60)
        }
    }
}
