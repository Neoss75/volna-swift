import SwiftUI

enum Panel: String, Identifiable {
    case list, queue, eq, fx, stats
    var id: String { rawValue }
}

enum ImportKind { case files, folder }

enum Prompt: Equatable {
    case newPlaylist(UUID?)
    case rename(UUID, String)
}

/// What is open on the screen right now.
@MainActor
final class UIState: ObservableObject {
    @Published var panel: Panel? { didSet { if panel != .fx { settingsPath = [] } } }
    @Published var settingsPath: [SettingsPage] = []
    @Published var importing: ImportKind?
    @Published var prompt: Prompt?
    @Published var coverFor: UUID?
    @Published var editing: UUID?
    @Published var listTab = ListTab.songs
    @Published var collection = SongCollection.all
    /// The full-screen visualisation is shown.
    @Published var saver = false
    private(set) var lastTouch = Date()
    private(set) var touching = false

    var nothingOpen: Bool { panel == nil && importing == nil && prompt == nil && coverFor == nil && editing == nil }

    func touch(_ down: Bool) {
        touching = down
        lastTouch = Date()
    }

    func add(_ kind: ImportKind) {
        importing = kind
    }
}

@main
struct VolnaApp: App {
    @StateObject private var library: Library
    @StateObject private var settings: Settings
    @StateObject private var stats: Stats
    @StateObject private var covers: CoverFinder
    @StateObject private var player: Player
    @StateObject private var ui = UIState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let library = Library(), settings = Settings(), stats = Stats()
        let covers = CoverFinder(library: library, settings: settings)
        _library = StateObject(wrappedValue: library)
        _settings = StateObject(wrappedValue: settings)
        _stats = StateObject(wrappedValue: stats)
        _covers = StateObject(wrappedValue: covers)
        // made right now, not with the first screen: Siri and the widget may start the app without any screen
        let player = Player(library: library, settings: settings, stats: stats, covers: covers)
        _player = StateObject(wrappedValue: player)
        SiriBridge.library = library
        SiriBridge.player = player
    }

    var body: some Scene {
        WindowGroup {
            PlayerScreen()
                .environmentObject(library)
                .environmentObject(settings)
                .environmentObject(stats)
                .environmentObject(covers)
                .environmentObject(player)
                .environmentObject(player.clock)
                .environmentObject(player.analyzer)
                .environmentObject(ui)
                .environmentObject(Toaster.shared)
                .preferredColorScheme(settings.colorScheme)
                .tint(settings.accent)
            #if DEBUG
                .task { await Demo.run(library: library, player: player, settings: settings, ui: ui) }
            #endif
        }
        .onChange(of: library.tracks.count) { _, _ in VolnaShortcuts.updateAppShortcutParameters() }
        .onChange(of: library.playlists.count) { _, _ in VolnaShortcuts.updateAppShortcutParameters() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { VolnaShortcuts.updateAppShortcutParameters() }
            if phase == .active, settings.v.refreshFolders {
                Task { await library.refreshFolders(quiet: true) }
            }
            if phase != .active {
                player.save()
                library.saveNow()
                stats.flush(keepTicking: true)
            }
        }
    }
}
