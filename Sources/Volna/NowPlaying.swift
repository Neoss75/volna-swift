import MediaPlayer
import UIKit

/// Lock screen, Control Centre, headphones and CarPlay buttons.
@MainActor
final class NowPlaying {
    private var registered = false
    private var artworkID: UUID?
    private var artwork: MPMediaItemArtwork?

    func registerCommands(for player: Player) {
        guard !registered else { return }
        registered = true
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let c = MPRemoteCommandCenter.shared()

        c.playCommand.isEnabled = true
        c.playCommand.addTarget { [weak player] _ in
            MainActor.assumeIsolated { player?.resume() }
            return .success
        }
        c.pauseCommand.isEnabled = true
        c.pauseCommand.addTarget { [weak player] _ in
            MainActor.assumeIsolated { player?.pause() }
            return .success
        }
        c.togglePlayPauseCommand.isEnabled = true
        c.togglePlayPauseCommand.addTarget { [weak player] _ in
            MainActor.assumeIsolated { player?.togglePlayPause() }
            return .success
        }
        c.nextTrackCommand.isEnabled = true
        c.nextTrackCommand.addTarget { [weak player] _ in
            MainActor.assumeIsolated { player?.next() }
            return .success
        }
        c.previousTrackCommand.isEnabled = true
        c.previousTrackCommand.addTarget { [weak player] _ in
            MainActor.assumeIsolated { player?.previous() }
            return .success
        }
        c.changePlaybackPositionCommand.isEnabled = true
        c.changePlaybackPositionCommand.addTarget { [weak player] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let time = e.positionTime
            MainActor.assumeIsolated { player?.seek(to: time) }
            return .success
        }

        // no "±10 seconds" buttons: the lock screen shows previous / next instead
        for command in [c.skipForwardCommand, c.skipBackwardCommand, c.seekForwardCommand, c.seekBackwardCommand] {
            command.isEnabled = false
        }
    }

    func update(track: Track?, artwork image: UIImage?, elapsed: Double, duration: Double, playing: Bool) {
        let center = MPNowPlayingInfoCenter.default()
        guard let track else {
            center.nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if !track.artist.isEmpty { info[MPMediaItemPropertyArtist] = track.artist }
        if !track.album.isEmpty { info[MPMediaItemPropertyAlbumTitle] = track.album }

        if artworkID != track.id {
            artworkID = track.id
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
