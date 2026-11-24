import SwiftUI
import UIKit.UIGestureRecognizerSubclass

/// The full-screen visualisation shown after a while without touches. A tap brings the player back.
struct SaverView: View {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var ui: UIState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = CGSize.zero

    var body: some View {
        GeometryReader { geo in
            let s = geo.size, wide = s.width > s.height
            ZStack {
                Color.black
                CoverView(track: player.current, corner: 0, letter: 0)
                    .frame(width: s.width, height: s.height)
                    .blur(radius: 70, opaque: true)
                    .opacity(0.28)
                    .clipped()
                if mode.wholeScreen {
                    VizStrip(mode: mode, height: s.height)
                    titles(.center)
                        .shadow(color: .black, radius: 8)
                        .padding(.horizontal, 30)
                        .padding(.bottom, wide ? 34 : 90)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .offset(drift)
                } else {
                    Group {
                        if wide { landscape(s) } else { portrait(s) }
                    }
                    .offset(drift)
                }
            }
            .frame(width: s.width, height: s.height)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .contentShape(Rectangle())
        .onTapGesture(perform: close)
        .gesture(DragGesture(minimumDistance: 15).onEnded { _ in close() })
        .accessibilityElement()
        .accessibilityLabel("Заставка. Нажмите, чтобы вернуться к плееру")
        .accessibilityAddTraits(.isButton)
        .task {
            // a still picture is not good for the screen, so everything wanders a little
            while !Task.isCancelled, !reduceMotion {
                withAnimation(.easeInOut(duration: 12)) {
                    drift = CGSize(width: .random(in: -7...7), height: .random(in: -14...14))
                }
                try? await Task.sleep(for: .seconds(12))
            }
        }
    }

    private var mode: VizMode {
        let m = settings.v.saverViz == .off ? settings.v.viz : settings.v.saverViz
        return m == .off ? .ring : m
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.25)) { ui.saver = false }
    }

    private func portrait(_ s: CGSize) -> some View {
        VStack(spacing: 36) {
            if mode == .ring {
                RingCover(track: player.current, side: s.width - 20)
            } else {
                VizStrip(mode: mode, height: s.height * (mode.tall ? 0.5 : 0.4)).padding(.horizontal, 20)
            }
            titles(.center).padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private func landscape(_ s: CGSize) -> some View {
        if mode == .ring {
            HStack(spacing: 30) {
                RingCover(track: player.current, side: s.height - 30)
                titles(.leading).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 70)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 20) {
                VizStrip(mode: mode, height: s.height * 0.62)
                titles(.center)
            }
            .padding(.horizontal, 80)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func titles(_ align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 6) {
            Text(player.current?.title ?? "").font(.display(20, .semibold)).foregroundStyle(Theme.fg)
            if let a = player.current?.artist, !a.isEmpty {
                Text(a).font(.system(size: 16)).foregroundStyle(Theme.muted)
            }
        }
        .lineLimit(2)
        .multilineTextAlignment(align == .center ? .center : .leading)
    }
}

/// Starts the screensaver after the chosen time without touches, only on the main screen while music plays.
struct SaverControl: ViewModifier {
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var ui: UIState
    @Environment(\.scenePhase) private var scenePhase

    private struct Key: Equatable {
        let ready: Bool
        let seconds: Int
    }

    private var ready: Bool {
        settings.v.saverOn && player.isPlaying && !ui.saver && ui.nothingOpen && !settings.v.lyricsOn
            && scenePhase == .active && !UIAccessibility.isVoiceOverRunning
    }

    func body(content: Content) -> some View {
        content
            .environment(\.covered, ui.saver)
            .background(TouchWatch { ui.touch($0) })
            .overlay { if ui.saver { SaverView().transition(.opacity) } }
            .statusBarHidden(ui.saver)
            .persistentSystemOverlays(ui.saver ? .hidden : .automatic)
            .task(id: Key(ready: ready, seconds: settings.v.saver)) {
                guard ready else { return }
                let start = Date(), wait = Double(settings.v.saver)
                while !Task.isCancelled {
                    let left = wait + max(start, ui.lastTouch).timeIntervalSinceNow
                    if left <= 0, !ui.touching {
                        withAnimation(.easeInOut(duration: 0.8)) { ui.saver = true }
                        return
                    }
                    try? await Task.sleep(for: .seconds(max(0.3, left)))
                }
            }
            .onChange(of: player.isPlaying) { _, on in
                if !on { withAnimation { ui.saver = false } }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { ui.saver = false }
            }
            .onChange(of: ui.saver) { _, on in
                UIApplication.shared.isIdleTimerDisabled = on && settings.v.saverAwake
            }
    }
}

extension EnvironmentValues {
    /// The screensaver is on top: what is under it does not need to move.
    @Entry var covered = false
}

/// Sees every touch in the window and takes none of them.
private struct TouchWatch: UIViewRepresentable {
    let onTouch: (Bool) -> Void

    func makeUIView(context: Context) -> Holder { Holder(onTouch) }
    func updateUIView(_ v: Holder, context: Context) {}

    final class Holder: UIView {
        private let watcher: Watcher

        init(_ onTouch: @escaping (Bool) -> Void) {
            watcher = Watcher(onTouch)
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            watcher.view?.removeGestureRecognizer(watcher)
            window?.addGestureRecognizer(watcher)
        }
    }

    final class Watcher: UIGestureRecognizer {
        private let onTouch: (Bool) -> Void

        init(_ onTouch: @escaping (Bool) -> Void) {
            self.onTouch = onTouch
            super.init(target: nil, action: nil)
            cancelsTouchesInView = false
            delaysTouchesBegan = false
            delaysTouchesEnded = false
        }

        override func canPrevent(_ other: UIGestureRecognizer) -> Bool { false }
        override func canBePrevented(by other: UIGestureRecognizer) -> Bool { false }
        override func shouldRequireFailure(of other: UIGestureRecognizer) -> Bool { false }
        override func shouldBeRequiredToFail(by other: UIGestureRecognizer) -> Bool { false }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { onTouch(true) }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { finish(event) }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { finish(event) }

        private func finish(_ event: UIEvent) {
            let down = event.allTouches?.contains { $0.phase != .ended && $0.phase != .cancelled } ?? false
            if !down { state = .failed }
        }

        override func reset() {
            super.reset()
            onTouch(false)
        }
    }
}
