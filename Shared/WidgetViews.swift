import AppIntents
import SwiftUI

private let widgetFg = Color(red: 0.925, green: 0.914, blue: 0.886)
private let widgetMuted = Color(red: 0.584, green: 0.612, blue: 0.682)
let widgetBackground = LinearGradient(colors: [Color(red: 0.137, green: 0.153, blue: 0.212), Color(red: 0.067, green: 0.075, blue: 0.102)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)

struct WidgetCover: View {
    let image: UIImage?
    let accent: Color

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [accent.opacity(0.9), accent.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "waveform").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct WidgetPlayButton: View {
    let state: WidgetState
    var size: CGFloat = 40

    var body: some View {
        Button(intent: ToggleIntent()) {
            Image(systemName: state.playing ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.42))
                .foregroundStyle(Color(red: 0.08, green: 0.07, blue: 0.04))
                .frame(width: size, height: size)
                .background(Circle().fill(state.accentColor))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.playing ? tr("Пауза") : tr("Играть"))
    }
}

struct WidgetTitles: View {
    let state: WidgetState

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(state.title.isEmpty ? tr("Волна") : state.title).font(.system(size: 14, weight: .bold)).foregroundStyle(widgetFg)
            Text(state.title.isEmpty ? tr("Ничего не играет") : state.artist.isEmpty ? tr("Неизвестный исполнитель") : state.artist)
                .font(.system(size: 12))
                .foregroundStyle(widgetMuted)
        }
        .lineLimit(1)
    }
}

struct SmallWidgetView: View {
    let state: WidgetState
    let cover: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                WidgetCover(image: cover, accent: state.accentColor).frame(width: 66, height: 66)
                Spacer()
                WidgetPlayButton(state: state, size: 42)
            }
            Spacer(minLength: 0)
            WidgetTitles(state: state)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct MediumWidgetView: View {
    let state: WidgetState
    let cover: UIImage?

    var body: some View {
        HStack(spacing: 16) {
            WidgetCover(image: cover, accent: state.accentColor).aspectRatio(1, contentMode: .fit)
            VStack(alignment: .leading, spacing: 8) {
                WidgetTitles(state: state)
                HStack(spacing: 20) {
                    Button(intent: PreviousIntent()) { icon("backward.end.fill") }.accessibilityLabel(tr("Предыдущая"))
                    WidgetPlayButton(state: state, size: 46)
                    Button(intent: NextIntent()) { icon("forward.end.fill") }.accessibilityLabel(tr("Следующая"))
                }
                .buttonStyle(.plain)
                if let p = state.preset {
                    Button(intent: NextPresetIntent()) {
                        Label(tr("Эквалайзер: ") + p, systemImage: "slider.vertical.3")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(widgetFg)
                            .lineLimit(1)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("Следующая настройка эквалайзера"))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 20)).foregroundStyle(widgetFg).frame(width: 34, height: 44)
    }
}

/// Lock screen.
struct LockWidgetView: View {
    let state: WidgetState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: state.playing ? "waveform" : "play.fill").font(.system(size: 18, weight: .semibold))
            VStack(alignment: .leading, spacing: 0) {
                Text(state.title.isEmpty ? tr("Волна") : state.title).font(.system(size: 14, weight: .semibold))
                Text(state.title.isEmpty ? tr("Ничего не играет") : state.artist).font(.system(size: 12)).opacity(0.8)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}
