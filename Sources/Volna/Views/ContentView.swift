import SwiftUI
import UniformTypeIdentifiers

/// Tabs at the bottom (Liquid Glass tab bar), the mini player floats above them.
struct ContentView: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: Player
    @State private var showImporter = false
    @State private var showPlayer = false
    @State private var query = ""
    @Namespace private var playerZoom

    var body: some View {
        TabView {
            Tab("Песни", systemImage: "music.note.list") {
                NavigationStack {
                    LibraryScreen(showImporter: $showImporter)
                }
            }
            Tab("Эквалайзер", systemImage: "slider.vertical.3") {
                EQView(showsDone: false)
            }
            Tab(role: .search) {
                NavigationStack {
                    SearchScreen(query: $query)
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            MiniPlayer(
                open: { showPlayer = true },
                addMusic: { showImporter = true }
            )
            .matchedTransitionSource(id: "player", in: playerZoom)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                Task { await library.add(urls: urls) }
            }
        }
        .sheet(isPresented: $showPlayer) {
            NowPlayingView()
                .navigationTransition(.zoom(sourceID: "player", in: playerZoom))
        }
        .overlay {
            if library.isImporting {
                ProgressView("Читаю теги…")
                    .padding(22)
                    .glassEffect(.regular, in: .rect(cornerRadius: 22))
            }
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
}

struct LibraryScreen: View {
    @EnvironmentObject private var library: Library
    @Binding var showImporter: Bool

    var body: some View {
        Group {
            if library.tracks.isEmpty {
                ContentUnavailableView {
                    Label("Пока нет песен", systemImage: "music.note")
                } description: {
                    Text("Добавьте аудиофайлы из «Файлов». Они останутся на своём месте: «Волна» их не копирует.")
                } actions: {
                    Button {
                        showImporter = true
                    } label: {
                        Text("Добавить музыку")
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.accentInk)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.accent)
                }
            } else {
                TrackList(tracks: library.tracks)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Волна")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showImporter = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Добавить музыку")
            }
        }
    }
}

struct SearchScreen: View {
    @EnvironmentObject private var library: Library
    @Binding var query: String

    private var results: [Track] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return library.tracks.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.artist.localizedCaseInsensitiveContains(q)
                || $0.album.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        Group {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                ContentUnavailableView("Поиск по песням", systemImage: "magnifyingglass",
                                       description: Text("Название, исполнитель или альбом"))
            } else if results.isEmpty {
                ContentUnavailableView("Ничего не нашлось", systemImage: "magnifyingglass",
                                       description: Text("По запросу «\(query)» песен нет"))
            } else {
                TrackList(tracks: results)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Поиск")
        .searchable(text: $query, prompt: "Песня, исполнитель, альбом")
    }
}

struct TrackList: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: Player
    let tracks: [Track]

    var body: some View {
        List {
            ForEach(tracks) { track in
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
            ArtworkView(track: track, corner: 10, iconSize: 18)
                .frame(width: 50, height: 50)
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
            if let image = track.flatMap(artworkImage) {
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

@MainActor
func artworkImage(_ track: Track) -> UIImage? {
    track.hasArtwork ? ArtworkStore.image(for: track.id) : nil
}
