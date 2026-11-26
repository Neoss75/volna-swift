#if DEBUG
import AVFoundation
import UIKit

/// A showcase for the App Store screenshots: made-up artists and songs, drawn covers, favourites, playlists,
/// statistics, lyrics and stations. Only in test builds.
@MainActor
enum StoreDemo {
    /// Artist, title, album, length shown in the list.
    static let songs: [(String, String, String, Double)] = [
        ("Северный Ветер", "Над морем", "Маяки", 214),
        ("Lumen Drive", "Night Train", "Afterglow", 237),
        ("Тиха Гавань", "Світанок", "Світанок", 198),
        ("Velvet Coast", "Glass Hearts", "Tides", 251),
        ("Город Огней", "Последний трамвай", "Ночные улицы", 226),
        ("Mira Sol", "Golden Hour", "Golden Hour", 189),
        ("Полярный Свет", "Километры", "Север", 243),
        ("Kite & Compass", "Paper Planes", "Small Wonders", 205),
        ("Ночной Экспресс", "Неон", "Ночные улицы", 232),
        ("Blue Meridian", "Slow Motion", "Tides", 264),
        ("Тёплый Ламповый", "Винил", "Пластинки", 219),
        ("Sora Lane", "Echoes", "Afterglow", 241),
    ]

    static var folder: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Store", isDirectory: true) }

    static func build(library: Library, player: Player, settings: Settings) async {
        if !library.tracks.contains(where: { $0.path.contains("/Store/") }) {
            library.clearForDemo()
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var urls: [URL] = []
            for (i, s) in songs.enumerated() {
                // the first one plays in the screenshots: long enough and without losses
                let url = folder.appendingPathComponent("\(s.0) - \(s.1)." + (i == 0 ? "flac" : "wav"))
                if !FileManager.default.fileExists(atPath: url.path) {
                    Demo.synth(url, rate: 44100, channels: 2, seconds: i == 0 ? s.3 : 6, format: i == 0 ? kAudioFormatFLAC : kAudioFormatLinearPCM)
                }
                urls.append(url)
            }
            await library.add(urls: urls)
            let ids = order(library)
            for (i, id) in ids.enumerated() {
                if i > 0 { library.update(id) { $0.duration = songs[i].3 } }
                library.edit(id, title: songs[i].1, artist: songs[i].0, album: songs[i].2)
                if let art = cover(i) { library.setCover(art, for: [id]) }
            }
            for i in [0, 3, 5, 8] where !library.isFavourite(ids[i]) { library.toggleFavourite(ids[i]) }
            library.createPlaylist(tr("В дорогу"), with: [ids[1], ids[3], ids[6], ids[9], ids[0]])
            library.createPlaylist(tr("Вечер"), with: [ids[2], ids[5], ids[10], ids[11]])
            Toaster.shared.dismiss()
        }
        let ids = order(library)
        guard ids.count == songs.count else { return }

        // listening statistics: the lists of the month and of the time of day show up
        var d = Stats.Data()
        let part = Stats.DayPart.of().rawValue
        for (i, id) in ids.enumerated() where i < 9 {
            let seconds = Double(1800 - i * 150)
            var parts = [Double](repeating: 0, count: 4)
            parts[part] = seconds * 0.7
            parts[(part + 2) % 4] = seconds * 0.3
            d.songs[id.uuidString] = Stats.Entry(plays: 12 - i, seconds: seconds, title: songs[i].1, artist: songs[i].0, last: Date(),
                                                 months: [Stats.monthKey(): seconds], parts: parts)
        }
        d.total = 6 * 3600
        d.days[Stats.dayKey()] = 2400
        player.demoStats.replace(d)

        LyricsStore.save(Lyrics(text: lyrics, source: "lrclib.net · синхронный"), id: ids[0])
        settings.v.viz = .bars
        player.play(ids[0], from: ids)
        player.seek(to: 71)
    }

    /// The songs in the order of the list above.
    static func order(_ library: Library) -> [UUID] {
        songs.compactMap { s in library.tracks.first { $0.path.contains("/Store/") && $0.fileName.hasPrefix(s.0 + " - " + s.1) }?.id }
    }

    /// Made-up words, timed so that the middle of the screen is at 1:11.
    static let lyrics = """
    [00:58.00]Ветер ловит паруса
    [01:02.00]Над водой гудит маяк
    [01:06.00]Я считаю голоса
    [01:10.00]Тех, кто шёл со мной не так
    [01:14.00]Над морем, над морем
    [01:18.00]Светает горизонт
    [01:22.00]И всё, что было с нами
    [01:26.00]Уносит ветер вон
    [01:30.00]Над морем, над морем
    [01:34.00]Дорога до утра
    """

    /// A gradient with soft circles and a wave: no letters, no pictures of anybody.
    static func cover(_ seed: Int) -> Data? {
        let size = CGSize(width: 600, height: 600)
        let hues: [(CGFloat, CGFloat)] = [(0.58, 0.72), (0.92, 0.78), (0.08, 0.98), (0.48, 0.62), (0.75, 0.88), (0.11, 0.02),
                                         (0.55, 0.45), (0.33, 0.48), (0.83, 0.62), (0.6, 0.53), (0.04, 0.09), (0.7, 0.95)]
        let (h1, h2) = hues[seed % hues.count]
        let image = UIGraphicsImageRenderer(size: size).image { c in
            let g = c.cgContext
            let colors = [UIColor(hue: h1, saturation: 0.65, brightness: 0.85, alpha: 1).cgColor, UIColor(hue: h2, saturation: 0.75, brightness: 0.35, alpha: 1).cgColor]
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                g.drawLinearGradient(grad, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            for k in 0..<5 {
                let x = CGFloat((seed * 97 + k * 131) % 600), y = CGFloat((seed * 53 + k * 211) % 600), d = CGFloat(120 + (seed * 31 + k * 67) % 260)
                UIColor.white.withAlphaComponent(0.06 + CGFloat(k) * 0.025).setFill()
                UIBezierPath(ovalIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)).fill()
            }
            let wave = UIBezierPath()
            let base = 380 + CGFloat(seed % 4) * 30
            wave.move(to: CGPoint(x: 0, y: base))
            for x in stride(from: 0, through: 600, by: 10) {
                wave.addLine(to: CGPoint(x: CGFloat(x), y: base + 28 * sin(CGFloat(x) / 60 + CGFloat(seed))))
            }
            UIColor.white.withAlphaComponent(0.55).setStroke()
            wave.lineWidth = 6
            wave.stroke()
        }
        return image.jpegData(compressionQuality: 0.9)
    }

    /// Stations with made-up names on the test server.
    static func radio(_ player: Player, _ stations: Stations, _ settings: Settings, _ server: TestServer) {
        let list = [("Волна FM", "/live", "Поп"), ("Lounge 24", "/mp3", "Lounge"), ("Ретро Хиты", "/mp3", "Ретро"), ("Jazz Corner", "/mp3", "Jazz"),
                    ("Рок Волна", "/mp3", "Рок"), ("Classic Hall", "/mp3", "Классика")].map { Station(name: $0.0, url: server.url($0.1), group: $0.2) }
        var first = list
        first[0].favourite = true
        first[3].favourite = true
        stations.add(first)
        settings.v.radioExtras = true
        RadioExtras.fake = (cover(6).flatMap(UIImage.init(data:)), lyrics)
        player.play(first[0], from: stations.ordered.map(\.id))
    }
}
#endif
