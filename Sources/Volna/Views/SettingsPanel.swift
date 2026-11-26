import AppIntents
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

/// Pages of the settings, grouped on the first screen by what they are about.
enum SettingsPage: String, Hashable, CaseIterable {
    case path, headphones, sound, eq, loudness, playback, hires
    case theme, viz
    case library, wifi, covers, lyrics
    case siri, language, stats, backup, about

    var title: String {
        switch self {
        case .path: tr("Путь звука")
        case .headphones: tr("Наушники")
        case .sound: tr("Обработка звука")
        case .eq: tr("Эквалайзер")
        case .loudness: tr("Выравнивание громкости")
        case .playback: tr("Воспроизведение")
        case .hires: tr("Hi-res и вывод")
        case .theme: tr("Оформление")
        case .viz: tr("Визуализация")
        case .library: tr("Библиотека и файлы")
        case .wifi: tr("Передача по Wi-Fi")
        case .covers: tr("Обложки")
        case .lyrics: tr("Тексты песен")
        case .siri: tr("Siri и команды")
        case .language: tr("Язык")
        case .stats: tr("Статистика")
        case .backup: tr("Резервная копия")
        case .about: tr("О приложении")
        }
    }

    var icon: String {
        switch self {
        case .path: "point.topleft.down.to.point.bottomright.curvepath"
        case .headphones: "headphones"
        case .sound: "waveform"
        case .eq: "slider.vertical.3"
        case .loudness: "speaker.wave.2"
        case .playback: "play.circle"
        case .hires: "hifispeaker"
        case .theme: "paintpalette"
        case .viz: "chart.bar.fill"
        case .library: "folder"
        case .wifi: "wifi"
        case .covers: "photo"
        case .lyrics: "text.bubble"
        case .siri: "mic"
        case .language: "globe"
        case .stats: "chart.xyaxis.line"
        case .backup: "externaldrive"
        case .about: "info.circle"
        }
    }

    static let groups: [(title: String, pages: [SettingsPage])] = [
        ("Аудио", [.path, .headphones, .eq, .sound, .loudness, .playback, .hires]),
        ("Графика", [.theme, .viz]),
        ("Музыка", [.library, .wifi, .covers, .lyrics]),
        ("Прочее", [.siri, .language, .stats, .backup, .about]),
    ]
}

struct SettingsPanel: View {
    @EnvironmentObject private var ui: UIState

    var body: some View {
        NavigationStack(path: $ui.settingsPath) {
            SettingsRoot()
                .navigationTitle(tr("Настройки"))
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
                .accessibilityLabel(tr("Закрыть"))
        }
    }
}

