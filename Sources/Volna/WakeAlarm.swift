import ActivityKit
import AlarmKit
import AVFoundation
import SwiftUI

/// Nothing extra travels with the alarm: everything is in the settings.
struct VolnaAlarmData: AlarmMetadata {}

/// The alarm clock: a real system alarm (AlarmKit) that rings even in silent mode and Focus,
/// with the start of a chosen song as its sound. "Listen" on the alarm opens Volna and plays music that grows louder.
@MainActor
enum WakeAlarm {
    private static let key = "wakeAlarmID"
    /// Seconds of the song the alarm rings with.
    static let ringSeconds = 30.0
    #if DEBUG
    /// The screenshots show the page without asking the simulator for permission.
    static var dryRun = false
    #endif

    private static var scheduledID: UUID? {
        get { UserDefaults.standard.string(forKey: key).flatMap(UUID.init(uuidString:)) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: key) }
    }

    static var denied: Bool { AlarmManager.shared.authorizationState == .denied }

    /// Brings the system alarm in line with the settings. Returns a problem to show, or nil.
    static func apply(_ settings: Settings, _ library: Library) async -> String? {
        #if DEBUG
        if dryRun { return nil }
        #endif
        if let id = scheduledID {
            try? AlarmManager.shared.cancel(id: id)
            scheduledID = nil
        }
        let v = settings.v
        guard v.alarmOn else { return nil }
        if AlarmManager.shared.authorizationState == .notDetermined {
            _ = try? await AlarmManager.shared.requestAuthorization()
        }
        guard AlarmManager.shared.authorizationState == .authorized else {
            return tr("Разрешите Волне будильники: Настройки iPhone → Приложения → Волна.")
        }
        let sound: AlertConfiguration.AlertSound
        if let name = await ringtone(v.alarmSong, library) { sound = .named(name) } else { sound = .default }

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: tr("Доброе утро")),
            stopButton: AlarmButton(text: LocalizedStringResource(stringLiteral: tr("Стоп")), textColor: .white, systemImageName: "stop.fill"),
            secondaryButton: AlarmButton(text: LocalizedStringResource(stringLiteral: tr("Слушать")), textColor: .white, systemImageName: "music.note"),
            secondaryButtonBehavior: .custom)
        let attributes = AlarmAttributes<VolnaAlarmData>(presentation: AlarmPresentation(alert: alert), metadata: VolnaAlarmData(), tintColor: settings.accent)
        let days = v.alarmDays.sorted().compactMap(weekday)
        let time = Alarm.Schedule.Relative.Time(hour: v.alarmHour, minute: v.alarmMinute)
        let schedule = Alarm.Schedule.relative(.init(time: time, repeats: days.isEmpty ? .never : .weekly(days)))
        let config = AlarmManager.AlarmConfiguration<VolnaAlarmData>(countdownDuration: nil, schedule: schedule, attributes: attributes,
                                                                    stopIntent: nil, secondaryIntent: WakeListenIntent(), sound: sound)
        let id = UUID()
        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: config)
            scheduledID = id
            return nil
        } catch {
            return tr("Не удалось поставить будильник") + ": " + error.localizedDescription
        }
    }

    /// Calendar weekdays (1 = Sunday) as AlarmKit wants them.
    private static func weekday(_ d: Int) -> Locale.Weekday? {
        [1: .sunday, 2: .monday, 3: .tuesday, 4: .wednesday, 5: .thursday, 6: .friday, 7: .saturday][d]
    }

    // MARK: - The sound

    static var sounds: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Sounds", isDirectory: true)
    }

    /// The start of the chosen song as a sound file in Library/Sounds, where the system looks for alarm sounds.
    static func ringtone(_ song: String, _ library: Library) async -> String? {
        guard let id = UUID(uuidString: song), let t = library.track(id), let access = library.open(t) else { return nil }
        let name = "volna-alarm-\(id.uuidString).caf"
        let dest = sounds.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: dest.path) { return name }
        let start = t.cueStart ?? t.soundStart ?? 0, seconds = ringSeconds
        let ok = await Task.detached(priority: .userInitiated) { () -> Bool in
            guard let src = try? OggFile.playable(access.url, id: id) else { return false }
            return cut(src, from: start, seconds: seconds, to: dest)
        }.value
        guard ok else { return nil }
        // only the sound of the current choice is kept
        for f in (try? FileManager.default.contentsOfDirectory(atPath: sounds.path)) ?? [] where f.hasPrefix("volna-alarm-") && f != name {
            try? FileManager.default.removeItem(at: sounds.appendingPathComponent(f))
        }
        return name
    }

    /// Writes a piece of a song as 16-bit PCM, softly faded in and out.
    nonisolated static func cut(_ src: URL, from start: Double, seconds: Double, to dest: URL) -> Bool {
        guard let file = try? AVAudioFile(forReading: src) else { return false }
        let format = file.processingFormat
        let rate = format.sampleRate
        let first = AVAudioFramePosition(max(0, start) * rate)
        guard first < file.length else { return false }
        let count = AVAudioFrameCount(min(Double(file.length - first), seconds * rate))
        guard count > 0, let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else { return false }
        file.framePosition = first
        guard (try? file.read(into: buf, frameCount: count)) != nil, let ch = buf.floatChannelData else { return false }
        let n = Int(buf.frameLength), edge = min(n / 2, Int(rate * 0.8))
        for c in 0..<Int(format.channelCount) {
            for i in 0..<edge {
                let k = Float(i) / Float(edge)
                ch[c][i] *= k
                ch[c][n - 1 - i] *= k
            }
        }
        try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: dest)
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: format.channelCount,
                                       AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
        do {
            let out = try AVAudioFile(forWriting: dest, settings: settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
            try out.write(from: buf)
            return true
        } catch {
            try? FileManager.default.removeItem(at: dest)
            return false
        }
    }

    // MARK: - After waking up

    /// What plays after "Listen", louder bit by bit.
    static func listen(playlist: UUID? = nil, oneTime: Bool = true) {
        guard let lib = SiriBridge.library, let player = SiriBridge.player, let settings = SiriBridge.settings else { return }
        // a one-time alarm has done its job
        if oneTime, settings.v.alarmDays.isEmpty { settings.v.alarmOn = false }
        let v = settings.v
        var ids: [UUID] = []
        let choice = playlist.map { "playlist:" + $0.uuidString } ?? v.alarmMusic
        switch choice {
        case "favourites":
            ids = lib.tracks.filter { lib.isFavourite($0.id) }.map(\.id).shuffled()
        case "all":
            ids = lib.tracks.map(\.id).shuffled()
        case let c where c.hasPrefix("playlist:"):
            let pid = UUID(uuidString: String(c.dropFirst(9)))
            ids = lib.playlists.first { $0.id == pid }?.keys.filter { lib.track($0) != nil } ?? []
        default:
            // the alarm song, then the rest of the music
            let song = UUID(uuidString: v.alarmSong).flatMap { lib.track($0)?.id }
            ids = lib.tracks.map(\.id).filter { $0 != song }.shuffled()
            if let song { ids.insert(song, at: 0) }
        }
        if ids.isEmpty { ids = lib.tracks.map(\.id).shuffled() }
        guard let first = ids.first else { return }
        player.play(first, from: ids)
        player.rise(over: v.alarmRise)
    }
}
