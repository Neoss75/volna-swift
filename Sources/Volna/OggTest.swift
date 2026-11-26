#if DEBUG
import AVFoundation
import Foundation

extension Demo {
    /// Real Ogg Vorbis and Ogg Opus files, made on the check machine (scripts/simulator.sh puts them into Documents):
    /// their tags and length, decoding, playing, and the same files as a radio station.
    static func oggTest(_ library: Library, _ player: Player, _ stations: Stations,
                        _ check: (String, Bool, String) -> Void, _ wait: (Double) async -> Void) async {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let vorbis = docs.appendingPathComponent("Тест Vorbis.ogg"), opus = docs.appendingPathComponent("Тест Opus.opus")
        guard FileManager.default.fileExists(atPath: vorbis.path), FileManager.default.fileExists(atPath: opus.path) else {
            return check("ogg test files", false, "missing: the check machine could not make them")
        }

        // pages and packets, on a page cut in two
        let pageData = (try? Data(contentsOf: vorbis)) ?? Data()
        var pages = OggPages()
        var whole = OggPages()
        let all = whole.feed(pageData).count
        let half = pages.feed(pageData.prefix(100)).count, rest = pages.feed(pageData.dropFirst(100)).count
        check("ogg pages", half + rest == all && all > 3 && pages.junk == 0, "\(half) + \(rest) of \(all), \(pages.junk)")
        check("opus packet length", OggDecoder.opusFrames(Data([0xFC])) == 960 && OggDecoder.opusFrames(Data([0x0A])) == 1920
              && OggDecoder.opusFrames(Data([0x13, 3])) == 5760, "")

        for (url, kind, title) in [(vorbis, "OGG", "Тест Vorbis"), (opus, "OPUS", "Тест Opus")] {
            let m = OggInfo.meta(url)
            check("ogg tags \(kind)", m?.title == title && m?.artist == "Волна" && m?.header.ext == kind, "\(m?.title ?? "-") \(m?.artist ?? "-") \(m?.header.ext ?? "-")")
            check("ogg length \(kind)", abs((m?.duration ?? 0) - 3) < 0.05, "\(m?.duration ?? 0)")
            let id = UUID()
            let decoded = try? OggFile.playable(url, id: id), file = decoded.flatMap { try? AVAudioFile(forReading: $0) }
            let seconds = file.map { Double($0.length) / $0.processingFormat.sampleRate } ?? 0
            check("ogg decoded \(kind)", abs(seconds - 3) < 0.05, String(format: "%.3f s", seconds))
            // the decoded sound is the tone, not silence
            if let file, let b = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4800) {
                file.framePosition = 24000
                try? file.read(into: b)
                let peak = (0..<Int(b.frameLength)).map { abs(b.floatChannelData?[0][$0] ?? 0) }.max() ?? 0
                check("ogg sound \(kind)", peak > 0.2 && peak < 1.1, "\(peak)")
            }
            OggFile.forget(id)
        }

        let before = Set(library.tracks.map(\.id))
        await library.add(urls: [vorbis, opus])
        let added = library.tracks.filter { !before.contains($0.id) }
        check("ogg added", added.map(\.kind).sorted() == ["OGG", "OPUS"] && added.allSatisfy { abs($0.duration - 3) < 0.05 }, "\(added.map(\.formatLine))")
        for t in added {
            player.play(t.id, from: added.map(\.id))
            var ok = false
            for _ in 0..<40 where !ok {
                await wait(0.25)
                ok = player.isPlaying && player.position > 0.5
            }
            check("ogg plays \(t.kind)", ok && t.bad != true, String(format: "%.2f of %.2f", player.position, player.duration))
        }
        player.pause()
        library.remove(Set(added.map(\.id)))
        for t in added { OggFile.forget(t.id) }

        // the radio: the file sent again and again, every round is a new stream with its own name
        guard let server = await makeServer() else { return check("ogg radio server", false, "") }
        server.ogg["/vorbis"] = (try? Data(contentsOf: vorbis)) ?? Data()
        server.ogg["/opus"] = (try? Data(contentsOf: opus)) ?? Data()
        let live = player.live
        for (path, kind) in [("/vorbis", "Vorbis"), ("/opus", "Opus")] {
            let s = Station(name: "Ogg " + kind, url: server.url(path))
            stations.add([s])
            player.play(s, from: [s.id])
            var ok = false
            for _ in 0..<60 where !ok {
                await wait(0.25)
                ok = live.state == .playing && live.info.kind == kind
            }
            check("ogg radio \(kind)", ok && live.title == "Волна - Тест " + kind, "\(live.state) \(live.info.kind) \(live.title)")
            await wait(4)
            check("ogg radio goes on \(kind)", live.state == .playing && live.stored > 0.5, String(format: "%.1f s", live.stored))
            let probe = await StationProbe.ask(s, StationProbe.session())
            check("ogg station check \(kind)", probe.error == nil && probe.facts?.kind == kind, probe.facts?.text ?? "\(String(describing: probe.error))")
            stations.remove([s.id])
        }
        player.pause()
    }
}
#endif