private struct SettingsRoot: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var headphones: Headphones
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var stats: Stats

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(SettingsPage.groups, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr(group.title)).font(.display(14, .semibold)).foregroundStyle(Theme.fg).padding(.leading, 4)
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
            return v.eqOn ? (settings.preset.map { tr($0.name) } ?? tr("Свой")) : tr("Выключен")
        case .headphones:
            return headphones.active?.name ?? (headphones.chosen == nil ? tr("Профиль не выбран") : tr("Выключен"))
        case .sound:
            var p: [String] = []
            if v.bass > 0 { p.append(tr("бас +") + String(format: "%g", v.bass) + tr(" дБ")) }
            if v.balance != 0 { p.append(FXFormat.balance(v.balance)) }
            if v.mono { p.append(tr("моно")) }
            p.append(v.limiter ? tr("лимитер включён") : tr("лимитер выключен"))
            return p.joined(separator: " · ")
        case .loudness:
            return v.normalize ? tr("Включено") : tr("Выключено")
        case .playback:
            var p = [v.crossfade > 0 ? tr("кроссфейд {} с", "\(Int(v.crossfade))") : v.gapless ? tr("без пауз") : tr("без кроссфейда")]
            if v.rate != 1 { p.append(FXFormat.rate(v.rate)) }
            if v.semitones != 0 { p.append(tr("тональность {}", FXFormat.semitones(v.semitones))) }
            if player.sleepAt != nil || player.sleepAfterTrack { p.append(tr("таймер сна")) }
            return p.joined(separator: " · ")
        case .path:
            let o = SoundPath.Output.now()
            return o.name + " · " + OutputInfo.khz(o.rate)
        case .hires:
            return v.direct ? tr("Прямой вывод") : OutputInfo.now().rateText
        case .theme:
            let mode = ["dark": tr("Тёмная"), "light": tr("Светлая")][v.themeMode] ?? tr("Как в системе")
            return mode + " · " + tr(Accent.all.first { $0.id == v.accent }?.name ?? "")
        case .viz:
            return v.viz == .off ? v.viz.name : v.viz.name + " · " + v.vizPalette.name.lowercased()
        case .library:
            return plural(library.tracks.count, tr("песня"), tr("песни"), tr("песен")) + " · " + plural(library.playlists.count, tr("плейлист"), tr("плейлиста"), tr("плейлистов"))
        case .wifi:
            return tr("Музыка с компьютера через браузер")
        case .covers:
            return v.onlineArt ? tr("Поиск в iTunes включён") : tr("Поиск выключен")
        case .lyrics:
            return v.lyricsOn ? tr("Показан вместо обложки") : tr("Открывается кнопкой на главном экране")
        case .siri:
            return tr("Включи избранное в Волне")
        case .language:
            return v.language == "system" ? tr("Как в системе") : Lang.current.name
        case .stats:
            return stats.data.total < 1 ? tr("Пока ничего не прослушано") : tr("Всего ") + formatSpan(stats.data.total)
        case .backup:
            return library.waiting.isEmpty ? tr("Всё, кроме музыки, в одном файле") : tr("Ждут своих файлов: ") + plural(library.waiting.count, tr("песня"), tr("песни"), tr("песен"))
        case .about:
            return tr("Волна ") + AppInfo.version
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
    static func balance(_ v: Double) -> String { v == 0 ? tr("центр") : (v < 0 ? tr("Л ") : tr("П ")) + "\(Int(abs(v)))%" }
    static func rate(_ v: Double) -> String { String(format: "%.2f×", v) }
    static func semitones(_ v: Double) -> String { v == 0 ? tr("обычная") : String(format: "%+d", Int(v)) }
}

/// A titled block inside a settings page.
struct Block<Content: View>: View {
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
                        case .path: SoundPathPage()
                        case .headphones: HeadphonesPage()
                        case .sound: SoundPage()
                        case .loudness: LoudnessPage()
                        case .playback: PlaybackPage()
                        case .hires: HiResPage()
                        case .theme: ThemePage()
                        case .viz: VizPage()
                        case .library: LibraryPage()
                        case .wifi: WifiPage()
                        case .covers: CoversPage()
                        case .lyrics: LyricsPage()
                        case .siri: SiriPage()
                        case .language: LanguagePage()
                        case .backup: BackupPage()
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
        Block(tr("Тембр")) {
            SliderRow(label: tr("Усиление баса"), value: $settings.v.bass, range: 0...12, step: 0.5, format: formatDb)
            NavigationLink(value: SettingsPage.eq) { Text(tr("Открыть эквалайзер")) }.buttonStyle(.glass)
        }
        Block(tr("Стерео")) {
            SliderRow(label: tr("Баланс"), value: $settings.v.balance, range: -100...100, step: 5, format: FXFormat.balance)
            SwitchRow(label: tr("Моно"), on: $settings.v.mono)
            Hint(tr("Оба наушника играют одно и то же: удобно с одним наушником или когда одно ухо слышит хуже."))
        }
        Block(tr("Защита от искажений")) {
            SwitchRow(label: tr("Лимитер"), on: $settings.v.limiter)
            Hint(tr("Убирает хрип, когда бас или эквалайзер сильно подняты."))
        }
        Button(tr("Сбросить обработку")) {
            settings.v.bass = 0
            settings.v.balance = 0
            settings.v.mono = false
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
            SwitchRow(label: tr("Выравнивать громкость между песнями"), on: $settings.v.normalize)
            Hint(tr("Плеер один раз измеряет громкость каждой песни и подстраивает её, чтобы тихие и громкие треки звучали одинаково. Сами файлы не меняются."))
        }
        Block(tr("Измерения")) {
            let done = library.tracks.filter { $0.gainDb != nil }.count
            Hint(tr("Измерено {} из {}", "\(done)", "\(library.tracks.count)") + (analyzer.left > 0 ? tr(" · идёт измерение…") : ""))
            if let g = player.current?.gainDb { Hint(tr("Текущая песня: ") + formatDb(g)) }
            Button(tr("Измерить всю библиотеку")) { measureAll() }.buttonStyle(.glass)
        }
    }

    private func measureAll() {
        let l = library.tracks.filter { ($0.gainDb == nil || $0.wave == nil) && $0.bad != true }
        if l.isEmpty {
            toast(tr("Вся библиотека уже измерена"))
            return
        }
        for t in l { analyzer.request(t, first: false) }
        toast(tr("Измеряю громкость: ") + plural(l.count, tr("песня"), tr("песни"), tr("песен")))
    }
}

