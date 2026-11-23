import SwiftUI

/// Lyrics in place of the cover. Synchronised lines follow the song; a tap on a line jumps there.
struct LyricsView: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var clock: PlaybackClock
    @State private var lyrics: Lyrics?
    @State private var lines: [LyricLine]?
    @State private var searching = false
    @State private var editing = false
    @State private var touched = Date.distantPast

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text((lyrics?.source ?? "текст песни").uppercased())
                    .font(.mono(10))
                    .kerning(0.6)
                    .foregroundStyle(Theme.muted)
                Spacer()
                if player.current != nil {
                    Menu {
                        Button("Найти в интернете", systemImage: "magnifyingglass") { find() }
                        Button(lyrics == nil ? "Вставить текст" : "Изменить текст", systemImage: "pencil") { editing = true }
                        if lyrics != nil {
                            Button("Удалить текст", systemImage: "trash", role: .destructive) { remove() }
                        }
                    } label: {
                        Image(systemName: "ellipsis").foregroundStyle(Theme.muted).frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Действия с текстом")
                }
                Button { settings.v.lyricsOn = false } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted).frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Закрыть текст")
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.raise, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .task(id: player.current?.id) { reload() }
        .sheet(isPresented: $editing, onDismiss: reload) {
            if let t = player.current { LyricsEditor(id: t.id, text: lyrics?.text ?? "") }
        }
    }

    @ViewBuilder private var content: some View {
        if player.current == nil {
            empty("Сначала выберите песню.")
        } else if let lines {
            synced(lines)
        } else if let lyrics {
            ScrollView {
                Text(LyricsParser.plain(lyrics.text))
                    .font(.system(size: 16))
                    .lineSpacing(6)
                    .foregroundStyle(Theme.fg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        } else if searching {
            Spacer()
            ProgressView("Ищу текст на lrclib.net…")
            Spacer()
        } else {
            VStack(spacing: 14) {
                Spacer()
                Text("Текста для этой песни пока нет.").foregroundStyle(Theme.muted)
                HStack {
                    Button("Найти в интернете") { find() }
                        .buttonStyle(.glassProminent)
                        .foregroundStyle(Theme.accentInk)
                    Button("Вставить текст") { editing = true }
                        .buttonStyle(.glass)
                }
                Text("Поиск отправит название и исполнителя на сайт lrclib.net. Ещё можно добавить вместе с песней файл .lrc с тем же именем.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }

    private func empty(_ s: String) -> some View {
        VStack {
            Spacer()
            Text(s).foregroundStyle(Theme.muted)
            Spacer()
        }
    }

    private func synced(_ lines: [LyricLine]) -> some View {
        let now = lines.last { $0.time <= clock.time + 0.2 }?.id ?? -1
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(lines) { l in
                        Button { player.seek(to: max(0, l.time)) } label: {
                            Text(l.text.isEmpty ? "♪" : l.text)
                                .font(.display(l.text.isEmpty ? 14 : 19, .semibold))
                                .foregroundStyle(l.id == now ? Theme.fg : Theme.muted)
                                .opacity(l.id == now ? 1 : 0.5)
                                .scaleEffect(l.id == now ? 1.03 : 1, anchor: .leading)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)
                        .id(l.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.easeOut(duration: 0.25), value: now)
            }
            .simultaneousGesture(DragGesture().onChanged { _ in touched = Date() })
            .onChange(of: now) { _, id in
                guard id >= 0, Date().timeIntervalSince(touched) > 4 else { return }
                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(id, anchor: .center) }
            }
            .onAppear { if now >= 0 { proxy.scrollTo(now, anchor: .center) } }
        }
    }

    private func reload() {
        lyrics = player.current.flatMap { LyricsStore.load($0.id) }
        lines = lyrics.flatMap { LyricsParser.lines($0.text) }
    }

    private func find() {
        guard let t = player.current else { return }
        searching = true
        Task {
            defer { searching = false }
            do {
                if let l = try await LyricsSearch.find(t) {
                    LyricsStore.save(l, id: t.id)
                    reload()
                    toast(l.source.contains("синхр") ? "Найден текст с синхронизацией" : "Найден текст")
                } else {
                    toast("Текст не найден. Его можно вставить вручную")
                }
            } catch {
                toast("Не удалось связаться с lrclib.net. Проверьте интернет")
            }
        }
    }

    private func remove() {
        guard let t = player.current else { return }
        LyricsStore.delete(t.id)
        reload()
        toast("Текст удалён")
    }
}

struct LyricsEditor: View {
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State var text: String

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(.system(size: 16))
                .padding(.horizontal, 12)
                .scrollContentBackground(.hidden)
                .background(Theme.surface)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Вставьте текст. Строки вида [01:23.45] будут подсвечиваться в такт песне.")
                            .foregroundStyle(Theme.muted)
                            .padding(.horizontal, 18)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
                .navigationTitle("Текст песни")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сохранить") {
                            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !t.isEmpty { LyricsStore.save(Lyrics(text: t, source: "добавлен вручную"), id: id) }
                            dismiss()
                        }
                    }
                }
        }
    }
}
