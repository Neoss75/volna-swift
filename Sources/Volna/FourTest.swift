#if DEBUG
import AVFoundation
import Foundation

extension Demo {
    /// Mono, the like from outside the app, the lyrics found by themselves.
    static func fourTest(_ library: Library, _ player: Player, _ settings: Settings, _ check: (String, Bool, String) -> Void, _ wait: (Double) async -> Void) async {
        let ids = library.tracks.map(\.id)
        guard ids.count >= 3 else { return check("four: songs", false, "") }
        player.play(ids[0], from: ids)
        await wait(1)
        settings.v.mono = true
        await wait(1)
        let p1 = player.position
        check("mono", player.graph.outChannels == 1 && player.graph.mono && player.isPlaying, "\(player.graph.outChannels)")
        await wait(1)
        check("mono plays on", player.position > p1 + 0.5, String(format: "%.2f → %.2f", p1, player.position))
        settings.v.mono = false
        check("stereo again", player.graph.outChannels == 2, "\(player.graph.outChannels)")

        let was = library.isFavourite(ids[0])
        PlayerBridge.like?()
        check("like from outside", library.isFavourite(ids[0]) != was, "")
        PlayerBridge.like?()
        check("like again", library.isFavourite(ids[0]) == was, "")

        // the lyrics: a song without them, the switch on
        let t = ids[2], own = LyricsStore.load(t)
        LyricsStore.delete(t)
        library.update(t) { $0.lyricsTried = nil }
        var asked = 0
        LyricsAuto.finder = { _ in
            asked += 1
            return Lyrics(text: "Знайдений текст", source: "lrclib.net")
        }
        player.play(t, from: ids)
        await wait(1)
        check("lyrics not looked for when off", asked == 0 && LyricsStore.load(t) == nil, "\(asked)")
        settings.v.lyricsAuto = true
        player.play(ids[1], from: ids)
        player.play(t, from: ids)
        await wait(1)
        check("lyrics found by themselves", asked == 1 && LyricsStore.load(t)?.text == "Знайдений текст" && library.track(t)?.lyricsTried == true, "\(asked)")
        LyricsStore.delete(t)
        player.play(ids[1], from: ids)
        player.play(t, from: ids)
        await wait(1)
        check("lyrics asked once", asked == 1, "\(asked)")
        settings.v.lyricsAuto = false
        LyricsAuto.finder = { try await LyricsSearch.find($0) }
        library.update(t) { $0.lyricsTried = nil }
        if let own { LyricsStore.save(own, id: t) }
        player.pause()
    }
}
#endif
