import SwiftUI

/// Root of the app: profile picker, the game for the active profile, the parental gate and the parent area.
///
/// ```swift
/// FamilyRootView(store: family) { session in
///     FarmHostView(session: session, family: family)
/// }
/// ```
/// The game view gets a fresh identity for every session. It stays mounted behind the gate and the parent area.
struct FamilyRootView<Game: View>: View {
    let store: FamilyStore
    private let game: (FamilySession) -> Game

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    init(store: FamilyStore, @ViewBuilder game: @escaping (FamilySession) -> Game) {
        self.store = store
        self.game = game
    }

    var body: some View {
        ZStack {
            if let session = store.session {
                game(session)
                    .id(session.id)
                    .accessibilityHidden(store.isParentFlowActive || isFallbackSleep)
            } else {
                ProfilePickerView(store: store)
                    .accessibilityHidden(store.isParentFlowActive)
            }
            if isFallbackSleep {
                GoodNightView()
                    .transition(.opacity)
            }
            switch store.parentFlow {
            case .gate:
                ParentalGateView(store: store)
                    .transition(.opacity)
            case .parentArea:
                ParentAreaView(store: store)
                    .transition(.opacity)
            case nil:
                EmptyView()
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.parentFlow)
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.2), value: isFallbackSleep)
        .task { await runClock() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active: store.sceneBecameActive()
            case .background: store.sceneEnteredBackground()
            default: store.sceneBecameInactive()
            }
        }
        .onChange(of: systemAccessibility, initial: true) { _, value in
            store.systemAccessibility = value
        }
    }

    private var isFallbackSleep: Bool {
        if case .fallbackSleep = store.sessionTimer.phase { return true }
        return false
    }

    private var systemAccessibility: SystemAccessibility {
        SystemAccessibility(
            reduceMotion: reduceMotion,
            increaseContrast: colorSchemeContrast == .increased,
            differentiateWithoutColor: differentiateWithoutColor,
            voiceOverEnabled: voiceOverEnabled
        )
    }

    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            store.tick()
        }
    }
}

/// Soft good night when the evening ritual did not end the session in time.
struct GoodNightView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.10, blue: 0.27), Color(red: 0.20, green: 0.18, blue: 0.42)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 32) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(Color(red: 1.0, green: 0.92, blue: 0.62))
                    .scaleEffect(glow ? 1.04 : 1.0)
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gute Nacht. Der Hof schläft.")
        .accessibilityIdentifier("family.goodNight")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}
