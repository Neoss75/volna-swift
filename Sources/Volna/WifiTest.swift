#if DEBUG
import Foundation

extension Demo {
    /// Sends a file to the running Wi-Fi page as a browser would; gives the status and the answer.
    static func wifiSend(_ port: UInt16, _ path: String, _ data: Data) async -> (Int, [String: Any]) {
        let q = path.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        guard let url = URL(string: "http://127.0.0.1:\(port)/upload?path=" + q) else { return (0, [:]) }
        var r = URLRequest(url: url, timeoutInterval: 20)
        r.httpMethod = "PUT"
        guard let (d, resp) = try? await URLSession.shared.upload(for: r, from: data) else { return (0, [:]) }
        return ((resp as? HTTPURLResponse)?.statusCode ?? 0, (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] ?? [:])
    }

    static func wifiTest(_ library: Library, _ settings: Settings, _ check: (String, Bool, String) -> Void, _ wait: (Double) async -> Void) async {
        let wifi = WifiTransfer.shared, fm = FileManager.default
        await wifi.start(library, accent: settings.v.accent)
        guard let port = wifi.port else { return check("wifi starts", false, "\(wifi.state)") }
        check("wifi starts", true, "\(port) \(wifi.address ?? "no Wi-Fi here")")
        let page = (try? await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/")!)).map { String(decoding: $0.0, as: UTF8.self) } ?? ""
        check("wifi page", page.contains("webkitGetAsEntry") && page.contains(tr("Перетащите сюда файлы или папки с музыкой")), "\(page.count)")

        let src = fm.temporaryDirectory.appendingPathComponent("wifi.wav")
        synth(src, rate: 44100, channels: 2, seconds: 3)
        let wav = (try? Data(contentsOf: src)) ?? Data()
        func song() -> Track? { library.tracks.first { $0.folderID == Library.wifiID && $0.fileName == "Пісня.wav" } }
        func until(_ ok: () -> Bool) async { for _ in 0..<40 where !ok() { await wait(0.25) } }

        let (code, answer) = await wifiSend(port, "Альбом/Пісня.wav", wav)
        await until { song() != nil }
        check("wifi song", code == 200 && song()?.folder == "Wi-Fi / Альбом" && abs((song()?.duration ?? 0) - 3) < 0.1, "\(code) \(answer) \(song()?.folder ?? "-")")
        check("wifi page on the phone", wifi.received == ["Альбом/Пісня.wav"], "\(wifi.received)")
        let again = await wifiSend(port, "Альбом/Пісня.wav", wav)
        await wait(1.5)
        check("wifi same file twice", again.1["skipped"] as? Bool == true && library.tracks.filter { $0.fileName == "Пісня.wav" }.count == 1, "\(again.1)")
        let other = await wifiSend(port, "Альбом/Пісня.wav", wav + Data(count: 4))
        check("wifi another file with that name", other.1["name"] as? String == "Альбом/Пісня (2).wav", "\(other.1)")
        let sneaky = await wifiSend(port, "../../Library/x.wav", wav)
        check("wifi stays in its folder", sneaky.1["name"] as? String == "Library/x.wav" && fm.fileExists(atPath: Library.wifiFolder.appendingPathComponent("Library/x.wav").path), "\(sneaky.1)")
        let exe = await wifiSend(port, "setup.exe", Data(count: 10))
        check("wifi takes only music", exe.0 == 415, "\(exe.0)")

        // a big file arrives in many pieces
        var big = Data(count: 24_000_000)
        big[12_345_678] = 7
        let large = await wifiSend(port, "big.flac", big)
        let stored = Library.wifiFolder.appendingPathComponent("big.flac")
        check("wifi big file", large.0 == 200 && (try? Data(contentsOf: stored)) == big, "\(large.0)")
        try? fm.removeItem(at: stored)

        let list = (try? await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/list")!)).flatMap { try? JSONSerialization.jsonObject(with: $0.0) as? [[String: Any]] } ?? []
        check("wifi list", list.contains { $0["name"] as? String == "Альбом/Пісня.wav" && $0["size"] as? Int == wav.count }, "\(list.count)")

        // removing the song in the player removes the file, sending it again brings it back
        await until { library.tracks.contains { $0.fileName == "Пісня (2).wav" } }
        if let t = song() { library.remove([t.id]) }
        let file = Library.wifiFolder.appendingPathComponent("Альбом/Пісня.wav")
        check("wifi removal frees the room", song() == nil && !fm.fileExists(atPath: file.path), "")
        _ = await wifiSend(port, "Альбом/Пісня.wav", wav)
        await until { song() != nil }
        check("wifi song sent again", song() != nil && fm.fileExists(atPath: file.path), "")

        wifi.stop()
        await wait(0.5)
        let closed = await wifiSend(port, "after.wav", wav)
        check("wifi stops", closed.0 == 0 && !wifi.running, "\(closed.0)")
        for t in library.tracks where t.folderID == Library.wifiID { library.remove([t.id]) }
    }

    /// For the screenshots: two songs arrive while the page is open.
    static func wifiShow() async {
        for _ in 0..<40 where WifiTransfer.shared.port == nil { try? await Task.sleep(for: .seconds(0.25)) }
        guard let port = WifiTransfer.shared.port else { return }
        let src = FileManager.default.temporaryDirectory.appendingPathComponent("show.wav")
        synth(src, rate: 44100, channels: 2, seconds: 2)
        let wav = (try? Data(contentsOf: src)) ?? Data()
        for name in ["Океан Ельзи - Земля/01. Земля.wav", "Океан Ельзи - Земля/02. Обійми.wav"] { _ = await wifiSend(port, name, wav) }
    }
}
#endif
