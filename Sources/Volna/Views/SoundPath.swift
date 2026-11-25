import AVFoundation
import AVKit
import SwiftUI

/// The way of the sound from the file to the ears, in steps. Only what is really known is shown:
/// iOS does not tell apps the Bluetooth codec or the bit depth sent to a DAC.
struct SoundPath: Equatable {
    /// What iOS says about the output.
    struct Output: Equatable {
        var port: AVAudioSession.Port = .builtInSpeaker
        var name = ""
        var rate = 48000.0
        var channels = 2
        var latency = 0.0
        var volume = 1.0

        @MainActor
        static func now() -> Output {
            #if DEBUG
                if let fake { return fake }
            #endif
            let s = AVAudioSession.sharedInstance(), o = s.currentRoute.outputs.first
            return Output(port: o?.portType ?? .builtInSpeaker, name: o?.portName ?? "—", rate: s.sampleRate, channels: s.outputNumberOfChannels,
                          latency: s.outputLatency + s.ioBufferDuration, volume: Double(s.outputVolume))
        }

        #if DEBUG
            @MainActor static var fake: Output?
        #endif

        var wireless: Bool { [.bluetoothA2DP, .bluetoothLE, .bluetoothHFP].contains(port) }
        /// The DAC outside the phone gets the numbers as they are.
        var digital: Bool { [.usbAudio, .HDMI, .thunderbolt, .displayPort].contains(port) }

        var kind: String {
            switch port {
            case .builtInSpeaker: tr("динамики iPhone")
            case .builtInReceiver: tr("разговорный динамик")
            case .headphones: tr("наушники по проводу")
            case .bluetoothA2DP: "Bluetooth (A2DP)"
            case .bluetoothLE: "Bluetooth LE Audio"
            case .bluetoothHFP: tr("Bluetooth, режим звонка")
            case .usbAudio: "USB"
            case .HDMI: "HDMI"
            case .displayPort: "DisplayPort"
            case .thunderbolt: "Thunderbolt"
            case .airPlay: "AirPlay"
            case .carAudio: tr("машина (CarPlay)")
            case .lineOut: tr("линейный выход")
            default: port.rawValue
            }
        }

        var icon: String {
            switch port {
            case .builtInSpeaker, .builtInReceiver: "iphone"
            case .headphones, .lineOut: "headphones"
            case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP: "headphones.circle"
            case .usbAudio, .thunderbolt: "cable.connector"
            case .HDMI, .displayPort: "tv"
            case .airPlay: "airplayaudio"
            case .carAudio: "car"
            default: "hifispeaker"
            }
        }
    }

    enum Mark { case plain, good, changed }

    struct Step: Equatable {
        let icon: String
        let title: String
        let value: String
        var detail = ""
        var mark = Mark.plain
    }

    let steps: [Step]
    /// What comes out in the end, in one or two sentences.
    let verdict: String
    let clean: Bool

    /// `rate` is the rate of the decoded song, `graph` the rate the player works at.
    static func build(_ t: Track?, rate: Double, channels: Int, graph: Double, _ v: Settings.Values, preset: String?, _ out: Output) -> SoundPath {
        var steps: [Step] = []
        let work = graph > 0 ? graph : out.rate
        let resampled = t != nil && rate > 0 && (abs(rate - work) > 1 || abs(work - out.rate) > 1)
        // every change of the rate on the way
        let chain = [work, out.rate].reduce([rate]) { abs(($1 - ($0.last ?? 0))) > 1 ? $0 + [$1] : $0 }
        if let t {
            let depth = t.bits.map { tr("{} бит / ", "\($0)") } ?? ""
            let file = t.kind + " · " + depth + OutputInfo.khz(t.sampleRate ?? rate)
            let how = t.isLossless ? tr("без потерь") : tr("со сжатием")
            steps.append(Step(icon: "doc", title: tr("Файл"), value: file, detail: [how, t.bitrateText].filter { !$0.isEmpty }.joined(separator: " · "),
                              mark: t.isLossless ? .good : .plain))
            steps.append(Step(icon: "cpu", title: tr("Распаковка"), value: "PCM · " + OutputInfo.khz(rate) + " · " + Self.channels(channels),
                              detail: tr("внутри плеера звук 32-битный")))
            steps.append(Step(icon: "waveform.path", title: tr("Частота"),
                              value: chain.map { OutputInfo.khz($0) }.joined(separator: " → "),
                              detail: resampled ? tr("пересчитывается") : tr("без пересчёта"), mark: resampled ? .changed : .good))
        }
        let changes = Self.changes(v, gain: t?.gainDb, preset: preset)
        steps.append(Step(icon: "slider.vertical.3", title: tr("Обработка"),
                          value: v.direct ? tr("Прямой вывод") : changes.isEmpty ? tr("ничего не меняет") : changes.joined(separator: ", "),
                          detail: v.direct ? tr("обработка обойдена") : "", mark: changes.isEmpty ? .good : .changed))
        steps.append(Step(icon: "speaker.wave.2", title: tr("Громкость iPhone"), value: "\(Int((out.volume * 100).rounded()))%"))
        steps.append(Step(icon: out.icon, title: tr("Устройство"), value: out.name, detail: out.kind))
        steps.append(Step(icon: "ear", title: tr("На выходе"), value: OutputInfo.khz(out.rate) + " · " + Self.channels(out.channels),
                          detail: out.latency > 0 ? tr("задержка {} мс", "\(Int((out.latency * 1000).rounded()))") : ""))
        let clean = !resampled && changes.isEmpty
        return SoundPath(steps: steps, verdict: Self.verdict(t, out, resampled: resampled, changed: !changes.isEmpty), clean: clean && out.digital && t != nil)
    }