private struct PlaybackPage: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var player: Player

    var body: some View {
        Block(tr("Переход между песнями")) {
            SliderRow(label: tr("Кроссфейд"), value: $settings.v.crossfade, range: 0...12, step: 1) { $0 == 0 ? tr("выкл") : tr("{} с", "\(Int($0))") }
            Hint(tr("Конец песни плавно затухает, а следующая нарастает поверх него. Работает при автоматическом переходе. Кнопки «вперёд» и «назад» и свайп по обложке переключают сразу."))
        }
        Block(tr("Без пауз")) {
            SwitchRow(label: tr("Песни без пауз между собой"), on: $settings.v.gapless)
            Hint(tr("Следующая песня начинается ровно в конце предыдущей: важно для концертов и альбомов, где музыка не прерывается. Работает, когда кроссфейд выключен и у обеих песен одинаковая частота и число каналов."))
            SwitchRow(label: tr("Пропускать тишину в начале и в конце"), on: $settings.v.trimSilence)
            Hint(tr("Если в начале или в конце песни есть тишина дольше пары десятых секунды, она не играет, и следующая песня начинается сразу. Тишина находится вместе с волной песни, поэтому у новых песен срабатывает со второго включения."))
        }
        Block(tr("Скорость")) {
            SliderRow(label: tr("Скорость"), value: $settings.v.rate, range: 0.5...2, step: 0.05, format: FXFormat.rate)
            SwitchRow(label: tr("Сохранять высоту тона"), on: $settings.v.keepPitch)
            if settings.v.rate != 1 {
                Button(tr("Обычная скорость")) { settings.v.rate = 1 }.buttonStyle(.glass)
            }
        }
        Block(tr("Тональность")) {
            SliderRow(label: tr("Тональность"), value: $settings.v.semitones, range: -6...6, step: 1, format: FXFormat.semitones)
            Hint(tr("Выше или ниже на полутоны, скорость при этом не меняется. Удобно, чтобы подпевать в своей тональности."))
            if settings.v.semitones != 0 {
                Button(tr("Обычная тональность")) { settings.v.semitones = 0 }.buttonStyle(.glass)
            }
        }
        Block(tr("Радио: запас звука")) {
            Flow {
                ForEach(Settings.radioBuffers, id: \.self) { s in
                    Chip(text: tr("{} с", "\(Int(s))"), on: settings.v.radioBuffer == s) { settings.v.radioBuffer = s }
                }
            }
            Hint(tr("Столько звука плеер набирает, прежде чем заиграть. Больше запас: реже прерывается при плохой связи, но станция дольше включается."))
        }
        Block(tr("Таймер сна")) {
            Flow {
                Chip(text: tr("Выключен"), on: player.sleepAt == nil && !player.sleepAfterTrack) { player.sleep(minutes: nil) }
                ForEach([15, 30, 45, 60], id: \.self) { m in
                    Chip(text: m == 60 ? tr("1 час") : tr("{} минут", "\(m)"), on: false) {
                        player.sleep(minutes: m)
                        toast(tr("Таймер сна: {} минут", "\(m)"))
                    }
                }
                Chip(text: tr("После трека"), on: player.sleepAfterTrack) { player.sleepAfterThisTrack() }
            }
            SleepNote()
        }
    }
}

/// Where the sound goes right now and at what rate.
struct OutputInfo: Equatable {
    let device: String
    let rate: Double
    let digital: Bool

    @MainActor
    static func now() -> OutputInfo {
        let s = AVAudioSession.sharedInstance()
        return OutputInfo(device: s.currentRoute.outputs.first?.portName ?? "—", rate: s.sampleRate, digital: AudioGraph.digitalPort != nil)
    }

