import SwiftUI

struct FarmPauseMenu: View {
    let onContinue: () -> Void
    let onSleep: () -> Void
    let onProfiles: () -> Void
    let onParents: () -> Void
    var onCoPlay: (() -> Void)?

    var body: some View {
        GeometryReader { space in
            let width = min(350, max(0, space.size.width - 24))
            let columns = width >= 272 ? 4 : 2

            ZStack {
                FarmScrim()
                VStack(spacing: 14) {
                    FarmLandscape()
                        .frame(height: space.size.height < 350 ? 54 : 78)
                        .clipShape(.rect(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(FarmInk.bark.opacity(0.24))
                        }
                        .accessibilityHidden(true)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                             count: columns), spacing: 8) {
                        key("play.fill", "Weiterspielen", "pause.continue",
                            color: FarmInk.moss, ink: .white, action: onContinue)
                            .keyboardShortcut(.cancelAction)
                        key("moon.stars.fill", "Schlafen gehen", "pause.sleep",
                            color: FarmInk.dusk, action: onSleep)
                        key("person.2.fill", "Profil auswählen", "pause.profiles",
                            color: FarmInk.hay, action: onProfiles)
                        key("lock.shield.fill", "Elternbereich öffnen", "pause.parents",
                            color: FarmInk.clay, action: onParents)
                    }
                    if let onCoPlay {
                        Button(action: onCoPlay) {
                            Label("Gemeinsam tragen", systemImage: "hands.sparkles.fill")
                                .font(.headline).frame(maxWidth: .infinity, minHeight: 64)
                                .background(FarmInk.sage, in: .rect(cornerRadius: 16))
                        }
                        .buttonStyle(.plain).foregroundStyle(FarmInk.bark)
                        .accessibilityIdentifier("pause.coPlay")
                    }
                }
                .padding(14)
                .frame(width: width)
                .background(FarmInk.paper, in: .rect(cornerRadius: 27))
                .overlay {
                    RoundedRectangle(cornerRadius: 27)
                        .strokeBorder(FarmInk.bark.opacity(0.42), lineWidth: 2)
                }
                .shadow(color: FarmInk.bark.opacity(0.32), radius: 12, y: 6)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Pausenmenü")
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape, onContinue)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func key(_ symbol: String, _ label: String, _ identifier: String,
                     color: Color, ink: Color = FarmInk.bark,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(color, in: .rect(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(FarmInk.bark.opacity(0.22))
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityIdentifier(identifier)
    }
}

private struct FarmScrim: View {
    var body: some View {
        FarmInk.bark.opacity(0.48)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

private struct FarmLandscape: View {
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 300, y: size.height / 80)
            context.fill(Path(CGRect(x: 0, y: 0, width: 300, height: 80)), with: .color(FarmInk.hay))
            context.fill(Path(ellipseIn: CGRect(x: 55, y: 9, width: 25, height: 25)),
                         with: .color(FarmInk.paper))

            var meadow = Path()
            meadow.move(to: CGPoint(x: 0, y: 49))
            meadow.addQuadCurve(to: CGPoint(x: 173, y: 49), control: CGPoint(x: 72, y: 18))
            meadow.addQuadCurve(to: CGPoint(x: 300, y: 36), control: CGPoint(x: 258, y: 22))
            meadow.addLine(to: CGPoint(x: 300, y: 80))
            meadow.addLine(to: CGPoint(x: 0, y: 80))
            meadow.closeSubpath()
            context.fill(meadow, with: .color(FarmInk.sage))

            var barn = Path()
            barn.move(to: CGPoint(x: 178, y: 45))
            barn.addLine(to: CGPoint(x: 178, y: 28))
            barn.addLine(to: CGPoint(x: 192, y: 17))
            barn.addLine(to: CGPoint(x: 206, y: 28))
            barn.addLine(to: CGPoint(x: 206, y: 45))
            barn.closeSubpath()
            context.fill(barn, with: .color(FarmInk.terracotta))
            context.fill(Path(CGRect(x: 188, y: 32, width: 8, height: 13)), with: .color(FarmInk.bark))

            var field = Path()
            field.move(to: CGPoint(x: 0, y: 80))
            field.addQuadCurve(to: CGPoint(x: 300, y: 54), control: CGPoint(x: 157, y: 30))
            field.addLine(to: CGPoint(x: 300, y: 80))
            field.closeSubpath()
            context.fill(field, with: .color(FarmInk.moss))
            for offset in [0, 24, 48] {
                var furrow = Path()
                furrow.move(to: CGPoint(x: 98 + offset, y: 80))
                furrow.addQuadCurve(to: CGPoint(x: 230 + offset, y: 54),
                                    control: CGPoint(x: 151 + offset, y: 61))
                context.stroke(furrow, with: .color(FarmInk.sage.opacity(0.7)), lineWidth: 1.5)
            }
        }
    }
}

private enum FarmInk {
    static let bark = Color(red: 0.22, green: 0.15, blue: 0.10)
    static let moss = Color(red: 0.22, green: 0.36, blue: 0.24)
    static let sage = Color(red: 0.65, green: 0.72, blue: 0.52)
    static let paper = Color(red: 1.00, green: 0.96, blue: 0.86)
    static let hay = Color(red: 0.97, green: 0.82, blue: 0.54)
    static let terracotta = Color(red: 0.65, green: 0.31, blue: 0.20)
    static let clay = Color(red: 0.91, green: 0.71, blue: 0.61)
    static let dusk = Color(red: 0.80, green: 0.80, blue: 0.87)
}
