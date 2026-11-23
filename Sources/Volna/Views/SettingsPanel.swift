import SwiftUI

/// Pages of the settings, grouped on the first screen by what they are about.
enum SettingsPage: String, Hashable, CaseIterable {
    case sound, eq, loudness, playback
    case theme, viz
    case library, covers, lyrics
    case stats, about

    var title: String {
        switch self {
        case .sound: "Обработка звука"
        case .eq: "Эквалайзер"
        case .loudness: "Выравнивание громкости"
        case .playback: "Воспроизведение"
        case .theme: "Оформление"
        case .viz: "Визуализация"
        case .library: "Библиотека и файлы"
        case .covers: "Обложки"
        case .lyrics: "Тексты песен"
        case .stats: "Статистика"
        case .about: "О приложении"
        }
    }

    var icon: String {
        switch self {
        case .sound: "waveform"
        case .eq: "slider.vertical.3"
        case .loudness: "speaker.wave.2"
        case .playback: "play.circle"
        case .theme: "paintpalette"
        case .viz: "chart.bar.fill"
        case .library: "folder"
        case .covers: "photo"
        case .lyrics: "text.bubble"
        case .stats: "chart.xyaxis.line"
        case .about: "info.circle"
        }
    }

    static let groups: [(title: String, pages: [SettingsPage])] = [
        ("Аудио", [.eq, .sound, .loudness, .playback]),
        ("Графика", [.theme, .viz]),
        ("Музыка", [.library, .covers, .lyrics]),
        ("Прочее", [.stats, .about]),
    ]
}

struct SettingsPanel: View {
    @EnvironmentObject private var ui: UIState

    var body: some View {
        NavigationStack(path: $ui.settingsPath) {
            SettingsRoot()
                .navigationTitle("Настройки")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { closeButton }
                .navigationDestination(for: SettingsPage.self) { page in
                    SettingsPageView(page: page)
                        .navigationTitle(page.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { closeButton }
                }
        }
    }

    private var closeButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { ui.panel = nil } label: { Image(systemName: "xmark").foregroundStyle(Theme.fg) }
                .accessibilityLabel("Закрыть")
        }
    }
}