    var rateText: String { Self.khz(rate) }

    /// The song is better than CD quality and goes to a wired DAC at its own rate.
    func plays(_ t: Track?) -> Bool {
        guard digital, let t, t.isHiRes, let sr = t.sampleRate else { return false }
        return abs(sr - rate) < 1
    }

    static func khz(_ r: Double) -> String { String(format: tr("%g кГц"), (r / 100).rounded() / 10) }
}

private struct HiResPage: View {
    @EnvironmentObject private var settings: Settings

    var body: some View {
        Block {
            NavigationLink(value: SettingsPage.path) { Text(tr("Путь звука")) }.buttonStyle(.glass)
            Hint(tr("Показывает по шагам, что происходит со звуком от файла до наушников."))
        }
        Block(tr("Частота")) {
            SwitchRow(label: tr("Подстраивать вывод под файл"), on: $settings.v.matchRate)
            Hint(tr("Значок LOSSLESS на главном экране: файл без потерь (FLAC, ALAC, WAV, AIFF). Он говорит о файле, а не о наушниках."))
            Hint(tr("Значок HI-RES на главном экране: контур означает, что режим включён, закрашенный — что песня выше качества CD и идёт на ЦАП без пересчёта."))
            Hint(tr("Работает с внешним ЦАП по USB-C или HDMI: он переключается на частоту песни, и она идёт без пересчёта. Динамик и Bluetooth работают на своей частоте, её поменять нельзя, а Bluetooth к тому же сжимает звук."))
        }
        Block(tr("Обработка")) {
            SwitchRow(label: tr("Прямой вывод"), on: $settings.v.direct)
            Hint(tr("Выключает всё, что меняет звук: эквалайзер, бас, баланс, лимитер, выравнивание и скорость. Ваши настройки сохраняются и вернутся, когда вы выключите этот режим."))
        }
    }
}

// MARK: - Графика

private struct ThemePage: View {
    @EnvironmentObject private var settings: Settings

    var body: some View {
        Block(tr("Тема")) {
            Flow {
                ForEach([("system", tr("Как в системе")), ("dark", tr("Тёмная")), ("light", tr("Светлая"))], id: \.0) { m in
                    Chip(text: m.1, on: settings.v.themeMode == m.0) { settings.v.themeMode = m.0 }
                }
            }
        }
        Block(tr("Цвет")) {
            Flow {
                ForEach(Accent.all) { a in
                    Chip(text: tr(a.name), dot: a.color, on: settings.v.accent == a.id) { settings.v.accent = a.id }
                }
            }
        }
        Block(tr("Отклик")) {
            SwitchRow(label: tr("Лёгкая вибрация при нажатиях"), on: $settings.v.haptics)
            Hint(tr("Телефон слегка отзывается на кнопки плеера, смахивание обложки и лайк."))
        }
    }
}

