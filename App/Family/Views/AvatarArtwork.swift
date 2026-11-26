import SwiftUI

/// Draws the animal of a profile avatar. The host can swap in the real pictograms:
/// `.environment(\.familyAvatarArtwork, FamilyAvatarArtwork { AnyView(FarmPictogram(id: $0.rawValue)) })`
struct FamilyAvatarArtwork: Sendable {
    let render: @MainActor @Sendable (ProfileAvatar) -> AnyView

    init(render: @escaping @MainActor @Sendable (ProfileAvatar) -> AnyView) {
        self.render = render
    }

    static let emoji = FamilyAvatarArtwork { avatar in
        AnyView(
            Text(avatar.fallbackEmoji)
                .font(.system(size: 200))
                .minimumScaleFactor(0.05)
                .lineLimit(1)
        )
    }
}

extension EnvironmentValues {
    @Entry var familyAvatarArtwork: FamilyAvatarArtwork = .emoji
}

extension ProfileAvatar {
    /// Frame color. Each avatar also differs by its animal, so color is never the only cue.
    var frameColor: Color {
        switch self {
        case .cow: Color(red: 0.80, green: 0.30, blue: 0.24)
        case .sheep: Color(red: 0.25, green: 0.52, blue: 0.80)
        case .pig: Color(red: 0.86, green: 0.45, blue: 0.62)
        case .chicken: Color(red: 0.90, green: 0.66, blue: 0.10)
        case .duck: Color(red: 0.22, green: 0.62, blue: 0.40)
        case .rabbit: Color(red: 0.52, green: 0.38, blue: 0.74)
        }
    }
}

/// Picture frame with the avatar animal. No photo, no name (doc 11 §9).
struct ProfileAvatarFrame: View {
    let avatar: ProfileAvatar
    var size: CGFloat = 160
    var highContrast = false

    @Environment(\.familyAvatarArtwork) private var artwork

    var body: some View {
        let corner = size * 0.16
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(avatar.frameColor)
            RoundedRectangle(cornerRadius: corner * 0.7, style: .continuous)
                .fill(Color(red: 1.0, green: 0.98, blue: 0.93))
                .padding(size * 0.08)
            artwork.render(avatar)
                .frame(width: size * 0.62, height: size * 0.62)
        }
        .frame(width: size, height: size)
        .overlay {
            if highContrast {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.black, lineWidth: max(3, size * 0.03))
            }
        }
        .shadow(color: .black.opacity(highContrast ? 0 : 0.18), radius: size * 0.04, y: size * 0.03)
    }
}