    static func channels(_ n: Int) -> String { n == 1 ? tr("моно") : n == 2 ? tr("стерео") : tr("каналов: {}", "\(n)") }

    /// What the player itself does to the sound now.
    static func changes(_ v: Settings.Values, gain: Double?, preset: String?) -> [String] {
        guard !v.direct else { return [] }
        var c: [String] = []
        if v.eqOn, v.preamp != 0 || v.bands.contains(where: { $0 != 0 }) { c.append(tr("эквалайзер") + (preset.map { " «" + tr($0) + "»" } ?? "")) }
        if v.bass != 0 { c.append(tr("бас +") + String(format: "%g", v.bass) + tr(" дБ")) }
        if v.normalize, let gain, gain != 0 { c.append(tr("выравн. ") + formatDb(gain)) }
        if v.balance != 0 { c.append(tr("баланс") + " " + FXFormat.balance(v.balance)) }
        if v.rate != 1 { c.append(tr("скорость") + " " + FXFormat.rate(v.rate)) }
        if v.limiter { c.append(tr("лимитер")) }
        return c
    }

    private static func verdict(_ t: Track?, _ out: Output, resampled: Bool, changed: Bool) -> String {
        guard let t else { return tr("Включите песню, чтобы увидеть весь путь.") }
        let source = t.isLossless ? "" : " " + tr("Сам файл сжат с потерями, лучше него на выходе не станет.")
        switch out.port {
        case .bluetoothA2DP, .bluetoothLE:
            guard t.isLossless else { return tr("Файл уже сжат с потерями, а по Bluetooth звук сжимается ещё раз. Каким способом, iPhone приложениям не сообщает (обычно AAC).") }
            return tr("По Bluetooth звук сжимается ещё раз перед отправкой, поэтому без потерь он не дойдёт. Каким способом, iPhone приложениям не сообщает (обычно AAC).")
        case .bluetoothHFP:
            return tr("Наушники в режиме звонка: звук сильно упрощён. Закройте приложение, которое использует микрофон.")
        case .builtInSpeaker, .builtInReceiver:
            guard t.isLossless else { return tr("Файл сжат с потерями, лучше него на выходе не станет. Динамики iPhone работают на своей частоте, для такого файла это почти не слышно.") }
            return tr("Динамики iPhone работают на своей частоте. Чтобы услышать файл без потерь, нужны наушники по проводу или ЦАП.")
        case .airPlay:
            return tr("По AirPlay звук передаётся по Wi-Fi. В каком виде он доходит, iPhone приложениям не сообщает.") + source
        default:
            break
        }
        guard out.digital else {
            return (resampled ? tr("Звук идёт по проводу, но частота пересчитана.") : tr("Звук идёт по проводу на частоте песни.")) + source
        }
        if resampled { return tr("ЦАП работает не на частоте песни, она пересчитывается. Включите «Подстраивать вывод под файл»; если уже включено, ЦАП такую частоту не умеет.") + source }
        if changed { return tr("Частота песни сохранена, но плеер меняет звук обработкой. Чтобы убрать её, включите «Прямой вывод».") + source }
        return tr("Песня уходит на ЦАП на своей частоте, плеер ничего не меняет. Разрядность на выходе iPhone не сообщает, громкость лучше держать на 100%.") + source
    }
}

extension SoundPath {
    @MainActor
    static func now(_ player: Player, _ settings: Settings) -> SoundPath {
        let f = player.sourceFormat, t = player.current
        let out = Output.now()
        var graph = player.graph.rate
        #if DEBUG
            if Output.fake != nil { graph = out.rate }
        #endif
        return build(t, rate: f?.sampleRate ?? t?.sampleRate ?? 0, channels: Int(f?.channelCount ?? 2), graph: graph, settings.v,
                     preset: settings.preset?.name, out)
    }
}

struct SoundPathPage: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var player: Player

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let path = SoundPath.now(player, settings)
            VStack(spacing: 14) {
                Block {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(path.steps.enumerated()), id: \.offset) { i, s in
                            row(s, last: i == path.steps.count - 1)
                        }
                    }
                }
                Block(tr("Что получаем")) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: path.clean ? "checkmark.seal.fill" : "info.circle")
                            .foregroundStyle(path.clean ? settings.accent : Theme.muted)
                        Text(path.verdict).font(.system(size: 14)).foregroundStyle(Theme.fg).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        Block {
            HStack {
                Text(tr("Выбрать устройство")).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.fg)
                Spacer()
                RoutePicker(tint: UIColor(settings.accent)).frame(width: 40, height: 36)
            }
            if player.isPlaying == false { Hint(tr("Музыка на паузе: ЦАП переключится на частоту песни, когда она заиграет.")) }
        }
    }

    private func row(_ s: SoundPath.Step, last: Bool) -> some View {
        let color = s.mark == .plain ? Theme.muted : s.mark == .good ? settings.accent : Theme.danger
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: s.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(color.opacity(0.15)))
                if !last { Rectangle().fill(Theme.line).frame(width: 2).frame(maxHeight: .infinity) }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(s.title).font(.system(size: 12)).foregroundStyle(Theme.muted)
                Text(s.value).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.fg).fixedSize(horizontal: false, vertical: true)
                if !s.detail.isEmpty { Text(s.detail).font(.system(size: 13)).foregroundStyle(s.mark == .changed ? Theme.danger : Theme.muted) }
            }
            .padding(.bottom, last ? 0 : 16)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// The system list of outputs.
private struct RoutePicker: UIViewRepresentable {
    let tint: UIColor

    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.prioritizesVideoDevices = false
        return v
    }

    func updateUIView(_ v: AVRoutePickerView, context: Context) {
        v.tintColor = tint
        v.activeTintColor = tint
    }
}
