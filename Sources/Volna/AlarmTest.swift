#if DEBUG
import AVFoundation
import Foundation

extension Demo {
    /// The alarm sound cut from a song, the music after waking up, the sleep timer at a clock time.
    static func alarmTest(_ library: Library, _ player: Player, _ settings: Settings, _ check: (String, Bool, String) -> Void, _ wait: (Double) async -> Void) async {
        let ids = library.tracks.map(\.id)
        guard ids.count >= 2 else { return check("alarm: songs", false, "") }
        let saved = settings.v

        // the ringtone: the start of the song in Library/Sounds
        let name = await WakeAlarm.ringtone(ids[0].uuidString, library)
        let file = name.flatMap { try? AVAudioFile(forReading: WakeAlarm.sounds.appendingPathComponent($0)) }
        let seconds = file.map { Double($0.length) / $0.processingFormat.sampleRate } ?? 0
        check("alarm sound cut", seconds > 5 && seconds <= WakeAlarm.ringSeconds + 0.1, String(format: "%.1f s", seconds))
        check("alarm: no sound for a missing song", await WakeAlarm.ringtone(UUID().uuidString, library) == nil, "")

        // "Listen": the alarm song first, quiet at the start, then louder; a one-time alarm switches itself off
        settings.v.alarmSong = ids[1].uuidString
        settings.v.alarmMusic = "song"
        settings.v.alarmRise = 2
        settings.v.alarmDays = []
        settings.v.alarmOn = true
        WakeAlarm.listen()
        await wait(0.3)
        let quiet = player.graph.master
        check("alarm: the alarm song plays", player.current?.id == ids[1] && player.isPlaying, "")
        check("alarm: starts quietly", quiet < 0.3, String(format: "%.2f", quiet))
        check("alarm: one-time alarm off", !settings.v.alarmOn, "")
        await wait(2.5)
        check("alarm: grows to full volume", player.graph.master > 0.99, String(format: "%.2f", player.graph.master))

        // the sleep timer at a clock time
        player.sleep(at: Date().addingTimeInterval(1))
        check("sleep at a time set", player.sleepAt != nil, "")
        await wait(7)
        check("sleep at a time stops", !player.isPlaying && player.graph.master == 1, "")

        settings.v = saved
    }
}
#endif
