import Foundation

/// What is known about the sound of a station: learnt while it plays or is checked.
struct StationFacts: Codable, Equatable {
    /// "MP3", "AAC", "AAC+", or "HLS" when only that is known.
    var kind: String
    /// The sound itself, kilobits per second.
    var kbps: Double?
    /// Everything that is downloaded, kilobits per second, when it is more than the sound.
    var total: Double?
    var rate: Double?

    /// Megabytes in an hour of listening.
    var perHour: Double? { (total ?? kbps).map { $0 * 3600 / 8 / 1000 } }

    var text: String {
        [kind, kbps.map { tr("{} кбит/с", "\(Int($0.rounded()))") } ?? "", perHour.map(Self.traffic) ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    static func traffic(_ mb: Double) -> String {
        mb >= 950 ? String(format: tr("≈ %.1f ГБ/ч"), mb / 1000) : tr("≈ {} МБ/ч", "\(Int(mb.rounded()))")
    }

    /// Newer knowledge over older; what the newer does not know stays.
    func over(_ old: StationFacts?, rough: Bool = false) -> StationFacts {
        guard let old else { return self }
        // measured on a few packets: what was heard for a while is more exact
        if rough, old.kind == kind, old.kbps != nil { return old }
        var f = self
        if kind == "HLS", old.kind != "HLS" { f.kind = old.kind }
        f.kbps = kbps ?? old.kbps
        f.total = total ?? old.total
        f.rate = rate ?? old.rate
        return f
    }

    static func standard(_ kbps: Double, within part: Double = 0.06) -> Double {
        let usual: [Double] = [24, 32, 48, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320]
        var best = kbps.rounded(), error = part
        for u in usual where abs(u - kbps) / u < error {
            error = abs(u - kbps) / u
            best = u
        }
        return best
    }

    /// Looks at the first bytes of a stream: the packets of MP3 and AAC say how long they are.
    static func look(_ d: Data) -> StationFacts? {
        let b = [UInt8](d)
        guard b.count > 400 else { return nil }
        for i in 0..<min(b.count - 8, 6000) where b[i] == 0xFF && b[i + 1] & 0xE0 == 0xE0 {
            if b[i + 1] & 0xF6 == 0xF0 {
                if let f = aac(b, i) { return f }
            } else if let f = mp3(b, i) {
                return f
            }
        }
        return nil
    }

    private static func aac(_ b: [UInt8], _ start: Int) -> StationFacts? {
        let rates: [Double] = [96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000]
        var at = start, frames = 0
        let r = Int(b[start + 2] >> 2 & 15)
        guard r < rates.count else { return nil }
        while at + 7 <= b.count {
            guard b[at] == 0xFF, b[at + 1] & 0xF6 == 0xF0, Int(b[at + 2] >> 2 & 15) == r else { break }
            let n = Int(b[at + 3] & 3) << 11 | Int(b[at + 4]) << 3 | Int(b[at + 5]) >> 5
            guard n > 7 else { break }
            if at + n > b.count { break }
            at += n
            frames += 1
        }
        guard frames >= 4 else { return nil }
        // a half of the usual rate means that the upper half is kept apart (AAC+)
        let plus = rates[r] <= 24000
        return StationFacts(kind: plus ? "AAC+" : "AAC", kbps: standard(Double(at - start) * 8 * rates[r] / Double(frames * 1024) / 1000, within: 0.12),
                            total: nil, rate: plus ? rates[r] * 2 : rates[r])
    }

    private static func mp3(_ b: [UInt8], _ start: Int) -> StationFacts? {
        let first: [Double] = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320]
        let second: [Double] = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160]
        var at = start, frames = 0, sum = 0.0, rate = 0.0
        while at + 4 <= b.count {
            let version = b[at + 1] >> 3 & 3, k = Int(b[at + 2] >> 4), r = Int(b[at + 2] >> 2 & 3)
            guard b[at] == 0xFF, b[at + 1] & 0xE0 == 0xE0, version != 1, b[at + 1] >> 1 & 3 == 1, k > 0, k < 15, r < 3 else { break }
            let base: [Double] = [44100, 48000, 32000]
            let sr = base[r] / (version == 3 ? 1 : version == 2 ? 2 : 4)
            if rate != 0, rate != sr { break }
            rate = sr
            let kbps = version == 3 ? first[k] : second[k]
            let n = Int((version == 3 ? 144000 : 72000) * kbps / sr) + Int(b[at + 2] >> 1 & 1)
            if at + n > b.count { break }
            sum += kbps
            frames += 1
            at += n
        }
        guard frames >= 3 else { return nil }
        return StationFacts(kind: "MP3", kbps: (sum / Double(frames)).rounded(), total: nil, rate: rate)
    }
}
