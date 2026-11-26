import SwiftUI

struct BasketTogetherView: View {
    let owner: FamilyProfile
    let stage: FarmStage
    let profiles: [FamilyProfile]
    let storage: FamilyStorage
    let deliver: (UUID, BasketVisitor?) throws -> Void
    let close: () -> Void

    @State private var round: Round?
    @State private var issue: String?
    @Environment(\.scenePhase) private var scene

    private struct Round: Identifiable {
        let id = UUID()
        let visitor: BasketVisitor?
        var carry: BasketTouchSurface.Carry
        var saved = false
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                HStack {
                    Button(action: close) { Image(systemName: "arrow.uturn.backward.circle.fill").font(.largeTitle) }
                        .frame(width: 72, height: 72)
                        .accessibilityLabel("Zurück zum Hof").accessibilityIdentifier("coop.close")
                    Spacer()
                    Label("Gemeinsam tragen", systemImage: "hand.raised.fingers.spread.fill")
                        .font(.title2.bold())
                    Spacer()
                    FarmPictogram(id: "tool.basket").frame(width: 66, height: 66).accessibilityHidden(true)
                }
                if let current = round {
                    if current.saved {
                        Spacer()
                        FarmPictogram(id: "tool.basket").frame(maxHeight: 160).accessibilityHidden(true)
                        Label("Der Korb ist da!", systemImage: "checkmark.seal.fill")
                            .font(.title.bold()).accessibilityIdentifier("coop.delivered")
                        Button(action: close) {
                            Label("Zurück zum Hof", systemImage: "house.fill").foregroundStyle(.white).padding(12)
                        }
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("coop.finish")
                        Spacer()
                    } else {
                        HStack {
                            identity(owner.avatar, side: .left)
                            Spacer()
                            HStack {
                                ForEach(0..<current.carry.quota, id: \.self) { i in
                                    Image(systemName: i < current.carry.baskets ? "checkmark.circle.fill" : "basket")
                                }
                            }
                            .accessibilityLabel("Korb \(min(current.carry.baskets + 1, current.carry.quota)) von \(current.carry.quota)")
                            Spacer()
                            identity(current.visitor?.avatar, side: .right)
                        }
                        board(current)
                    }
                } else {
                    Spacer()
                    Text("Wer trägt mit?").font(.largeTitle.bold())
                    HStack(spacing: 16) {
                        ForEach(profiles.filter { $0.id != owner.id }) { profile in
                            Button {
                                do {
                                    begin(try BasketVisitor(profile: profile, saves: storage.saves(for: profile.id)))
                                } catch { issue = error.localizedDescription }
                            } label: {
                                ProfileAvatarFrame(avatar: profile.avatar, size: 90)
                            }
                            .accessibilityLabel("Mit \(profile.avatar.displayName) tragen")
                            .accessibilityIdentifier("coop.join.\(profile.avatar.rawValue)")
                        }
                        Button { begin(nil) } label: {
                            Image(systemName: "hand.raised.fill").font(.system(size: 44))
                                .foregroundStyle(.white).frame(width: 90, height: 90)
                                .background(Color(white: 0.40), in: .rect(cornerRadius: 18))
                        }
                        .accessibilityLabel("Graue Eltern-Hilfshand").accessibilityIdentifier("coop.join.helper")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(24)
            .foregroundStyle(Self.ink)
            .tint(Self.ink)
            .frame(maxWidth: 850, maxHeight: 590)
            .background(Color(red: 1, green: 0.96, blue: 0.86), in: .rect(cornerRadius: 32))
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, close)
        }
        .onChange(of: scene) { _, phase in if phase != .active { round?.carry.cancelContacts() } }
        .alert("Der Korb wartet", isPresented: Binding(get: { issue != nil }, set: { if !$0 { issue = nil } })) {
            if round?.carry.finished == true {
                Button("Noch einmal sichern") { complete() }
            }
            Button("Zurück zum Hof", action: close)
        } message: { Text(issue ?? "") }
    }

    private typealias Carry = BasketTouchSurface.Carry
    private static let ink = Color(red: 0.19, green: 0.27, blue: 0.22)

    private func begin(_ visitor: BasketVisitor?) {
        round = Round(visitor: visitor, carry: Carry(host: stage, visitor: visitor?.stage))
    }

