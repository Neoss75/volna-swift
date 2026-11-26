import SwiftUI

extension Library {
    /// The same song more than once: the same artist and title, the length within three seconds. The best copy first.
    func duplicates() -> [[Track]] {
        var byName: [String: [Track]] = [:]
        for t in tracks {
            let a = SongReading.normal(t.artist), n = SongReading.normal(t.title)
            guard !n.isEmpty else { continue }
            byName[a + "|" + n, default: []].append(t)
        }
        var out: [[Track]] = []
        for list in byName.values where list.count > 1 {
            var run: [Track] = []
            for t in list.sorted(by: { $0.duration < $1.duration }) {
                if let last = run.last, t.duration - last.duration > 3 {
                    if run.count > 1 { out.append(run) }
                    run = []
                }
                run.append(t)
            }
            if run.count > 1 { out.append(run) }
        }
        return out.map { $0.sorted(by: Self.better) }.sorted { ($0[0].artist, $0[0].title) < ($1[0].artist, $1[0].title) }
    }

    /// Without losses, then more bits, a higher rate, more kilobits, a bigger file, a cover, the one added first.
    static func better(_ a: Track, _ b: Track) -> Bool {
        func key(_ t: Track) -> [Double] {
            [t.isLossless ? 1 : 0, Double(t.bits ?? 0), t.sampleRate ?? 0, t.kbps ?? 0, Double(t.size ?? 0), t.hasArtwork ? 1 : 0]
        }
        let ka = key(a), kb = key(b)
        if ka != kb { return ka.lexicographicallyPrecedes(kb, by: >) }
        return (a.addedAt ?? .distantPast) < (b.addedAt ?? .distantPast)
    }
}

/// The groups of the same song: one copy stays in each, the rest leave the player.
struct DuplicatesView: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var settings: Settings
    @Environment(\.dismiss) private var dismiss
    @State private var groups: [[Track]] = []
    @State private var keep: [Int: UUID] = [:]
    @State private var asking = false

    private var dropCount: Int { groups.reduce(0) { $0 + $1.count - 1 } }

    var body: some View {
        NavigationStack {
            list
                .scrollContentBackground(.hidden)
                .background(Theme.surface)
                .navigationTitle(tr("Дубликаты"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .confirmationDialog(question, isPresented: $asking, titleVisibility: .visible) {
                    Button(tr("Убрать лишние"), role: .destructive) { clean() }
                } message: {
                    Text(tr("Файлы останутся в «Файлах» (кроме присланных по Wi-Fi). Лайки, плейлисты и статистика лишних копий перейдут к оставленной."))
                }
        }
        .onAppear { groups = library.duplicates() }
    }

    private var question: String {
        tr("Убрать из плеера: ") + plural(dropCount, tr("песня"), tr("песни"), tr("песен")) + "?"
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button(tr("Закрыть")) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
            Button(tr("Убрать лишние")) { asking = true }.disabled(groups.isEmpty)
        }
    }

    private var list: some View {
        List {
            if groups.isEmpty {
                Text(tr("Одинаковых песен не нашлось.")).foregroundStyle(Theme.muted)
            } else {
                Section {
                    Text(tr("Отмечена копия, которая останется. Волна выбрала лучшую: без потерь, с большим битрейтом. Можно отметить другую."))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
            }
            ForEach(groups.indices, id: \.self) { i in section(i) }
        }
    }

    private func title(_ t: Track) -> String {
        t.artist.isEmpty ? t.title : t.artist + " — " + t.title
    }

    private func section(_ i: Int) -> some View {
        let group = groups[i], chosen = keep[i] ?? group[0].id
        return Section(title(group[0])) {
            ForEach(group) { t in
                Button { keep[i] = t.id } label: { row(t, on: chosen == t.id) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func row(_ t: Track, on: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(on ? settings.accent : Theme.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.formatLine).font(.mono(12)).foregroundStyle(Theme.fg)
                Text(place(t) + " · " + formatTime(t.duration)).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func place(_ t: Track) -> String {
        t.folder ?? (t.path as NSString).deletingLastPathComponent.components(separatedBy: "/").last ?? t.fileName
    }

    private func clean() {
        var drop: Set<UUID> = []
        for (i, group) in groups.enumerated() {
            let kept = keep[i] ?? group[0].id, others = group.map(\.id).filter { $0 != kept }
            library.merge(keep: kept, drop: others)
            drop.formUnion(others)
        }
        library.remove(drop)
        dismiss()
    }
}
