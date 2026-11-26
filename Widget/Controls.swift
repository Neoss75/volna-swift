import AppIntents
import SwiftUI
import WidgetKit

/// Buttons for the Control Centre and the lock screen. The intents run inside the app, like the widget buttons.
struct PlayPauseControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.neoss75.volna.swift.playpause") {
            ControlWidgetButton(action: ToggleIntent()) {
                Label("Играть или пауза", systemImage: "playpause.fill")
            }
        }
        .displayName("Играть или пауза")
        .description("Волна: играть или пауза.")
    }
}

struct NextSongControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.neoss75.volna.swift.next") {
            ControlWidgetButton(action: NextIntent()) {
                Label("Следующая песня", systemImage: "forward.end.fill")
            }
        }
        .displayName("Следующая песня")
        .description("Волна: следующая песня.")
    }
}

struct PresetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.neoss75.volna.swift.preset") {
            ControlWidgetButton(action: NextPresetIntent()) {
                Label("Эквалайзер", systemImage: "slider.vertical.3")
            }
        }
        .displayName("Эквалайзер")
        .description("Волна: следующая настройка эквалайзера.")
    }
}
