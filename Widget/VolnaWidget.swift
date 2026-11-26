import SwiftUI
import WidgetKit

struct VolnaEntry: TimelineEntry {
    let date: Date
    let state: WidgetState
    let cover: UIImage?
}

struct VolnaProvider: TimelineProvider {
    private func entry() -> VolnaEntry {
        let s = WidgetState.load()
        Lang.apply(s.lang ?? "system")
        return VolnaEntry(date: Date(), state: s, cover: WidgetState.cover())
    }

    func placeholder(in context: Context) -> VolnaEntry {
        VolnaEntry(date: Date(), state: WidgetState(title: tr("Название песни"), artist: tr("Исполнитель")), cover: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (VolnaEntry) -> Void) { completion(entry()) }

    /// The app asks for a new picture whenever the song changes, so there is no schedule.
    func getTimeline(in context: Context, completion: @escaping (Timeline<VolnaEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .never))
    }
}

struct VolnaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VolnaEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium: MediumWidgetView(state: entry.state, cover: entry.cover)
            case .accessoryRectangular: LockWidgetView(state: entry.state)
            default: SmallWidgetView(state: entry.state, cover: entry.cover)
            }
        }
        .containerBackground(for: .widget) { widgetBackground }
    }
}

@main
struct VolnaWidgets: WidgetBundle {
    var body: some Widget {
        VolnaWidget()
        PlayPauseControl()
        NextSongControl()
        PresetControl()
        LikeControl()
    }
}

struct VolnaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VolnaNowPlaying", provider: VolnaProvider()) { VolnaWidgetView(entry: $0) }
            .configurationDisplayName("Сейчас играет")
            .description("Песня и кнопки плеера «Волна».")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
