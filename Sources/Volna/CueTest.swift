#if DEBUG
import AVFoundation
import Foundation

extension Demo {
    static func cueTest(_ library: Library, _ player: Player, _ settings: Settings, _ check: (String, Bool, String) -> Void, _ wait: (Double) async -> Void) async {
        let text = "REM GENRE Rock\nPERFORMER \"Океан Ельзи\"\nTITLE \"Земля\"\nFILE \"Альбом.wav\" WAVE\n  TRACK 01 AUDIO\n    TITLE \"Перша\"\n    INDEX 01 00:00:00\n"
            + "  TRACK 02 AUDIO\n    TITLE \"Друга\"\n    PERFORMER \"Гість\"\n    INDEX 00 00:04:60\n    INDEX 01 00:05:00\n  TRACK 03 AUDIO\n    INDEX 01 00:10:37\n"
        let sheet = CueSheet(text)
        check("cue", sheet.title == "Земля" && sheet.files.first?.songs.map(\.title) == ["Перша", "Друга", ""] && sheet.files.first?.songs.last?.start == 10 + 37.0 / 75, "\(sheet.files)")
        let old = text.data(using: .windowsCP1251) ?? Data()
        check("cue in the Windows encoding", CueSheet(CueSheet.text(old)) == sheet, "")
        let split = CueSheet("FILE \"1.flac\" WAVE\n TRACK 01 AUDIO\n INDEX 01 00:00:00\nFILE \"2.flac\" WAVE\n TRACK 02 AUDIO\n INDEX 01 00:00:00\n")
        check("cue of an album in files", split.files.count == 2 && split.files.allSatisfy { split.songs(of: $0) == nil }, "")
        check("cue finds the file", sheet.match(["x.mp3", "альбом.FLAC"], sheet: "a.cue").first?.name == "альбом.FLAC" && sheet.match(["Диск.flac"], sheet: "диск.cue").count == 1, "")
        var tag = Array("CUESHEET=".utf8) + Array(text.utf8)
        func le(_ n: Int) -> [UInt8] { [UInt8(n & 255), UInt8(n >> 8 & 255), UInt8(n >> 16 & 255), 0] }
        tag = le(3) + Array("abc".utf8) + le(1) + le(tag.count) + tag
        var flac: [UInt8] = Array("fLaC".utf8) + [0, 0, 0, 2, 1, 2]
        flac += [0x84, 0, UInt8(tag.count >> 8), UInt8(tag.count & 255)]
        flac += tag
        check("cue inside FLAC", CueSheet.embedded(in: flac) == sheet && CueSheet.embedded(in: Array(flac.prefix(60))) == nil, "")

        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Образ", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        synth(dir.appendingPathComponent("Альбом.wav"), rate: 44100, channels: 2, seconds: 16)
        // first without the sheet, then the sheet appears
        await library.add(urls: [dir])
        let whole = library.tracks.filter { $0.fileName == "Альбом.wav" }
        check("long file", whole.count == 1 && abs((whole.first?.duration ?? 0) - 16) < 0.1, "\(whole.count)")
        try? text.write(to: dir.appendingPathComponent("Альбом.cue"), atomically: true, encoding: .utf8)
        await library.refreshFolders(quiet: true)
        let songs = library.tracks.filter { $0.fileName == "Альбом.wav" }, ids = songs.map(\.id)
        check("cut by the sheet", songs.map(\.title) == ["Перша", "Друга", "Дорожка 3"] && songs.map(\.artist) == ["Океан Ельзи", "Гість", "Океан Ельзи"] && songs.allSatisfy { $0.album == "Земля" },
              "\(songs.map(\.title)) \(songs.map(\.artist))")
        guard songs.count == 3 else { return }
        check("lengths of the songs", abs(songs[0].duration - 5) < 0.01 && abs(songs[1].duration - 5.493) < 0.01 && abs(songs[2].duration - 5.507) < 0.05, "\(songs.map(\.duration))")
        await library.refreshFolders(quiet: true)
        check("not cut twice", library.tracks.filter { $0.fileName == "Альбом.wav" }.count == 3, "")
        settings.v.gapless = true
        settings.v.crossfade = 0
        while player.repeatMode != .off { player.cycleRepeat() }
        if player.shuffle { player.toggleShuffle() }
        player.play(ids[1], from: ids)
        await wait(1.5)
        let deck = player.graph.decks.first { $0.file != nil }
        check("second song of the file", player.isPlaying && deck?.first == 5 * 44100 && abs(player.duration - 5.493) < 0.01 && abs(player.position - 1.5) < 0.5,
              String(format: "%.2f of %.2f", player.position, player.duration) + " from \(deck?.first ?? -1)")
        player.seek(to: 3)
        await wait(0.5)
        check("seek inside the song", abs(player.position - 3.5) < 0.3 && player.qi == 1, String(format: "%.2f", player.position))
        await wait(3)
        check("next song without a gap", player.qi == 2 && player.isPlaying && abs(player.position - 1) < 0.5 && abs(player.duration - 5.507) < 0.05, String(format: "qi %d at %.2f", player.qi, player.position))
        await wait(5.5)
        check("the end of the file", !player.isPlaying && player.qi == 2, "\(player.qi)")
        player.play(ids[0], from: ids)
        await wait(0.5)
        player.seek(to: 4)
        await wait(2)
        check("the song ends where the next begins", player.qi == 1 && player.isPlaying && player.position > 0.5 && player.position < 1.8, String(format: "qi %d at %.2f", player.qi, player.position))
        settings.v.crossfade = 1
        player.play(ids[0], from: ids)
        await wait(6)
        check("short songs with crossfade on", player.qi == 1 && player.isPlaying, "qi \(player.qi)")
        settings.v.crossfade = 0
        player.pause()
        for id in ids { player.analyzer.request(library.track(id) ?? songs[0], first: true) }
        for _ in 0..<60 where ids.contains(where: { library.track($0)?.wave?.count != Analysis.points }) { await wait(0.1) }
        let waves = ids.compactMap { library.track($0)?.wave }
        check("waves of the songs", waves.count == 3 && waves[0] != waves[1] && waves[1] != waves[2] && waves.allSatisfy { $0.count == Analysis.points }, "\(waves.map(\.count))")
        library.remove(Set(ids))

        // a sheet picked together with the file
        let loose = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let file = loose.appendingPathComponent("Микс.wav"), cue = loose.appendingPathComponent("Микс.cue")
        synth(file, rate: 48000, channels: 2, seconds: 13)
        try? text.replacingOccurrences(of: "Альбом.wav", with: "Микс.flac").write(to: cue, atomically: true, encoding: .utf8)
        await library.add(urls: [cue, file])
        let mix = library.tracks.filter { $0.fileName == "Микс.wav" }
        check("sheet and file together", mix.count == 3 && mix.allSatisfy { $0.cueStart != nil }, "\(mix.map(\.title))")
        library.edit(mix[0].id, title: "X", artist: "Y", album: "Z")
        await library.restoreTags(mix[0].id)
        check("title back from the sheet", library.track(mix[0].id)?.title == "Перша" && library.track(mix[0].id)?.album == "Земля", library.track(mix[0].id)?.title ?? "")
        library.remove(Set(mix.map(\.id)))
        try? FileManager.default.removeItem(at: dir)
    }
}
#endif
