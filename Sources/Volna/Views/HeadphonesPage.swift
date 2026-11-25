import AVFoundation
import SwiftUI

struct HeadphonesPage: View {
    @EnvironmentObject private var headphones: Headphones
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var ui: UIState
    @State private var query = ""
    @State private var editing: HeadphoneProfile?

    var body: some View {
        now
        find
        if !headphones.data.profiles.isEmpty { mine }
        if headphones.data.devices.count > (headphones.data.devices.contains { $0.id == headphones.current.id } ? 1 : 0) { devices }
        Block(tr("Откуда профили")) {
            Hint(tr("Измерения {} моделей из открытого проекта AutoEq (лицензия MIT). Профиль выравнивает звук наушников, поверх него работает обычный эквалайзер.", "\(HeadphoneBase.all.count)"))
        }
    }

    // MARK: The connected device

    private var now: some View {
        let d = headphones.current, out = SoundPath.Output(port: AVAudioSession.Port(rawValue: d.port), name: d.name)
        return Block(tr("Сейчас подключено")) {
            HStack(spacing: 12) {
                Image(systemName: out.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(settings.accent)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(settings.accent.opacity(0.15)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(d.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.fg)
                    Text(out.kind).font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
            }
            if let p = headphones.chosen {
                Divider().overlay(Theme.line)
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.fg)
                        Text(HeadphoneText.about(p)).font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 8)
                    Button(tr("Настроить")) { editing = p }.buttonStyle(.glass)
                }
                EQCurve(accent: settings.accent, dim: !headphones.on || settings.v.direct) { p.response($0) }
                    .frame(height: 130)
                    .background(Theme.bg.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                SwitchRow(label: tr("Профиль включён"), on: Binding(get: { headphones.on }, set: { headphones.turn($0) }))
                if settings.v.direct { Hint(tr("Включён прямой вывод, поэтому профиль обойдён.")) }
                Hint(tr("С профилем звук тише: он опускает громкость, чтобы не было искажений. Сравнивайте на одинаковой громкости."))
                Button(tr("Убрать с этого устройства")) { headphones.assign(nil, to: d.id) }.buttonStyle(.glass)
            } else {
                let guesses = HeadphoneBase.guess(d.name)
                if guesses.isEmpty {
                    Hint(tr("Профиль не выбран. Найдите свою модель ниже."))
                } else {
                    Hint(tr("Похоже, это одна из этих моделей:"))
                    ForEach(guesses) { model($0) }
                }
            }
        }
        .sheet(item: $editing) { ProfileEditor(profile: $0) }
        #if DEBUG
            .onAppear { if ProcessInfo.processInfo.arguments.contains("-editor") { editing = headphones.chosen } }
        #endif
    }

    // MARK: Search

    private var find: some View {
        Block(tr("Найти модель")) {
            HStack(spacing: 6) {
                TextField(tr("AirPods, Sony, Sennheiser…"), text: $query)
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
            .background(Theme.bg.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            let found = HeadphoneBase.search(query, limit: 25)
            if found.isEmpty, HeadphoneBase.plain(query).count > 1 { Hint(tr("Ничего не найдено")) }
            ForEach(found) { model($0) }
            HStack(spacing: 8) {
                Button(tr("Из файла"), systemImage: "doc") { ui.add(.profile) }
                Button(tr("Свой профиль"), systemImage: "plus") {
                    let p = HeadphoneProfile(name: tr("Мой профиль"), filters: [EQFilter(kind: .low, hz: 105, db: 0, q: 0.7), EQFilter(), EQFilter(kind: .high, hz: 10000, db: 0, q: 0.7)])
                    headphones.assign(headphones.add(p), to: headphones.current.id)
                    editing = p
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .buttonStyle(.glass)
        }
    }

    private func model(_ m: HeadphoneBase.Model) -> some View {
        Button {
            headphones.assign(headphones.add(m.profile), to: headphones.current.id)
            query = ""
            toast(tr("Профиль: {}", "\(m.name)"))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(m.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.fg)
                    Text(m.source).font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                Image(systemName: "plus.circle").foregroundStyle(settings.accent)
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Saved profiles and devices

    private var mine: some View {
        Block(tr("Мои профили")) {
            ForEach(headphones.data.profiles) { p in
                HStack {
                    Button { headphones.assign(p.id, to: headphones.current.id) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: headphones.current.profile == p.id ? "checkmark.circle.fill" : "circle").foregroundStyle(settings.accent)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(p.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.fg)
                                Text(HeadphoneText.about(p)).font(.system(size: 13)).foregroundStyle(Theme.muted)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Menu {
                        Button(tr("Настроить"), systemImage: "slider.horizontal.3") { editing = p }
                        Button(tr("Удалить"), systemImage: "trash", role: .destructive) { headphones.remove(p.id) }
                    } label: {
                        Image(systemName: "ellipsis").foregroundStyle(Theme.muted).frame(width: 34, height: 36).contentShape(Rectangle())
                    }
                    .accessibilityLabel(p.name)
                }
            }
        }
    }

    private var devices: some View {
        Block(tr("Другие устройства")) {
            Hint(tr("Плеер сам меняет профиль, когда вы подключаете другие наушники."))
            ForEach(headphones.data.devices.filter { $0.id != headphones.current.id }.sorted { $0.last > $1.last }) { d in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(d.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.fg)
                        Text(SoundPath.Output(port: AVAudioSession.Port(rawValue: d.port)).kind).font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 8)
                    Menu {
                        Button(tr("Без профиля")) { headphones.assign(nil, to: d.id) }
                        ForEach(headphones.data.profiles) { p in Button(p.name) { headphones.assign(p.id, to: d.id) } }
                        Divider()
                        Button(tr("Забыть устройство"), systemImage: "trash", role: .destructive) { headphones.forget(d.id) }
                    } label: {
                        Text(headphones.profile(d.profile)?.name ?? tr("Без профиля")).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    }
                }
            }
        }
    }
}

enum HeadphoneText {
    static func about(_ p: HeadphoneProfile) -> String {
        let n = plural(p.filters.count, tr("фильтр"), tr("фильтра"), tr("фильтров"))
        return p.source.isEmpty ? n : p.source + " · " + n
    }

    static func hz(_ f: Double) -> String { f < 1000 ? tr("{} Гц", "\(Int(f.rounded()))") : String(format: tr("%g кГц"), (f / 10).rounded() / 100) }
}

/// A slider with small steps: the usual one draws a dot for every step.
private struct FineSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.fg).frame(width: 112, alignment: .leading)
            Slider(value: Binding(get: { min(max(value, range.lowerBound), range.upperBound) }, set: { value = ($0 / step).rounded() * step }), in: range) { Text(label) }
            Text(format(value)).font(.mono(12).monospacedDigit()).foregroundStyle(Theme.muted).frame(width: 74, alignment: .trailing)
        }
    }
}

