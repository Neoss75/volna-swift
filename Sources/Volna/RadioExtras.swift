import UIKit

/// The cover and the lyrics of the song a station is playing now. Off by default: only with the switch on
/// are the artist and the title sent to iTunes and lrclib.net.
@MainActor
final class RadioExtras: ObservableObject {
    enum State: Equatable {
        /// The switch is off.
        case off
        /// The station does not say what is playing, or says only the title.
        case unknown
        case searching
        case done
        /// No internet: tried again with the next song.
        case failed
    }

    @Published private(set) var state = State.off
    @Published private(set) var cover: UIImage?
    @Published private(set) var lyrics: String?
    /// The song the cover and the lyrics belong to.
    @Published private(set) var song: (artist: String, title: String)?
    var onChange: (() -> Void)?

    private struct Found {
        let cover: UIImage?
        let lyrics: String?
    }

    private let covers: CoverFinder
    private let settings: Settings
    private var key = ""
    private var task: Task<Void, Never>?
    private var memo: [String: Found] = [:]
    private var order: [String] = []

    #if DEBUG
    /// Screenshots in the cloud: these instead of the internet.
    static var fake: (UIImage?, String?)?
    #endif

    init(covers: CoverFinder, settings: Settings) {
        self.covers = covers
        self.settings = settings
    }

    /// Called with every change of what the player shows; nil when the radio is off.
    func update(_ now: (artist: String, title: String)?) {
        guard settings.v.radioExtras else { return reset(.off) }
        guard let now, !now.artist.isEmpty, !now.title.isEmpty, !Self.isNotSong(now) else { return reset(.unknown) }
        let k = SongReading.normal(now.artist) + "|" + SongReading.normal(now.title)
        guard k != key else { return }
        key = k
        song = now
        cover = nil
        lyrics = nil
        task?.cancel()
        if let f = memo[k] { return show(f) }
        state = .searching
        task = Task { [weak self] in
            // stations sometimes send the name twice in a row with a small fix: wait a moment first
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let self else { return }
            await self.search(now, k)
        }
    }

    private func search(_ now: (artist: String, title: String), _ k: String) async {
        #if DEBUG
        if let fake = Self.fake { return remember(Found(cover: fake.0, lyrics: fake.1.map(Self.plain)), k) }
        #endif
        let t = Track(id: UUID(), bookmark: Data(), path: "", title: now.title, artist: now.artist, album: "", duration: 0, hasArtwork: false)
        var failed = false
        var words: String?
        do {
            words = try await LyricsSearch.find(t).map { Self.plain($0.text) }
        } catch {
            failed = true
        }
        guard key == k, !Task.isCancelled else { return }
        lyrics = words
        var image: UIImage?
        do {
            if let best = try await covers.candidates(t, thorough: false).first(where: \.sure), let url = best.url(600) {
                let (raw, response) = try await URLSession.shared.data(from: url)
                if (response as? HTTPURLResponse)?.statusCode == 200, let data = MetadataReader.downscale(raw) { image = UIImage(data: data) }
            }
        } catch {
            failed = true
        }
        guard key == k, !Task.isCancelled else { return }
        if failed, words == nil, image == nil {
            state = .failed
            // the next time the same song comes, try again
            key = ""
            return
        }
        remember(Found(cover: image, lyrics: words), k)
    }

    private func remember(_ f: Found, _ k: String) {
        memo[k] = f
        order.append(k)
        if order.count > 40 { memo[order.removeFirst()] = nil }
        guard key == k else { return }
        show(f)
    }

    private func show(_ f: Found) {
        cover = f.cover
        lyrics = f.lyrics
        state = .done
        onChange?()
    }

    private func reset(_ s: State) {
        guard state != s || !key.isEmpty else { return }
        task?.cancel()
        let had = cover != nil
        key = ""
        song = nil
        cover = nil
        lyrics = nil
        state = s
        if had { onChange?() }
    }

    /// The radio cannot follow the timing of the lines: when the song began is not known.
    static func plain(_ text: String) -> String {
        LyricsParser.plain(text.replacingOccurrences(of: #"\[\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?\]"#, with: "", options: .regularExpression))
            .components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
    }

    /// News, jingles and ads: not worth a search.
    static func isNotSong(_ s: (artist: String, title: String)) -> Bool {
        let all = (s.artist + " " + s.title).lowercased()
        return ["реклама", "реклами", "новости", "новини", "advert", "commercial", "jingle", "джингл"].contains { all.contains($0) }
    }
}