    private func complete() {
        guard let current = round, current.carry.finished, !current.saved else { return }
        do {
            try deliver(current.id, current.visitor)
            round?.saved = true
        } catch { issue = error.localizedDescription }
    }

    private func color(_ side: Carry.Side) -> Color {
        side == .left ? Color(red: 0.21, green: 0.42, blue: 0.34)
            : (round?.visitor == nil ? Color(white: 0.40) : Color(red: 0.38, green: 0.36, blue: 0.57))
    }

    private func identity(_ avatar: ProfileAvatar?, side: Carry.Side) -> some View {
        HStack {
            if let avatar { FarmPictogram(id: avatar.rawValue).frame(width: 56, height: 56) }
            Image(systemName: side == .left ? "circle.fill" : "diamond.fill")
                .foregroundStyle(color(side))
            if avatar == nil { Image(systemName: "hand.raised.fill").foregroundStyle(color(side)) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(avatar?.displayName ?? "Eltern-Hilfshand")
    }

    private func board(_ current: Round) -> some View {
        GeometryReader { geo in
            let size = geo.size
            let a = current.carry.point(.left, in: size), b = current.carry.point(.right, in: size)
            let middle = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            let symbol = min(100, size.height * 0.25)
            ZStack {
                LinearGradient(colors: [Color(red: 0.82, green: 0.90, blue: 0.87),
                                        Color(red: 0.79, green: 0.84, blue: 0.65)],
                               startPoint: .top, endPoint: .bottom)
                FarmPictogram(id: "loc.plaza").frame(width: symbol * 1.3, height: symbol * 1.3)
                    .position(x: size.width / 2, y: size.height * 0.19)
                ForEach(Carry.Side.allCases, id: \.rawValue) { side in
                    let goal = Carry.anchor(side, goal: true, in: size)
                    let start = Carry.anchor(side, goal: false, in: size)
                    let form = side == .left ? "circle" : "diamond"
                    Image(systemName: "arrow.up").font(.largeTitle.weight(.light))
                        .foregroundStyle(color(side)).position(x: goal.x, y: (start.y + goal.y) / 2)
                    Image(systemName: form).resizable().scaledToFit().foregroundStyle(color(side))
                        .frame(width: symbol, height: symbol).position(goal)
                }
                Path { p in
                    p.move(to: a)
                    p.addQuadCurve(to: b, control: CGPoint(x: middle.x, y: middle.y + symbol * 0.42))
                }
                .stroke(Color.brown, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                FarmPictogram(id: "tool.basket").frame(width: symbol * 1.25, height: symbol * 1.25)
                    .position(middle)
                ForEach(Carry.Side.allCases, id: \.rawValue) { side in
                    Image(systemName: side == .left ? "circle.fill" : "diamond.fill")
                        .resizable().scaledToFit().foregroundStyle(color(side))
                        .overlay {
                            Image(systemName: current.carry.delivered(side) ? "checkmark" : "hand.raised.fill")
                                .font(.system(size: symbol * 0.37, weight: .semibold)).foregroundStyle(.white)
                        }
                        .frame(width: symbol, height: symbol)
                        .scaleEffect(current.carry.selected(side) ? 1.10 : 1)
                        .position(current.carry.point(side, in: size))
                }
                BasketTouchSurface { phase, id, p, radius, bounds in
                    round?.carry.input(phase, id: id, at: p, radius: radius, in: bounds)
                    if round?.carry.finished == true { complete() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipShape(.rect(cornerRadius: 22))
        }
        .accessibilityRepresentation {
            HStack {
                ForEach(Carry.Side.allCases, id: \.rawValue) { side in
                    let name = side == .left ? "Kreis" : "Raute"
                    Button("\(name): \(current.carry.selected(side) ? "ablegen" : "aufnehmen")") { activate(side) }
                        .disabled(current.carry.delivered(side))
                        .accessibilityIdentifier(side == .left ? "coop.grip.left" : "coop.grip.right")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Korbgriffe zum Hofplatz tragen")
        .accessibilityValue(current.carry.delivered(.left) ? "Kreis liegt am Ziel" :
                                current.carry.delivered(.right) ? "Raute liegt am Ziel" : "Beide Griffe bereit")
        .accessibilityIdentifier("coop.board")
    }

    private func activate(_ side: Carry.Side) {
        round?.carry.activate(side)
        if round?.carry.finished == true { complete() }
    }
}