// MARK: - The precise equaliser

struct ProfileEditor: View {
    @EnvironmentObject private var headphones: Headphones
    @EnvironmentObject private var settings: Settings
    @Environment(\.dismiss) private var dismiss
    @State private var p: HeadphoneProfile
    @State private var open: Int?
    private let original: HeadphoneProfile

    init(profile: HeadphoneProfile) {
        _p = State(initialValue: profile)
        original = profile
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Block {
                        TextField(tr("Название"), text: $p.name).font(.system(size: 16, weight: .semibold))
                        EQCurve(accent: settings.accent) { p.response($0) }
                            .frame(height: 150)
                            .background(Theme.bg.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        FineSlider(label: tr("Предусилитель"), value: $p.preamp, range: -24...6, step: 0.1, format: formatDb)
                        if p.peak > 0.5 {
                            Hint(tr("Самое громкое место поднято на {}: возможны искажения.", "\(formatDb(p.peak))"))
                            Button(tr("Убавить предусилитель")) { p.preamp = ((p.preamp - p.peak) * 10).rounded(.down) / 10 }.buttonStyle(.glass)
                        }
                    }
                    ForEach(p.filters.indices, id: \.self) { i in
                        if i < p.filters.count { filter(i) }
                    }
                    HStack(spacing: 8) {
                        Button(tr("Добавить фильтр"), systemImage: "plus") {
                            p.filters.append(EQFilter())
                            open = p.filters.count - 1
                        }
                        .disabled(p.filters.count >= HeadphoneProfile.maxFilters)
                        Button(tr("Вернуть как было")) { p = original }.disabled(p == original)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .buttonStyle(.glass)
                }
                .padding(16)
            }
            .background(Theme.surface.ignoresSafeArea())
            .navigationTitle(tr("Точный эквалайзер"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(tr("Готово")) { dismiss() } } }
        }
        .onChange(of: p) { _, new in headphones.update(new) } // heard at once
        .presentationDetents([.large])
    }

    private func filter(_ i: Int) -> some View {
        let f = p.filters[i]
        return Block {
            Button { open = open == i ? nil : i } label: {
                HStack {
                    Text(Self.name(f.kind)).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.fg)
                    Spacer()
                    Text(HeadphoneText.hz(f.hz) + " · " + formatDb(f.db) + " · Q " + String(format: "%.2f", f.q)).font(.mono(12)).foregroundStyle(Theme.muted)
                    Image(systemName: open == i ? "chevron.up" : "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open == i {
                Picker(tr("Вид"), selection: $p.filters[i].kind) {
                    ForEach(EQFilter.Kind.allCases, id: \.self) { Text(Self.name($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                FineSlider(label: tr("Частота"), value: Binding(get: { log10(p.filters[i].hz) }, set: { p.filters[i].hz = pow(10, $0).rounded() }),
                           range: log10(20)...log10(20000), step: 0.005) { HeadphoneText.hz(pow(10, $0)) }
                FineSlider(label: tr("Усиление"), value: $p.filters[i].db, range: -15...15, step: 0.1, format: formatDb)
                if f.kind == .peak {
                    FineSlider(label: tr("Острота (Q)"), value: $p.filters[i].q, range: 0.1...10, step: 0.05) { String(format: "%.2f", $0) }
                }
                Button(tr("Удалить фильтр"), role: .destructive) {
                    open = nil
                    p.filters.remove(at: i)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private static func name(_ k: EQFilter.Kind) -> String {
        switch k {
        case .low: tr("Низкая полка")
        case .peak: tr("Колокол")
        case .high: tr("Высокая полка")
        }
    }
}
