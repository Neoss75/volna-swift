#if DEBUG
import AVFoundation
import Foundation

extension Demo {
    /// The lists by month and by time of day, and the silence at the ends of a song.
    static func smartTest(_ library: Library, _ player: Player, _ check: (String, Bool, String) -> Void, _ wait: (Double) async -> Void) async {
        // the time of day
        func at(_ h: Int) -> Date { Calendar.current.date(bySettingHour: h, minute: 30, second: 0, of: Date()) ?? Date() }
        check("time of day", [at(4), at(5), at(10), at(11), at(16), at(17), at(22), at(23)].map { Stats.DayPart.of($0) }
            == [.night, .morning, .morning, .day, .day, .evening, .evening, .night], "")
        check("month key", Stats.monthKey().count == 7 && !Stats.monthName().isEmpty, Stats.monthKey() + " " + Stats.monthName())

        // the lists come from the statistics
        let stats = Stats(), saved = stats.data, ids = library.tracks.map(\.id)
        guard ids.count >= 3 else { return check("smart lists: songs", false, "\(ids.count)") }
        var d = Stats.Data()
        let now = Stats.DayPart.of(), other = Stats.DayPart(rawValue: (now.rawValue + 1) % 4) ?? .day
        func parts(_ here: Double, _ there: Double) -> [Double] {
            var p = [Double](repeating: 0, count: 4)
            p[now.rawValue] = here
            p[other.rawValue] = there
            return p
        }
        d.songs[ids[0].uuidString] = Stats.Entry(plays: 3, seconds: 300, title: "a", artist: "", months: [Stats.monthKey(): 300], parts: parts(300, 0))
        d.songs[ids[1].uuidString] = Stats.Entry(plays: 5, seconds: 900, title: "b", artist: "", months: [Stats.monthKey(): 600, "2001-01": 300], parts: parts(100, 800))
        d.songs[ids[2].uuidString] = Stats.Entry(plays: 1, seconds: 30, title: "c", artist: "", months: [Stats.monthKey(): 30], parts: parts(30, 0))
        stats.replace(d)
        let month = library.songs(in: .month, stats: stats).map(\.id), part = library.songs(in: .dayPart, stats: stats).map(\.id)
        check("list of the month", month == [ids[1], ids[0]], "\(month.count)")
        // the second song is heard mostly at another time, the third too little
        check("list of the time of day", part == [ids[0]], "\(part.count)")
        stats.replace(saved)

        // silence: two seconds, a three second tone, two seconds
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("тишина.wav")
        let rate = 44100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2),
              let file = try? AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: 2,
                                                                      AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false],
                                          commonFormat: .pcmFormatFloat32, interleaved: false),
              let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(rate * 7)), let data = b.floatChannelData else {
            return check("silence file", false, "")
        }
        b.frameLength = AVAudioFrameCount(rate * 7)
        for i in 0..<Int(rate * 7) {
            let t = Double(i) / rate, s: Float = t >= 2 && t < 5 ? Float(0.4 * sin(2 * .pi * 440 * t)) : Float.random(in: -0.0005...0.0005)
            data[0][i] = s
            data[1][i] = s
        }
        try? file.write(from: b)
        let r = Analysis.run(url)
        check("silence found", abs((r?.soundStart ?? 0) - 2) < 0.05 && abs((r?.soundEnd ?? 0) - 5) < 0.05,
              String(format: "%.3f…%.3f", r?.soundStart ?? -1, r?.soundEnd ?? -1))
        guard let opened = try? AVAudioFile(forReading: url) else { return check("silence file", false, "") }
        var t = Track(id: UUID(), bookmark: Data(), path: url.path, title: "", artist: "", album: "", duration: 7, hasArtwork: false)
        t.soundStart = r?.soundStart
        t.soundEnd = r?.soundEnd
        let cut = Deck.part(of: opened, t)
        check("silence skipped", abs(Double(cut.first) / rate - 2) < 0.05 && abs(Double(cut.count) / rate - 3) < 0.05,
              String(format: "%.3f + %.3f", Double(cut.first) / rate, Double(cut.count) / rate))
        Deck.trimSilence = false
        let whole = Deck.part(of: opened, t)
        Deck.trimSilence = true
        check("silence kept when switched off", whole.first == 0 && whole.count == opened.length, "")
        // a quiet song is not cut to nothing, a short pause is left alone
        var quiet = t
        quiet.soundStart = 3
        quiet.soundEnd = 3.5
        var short = t
        short.soundStart = 0.1
        short.soundEnd = 6.9
        check("silence: only real pauses", Deck.part(of: opened, quiet).count == opened.length && Deck.part(of: opened, short).count == opened.length, "")
        try? FileManager.default.removeItem(at: url)
    }
}
#endif
