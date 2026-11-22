import SwiftUI

/// Lives in the tab bar accessory: the system draws the glass capsule around it.
struct MiniPlayer: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: Player
    let open: () -> Void
    let addMusic: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if let track = player.currentTrack {
                ArtworkView(track: track, corner: 8, iconSize: 13)
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text(track.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(track.subtitle).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer(minLength: 4)
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 38, height: 38)
                }
                .accessibilityLabel(player.isPlaying ? "Пауза" : "Играть")
                Button { player.next() } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                        .frame(width: 34, height: 38)
                }
                .accessibilityLabel("Следующая")
            } else if library.tracks.isEmpty {
                Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
                Text("Добавить музыку").font(.subheadline.weight(.semibold))
                Spacer()
            } else {
                Image(systemName: "music.note").foregroundStyle(Theme.accent)
                Text("Ничего не играет").font(.subheadline.weight(.semibold))
                Spacer()
                Button { player.resume() } label: {
                    Image(systemName: "play.fill").font(.title3).frame(width: 38, height: 38)
                }
                .accessibilityLabel("Играть")
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.fg)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            if player.currentTrack != nil { open() } else if library.tracks.isEmpty { addMusic() }
        }
    }
}

/// The big player: blurred cover behind, glass buttons on top.
struct NowPlayingView: View {
    @EnvironmentObject private var player: Player
    @Environment(\.dismiss) private var dismiss
    @State private var showEQ = false

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down").font(.title3.weight(.semibold)).frame(width: 30, height: 30)
                }
                .accessibilityLabel("Свернуть")
                Spacer()
                Button { showEQ = true } label: {
                    Image(systemName: "slider.vertical.3").font(.title3.weight(.semibold)).frame(width: 30, height: 30)
                }
                .accessibilityLabel("Эквалайзер")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .foregroundStyle(Theme.fg)

            Spacer(minLength: 0)

            ArtworkView(track: player.currentTrack, corner: 26, iconSize: 90)
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: .black.opacity(0.5), radius: 30, y: 16)
                .scaleEffect(player.isPlaying ? 1 : 0.9)
                .animation(.spring(duration: 0.45, bounce: 0.3), value: player.isPlaying)

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

            GlassEffectContainer(spacing: 28) {
                HStack(spacing: 28) {
                    Button { player.previous() } label: {
                        Image(systemName: "backward.fill").font(.system(size: 24)).frame(width: 52, height: 52)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Предыдущая")

                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.accentInk)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 72, height: 72)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.accent)
                    .accessibilityLabel(player.isPlaying ? "Пауза" : "Играть")

                    Button { player.next() } label: {
                        Image(systemName: "forward.fill").font(.system(size: 24)).frame(width: 52, height: 52)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Следующая")
                }
                .buttonBorderShape(.circle)
                .foregroundStyle(Theme.fg)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 12)
        .background { Backdrop(track: player.currentTrack) }
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showEQ) { EQView(showsDone: true) }
    }
}

/// The song's cover, heavily blurred, so the glass has colour to refract.
struct Backdrop: View {
    let track: Track?

    var body: some View {
        ZStack {
            Theme.bg
            if let image = track.flatMap(artworkImage) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .blur(radius: 70)
                    .opacity(0.7)
            } else {
                RadialGradient(colors: [Theme.accent.opacity(0.25), .clear], center: .top, startRadius: 0, endRadius: 520)
            }
            LinearGradient(colors: [.black.opacity(0.1), Theme.bg.opacity(0.85)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
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
