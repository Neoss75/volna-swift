import SwiftUI

/// Which station the sheet is for; none = a new one.
struct StationSheet: Identifiable, Equatable {
    var station: UUID?
    var id: String { station?.uuidString ?? "new" }
}

// MARK: - The list of stations

struct RadioPanel: View {
    @EnvironmentObject private var stations: Stations
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var ui: UIState
    @State private var query = ""
    @State private var confirm = false
    @State private var confirmCheck = false
    @State private var confirmDead = false

    private var search: String { query.trimmingCharacters(in: .whitespaces) }

    private var sections: [(title: String?, stations: [Station])] {
        let all = stations.sections
        guard !search.isEmpty else { return all }
        return all.map { (title: $0.title, stations: $0.stations.filter { ($0.name + " " + ($0.group ?? "")).localizedCaseInsensitiveContains(search) }) }
            .filter { !$0.stations.isEmpty }
    }

    var body: some View {
        let sections = sections, ids = sections.flatMap(\.stations).map(\.id)
        VStack(spacing: 0) {
            if stations.all.isEmpty {
                Spacer()
                Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 44)).foregroundStyle(settings.accent)
                Text(tr("Станций пока нет. Добавьте список .m3u или .pls из «Файлов» или вставьте ссылку."))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(24)
                HStack(spacing: 10) {
                    Button(tr("Список"), systemImage: "plus") { ui.add(.stations) }
                    Button(tr("Ссылка"), systemImage: "link") { ui.stationSheet = StationSheet() }
                }
                .font(.system(size: 15, weight: .semibold))
                .buttonStyle(.glass)
                Spacer()
            } else {
                field
                if ids.isEmpty {
                    Spacer()
                    Text(tr("Ничего не найдено")).foregroundStyle(Theme.muted)
                    Spacer()
                } else {
                    list(sections, ids)
                }
                if let c = stations.check { checkRow(c) }
                footer(ids)
            }
        }
    }

    private var field: some View {
        HStack(spacing: 6) {
            TextField(tr("Поиск станции…"), text: $query)
                .font(.system(size: 15))
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("Очистить поиск"))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Theme.raise, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func list(_ sections: [(title: String?, stations: [Station])], _ ids: [UUID]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, s in
                        if let title = s.title {
                            Text(title).font(.display(14, .semibold)).foregroundStyle(Theme.fg).padding(.top, 14).padding(.bottom, 4)
                        }
                        ForEach(s.stations) { st in
                            StationRow(station: st) {
                                player.play(st, from: ids)
                            }
                            .id(st.id)
                            Divider().overlay(Theme.line)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.immediately)
            .onAppear { if let id = player.radio?.id { proxy.scrollTo(id, anchor: .center) } }
        }
    }

    private func minutes(_ n: Int) -> Int {
        max(1, Int((Double(n) * StationProbe.patience / Double(StationProbe.atOnce) / 60).rounded(.up)))
    }

    private func title(_ c: Stations.Check) -> String {
        if c.running { return tr("Проверено {} из {}", "\(c.done)", "\(c.total)") }
        if c.alive == 0 { return tr("Ни одна станция не ответила. Есть ли интернет?") }
        return tr("Проверка закончена: {} из {}", "\(c.done)", "\(c.total)")
    }

    private func checkRow(_ c: Stations.Check) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if c.running {
                ProgressView(value: Double(c.done), total: Double(max(1, c.total)))
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(c))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.fg)
                    Text(tr("отвечают: {} · молчат: {} · не тот формат: {}", "\(c.alive)", "\(c.dead.count)", "\(c.unsupported)"))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 6)
                if c.running {
                    Button(tr("Стоп")) { stations.endCheck() }.buttonStyle(.glass)
                } else {
                    if !stations.removable.isEmpty {
                        Button(tr("Убрать ({})", "\(stations.removable.count)")) { confirmDead = true }.buttonStyle(.glass).tint(Theme.danger)
                    }
                    Button { stations.check = nil } label: { Image(systemName: "xmark").foregroundStyle(Theme.muted) }
                        .buttonStyle(.plain)
                        .frame(width: 30, height: 36)
                        .accessibilityLabel(tr("Закрыть"))
                }
            }
            .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Divider().overlay(Theme.line) }
    }

    private func footer(_ ids: [UUID]) -> some View {
        HStack {
            Text(plural(ids.count, tr("станция"), tr("станции"), tr("станций"))).font(.system(size: 13)).foregroundStyle(Theme.muted)
            Spacer()
            Button(tr("Проверить")) { confirmCheck = true }
                .buttonStyle(.glass)
                .disabled(ids.isEmpty || stations.check?.running == true)
            Button(ids.count == stations.all.count ? tr("Удалить все") : tr("Удалить ({})", "\(ids.count)")) { confirm = true }
                .buttonStyle(.glass)
                .tint(Theme.danger)
                .disabled(ids.isEmpty)
        }
        .font(.system(size: 14, weight: .semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Divider().overlay(Theme.line) }
        .confirmationDialog(tr("Убрать станции из плеера: {}?", "\(ids.count)"), isPresented: $confirm, titleVisibility: .visible) {
            Button(tr("Убрать станции"), role: .destructive) { stations.remove(Set(ids)) }
        }
        .confirmationDialog(tr("Проверить, какие станции отвечают: {}? Займёт до {} мин и скачает до {} МБ, лучше по Wi-Fi. Не закрывайте плеер.", "\(ids.count)", "\(minutes(ids.count))", "\(max(1, ids.count / 20))"),
                            isPresented: $confirmCheck, titleVisibility: .visible) {
            Button(tr("Проверить станции")) { stations.startCheck(ids.compactMap { stations.station($0) }) }
        }
        .confirmationDialog(tr("Убрать из плеера неответившие станции: {}? Они могли не ответить и из-за вашей сети. Избранные останутся.", "\(stations.removable.count)"),
                            isPresented: $confirmDead, titleVisibility: .visible) {
            Button(tr("Убрать станции"), role: .destructive) { stations.removeDead() }
        }
    }
}