private struct SettingsRoot: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var stats: Stats

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(SettingsPage.groups, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.title).font(.display(14, .semibold)).foregroundStyle(Theme.fg).padding(.leading, 4)
                        VStack(spacing: 0) {
                            ForEach(group.pages, id: \.self) { page in
                                NavigationLink(value: page) { row(page) }.buttonStyle(.plain)
                                if page != group.pages.last { Divider().overlay(Theme.line).padding(.leading, 58) }
                            }
                        }
                        .background(Theme.raise, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.surface.ignoresSafeArea())
    }

    private func row(_ page: SettingsPage) -> some View {
        HStack(spacing: 12) {
            Image(systemName: page.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(settings.accent)
                .frame(width: 32, height: 32)
                .background(settings.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(page.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.fg)
                Text(summary(page)).font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            .lineLimit(1)
            Spacer(minLength: 6)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    /// What is set now, so there is no need to open the page to find out.
    private func summary(_ page: SettingsPage) -> String {
        let v = settings.v
        switch page {
        case .eq:
            return v.eqOn ? settings.preset?.name ?? "Свой" : "Выключен"
        case .sound:
            var p: [String] = []
            if v.bass > 0 { p.append("бас +" + String(format: "%g", v.bass) + " дБ") }
            if v.balance != 0 { p.append(FXFormat.balance(v.balance)) }
            p.append(v.limiter ? "лимитер включён" : "лимитер выключен")
            return p.joined(separator: " · ")
        case .loudness:
            return v.normalize ? "Включено" : "Выключено"
        case .playback:
            var p = [v.crossfade > 0 ? "кроссфейд \(Int(v.crossfade)) с" : "без кроссфейда"]
            if v.rate != 1 { p.append(FXFormat.rate(v.rate)) }
            if player.sleepAt != nil || player.sleepAfterTrack { p.append("таймер сна") }
            return p.joined(separator: " · ")
        case .theme:
            let mode = ["dark": "Тёмная", "light": "Светлая"][v.themeMode] ?? "Как в системе"
            return mode + " · " + (Accent.all.first { $0.id == v.accent }?.name ?? "")
        case .viz:
            return v.viz.name
        case .library:
            return plural(library.tracks.count, "песня", "песни", "песен") + " · " + plural(library.playlists.count, "плейлист", "плейлиста", "плейлистов")
        case .covers:
            return v.onlineArt ? "Поиск в iTunes включён" : "Поиск выключен"
        case .lyrics:
            return v.lyricsOn ? "Показан вместо обложки" : "Открывается нажатием на обложку"
        case .stats:
            return stats.data.total < 1 ? "Пока ничего не прослушано" : "Всего " + formatSpan(stats.data.total)
        case .about:
            return "Волна " + AppInfo.version
        }
    }
}

enum AppInfo {
    static var version: String {
        let i = Bundle.main.infoDictionary
        return "\(i?["CFBundleShortVersionString"] as? String ?? "") (\(i?["CFBundleVersion"] as? String ?? ""))"
    }
}

enum FXFormat {
    static func balance(_ v: Double) -> String { v == 0 ? "центр" : (v < 0 ? "Л " : "П ") + "\(Int(abs(v)))%" }
    static func rate(_ v: Double) -> String { String(format: "%.2f×", v) }
}

/// A titled block inside a settings page.
private struct Block<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title { Text(title).font(.display(14, .semibold)).foregroundStyle(Theme.fg) }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.raise, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct SettingsPageView: View {
    let page: SettingsPage

    var body: some View {
        Group {
            switch page {
            case .eq: EQPanel()
            case .stats: StatsPanel()
            default:
                ScrollView {
                    VStack(spacing: 14) {
                        switch page {
                        case .sound: SoundPage()
                        case .loudness: LoudnessPage()
                        case .playback: PlaybackPage()
                        case .theme: ThemePage()
                        case .viz: VizPage()
                        case .library: LibraryPage()
                        case .covers: CoversPage()
                        case .lyrics: LyricsPage()
                        default: AboutPage()
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Theme.surface.ignoresSafeArea())
    }
}

// MARK: - Аудио

private struct SoundPage: View {
    @EnvironmentObject private var settings: Settings

    var body: some View {
        Block("Тембр") {
            SliderRow(label: "Усиление баса", value: $settings.v.bass, range: 0...12, step: 0.5, format: formatDb)
            NavigationLink(value: SettingsPage.eq) { Text("Открыть эквалайзер") }.buttonStyle(.glass)
        }
        Block("Стерео") {
            SliderRow(label: "Баланс", value: $settings.v.balance, range: -100...100, step: 5, format: FXFormat.balance)
        }
        Block("Защита от искажений") {
            SwitchRow(label: "Лимитер", on: $settings.v.limiter)
            Hint("Убирает хрип, когда бас или эквалайзер сильно подняты.")
        }
        Button("Сбросить обработку") {
            settings.v.bass = 0
            settings.v.balance = 0
            settings.v.limiter = true
        }
        .buttonStyle(.glass)
    }
}

private struct LoudnessPage: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var analyzer: Analyzer

    var body: some View {
        Block {
            SwitchRow(label: "Выравнивать громкость между песнями", on: $settings.v.normalize)
            Hint("Плеер один раз измеряет громкость каждой песни и подстраивает её, чтобы тихие и громкие треки звучали одинаково. Сами файлы не меняются.")
        }
        Block("Измерения") {
            let done = library.tracks.filter { $0.gainDb != nil }.count
            Hint("Измерено \(done) из \(library.tracks.count)" + (analyzer.left > 0 ? " · идёт измерение…" : ""))
            if let g = player.current?.gainDb { Hint("Текущая песня: " + formatDb(g)) }
            Button("Измерить всю библиотеку") { measureAll() }.buttonStyle(.glass)
        }
    }

    private func measureAll() {
        let l = library.tracks.filter { ($0.gainDb == nil || $0.wave == nil) && $0.bad != true }
        if l.isEmpty {
            toast("Вся библиотека уже измерена")
            return
        }
        for t in l { analyzer.request(t, first: false) }
        toast("Измеряю громкость: " + plural(l.count, "песня", "песни", "песен"))
    }
}

private struct PlaybackPage: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var player: Player

    var body: some View {
        Block("Переход между песнями") {
            SliderRow(label: "Кроссфейд", value: $settings.v.crossfade, range: 0...12, step: 1) { $0 == 0 ? "выкл" : "\(Int($0)) с" }
            Hint("Конец песни плавно затухает, а следующая нарастает поверх него. Работает при автоматическом переходе. Кнопки «вперёд» и «назад» и свайп по обложке переключают сразу.")
        }
        Block("Скорость") {
            SliderRow(label: "Скорость", value: $settings.v.rate, range: 0.5...2, step: 0.05, format: FXFormat.rate)
            SwitchRow(label: "Сохранять высоту тона", on: $settings.v.keepPitch)
            if settings.v.rate != 1 {
                Button("Обычная скорость") { settings.v.rate = 1 }.buttonStyle(.glass)
            }
        }
        Block("Таймер сна") {
            Flow {
                Chip(text: "Выключен", on: player.sleepAt == nil && !player.sleepAfterTrack) { player.sleep(minutes: nil) }
                ForEach([15, 30, 45, 60], id: \.self) { m in
                    Chip(text: m == 60 ? "1 час" : "\(m) минут", on: false) {
                        player.sleep(minutes: m)
                        toast("Таймер сна: \(m) минут")
                    }
                }
                Chip(text: "После трека", on: player.sleepAfterTrack) { player.sleepAfterThisTrack() }
            }
            SleepNote()
        }
    }
}

// MARK: - Графика

private struct ThemePage: View {
    @EnvironmentObject private var settings: Settings

    var body: some View {
        Block("Тема") {
            Flow {
                ForEach([("system", "Как в системе"), ("dark", "Тёмная"), ("light", "Светлая")], id: \.0) { m in
                    Chip(text: m.1, on: settings.v.themeMode == m.0) { settings.v.themeMode = m.0 }
                }
            }
        }
        Block("Цвет") {
            Flow {
                ForEach(Accent.all) { a in
                    Chip(text: a.name, dot: a.color, on: settings.v.accent == a.id) { settings.v.accent = a.id }
                }
            }
        }
    }
}

private struct VizPage: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var player: Player

    var body: some View {
        Block("Как выглядит") {
            switch settings.v.viz {
            case .off:
                Hint("Визуализация выключена.")
            case .ring:
                HStack {
                    Spacer()
                    RingCover(track: player.current, side: 220)
                    Spacer()
                }
            default:
                VizStrip()
            }
            if !player.isPlaying, settings.v.viz != .off { Hint("Включите песню, чтобы увидеть движение.") }
        }
        Block("Режим") {
            Flow {
                ForEach(VizMode.allCases) { m in
                    Chip(text: m.name, on: settings.v.viz == m) { settings.v.viz = m }
                }
            }
            Hint("Режим также переключается нажатием на визуализацию под обложкой.")
        }
    }
}

// MARK: - Музыка

private struct LibraryPage: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var ui: UIState

    var body: some View {
        Block("Сейчас в плеере") {
            line("Песни", "\(library.tracks.count)")
            line("В избранном", "\(library.tracks.filter { library.isFavourite($0.id) }.count)")
            line("Плейлисты", "\(library.playlists.count)")
            line("Общий размер файлов", String(format: "%.0f МБ", Double(library.tracks.reduce(0) { $0 + ($1.size ?? 0) }) / 1_048_576))
        }
        Block("Добавить") {
            HStack {
                Button("Файлы") { ui.add(.files) }.buttonStyle(.glass)
                Button("Папку целиком") { ui.add(.folder) }.buttonStyle(.glass)
            }
            Hint("Песни не копируются: плеер играет их там, где они лежат в «Файлах». Удаление из списка сами файлы не трогает. Если переместить или удалить файл, песня перестанет открываться.")
        }
    }

    private func line(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.fg)
            Spacer()
            Text(value).font(.mono(13)).foregroundStyle(Theme.muted)
        }
    }
}

private struct CoversPage: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var covers: CoverFinder

    var body: some View {
        Block {
            SwitchRow(label: "Искать обложки в интернете", on: $settings.v.onlineArt)
            Hint("Для песен без своей обложки плеер ищет её в каталоге iTunes по исполнителю и альбому. Туда отправляются только эти названия. Найденная обложка сохраняется и дальше видна без интернета.")
        }
        Block("Библиотека") {
            let found = library.tracks.filter { $0.artOnline == true && $0.hasArtwork }.count, no = library.tracks.filter { !$0.hasArtwork }.count
            Hint("Найдено обложек: \(found). Без обложки: " + plural(no, "песня", "песни", "песен") + ".")
            if covers.left > 0 {
                Hint("Идёт поиск, осталось \(covers.left). iTunes отвечает не чаще раза в 3 секунды, так что это займёт несколько минут.")
            }
            Button("Найти для всей библиотеки") { covers.findAll() }.buttonStyle(.glass)
        }
    }
}

private struct LyricsPage: View {
    @EnvironmentObject private var settings: Settings

    var body: some View {
        Block {
            SwitchRow(label: "Показывать текст вместо обложки", on: $settings.v.lyricsOn)
            Hint("Текст открывается и нажатием на обложку. Строки с временем подсвечиваются в такт песне, нажатие на строку перематывает к ней.")
        }
        Block("Откуда берётся текст") {
            Hint("Из самого файла, из файла .lrc с тем же именем, с сайта lrclib.net по вашему нажатию «Найти в интернете» или вставленный вручную. На lrclib.net отправляются название, исполнитель и длительность песни.")
        }
    }
}

// MARK: - Прочее

private struct AboutPage: View {
    var body: some View {
        Block("Волна " + AppInfo.version) {
            Hint("Музыкальный плеер для файлов на вашем iPhone.")
        }
        Block("Что уходит в интернет") {
            Hint("Только названия песен и исполнителей: в iTunes для поиска обложек, если он включён, и на lrclib.net, когда вы ищете текст. Сами файлы, статистика и плейлисты остаются на телефоне.")
        }
    }
}
