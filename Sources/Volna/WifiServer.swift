import Foundation
import Network

/// A tiny web server: a browser on the same Wi-Fi gets a page and sends songs with PUT, one file per request.
final class WifiServer: @unchecked Sendable {
    enum Event: Sendable {
        case progress(name: String, done: Int64, total: Int64)
        case received(String)
        /// The same file is on the phone already.
        case skipped(String)
        case failed(name: String, reason: String)
        /// The listener stopped by itself, for example after the app was asleep.
        case stopped
    }

    static let allowed: Set<String> = Library.audioExtensions.union(["lrc", "cue"])

    let folder: URL
    let page: String
    let onEvent: @Sendable (Event) -> Void
    fileprivate let queue = DispatchQueue(label: "volna.wifi")
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: Connection] = [:]

    init(folder: URL, page: String, onEvent: @escaping @Sendable (Event) -> Void) {
        self.folder = folder
        self.page = page
        self.onEvent = onEvent
    }

    /// The first free port from 8080 on.
    func start() async -> UInt16? {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for p in UInt16(8080)...8099 {
            if await listen(p) { return p }
        }
        return nil
    }

    private func listen(_ number: UInt16) async -> Bool {
        guard let port = NWEndpoint.Port(rawValue: number), let l = try? NWListener(using: .tcp, on: port) else { return false }
        l.newConnectionHandler = { [weak self] c in self?.accept(c) }
        final class Once: @unchecked Sendable { var done = false }
        let once = Once()
        return await withCheckedContinuation { (k: CheckedContinuation<Bool, Never>) in
            l.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    guard !once.done else { return }
                    once.done = true
                    self?.listener = l
                    k.resume(returning: true)
                case .failed, .waiting:
                    l.cancel()
                    if once.done { self?.onEvent(.stopped) } else {
                        once.done = true
                        k.resume(returning: false)
                    }
                default:
                    break
                }
            }
            l.start(queue: queue)
        }
    }

    func stop() {
        queue.async {
            self.listener?.stateUpdateHandler = nil
            self.listener?.cancel()
            self.listener = nil
            for c in self.connections.values { c.close() }
            self.connections = [:]
        }
    }

    private func accept(_ c: NWConnection) {
        let conn = Connection(c, server: self)
        connections[ObjectIdentifier(conn)] = conn
        conn.start()
    }

    fileprivate func closed(_ conn: Connection) {
        connections[ObjectIdentifier(conn)] = nil
    }

    /// A safe place inside the folder: no "..", no hidden names, the same letters as iOS writes them.
    static func clean(_ raw: String) -> String? {
        let parts = raw.precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .map { String($0.trimmingCharacters(in: .whitespaces).drop { $0 == "." }).replacingOccurrences(of: ":", with: "-") }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty, parts.count <= 8, parts.allSatisfy({ $0.utf8.count < 240 }) else { return nil }
        return parts.joined(separator: "/")
    }

    /// What is in the folder already, oldest first.
    func list() -> [[String: Any]] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        guard let e = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [] }
        let base = folder.resolvingSymlinksInPath().path + "/"
        var out: [(String, Int, Date)] = []
        while let u = e.nextObject() as? URL {
            guard let v = try? u.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
            let p = u.resolvingSymlinksInPath().path
            guard p.hasPrefix(base) else { continue }
            out.append((String(p.dropFirst(base.count)), v.fileSize ?? 0, v.contentModificationDate ?? .distantPast))
        }
        return out.sorted { $0.2 < $1.2 }.map { ["name": $0.0, "size": $0.1] }
    }
}

/// One request from the browser.
private final class Connection: @unchecked Sendable {
    private struct Upload {
        let handle: FileHandle
        let temp: URL
        let rel: String
        let total: Int64
        var done: Int64 = 0
        var reported = Date.distantPast
    }

    private let c: NWConnection
    private weak var server: WifiServer?
    private var head = Data()
    private var upload: Upload?
    private var over = false

    init(_ c: NWConnection, server: WifiServer) {
        self.c = c
        self.server = server
    }

    func start() {
        guard let server else { return }
        c.start(queue: server.queue)
        read()
    }

