import MediaPlayer
import UIKit

/// Lock screen, Control Centre and headphone buttons.
@MainActor
final class NowPlaying {
    private var registered = false
    private var artworkFor: UIImage?
    private var artwork: MPMediaItemArtwork?

    func registerCommands(for player: Player) {
        guard !registered else { return }
        registered = true
        let c = MPRemoteCommandCenter.shared()
        func on(_ command: MPRemoteCommand, _ action: @escaping @MainActor (Player) -> Void) {
            command.isEnabled = true
            command.addTarget { [weak player] _ in
                MainActor.assumeIsolated { if let player { action(player) } }
                return .success
            }
        }
        on(c.playCommand) { $0.resume() }
        on(c.pauseCommand) { $0.pause() }
        on(c.togglePlayPauseCommand) { $0.toggle() }
        on(c.nextTrackCommand) { $0.next() }
        on(c.previousTrackCommand) { $0.previous() }
        c.changePlaybackPositionCommand.isEnabled = true
        c.changePlaybackPositionCommand.addTarget { [weak player] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let time = e.positionTime
            MainActor.assumeIsolated { player?.seek(to: time) }
            return .success
        }
        // no "±10 seconds" buttons: the lock screen shows previous / next instead
        for command in [c.skipForwardCommand, c.skipBackwardCommand, c.seekForwardCommand, c.seekBackwardCommand] as [MPRemoteCommand] {
            command.isEnabled = false
        }
    }

    func update(track: Track?, artwork image: UIImage?, elapsed: Double, duration: Double, rate: Double) {
        let center = MPNowPlayingInfoCenter.default()
        guard let track else {
            center.nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: rate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if !track.artist.isEmpty { info[MPMediaItemPropertyArtist] = track.artist }
        if !track.album.isEmpty { info[MPMediaItemPropertyAlbumTitle] = track.album }
        if artworkFor !== image {
            artworkFor = image
            artwork = image.map(makeArtwork)
        }
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        center.nowPlayingInfo = info
    }
}

/// Outside the main actor on purpose: iOS asks for the picture from a background thread.
private func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
    MPMediaItemArtwork(boundsSize: image.size) { _ in image }
}