private struct VizPage: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var ui: UIState

    var body: some View {
        Block(tr("Как выглядит")) {
            switch settings.v.viz {
            case .off:
                Hint(tr("Визуализация выключена."))
            case .ring:
                HStack {
                    Spacer()
                    RingCover(track: player.current, station: player.radio, side: 220)
                    Spacer()
                }
            default:
                VizStrip()
            }
            if !player.isPlaying, settings.v.viz != .off { Hint(tr("Включите песню, чтобы увидеть движение.")) }
        }
        Block(tr("Цвета")) {
            Flow {
                ForEach(VizColors.allCases) { c in
                    Chip(text: c.name, on: settings.v.vizPalette == c) { settings.v.vizPalette = c }
                }
            }
            if settings.v.vizPalette != .accent {
                LinearGradient(gradient: settings.v.vizPalette.gradient, startPoint: .leading, endPoint: .trailing)
                    .frame(height: 8)
                    .clipShape(Capsule())
                HStack {
                    Text(settings.v.vizPalette == .rainbow ? tr("низкие") : tr("тихо"))
                    Spacer()
                    Text(settings.v.vizPalette == .rainbow ? tr("высокие") : tr("громко"))
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            }
        }
        Block(tr("Режим")) {
            Flow {
                ForEach(VizMode.allCases) { m in
                    Chip(text: m.name, on: settings.v.viz == m) { settings.v.viz = m }
                }
            }
            Hint(tr("На главном экране нажатие на визуализацию меняет режим, долгое нажатие — цвета."))
        }
        Block(tr("Заставка")) {
            SwitchRow(label: tr("Включать заставку"), on: $settings.v.saverOn)
            Hint(tr("Если играет музыка и вы столько не касаетесь экрана, визуализация открывается на весь экран. Нажатие возвращает плеер. Поверх списков, настроек и текста песни заставка не появляется."))
            if settings.v.saverOn {
                Flow {
                    ForEach([(10, tr("10 секунд")), (20, tr("20 секунд")), (30, tr("30 секунд")), (60, tr("1 минута"))], id: \.0) { s in
                        Chip(text: s.1, on: settings.v.saver == s.0) { settings.v.saver = s.0 }
                    }
                }
                Flow {
                    ForEach([VizMode.off] + VizMode.allCases.filter { $0 != .off }) { m in
                        Chip(text: m == .off ? tr("Как на главном экране") : m.name, on: settings.v.saverViz == m) { settings.v.saverViz = m }
                    }
                }
                SwitchRow(label: tr("Не гасить экран во время заставки"), on: $settings.v.saverAwake)
                Hint(tr("Если выключено, iPhone погаснет сам через время из своих настроек («Экран и яркость → Автоблокировка»), музыка при этом играет дальше. Если включено, экран не гаснет и батарея садится быстрее."))
                Button(tr("Показать сейчас")) {
                    ui.panel = nil
                    ui.saver = true
                }
                .buttonStyle(.glass)
                .disabled(!player.isPlaying)
            }
        }
    }
}

// MARK: - Музыка

private struct LibraryPage: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var ui: UIState
    @State private var duplicates = false

    @EnvironmentObject private var settings: Settings

    var body: some View {
        Block(tr("Сейчас в плеере")) {
            line(tr("Песни"), "\(library.tracks.count)")
            line(tr("В избранном"), "\(library.tracks.filter { library.isFavourite($0.id) }.count)")
            line(tr("Плейлисты"), "\(library.playlists.count)")
            line(tr("Общий размер файлов"), String(format: tr("%.0f МБ"), Double(library.tracks.reduce(0) { $0 + ($1.size ?? 0) }) / 1_048_576))
        }
        Block(tr("Папки")) {
            SwitchRow(label: tr("Искать новые песни при запуске"), on: $settings.v.refreshFolders)
            if library.folders.isEmpty {
                Hint(tr("Папок пока нет. Добавьте папку целиком, и новые песни из неё будут появляться сами."))
            } else {
                Hint(tr("Папок: {}. Песни, которые вы убрали из плеера, при обновлении не возвращаются.", "\(library.folders.count)"))
                Button(library.refreshing ? tr("Ищу…") : tr("Обновить сейчас")) { Task { await library.refreshFolders(quiet: false) } }
                    .buttonStyle(.glass)
                    .disabled(library.refreshing)
            }
        }
        Block(tr("Дубликаты")) {
            let n = library.duplicates().reduce(0) { $0 + $1.count - 1 }
            Hint(n == 0 ? tr("Одинаковых песен нет.") : tr("Лишних копий: {}.", "\(n)"))
            Button(tr("Найти дубликаты")) { duplicates = true }.buttonStyle(.glass)
            Hint(tr("Одинаковые — это те же исполнитель, название и длина. Волна предложит оставить лучшую копию, лишние уберёт из плеера, а их лайки, плейлисты и статистику передаст оставленной."))
        }
        .sheet(isPresented: $duplicates) { DuplicatesView() }
        Block(tr("Добавить")) {
            HStack {
                Button(tr("Файлы")) { ui.add(.files) }.buttonStyle(.glass)
                Button(tr("Папку целиком")) { ui.add(.folder) }.buttonStyle(.glass)
            }
            Hint(tr("Песни не копируются: плеер играет их там, где они лежат в «Файлах». Удаление из списка сами файлы не трогает. Если переместить или удалить файл, песня перестанет открываться."))
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
            SwitchRow(label: tr("Искать обложки в интернете"), on: $settings.v.onlineArt)
            Hint(tr("Для песен без своей обложки плеер ищет её в каталоге iTunes по исполнителю и альбому. Туда отправляются только эти названия. Найденная обложка сохраняется и дальше видна без интернета."))
        }
        Block(tr("Библиотека")) {
            let found = library.tracks.filter { $0.artOnline == true && $0.hasArtwork }.count, no = library.tracks.filter { !$0.hasArtwork }.count
            Hint(tr("Найдено обложек: {}. Без обложки: ", "\(found)") + plural(no, tr("песня"), tr("песни"), tr("песен")) + ".")
            if covers.left > 0 {
                Hint(tr("Идёт поиск, осталось {}. iTunes отвечает не чаще раза в 3 секунды, так что это займёт несколько минут.", "\(covers.left)"))
            }
            Button(tr("Найти для всей библиотеки")) { covers.findAll() }.buttonStyle(.glass)
        }
        RadioExtrasBlock()
    }
}