    private func read() {
        c.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [self] data, _, end, error in
            if let data, !data.isEmpty { take(data) }
            if over { return }
            if error != nil || end {
                lost()
                return
            }
            read()
        }
    }

    private func take(_ data: Data) {
        if upload != nil {
            write(data)
            return
        }
        head.append(data)
        guard let r = head.range(of: Data("\r\n\r\n".utf8)) else {
            if head.count > 64 * 1024 { answer(431, ["error": "Request Header Fields Too Large"]) }
            return
        }
        let rest = head[r.upperBound...]
        let lines = String(decoding: head[..<r.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
        var headers: [String: String] = [:]
        for l in lines.dropFirst() {
            guard let colon = l.firstIndex(of: ":") else { continue }
            headers[l[..<colon].lowercased()] = l[l.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let first = lines.first?.split(separator: " ") ?? []
        guard first.count >= 2, let parts = URLComponents(string: String(first[1])) else { return answer(400, ["error": "Bad Request"]) }
        route(String(first[0]), parts, headers, Data(rest))
    }

    private func route(_ method: String, _ url: URLComponents, _ headers: [String: String], _ rest: Data) {
        guard let server else { return close() }
        switch (method, url.path) {
        case ("GET", "/"), ("GET", "/index.html"):
            send(200, "text/html; charset=utf-8", Data(server.page.utf8))
        case ("GET", "/list"):
            answer(200, server.list())
        case ("PUT", "/upload"):
            guard let raw = url.queryItems?.first(where: { $0.name == "path" })?.value, let rel = WifiServer.clean(raw) else { return answer(400, ["error": tr("Неподходящее имя файла")]) }
            guard WifiServer.allowed.contains((rel as NSString).pathExtension.lowercased()) else { return answer(415, ["error": tr("Это не музыка")]) }
            guard let total = headers["content-length"].flatMap({ Int64($0) }), total >= 0 else { return answer(411, ["error": "Length Required"]) }
            let free = (try? server.folder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?.volumeAvailableCapacityForImportantUsage ?? .max
            guard total + 100_000_000 < free else {
                server.onEvent(.failed(name: rel, reason: tr("на телефоне нет места")))
                return answer(507, ["error": tr("На телефоне нет места")])
            }
            let temp = server.folder.appendingPathComponent(".part-" + UUID().uuidString)
            guard FileManager.default.createFile(atPath: temp.path, contents: nil), let h = try? FileHandle(forWritingTo: temp) else {
                return answer(500, ["error": tr("Не получилось сохранить файл")])
            }
            upload = Upload(handle: h, temp: temp, rel: rel, total: total)
            server.onEvent(.progress(name: rel, done: 0, total: total))
            if total == 0 { finish() } else if !rest.isEmpty { write(rest) }
        default:
            answer(404, ["error": "Not Found"])
        }
    }

    private func write(_ data: Data) {
        guard var u = upload, let server else { return }
        let piece = data.prefix(Int(min(Int64(data.count), u.total - u.done)))
        do { try u.handle.write(contentsOf: piece) } catch {
            drop()
            server.onEvent(.failed(name: u.rel, reason: tr("на телефоне нет места")))
            return answer(507, ["error": tr("Не получилось сохранить файл")])
        }
        u.done += Int64(piece.count)
        if Date().timeIntervalSince(u.reported) > 0.25 {
            u.reported = Date()
            server.onEvent(.progress(name: u.rel, done: u.done, total: u.total))
        }
        upload = u
        if u.done >= u.total { finish() }
    }

    private func finish() {
        guard let u = upload, let server else { return }
        upload = nil
        try? u.handle.close()
        let fm = FileManager.default
        var dest = server.folder.appendingPathComponent(u.rel), rel = u.rel
        if let size = (try? dest.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
            if Int64(size) == u.total {
                try? fm.removeItem(at: u.temp)
                server.onEvent(.skipped(rel))
                return answer(200, ["ok": true, "skipped": true, "name": rel])
            }
            // another file with the same name: keep both
            let ext = (u.rel as NSString).pathExtension, stem = (u.rel as NSString).deletingPathExtension
            for n in 2...999 {
                rel = "\(stem) (\(n)).\(ext)"
                dest = server.folder.appendingPathComponent(rel)
                if !fm.fileExists(atPath: dest.path) { break }
            }
        }
        do {
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: u.temp, to: dest)
        } catch {
            try? fm.removeItem(at: u.temp)
            server.onEvent(.failed(name: u.rel, reason: tr("не получилось сохранить")))
            return answer(500, ["error": tr("Не получилось сохранить файл")])
        }
        server.onEvent(.received(rel))
        answer(200, ["ok": true, "skipped": false, "name": rel])
    }

    /// The browser went away in the middle of a file.
    private func lost() {
        if let u = upload {
            drop()
            server?.onEvent(.failed(name: u.rel, reason: tr("связь оборвалась")))
        }
        close()
    }

    private func drop() {
        guard let u = upload else { return }
        upload = nil
        try? u.handle.close()
        try? FileManager.default.removeItem(at: u.temp)
    }

    private func answer(_ code: Int, _ value: Any) {
        let data = (try? JSONSerialization.data(withJSONObject: value)) ?? Data("{}".utf8)
        send(code, "application/json; charset=utf-8", data)
    }

    private func send(_ code: Int, _ type: String, _ body: Data) {
        guard !over else { return }
        over = true
        let reason = [200: "OK", 400: "Bad Request", 404: "Not Found", 411: "Length Required", 415: "Unsupported Media Type", 431: "Too Large", 500: "Server Error", 507: "Insufficient Storage"][code] ?? "OK"
        let top = "HTTP/1.1 \(code) \(reason)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
        c.send(content: Data(top.utf8) + body, completion: .contentProcessed { [self] _ in close() })
    }

    func close() {
        over = true
        drop()
        c.cancel()
        server?.closed(self)
    }
}
