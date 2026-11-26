import SwiftUI

/// Settings → Music → Transfer over Wi-Fi: the address to open on a computer and what has come.
struct WifiPage: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var settings: Settings
    @ObservedObject private var wifi = WifiTransfer.shared

    var body: some View {
        VStack(spacing: 14) {
            address
            if !wifi.received.isEmpty || wifi.skipped > 0 || !wifi.problems.isEmpty { came }
            Block(tr("Как это работает")) {
                Hint(tr("1. Откройте адрес выше в браузере на компьютере: Chrome, Edge, Safari или Firefox."))
                Hint(tr("2. Перетащите в окно браузера файлы или целые папки с музыкой."))
                Hint(tr("3. Песни появятся в списке, в разделе «Папки» → «Wi-Fi»."))
                Divider().overlay(Theme.line)
                Hint(tr("Приём работает, пока открыт этот экран, телефон при этом не гаснет."))
                Hint(tr("Файлы лежат в «Файлах»: «На iPhone» → «Волна» → «Wi-Fi». Если убрать такую песню из плеера, её файл тоже удалится."))
            }
        }
        .onAppear { Task { await wifi.start(library, accent: settings.v.accent) } }
        .onDisappear { wifi.stop() }
    }

    private var address: some View {
        Block(tr("Адрес для браузера")) {
            switch wifi.state {
            case .off, .starting:
                HStack(spacing: 10) {
                    ProgressView()
                    Text(tr("Запускаю приём…")).font(.system(size: 15)).foregroundStyle(Theme.muted)
                }
            case .failed:
                Text(tr("Приём не запустился. Закройте этот экран и откройте снова.")).font(.system(size: 15)).foregroundStyle(Theme.fg)
            case .noWifi:
                Label(tr("Нет Wi-Fi"), systemImage: "wifi.slash").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.fg)
                Hint(tr("Подключите телефон к той же сети Wi-Fi, что и компьютер. Адрес появится сам."))
            case .waiting, .receiving:
                if let a = wifi.address {
                    Text(a)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("wifiAddress")
                }
                if let r = receiving {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("Принимаю: {}", (r.0 as NSString).lastPathComponent))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.fg)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        ProgressView(value: r.1).tint(settings.accent)
                    }
                } else {
                    HStack(spacing: 8) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text(tr("Жду файлы с компьютера")).font(.system(size: 14)).foregroundStyle(Theme.muted)
                    }
                }
                Hint(tr("Телефон и компьютер должны быть в одной сети Wi-Fi."))
            }
        }
    }

    private var receiving: (String, Double)? {
        if case .receiving(let name, let part) = wifi.state { return (name, part) }
        return nil
    }

    private var came: some View {
        Block(tr("Принято")) {
            Text(tr("Файлов: {}", "\(wifi.received.count)")).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.fg)
            if wifi.skipped > 0 { Hint(tr("Уже были на телефоне: {}", "\(wifi.skipped)")) }
            ForEach(Array(wifi.received.suffix(8).reversed().enumerated()), id: \.offset) { _, rel in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(settings.accent)
                    Text(rel).font(.system(size: 14)).foregroundStyle(Theme.fg).lineLimit(1).truncationMode(.middle)
                }
            }
            ForEach(Array(wifi.problems.suffix(5).enumerated()), id: \.offset) { _, p in
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    Text(p).font(.system(size: 14)).foregroundStyle(Theme.fg).lineLimit(2)
                }
            }
        }
    }
}