private struct LyricsPage: View {
    @EnvironmentObject private var settings: Settings

    var body: some View {
        Block {
            SwitchRow(label: tr("Показывать текст вместо обложки"), on: $settings.v.lyricsOn)
            Hint(tr("Текст открывается и кнопкой с облачком внизу главного экрана. Строки с временем подсвечиваются в такт песне, нажатие на строку перематывает к ней."))
        }
        Block(tr("Поиск")) {
            SwitchRow(label: tr("Искать текст сам"), on: $settings.v.lyricsAuto)
            Hint(tr("Когда начинается песня без текста, Волна один раз спрашивает о ней lrclib.net и сохраняет найденное. Отправляются название, исполнитель и длительность. По умолчанию выключено."))
        }
        Block(tr("Откуда берётся текст")) {
            Hint(tr("Из самого файла, из файла .lrc с тем же именем, с сайта lrclib.net по вашему нажатию «Найти в интернете» или вставленный вручную. На lrclib.net отправляются название, исполнитель и длительность песни."))
        }
        RadioExtrasBlock()
    }
}

/// The same switch on the covers page and on the lyrics page.
private struct RadioExtrasBlock: View {
    @EnvironmentObject private var settings: Settings

    var body: some View {
        Block(tr("Радио")) {
            SwitchRow(label: tr("Обложки и тексты для радио"), on: $settings.v.radioExtras)
            Hint(tr("Когда станция сообщает, какая песня играет, Волна ищет её обложку в iTunes и текст на lrclib.net. Отправляются только исполнитель и название. Текст открывается кнопкой с облачком. По умолчанию выключено."))
        }
    }
}

// MARK: - Прочее

private struct SiriPage: View {
    private var phrases: [String] {
        [tr("Включи избранное в Волне"), tr("Перемешай музыку в Волне"), tr("Включи музыку в Волне"),
         tr("Включи песню … в Волне"), tr("Включи исполнителя … в Волне"), tr("Включи плейлист … в Волне"), tr("Включи радио … в Волне"),
         tr("Таймер сна 30 минут в Волне"), tr("Эквалайзер Рок в Волне"), tr("Добавь в избранное в Волне")]
    }

    var body: some View {
        Block(tr("Что можно сказать")) {
            ForEach(phrases, id: \.self) { p in
                Text(p).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.fg)
            }
            Hint(tr("Название плеера в фразе обязательно. Пауза, следующая песня и громкость работают и без него, для того, что уже играет."))
            Hint(tr("Фразы работают на языке Siri: русском или английском. Украинского у Siri пока нет."))
        }
        Block(tr("Команды")) {
            Hint(tr("Эти же действия есть в приложении «Команды»: там их можно повесить на кнопку «Действие» или в автоматизацию."))
            ShortcutsLink()
        }
        Block(tr("Пункт управления")) {
            Hint(tr("Кнопки «Волны» можно добавить в Пункт управления и на экран блокировки: играть или пауза, следующая песня, эквалайзер. Откройте Пункт управления, нажмите «+», затем «Добавить элемент» и найдите «Волна»."))
        }
    }
}

private struct LanguagePage: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var player: Player

    var body: some View {
        Block {
            Flow {
                Chip(text: tr("Как в системе"), on: settings.v.language == "system") { choose("system") }
                ForEach(Lang.allCases, id: \.self) { l in
                    Chip(text: l.name, on: settings.v.language == l.rawValue) { choose(l.rawValue) }
                }
            }
            Hint(tr("«Как в системе» берёт язык из настроек iPhone."))
            Hint(tr("Названия песен и исполнителей не переводятся."))
        }
    }

    private func choose(_ code: String) {
        settings.v.language = code
        player.publish() // the widget speaks the same language
    }
}

