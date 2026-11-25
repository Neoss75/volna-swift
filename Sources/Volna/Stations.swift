import Foundation
import SwiftUI
import UIKit

/// One radio station: a name and a link to its stream.
struct Station: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var url: String
    var logo: String?
    var group: String?
    var favourite: Bool?
    var facts: StationFacts?

    init(name: String, url: String, logo: String? = nil, group: String? = nil) {
        id = UUID()
        self.name = name
        self.url = url
        self.logo = logo
        self.group = group
    }

    var letter: String { name.first { $0.isLetter || $0.isNumber }.map { String($0).uppercased() } ?? "♪" }
    var host: String { URL(string: url)?.host() ?? url }
}

/// Reads .m3u, .m3u8 and .pls lists.
enum StationList {
    static let extensions: Set<String> = ["m3u", "m3u8", "pls"]

    static func isHLS(_ url: String) -> Bool { URL(string: url)?.pathExtension.lowercased() == "m3u8" }

    static func text(_ data: Data) -> String {
        let raw = data.starts(with: [0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data[...]
        if let s = String(data: raw, encoding: .utf8) { return s }
        // a few damaged letters do not make a long list Windows text
        let s = String(decoding: raw, as: UTF8.self)
        let broken = s.unicodeScalars.lazy.filter { $0 == "\u{FFFD}" }.count, foreign = s.unicodeScalars.lazy.filter { $0.value > 127 }.count
        if broken * 10 < foreign { return s.replacingOccurrences(of: "\u{FFFD}", with: "") }
        return String(data: raw, encoding: .windowsCP1251) ?? s
    }

    /// A list of pieces of one broadcast (HLS), not a list of stations.
    static func isStream(_ text: String) -> Bool { text.contains("#EXT-X-") }

    /// `skipped` counts the lines that are not links, such as names of files on a computer.
    static func parse(_ text: String) -> (stations: [Station], skipped: Int) {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return lines.first?.lowercased() == "[playlist]" ? pls(lines) : m3u(lines)
    }

    private static func m3u(_ lines: [String]) -> ([Station], Int) {
        var list: [Station] = [], skipped = 0
        var name = "", logo: String?, group: String?, groupLine: String?
        for l in lines {
            if l.hasPrefix("#") {
                if l.uppercased().hasPrefix("#EXTINF") {
                    (name, logo, group) = info(l)
                } else if l.uppercased().hasPrefix("#EXTGRP:") {
                    groupLine = tidy(String(l.dropFirst(8)))
                }
                continue
            }
            let url = link(l)
            if url == nil, !name.isEmpty, l.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\")) == nil, !isFileName(l) {
                name += " " + l // a name written on two lines
                continue
            }
            if let url {
                list.append(Station(name: name.isEmpty ? fallback(url) : name, url: url, logo: logo, group: group ?? groupLine))
            } else {
                skipped += 1
            }
            (name, logo, group, groupLine) = ("", nil, nil, nil)
        }
        return (list, skipped)
    }

    private static func isFileName(_ s: String) -> Bool {
        ["mp3", "m4a", "aac", "flac", "wav", "ogg", "opus", "wma", "mp4", "ts"].contains((s as NSString).pathExtension.lowercased())
    }

    /// #EXTINF:-1 tvg-logo="…" group-title="…",Name
    private static func info(_ line: String) -> (String, String?, String?) {
        var quoted = false, comma: String.Index?
        for i in line.indices {
            if line[i] == "\"" { quoted.toggle() }
            if line[i] == ",", !quoted {
                comma = i
                break
            }
        }
        let name = comma.flatMap { tidy(String(line[line.index(after: $0)...])) }
        let logo = attribute("tvg-logo", line) ?? attribute("logo", line)
        return (name ?? "", logo.flatMap(link), attribute("group-title", line))
    }

    private static func attribute(_ key: String, _ line: String) -> String? {
        guard let a = line.range(of: key + "=\"", options: .caseInsensitive),
              let b = line.range(of: "\"", range: a.upperBound..<line.endIndex) else { return nil }
        return tidy(String(line[a.upperBound..<b.lowerBound]))
    }

    private static func tidy(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }

    private static func pls(_ lines: [String]) -> ([Station], Int) {
        var urls: [Int: String] = [:], names: [Int: String] = [:], skipped = 0
        for l in lines {
            guard let eq = l.firstIndex(of: "=") else { continue }
            let key = l[..<eq].lowercased().trimmingCharacters(in: .whitespaces), value = String(l[l.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if key.hasPrefix("file"), let n = Int(key.dropFirst(4)) {
                if let url = link(value) { urls[n] = url } else { skipped += 1 }
            } else if key.hasPrefix("title"), let n = Int(key.dropFirst(5)) {
                names[n] = value
            }
        }
        return (urls.keys.sorted().map { n in
            let url = urls[n] ?? ""
            return Station(name: names[n].flatMap(tidy) ?? fallback(url), url: url)
        }, skipped)
    }

    /// Only links to the internet; "icy://" is the same as "http://".
    static func link(_ s: String) -> String? {
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.lowercased().hasPrefix("icy://") { t = "http://" + t.dropFirst(6) }
        guard t.lowercased().hasPrefix("http://") || t.lowercased().hasPrefix("https://"), let u = URL(string: t), u.host()?.isEmpty == false else { return nil }
        return t
    }

    static func fallback(_ url: String) -> String {
        guard let u = URL(string: url) else { return url }
        let last = u.deletingPathExtension().lastPathComponent
        return last.count > 2 && last != "stream" && last != "live" ? last.replacingOccurrences(of: "_", with: " ") : (u.host() ?? url)
    }
}

/// What stands behind a link the user typed in.
enum StationLink {
    enum Found { case list(String), stream(name: String?), failure(String) }

    static func inspect(_ url: URL) async -> Found {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("1", forHTTPHeaderField: "Icy-MetaData")
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            defer { bytes.task.cancel() }
            let http = response as? HTTPURLResponse
            if let code = http?.statusCode, !(200..<300).contains(code) { return .failure(StreamError.status(code).text) }
            let type = (http?.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
            if StreamKind.of(type: type, url: url) == .list {
                var data = Data()
                for try await b in bytes {
                    data.append(b)
                    if data.count > 2_000_000 { break }
                }
                let text = StationList.text(data)
                return StationList.isStream(text) ? .stream(name: nil) : .list(text)
            }
            if StreamKind.of(type: type, url: url) == .page { return .failure(StreamError.notRadio.text) }
            return .stream(name: http?.value(forHTTPHeaderField: "icy-name").map(StreamReader.repair))
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}

/// Asks many stations whether they answer, several at a time. Only the beginning of an answer is taken.
enum StationProbe {
    static let atOnce = 24
    static let patience = 6.0

    static func session() -> URLSession {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = patience
        c.timeoutIntervalForResource = patience * 2
        c.httpMaximumConnectionsPerHost = 4
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: c)
    }

    struct Answer: Sendable {
        var id: UUID
        /// nil = it plays.
        var error: StreamError?
        var facts: StationFacts?
    }

    static func ask(_ s: Station, _ session: URLSession) async -> Answer {
        var a = Answer(id: s.id)
        a.error = await ask(s.url, session, &a.facts)
        return a
    }

    private static func ask(_ link: String, _ session: URLSession, _ facts: inout StationFacts?) async -> StreamError? {
        guard let url = URL(string: link) else { return .notRadio }
        var request = URLRequest(url: url)
        request.setValue("1", forHTTPHeaderField: "Icy-MetaData")
        do {
            let (bytes, response) = try await session.bytes(for: request)
            defer { bytes.task.cancel() }
            let http = response as? HTTPURLResponse
            if let code = http?.statusCode, !(200..<300).contains(code) { return .status(code) }
            switch StreamKind.of(type: (http?.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased(), url: response.url ?? url) {
            case .audio:
                // the names of songs are mixed into the sound after the first `metaint` bytes
                let meta = http?.value(forHTTPHeaderField: "icy-metaint").flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
                let limit = meta > 1000 ? min(meta, 16000) : 16000
                var data = Data()
                data.reserveCapacity(limit)
                do {
                    for try await b in bytes {
                        data.append(b)
                        if data.count >= limit { break }
                    }
                } catch {} // what has come is enough
                facts = StationFacts.look(data)
                return nil
            case .ogg: return .ogg
            case .video: return .video
            case .page: return .notRadio
            case .list:
                var data = Data()
                for try await b in bytes {
                    data.append(b)
                    if data.count > 50000 { break }
                }
                let text = StationList.text(data)
                if StationList.isStream(text) {
                    var list = HLSPlaylist(text), base = response.url ?? url
                    if list.segments.isEmpty, let u = list.best.flatMap({ URL(string: $0, relativeTo: base) }) {
                        let (d, r) = try await session.data(from: u)
                        if let code = (r as? HTTPURLResponse)?.statusCode, !(200..<300).contains(code) { return .status(code) }
                        list = HLSPlaylist(StationList.text(d))
                        base = r.url ?? u
                    }
                    if list.unsupported { return .hls }
                    facts = StationFacts(kind: "HLS", kbps: nil, total: await weight(list, base, session), rate: nil)
                    return nil
                }
                return StationList.parse(text).stations.isEmpty ? .notRadio : nil
            }
        } catch {
            return .network(tr("не отвечает"))
        }
    }

    /// The size of one piece is known before it is downloaded.
    private static func weight(_ list: HLSPlaylist, _ base: URL, _ session: URLSession) async -> Double? {
        guard let s = list.segments.last, s.seconds > 0.5, let u = URL(string: s.uri, relativeTo: base),
              let (bytes, r) = try? await session.bytes(from: u) else { return nil }
        bytes.task.cancel()
        guard (r as? HTTPURLResponse)?.statusCode == 200, r.expectedContentLength > 1000 else { return nil }
        return (Double(r.expectedContentLength) * 8 / s.seconds / 1000).rounded()
    }
}

/// The user's stations, in the order they were added.
@MainActor
final class Stations: ObservableObject {
    @Published private(set) var all: [Station] = [] { didSet { index = nil } }
    private var index: [UUID: Station]?
    @Published private(set) var loading = false
    /// Stations that did not open the last time, and why.
    @Published var problems: [UUID: String] = [:]
    var onChange: (() -> Void)?

    struct Check: Equatable {
        var total = 0
        var done = 0
        /// Does not answer, or there is no radio at the link.
        var dead: Set<UUID> = []
        /// Answers, but cannot be played here.
        var unsupported = 0
        var running = true
        var alive: Int { done - dead.count - unsupported }
    }

    @Published var check: Check?
    private var checking: Task<Void, Never>?

    private let file: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        file = dir.appendingPathComponent("stations.json")
        if let data = try? Data(contentsOf: file), let list = try? JSONDecoder().decode([Station].self, from: data) { all = list }
    }

    /// Lists of thousands of stations are usual.
    func station(_ id: UUID?) -> Station? {
        guard let id else { return nil }
        if index == nil { index = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }
        return index?[id]
    }

    /// The way they are shown: favourites first, then the groups.
    var sections: [(title: String?, stations: [Station])] {
        var out: [(title: String?, stations: [Station])] = []
        let fav = all.filter { $0.favourite == true }, rest = all.filter { $0.favourite != true }
        if !fav.isEmpty { out.append((title: tr("Избранное"), stations: fav)) }
        var order: [String] = [], byGroup: [String: [Station]] = [:]
        for s in rest {
            let g = s.group ?? ""
            if byGroup[g] == nil { order.append(g) }
            byGroup[g, default: []].append(s)
        }
        let onlyOne = out.isEmpty && order.count == 1
        for g in order {
            let title: String? = !g.isEmpty ? g : onlyOne ? nil : tr("Станции")
            out.append((title: title, stations: byGroup[g] ?? []))
        }
        return out
    }

    var ordered: [Station] { sections.flatMap(\.stations) }

    /// Returns how many were new.
    @discardableResult
    func add(_ list: [Station]) -> Int {
        var known = Set(all.map(\.url)), added = 0
        for s in list where known.insert(s.url).inserted {
            all.append(s)
            added += 1
        }
        if added > 0 { save() }
        return added
    }

    func add(text: String, name: String? = nil) {
        if StationList.isStream(text) { return toast(tr("Это поток HLS, а не список станций")) }
        let found = StationList.parse(text)
        guard !found.stations.isEmpty else { return toast(tr("В этом списке нет ссылок на станции")) }
        var list = found.stations
        if list.count == 1, let name, !name.isEmpty { list[0].name = name }
        let added = add(list)
        var parts = [tr("Добавлено станций: {}", "\(added)")]
        if list.count > added { parts.append(tr("уже в списке: {}", "\(list.count - added)")) }
        if found.skipped > 0 { parts.append(tr("пропущено строк: {}", "\(found.skipped)")) }
        toast(parts.joined(separator: ", "))
    }

    func add(files: [URL]) {
        for url in files {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), data.count < 20_000_000 else {
                toast(tr("не удалось открыть файл"))
                continue
            }
            add(text: StationList.text(data))
        }
    }

    /// A link to a stream or to a whole list. Returns false when it could not be opened.
    func add(link: String, name: String) async -> Bool {
        let t = link.trimmingCharacters(in: .whitespaces)
        guard let s = StationList.link(t.contains("://") ? t : "https://" + t), let url = URL(string: s) else {
            toast(tr("Это не похоже на ссылку"))
            return false
        }
        loading = true
        defer { loading = false }
        switch await StationLink.inspect(url) {
        case .list(let text):
            add(text: text, name: name)
            return true
        case .stream(let found):
            let n = !name.isEmpty ? name : found.flatMap { $0.isEmpty ? nil : $0 } ?? StationList.fallback(s)
            toast(add([Station(name: n, url: s)]) > 0 ? tr("Станция «{}» добавлена", "\(n)") : tr("Эта станция уже есть"))
            return true
        case .failure(let why):
            toast(tr("Не удалось открыть ссылку: {}", "\(why)"))
            return false
        }
    }

    // MARK: - Checking

    func startCheck(_ list: [Station]) {
        checking?.cancel()
        check = Check(total: list.count)
        UIApplication.shared.isIdleTimerDisabled = true // asleep, the phone would call every station dead
        checking = Task { [weak self] in
            let session = StationProbe.session()
            await withTaskGroup(of: StationProbe.Answer.self) { group in
                var rest = list.makeIterator()
                for _ in 0..<StationProbe.atOnce {
                    if let s = rest.next() { group.addTask { await StationProbe.ask(s, session) } }
                }
                // shown in portions: thousands of redraws would slow the list down
                var fresh: [StationProbe.Answer] = [], shown = Date()
                while let answer = await group.next() {
                    if Task.isCancelled { break }
                    fresh.append(answer)
                    if Date().timeIntervalSince(shown) > 0.5 {
                        self?.take(fresh)
                        fresh = []
                        shown = Date()
                    }
                    if let s = rest.next() { group.addTask { await StationProbe.ask(s, session) } }
                }
                if !Task.isCancelled { self?.take(fresh) }
                group.cancelAll()
            }
            session.invalidateAndCancel()
            if !Task.isCancelled { self?.endCheck() }
        }
    }

    private func take(_ answers: [StationProbe.Answer]) {
        guard var c = check else { return }
        var p = problems, learnt: [UUID: StationFacts] = [:]
        for a in answers {
            c.done += 1
            p[a.id] = a.error?.text
            if let f = a.facts { learnt[a.id] = f }
            switch a.error {
            case nil: break
            case .hls?, .ogg?, .video?, .format?: c.unsupported += 1
            default: c.dead.insert(a.id)
            }
        }
        problems = p
        if !learnt.isEmpty {
            all = all.map { s in
                guard let f = learnt[s.id] else { return s }
                var s = s
                s.facts = f.over(s.facts, rough: true)
                return s
            }
        }
        check = c
    }

    /// Keeps what is known so far.
    func endCheck() {
        checking?.cancel()
        checking = nil
        UIApplication.shared.isIdleTimerDisabled = false
        check?.running = false
        if check?.done == 0 { check = nil } else { save() }
    }

    /// Favourites stay even when they do not answer.
    var removable: Set<UUID> {
        guard let c = check, c.alive > 0 else { return [] }
        return c.dead.filter { station($0).map { $0.favourite != true } ?? false }
    }

    func removeDead() {
        let gone = removable
        remove(gone)
        check = nil
        toast(tr("Убрано станций: {}", "\(gone.count)"))
    }

    /// What was found out while the station plays.
    func learn(_ id: UUID, _ f: StationFacts) {
        if problems[id] != nil { problems[id] = nil }
        guard let s = station(id), !f.kind.isEmpty else { return }
        let new = f.over(s.facts)
        if new != s.facts { change(id) { $0.facts = new } }
    }

    func toggleFavourite(_ id: UUID) { change(id) { $0.favourite = $0.favourite == true ? nil : true } }

    func edit(_ id: UUID, name: String, url: String) {
        change(id) {
            $0.name = name
            if $0.url != url { $0.facts = nil }
            $0.url = url
        }
        problems[id] = nil
    }

    private func change(_ id: UUID, _ body: (inout Station) -> Void) {
        guard let i = all.firstIndex(where: { $0.id == id }) else { return }
        body(&all[i])
        save()
    }

    func remove(_ ids: Set<UUID>) {
        all.removeAll { ids.contains($0.id) }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(all) { try? data.write(to: file, options: .atomic) }
        onChange?()
    }
}

/// Pictures of the stations: downloaded once, kept in the cache folder.
@MainActor
final class Logos: ObservableObject {
    static let shared = Logos()
    @Published private var images: [String: UIImage] = [:]
    private var tried: Set<String> = []

    func image(_ s: Station?) -> UIImage? {
        guard let link = s?.logo else { return nil }
        if let i = images[link] { return i }
        if tried.insert(link).inserted { Task { await load(link) } }
        return nil
    }

    private func load(_ link: String) async {
        guard let url = URL(string: link) else { return }
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("logos")
        var hash: UInt64 = 5381
        for b in link.utf8 { hash = hash &* 33 &+ UInt64(b) }
        let file = dir.appendingPathComponent(String(hash, radix: 16))
        var data = try? Data(contentsOf: file)
        if data == nil {
            guard let (d, r) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 15)),
                  (r as? HTTPURLResponse)?.statusCode == 200, d.count < 3_000_000 else { return }
            data = d
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? d.write(to: file)
        }
        guard let data, let full = UIImage(data: data), min(full.size.width, full.size.height) >= 40 else { return } // tiny site icons look bad
        images[link] = await full.byPreparingThumbnail(ofSize: Self.fit(full.size)) ?? full
        onChange?()
    }

    var onChange: (() -> Void)?

    private static func fit(_ s: CGSize) -> CGSize {
        let k = min(1, 600 / max(s.width, s.height, 1))
        return CGSize(width: max(1, s.width * k), height: max(1, s.height * k))
    }
}

/// The picture of a station on a coloured ground, or its first letter.
struct StationLogo: View {
    @ObservedObject private var logos = Logos.shared
    let station: Station
    var corner: CGFloat = 10
    var letter: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let i = logos.image(station) {
                    Color.white
                    Image(uiImage: i).resizable().scaledToFit().padding(geo.size.width * 0.06)
                } else {
                    let h = hue(station.name)
                    LinearGradient(colors: [Color(h: h, s: 0.55, l: 0.5), Color(h: h + 55, s: 0.6, l: 0.26)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(station.letter).font(.display(letter, .semibold)).foregroundStyle(.white)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}
