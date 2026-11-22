import SwiftUI

/// The bar above the bottom edge: cover, title, play/pause, next. Tap opens the big player.
struct MiniPlayer: View {
    @EnvironmentObject private var player: Player
    let open: () -> Void

    var body: some View {
        if let track = player.currentTrack {
            VStack(spacing: 0) {
                ProgressLine(clock: player.clock, duration: player.duration)
                HStack(spacing: 12) {
                    ArtworkView(track: track, corner: 6, iconSize: 16)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(track.subtitle).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(player.isPlaying ? "Пауза" : "Играть")
                    Button { player.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .frame(width: 40, height: 44)
                    }
                    .accessibilityLabel("Следующая")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture(perform: open)
            }
            .foregroundStyle(Theme.fg)
            .background(Theme.surface.opacity(0.75))
            .background(.ultraThinMaterial)
        }
    }
}

struct ProgressLine: View {
    @ObservedObject var clock: PlaybackClock
    let duration: Double

    var body: some View {
        GeometryReader { geo in
            let fraction = duration > 0 ? min(max(clock.time / duration, 0), 1) : 0
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.line)
                Rectangle().fill(Theme.accent).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 2)
    }
}

/// The big player screen.
struct NowPlayingView: View {
    @EnvironmentObject private var player: Player
    @Environment(\.dismiss) private var dismiss
    @State private var showEQ = false

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Свернуть")
                Spacer()
                Button { showEQ = true } label: {
                    Image(systemName: "slider.vertical.3").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Эквалайзер")
            }
            .font(.title3)
            .foregroundStyle(Theme.fg)

            Spacer(minLength: 0)

            ArtworkView(track: player.currentTrack, corner: 22, iconSize: 90)
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: .black.opacity(0.45), radius: 24, y: 12)

            VStack(spacing: 6) {
                Text(player.currentTrack?.title ?? "—")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.fg)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(player.currentTrack?.subtitle ?? "")
                    .font(.body)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }

            SeekBar(clock: player.clock, duration: player.duration) { player.seek(to: $0) }

            HStack(spacing: 46) {
                Button { player.previous() } label: {
                    Image(systemName: "backward.fill").font(.system(size: 30))
                }
                .accessibilityLabel("Предыдущая")
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.accentInk)
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(Theme.accent))
                }
                .accessibilityLabel(player.isPlaying ? "Пауза" : "Играть")
                Button { player.next() } label: {
                    Image(systemName: "forward.fill").font(.system(size: 30))
                }
                .accessibilityLabel("Следующая")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.fg)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showEQ) { EQView() }
    }
}

struct SeekBar: View {
    @ObservedObject var clock: PlaybackClock
    let duration: Double
    let onSeek: (Double) -> Void
    @State private var dragging: Double?

    var body: some View {
        let upper = max(duration, 0.01)
        let shown = min(dragging ?? clock.time, upper)
        VStack(spacing: 4) {
            Slider(
                value: Binding(get: { shown }, set: { dragging = $0 }),
                in: 0...upper,
                onEditingChanged: { editing in
                    if !editing, let value = dragging {
                        onSeek(value)
                        dragging = nil
                    }
                }
            )
            .tint(Theme.accent)
            HStack {
                Text(formatTime(shown))
                Spacer()
                Text("−" + formatTime(max(duration - shown, 0)))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Theme.muted)
        }
    }
}
