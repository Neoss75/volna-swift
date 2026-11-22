import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: Player
    @State private var showImporter = false
    @State private var showPlayer = false
    @State private var showEQ = false

    var body: some View {
        NavigationStack {
            Group {
                if library.tracks.isEmpty {
                    emptyState
                } else {
                    trackList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Волна")
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showEQ = true } label: {
                        Image(systemName: "slider.vertical.3")
                    }
                    .accessibilityLabel("Эквалайзер")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showImporter = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Добавить музыку")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if player.currentTrack != nil {
                    MiniPlayer { showPlayer = true }
                }
            }
            .overlay {
                if library.isImporting {
                    ProgressView("Читаю теги…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                Task { await library.add(urls: urls) }
            }
        }
        .sheet(isPresented: $showPlayer) {
            NowPlayingView()
        }
        .sheet(isPresented: $showEQ) {
            EQView()
        }
        .alert("Не получилось", isPresented: Binding(
            get: { player.errorMessage != nil },
            set: { if !$0 { player.errorMessage = nil } }
        )) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(player.errorMessage ?? "")
        }
        .alert("Готово", isPresented: Binding(
            get: { library.notice != nil },
            set: { if !$0 { library.notice = nil } }
        )) {
            Button("Хорошо", role: .cancel) {}
        } message: {
            Text(library.notice ?? "")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Пока нет песен", systemImage: "music.note")
        } description: {
            Text("Добавьте аудиофайлы из «Файлов». Они останутся на своём месте: «Волна» их не копирует.")
        } actions: {
            Button {
                showImporter = true
            } label: {
                Text("Добавить музыку").fontWeight(.semibold).padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .foregroundStyle(Theme.accentInk)
        }
    }

    private var trackList: some View {
        List {
            ForEach(library.tracks) { track in
                Button {
                    player.play(track)
                } label: {
                    TrackRow(track: track, isCurrent: track.id == player.currentID, isPlaying: player.isPlaying)
                }
                .buttonStyle(.plain)
                .listRowBackground(Theme.bg)
                .listRowSeparatorTint(Theme.line)
                .swipeActions {
                    Button(role: .destructive) {
                        library.remove(id: track.id)
                    } label: {
                        Label("Убрать", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct TrackRow: View {
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(track: track, corner: 8, iconSize: 18)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isCurrent ? Theme.accent : Theme.fg)
                    .lineLimit(1)
                Text(track.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if isCurrent {
                Image(systemName: "waveform")
                    .foregroundStyle(Theme.accent)
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)
            } else {
                Text(formatTime(track.duration))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct ArtworkView: View {
    let track: Track?
    var corner: CGFloat = 8
    var iconSize: CGFloat = 18

    var body: some View {
        ZStack {
            if let track, track.hasArtwork, let image = ArtworkStore.image(for: track.id) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [Theme.raise, Theme.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(Theme.accent.opacity(0.85))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}
