import SwiftUI

@main
struct VolnaApp: App {
    @StateObject private var library: Library
    @StateObject private var player: Player
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let library = Library()
        _library = StateObject(wrappedValue: library)
        _player = StateObject(wrappedValue: Player(library: library))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(player)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { player.saveState() }
        }
    }
}
