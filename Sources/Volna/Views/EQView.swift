import SwiftUI

/// 10-band equaliser, 31 Hz … 16 kHz, ±12 dB.
struct EQView: View {
    @EnvironmentObject private var player: Player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Toggle("Включён", isOn: $player.eqEnabled)
                    .tint(Theme.accent)
                    .foregroundStyle(Theme.fg)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EQPreset.all) { preset in
                            let active = preset.gains == player.eqGains
                            Button(preset.name) { player.eqGains = preset.gains }
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .foregroundStyle(active ? Theme.accentInk : Theme.fg)
                                .background(Capsule().fill(active ? Theme.accent : Theme.raise))
                        }
                    }
                }
                .disabled(!player.eqEnabled)

                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<Player.frequencies.count, id: \.self) { i in
                        VStack(spacing: 8) {
                            Text(gainLabel(player.eqGains[i]))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(player.eqGains[i] == 0 ? Theme.muted : Theme.accent)
                            VerticalSlider(value: $player.eqGains[i], range: Player.gainRange)
                                .frame(height: 230)
                            Text(Player.bandLabels[i])
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .opacity(player.eqEnabled ? 1 : 0.4)
                .disabled(!player.eqEnabled)

                Text("Крайние полосы поднимают весь самый низ и весь верх, до 20 кГц. Двойное касание полосы возвращает её в ноль. Когда полосы подняты, общая громкость сама чуть снижается, чтобы звук не хрипел.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Эквалайзер")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func gainLabel(_ g: Float) -> String {
        g == 0 ? "0" : String(format: "%+.0f", g)
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
                Capsule().fill(Theme.raise).frame(width: 4)
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 4, height: abs(knobY - zeroY))
                    .position(x: geo.size.width / 2, y: (knobY + zeroY) / 2)
                Rectangle().fill(Theme.line).frame(width: 12, height: 1)
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