private struct StationRow: View {
    @EnvironmentObject private var stations: Stations
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var live: Radio
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var ui: UIState
    let station: Station
    let play: () -> Void

    var body: some View {
        let on = player.radio?.id == station.id, fav = station.favourite == true
        HStack(spacing: 12) {
            Button(action: play) {
                HStack(spacing: 12) {
                    StationLogo(station: station, corner: 10, letter: 18).frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(station.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(on ? settings.accent : Theme.fg)
                        Text(subtitle(on)).font(.system(size: 13)).foregroundStyle(stations.problems[station.id] != nil && !on ? Theme.danger : Theme.muted)
                    }
                    .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { stations.toggleFavourite(station.id) } label: {
                Image(systemName: fav ? "heart.fill" : "heart").font(.system(size: 18)).foregroundStyle(fav ? Theme.danger : Theme.muted).frame(width: 34, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(fav ? tr("Убрать из избранного") : tr("Добавить в избранное"))
            Menu {
                Button(tr("Изменить…"), systemImage: "pencil") { ui.stationSheet = StationSheet(station: station.id) }
                Button(tr("Удалить из плеера"), systemImage: "trash", role: .destructive) { stations.remove([station.id]) }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 16)).foregroundStyle(Theme.muted).frame(width: 34, height: 40).contentShape(Rectangle())
            }
            .accessibilityLabel(tr("Изменить станцию"))
        }
        .padding(.vertical, 8)
    }

    private func subtitle(_ on: Bool) -> String {
        if on, player.isPlaying { return live.title.isEmpty ? RadioText.state(live, playing: true) : live.title }
        return stations.problems[station.id] ?? station.host
    }
}

// MARK: - New station

struct StationEditor: View {
    @EnvironmentObject private var stations: Stations
    @Environment(\.dismiss) private var dismiss
    let station: Station?
    @State private var link: String
    @State private var name: String

    init(station: Station?) {
        self.station = station
        _link = State(initialValue: station?.url ?? "")
        _name = State(initialValue: station?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(tr("Ссылка"), text: $link, axis: .vertical)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(1...4)
                    TextField(tr("Название"), text: $name)
                    if station == nil {
                        PasteButton(payloadType: String.self) { list in
                            let text = list.first ?? ""
                            Task { @MainActor in link = text.trimmingCharacters(in: .whitespacesAndNewlines) }
                        }
                    }
                } footer: {
                    if station == nil {
                        Text(tr("Подходит ссылка на поток (MP3, AAC, HLS) или на целый список .m3u или .pls. Название можно не писать."))
                    }
                }
                if stations.loading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(tr("Открываю ссылку…")).foregroundStyle(Theme.muted)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.surface.ignoresSafeArea())
            .navigationTitle(station == nil ? tr("Новая станция") : tr("Изменить станцию"))
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) { ToastView().padding(.bottom, 12) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("Отмена")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Сохранить")) { save() }
                        .disabled(stations.loading || link.trimmingCharacters(in: .whitespaces).isEmpty || station != nil && tidy(name).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func tidy(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        guard let station else {
            Task { if await stations.add(link: tidy(link), name: tidy(name)) { dismiss() } }
            return
        }
        guard let url = StationList.link(link) else { return toast(tr("Это не похоже на ссылку")) }
        stations.edit(station.id, name: tidy(name), url: url)
        dismiss()
    }
}

// MARK: - On the main screen

@MainActor
enum RadioText {
    static func state(_ live: Radio, playing: Bool) -> String {
        guard playing else { return tr("На паузе") }
        switch live.state {
        case .idle: return tr("На паузе")
        case .connecting: return tr("Подключаюсь…")
        case .buffering: return tr("Набираю запас звука: {} из {} с", "\(Int(live.stored))", "\(Int(live.target.rounded()))")
        case .waiting: return tr("Связь пропала, подключаюсь снова…")
        case .playing: return tr("Прямой эфир")
        }
    }

    static func format(_ i: StreamInfo) -> String {
        guard i.rate > 0 else { return "" }
        return [i.kind, OutputInfo.khz(i.rate), i.kbps.map { tr("{} кбит/с", "\(Int($0.rounded()))") } ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct RadioTitle: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var live: Radio
    @EnvironmentObject private var stations: Stations
    let station: Station
    let compact: Bool

    var body: some View {
        let song = live.artistAndSong, fav = station.favourite == true
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Text(song?.title ?? station.name)
                    .font(.display(compact ? 18 : 21, .semibold))
                    .foregroundStyle(Theme.fg)
                    .lineLimit(compact ? 1 : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { stations.toggleFavourite(station.id) } label: {
                    Image(systemName: fav ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundStyle(fav ? Theme.danger : Theme.muted)
                        .frame(width: 34, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(fav ? tr("Убрать из избранного") : tr("Добавить в избранное"))
            }
            HStack(spacing: 10) {
                Text(song == nil ? station.group ?? station.host : [song?.artist ?? "", station.name].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                if compact {
                    Spacer(minLength: 0)
                    OutputBadges()
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                let f = RadioText.format(live.info)
                Text(f.isEmpty ? station.host : f)
                if let (n, of) = player.radioPlace { Text(tr("{} из {}", "\(n)", "\(of)")) }
            }
            .font(.mono(11))
            .kerning(0.3)
            .foregroundStyle(Theme.muted)
            .lineLimit(1)
            .padding(.top, 2)
        }
    }
}

/// In place of the wave: a live broadcast cannot be wound.
struct LiveBlock: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var live: Radio
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var clock: PlaybackClock

    var body: some View {
        let on = player.isPlaying && live.state == .playing
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                if player.isPlaying, !on {
                    ProgressView().controlSize(.small)
                } else {
                    Circle().fill(on ? Theme.danger : Theme.muted).frame(width: 8, height: 8)
                }
                Text(RadioText.state(live, playing: player.isPlaying))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(on ? Theme.fg : Theme.muted)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .accessibilityElement(children: .combine)
            HStack {
                Text(player.isPlaying ? formatTime(clock.time) : " ").foregroundStyle(Theme.muted)
                Spacer()
                Menu {
                    Picker(tr("Радио: запас звука"), selection: $settings.v.radioBuffer) {
                        ForEach(Settings.radioBuffers, id: \.self) { Text(tr("{} с", "\(Int($0))")).tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(on ? tr("запас {} с", "\(Int(live.stored.rounded()))") : tr("запас"))
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Theme.muted)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(tr("Радио: запас звука"))
            }
            .font(.mono(12).monospacedDigit())
        }
    }
}
