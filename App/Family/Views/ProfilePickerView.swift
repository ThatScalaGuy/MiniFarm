import SwiftUI

/// Child facing profile choice: one big picture frame per profile, no text to read (doc 11 §9).
struct ProfilePickerView: View {
    let store: FamilyStore

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack(alignment: .topLeading) {
            PickerBackground()
            Group {
                if store.profiles.isEmpty {
                    welcome
                } else {
                    profileGrid
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            parentButton
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("family.picker")
    }

    private var profileGrid: some View {
        let large: CGFloat = horizontalSizeClass == .regular ? 200 : 150
        let count = max(store.profiles.count, 1)
        return ViewThatFits {
            grid(columns: count, size: large)
            grid(columns: min(count, 2), size: large)
            grid(columns: count, size: 120)
            grid(columns: min(count, 2), size: 110)
        }
    }

    private func grid(columns: Int, size: CGFloat) -> some View {
        Grid(horizontalSpacing: size * 0.18, verticalSpacing: size * 0.18) {
            ForEach(Array(rows(columns: columns).enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row) { profile in
                        Button {
                            store.startSession(profile.id)
                        } label: {
                            ProfileAvatarFrame(
                                avatar: profile.avatar,
                                size: size,
                                highContrast: store.systemAccessibility.increaseContrast
                                    || store.systemAccessibility.differentiateWithoutColor
                                    || profile.settings.comfort.highContrast
                            )
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Profil \(profile.avatar.displayName)")
                        .accessibilityHint("Spielen")
                        .accessibilityIdentifier("family.picker.profile.\(profile.avatar.rawValue)")
                    }
                }
            }
        }
        .padding(.horizontal, 64)
        .padding(.vertical, 32)
    }

    private func rows(columns: Int) -> [[FamilyProfile]] {
        stride(from: 0, to: store.profiles.count, by: columns).map {
            Array(store.profiles[$0..<min($0 + columns, store.profiles.count)])
        }
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 96))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Willkommen bei MiniFarm")
                    .font(.title.bold())
                Text("Für Eltern: Legen Sie zuerst ein Profil für Ihr Kind an. \(FamilyInfo.offlineNote)")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .foregroundStyle(Color(red: 0.25, green: 0.18, blue: 0.10))
            Button {
                store.requestParentArea()
            } label: {
                Label("Profil einrichten", systemImage: "lock")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.36, green: 0.55, blue: 0.24))
            .accessibilityIdentifier("family.picker.setupButton")
        }
        .padding(32)
    }

    private var parentButton: some View {
        Button {
            store.requestParentArea()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(red: 0.35, green: 0.30, blue: 0.24).opacity(0.7))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(12)
        .accessibilityLabel("Elternbereich")
        .accessibilityIdentifier("family.picker.parentButton")
    }
}

private struct PickerBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.73, green: 0.88, blue: 0.97), Color(red: 0.96, green: 0.92, blue: 0.80)],
            startPoint: .top,
            endPoint: .center
        )
        .overlay(alignment: .bottom) {
            Ellipse()
                .fill(Color(red: 0.55, green: 0.76, blue: 0.40))
                .frame(height: 220)
                .scaleEffect(x: 1.6)
                .offset(y: 110)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Gentle press feedback that honors Reduce Motion.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.8 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2), value: configuration.isPressed)
    }
}
