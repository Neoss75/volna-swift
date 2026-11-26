import SwiftUI

/// The cover of the song on the radio when one was found, otherwise the logo of the station.
struct RadioCover: View {
    @EnvironmentObject private var extras: RadioExtras
    let station: Station
    var corner: CGFloat = 10
    var letter: CGFloat = 16
    /// A small logo of the station in the corner of the found cover.
    var badge = false

    var body: some View {
        if let image = extras.cover {
            GeometryReader { geo in
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        if badge {
                            let s = max(28, geo.size.width * 0.2)
                            StationLogo(station: station, corner: s * 0.24, letter: s * 0.4)
                                .frame(width: s, height: s)
                                .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                                .padding(geo.size.width * 0.04)
                        }
                    }
            }
            .transition(.opacity)
        } else {
            StationLogo(station: station, corner: corner, letter: letter)
        }
    }
}

/// The lyrics of the song the station is playing now, without timing: when the song began is not known.
struct RadioLyricsView: View {
    @EnvironmentObject private var extras: RadioExtras
    @EnvironmentObject private var settings: Settings

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text((extras.lyrics == nil ? tr("текст песни") : "lrclib.net").uppercased())
                    .font(.mono(10))
                    .kerning(0.6)
                    .foregroundStyle(Theme.muted)
                Spacer()
                Button { settings.v.lyricsOn = false } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted).frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Закрыть текст"))
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.raise, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder private var content: some View {
        switch extras.state {
        case .off:
            VStack(spacing: 14) {
                Spacer()
                Text(tr("Волна может найти текст и обложку песни, которая сейчас играет на радио."))
                    .foregroundStyle(Theme.fg)
                    .multilineTextAlignment(.center)
                Button(tr("Включить")) { settings.v.radioExtras = true }
                    .buttonStyle(.glassProminent)
                    .foregroundStyle(Theme.accentInk)
                Text(tr("В iTunes и на lrclib.net отправятся только исполнитель и название песни. Выключить можно в настройках, в разделе «Обложки»."))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.horizontal, 20)
        case .unknown:
            message(tr("Станция не сообщает, какая песня сейчас играет."))
        case .searching:
            Spacer()
            ProgressView(tr("Ищу текст на lrclib.net…"))
            Spacer()
        case .failed:
            message(tr("Не удалось связаться с lrclib.net. Проверьте интернет"))
        case .done:
            if let words = extras.lyrics {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let song = extras.song {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title).font(.display(19, .semibold)).foregroundStyle(Theme.fg)
                                Text(song.artist).font(.system(size: 14)).foregroundStyle(Theme.muted)
                            }
                        }
                        Text(words)
                            .font(.system(size: 16))
                            .lineSpacing(6)
                            .foregroundStyle(Theme.fg)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
            } else {
                message(tr("Текста для этой песни не нашлось."))
            }
        }
    }

    private func message(_ s: String) -> some View {
        VStack {
            Spacer()
            Text(s).foregroundStyle(Theme.muted).multilineTextAlignment(.center).padding(.horizontal, 20)
            Spacer()
        }
    }
}
