import SwiftUI

/// 10-band equaliser, 31 Hz … 16 kHz, ±12 dB; the outer bands are shelves.
/// Used as a tab (no "Готово" button) and as a sheet from the big player.
struct EQView: View {
    @EnvironmentObject private var player: Player
    @Environment(\.dismiss) private var dismiss
    var showsDone = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Toggle("Включён", isOn: $player.eqEnabled)
                        .tint(Theme.accent)
                        .foregroundStyle(Theme.fg)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))

                    ScrollView(.horizontal, showsIndicators: false) {
                        GlassEffectContainer(spacing: 8) {
                            HStack(spacing: 8) {
                                ForEach(EQPreset.all) { preset in
                                    PresetButton(name: preset.name, active: preset.gains == player.eqGains) {
                                        withAnimation(.snappy) { player.eqGains = preset.gains }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .scrollClipDisabled()
                    .disabled(!player.eqEnabled)

                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(0..<Player.frequencies.count, id: \.self) { i in
                            VStack(spacing: 8) {
                                Text(gainLabel(player.eqGains[i]))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(player.eqGains[i] == 0 ? Theme.muted : Theme.accent)
                                VerticalSlider(value: $player.eqGains[i], range: Player.gainRange)
                                    .frame(height: 240)
                                Text(Player.bandLabels[i])
                                    .font(.caption2)
                                    .foregroundStyle(Theme.muted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, 6)
                    .glassEffect(.regular, in: .rect(cornerRadius: 26))
                    .opacity(player.eqEnabled ? 1 : 0.45)
                    .disabled(!player.eqEnabled)

                    Text("Крайние полосы поднимают весь самый низ и весь верх, до 20 кГц. Двойное касание полосы возвращает её в ноль. Когда полосы подняты, общая громкость сама чуть снижается, чтобы звук не хрипел.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .background {
                ZStack {
                    Theme.bg
                    RadialGradient(colors: [Theme.accent.opacity(0.18), .clear], center: .topTrailing, startRadius: 0, endRadius: 480)
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Эквалайзер")
            .navigationBarTitleDisplayMode(showsDone ? .inline : .large)
            .toolbar {
                if showsDone {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") { dismiss() }
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func gainLabel(_ g: Float) -> String {
        g == 0 ? "0" : String(format: "%+.0f", g)
    }
}

private struct PresetButton: View {
    let name: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        if active {
            Button(action: action) {
                Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accentInk)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.accent)
        } else {
            Button(action: action) {
                Text(name).font(.subheadline.weight(.medium)).foregroundStyle(Theme.fg)
            }
            .buttonStyle(.glass)
        }
    }
}

struct VerticalSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let span = range.upperBound - range.lowerBound
            let fraction = CGFloat((value - range.lowerBound) / span)
            let zeroY = h * (1 - CGFloat((0 - range.lowerBound) / span))
            let knobY = h * (1 - fraction)
            ZStack {
                Capsule().fill(Theme.line.opacity(0.7)).frame(width: 4)
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 4, height: abs(knobY - zeroY))
                    .position(x: geo.size.width / 2, y: (knobY + zeroY) / 2)
                Rectangle().fill(Theme.muted.opacity(0.6)).frame(width: 12, height: 1)
                    .position(x: geo.size.width / 2, y: zeroY)
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .position(x: geo.size.width / 2, y: knobY)
            }
            .frame(width: geo.size.width, height: h)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let p = Float(1 - min(max(drag.location.y / h, 0), 1))
                        let v = (range.lowerBound + p * span).rounded()
                        if v != value { value = v }
                    }
            )
            .simultaneousGesture(TapGesture(count: 2).onEnded { value = 0 })
        }
    }
}