private struct BackupPage: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var stations: Stations
    @EnvironmentObject private var headphones: Headphones
    @EnvironmentObject private var stats: Stats
    @State private var file: URL?
    @State private var saving = false
    @State private var picking = false
    @State private var found: Backup?

    var body: some View {
        Block {
            Hint(tr("В копию попадают настройки, эквалайзер, профили наушников, радиостанции, статистика, избранное, плейлисты, исправленные названия и тексты песен. Самой музыки в ней нет, поэтому файл маленький."))
            Button(tr("Сохранить копию"), systemImage: "square.and.arrow.down") { save() }
                .buttonStyle(.glassProminent)
                .foregroundStyle(Theme.accentInk)
            Hint(tr("Лучше всего положить файл в iCloud Drive: тогда он не пропадёт вместе с телефоном."))
        }
        Block(tr("Восстановление")) {
            Hint(tr("Выберите файл копии. Настройки, станции, профили наушников и статистика заменятся теми, что в копии. Избранное и плейлисты добавятся к нынешним."))
            Button(tr("Восстановить из копии"), systemImage: "arrow.counterclockwise") { picking = true }
                .buttonStyle(.glass)
            Hint(tr("На новом телефоне сначала добавьте музыку, потом восстановите копию. Можно и наоборот: Волна узнает песни, когда вы их добавите."))
        }
        if !library.waiting.isEmpty {
            Block(tr("Ждут своих файлов")) {
                Hint(plural(library.waiting.count, tr("песня"), tr("песни"), tr("песен")) + tr(" из копии пока не найдены в плеере. Когда вы их добавите, Волна вернёт им избранное, плейлисты, тексты и исправленные названия."))
                Button(tr("Больше не ждать")) { library.forgetWaiting() }.buttonStyle(.glass)
            }
        }
        Color.clear.frame(height: 1)
            .fileMover(isPresented: $saving, file: file) { result in
                if case .success = result { toast(tr("Копия сохранена")) }
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.json, .data]) { result in
                guard case .success(let url) = result else { return }
                do {
                    found = try BackupFile.read(url)
                } catch {
                    toast(tr("Это не файл копии Волны"))
                }
            }
            .alert(tr("Восстановить из копии?"), isPresented: Binding(get: { found != nil }, set: { if !$0 { found = nil } })) {
                Button(tr("Восстановить"), role: .destructive) { restore() }
                Button(tr("Отмена"), role: .cancel) { found = nil }
            } message: {
                Text(found.map { tr("Копия от {}.", $0.made.formatted(date: .long, time: .shortened)) + " " } ?? "")
                    + Text(tr("Настройки, станции, профили наушников и статистика будут заменены."))
            }
    }

    private func save() {
        do {
            file = try BackupFile.write(BackupFile.make(library: library, settings: settings, stations: stations, headphones: headphones, stats: stats))
            saving = true
        } catch {
            toast(tr("Не удалось сохранить копию"))
        }
    }

    private func restore() {
        guard let b = found else { return }
        found = nil
        let r = BackupFile.restore(b, library: library, settings: settings, stations: stations, headphones: headphones, stats: stats)
        if r.total == 0 || r.found == r.total {
            toast(tr("Копия восстановлена"))
        } else {
            toast(tr("Копия восстановлена. Узнано песен: {} из {}", "\(r.found)", "\(r.total)"))
        }
    }
}

private struct AboutPage: View {
    var body: some View {
        Block(tr("Волна ") + AppInfo.version) {
            Hint(tr("Музыкальный плеер для файлов на вашем iPhone."))
            Hint(tr("Профили наушников: AutoEq, © Jaakko Pasanen, лицензия MIT."))
        }
        Block(tr("Что уходит в интернет")) {
            Hint(tr("Только названия песен и исполнителей: в iTunes для поиска обложек, если он включён, и на lrclib.net, когда вы ищете текст, включён его автопоиск или тексты для радио. Радио подключается к серверам станций. Сами файлы, статистика и плейлисты остаются на телефоне."))
        }
    }
}
