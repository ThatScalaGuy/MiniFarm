import CoreGraphics

/// Input identity is fixed at pickup, even if contacts cross. Only completed drops
/// latch; releasing early or receiving a UIKit cancellation never completes a side.
struct BasketCarry<Contact: Hashable> {
    enum Side: Int, CaseIterable { case left, right }
    enum Phase { case began, moved, ended, cancelled }

    private struct Grip {
        var contact: Contact?
        var point: CGPoint?
        var selected = false
        var delivered = false
        var beganAtGoal = false
    }

    let quota: Int
    private(set) var baskets = 0
    private var grips = [Grip(), Grip()]
    var finished: Bool { baskets == quota }

    init(host: FarmStage, visitor: FarmStage?) {
        func quota(_ stage: FarmStage) -> Int {
            switch stage { case .sprout: 1; case .shoot: 2; case .bloom: 3 }
        }
        self.quota = min(quota(host), quota(visitor ?? host))
    }

    func selected(_ side: Side) -> Bool { grips[side.rawValue].selected }
    func delivered(_ side: Side) -> Bool { grips[side.rawValue].delivered }

    func point(_ side: Side, in size: CGSize) -> CGPoint {
        grips[side.rawValue].point ?? Self.anchor(side, goal: delivered(side), in: size)
    }

    static func anchor(_ side: Side, goal: Bool, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * (side == .left ? 0.26 : 0.74), y: size.height * (goal ? 0.23 : 0.76))
    }

    mutating func input(_ phase: Phase, id: Contact, at p: CGPoint, radius: CGFloat, in size: CGSize) {
        guard !finished, size.width > 0, size.height > 0 else { return }
        let side: Side
        if phase == .began {
            guard radius <= 28, p.x >= 24, p.x <= size.width - 24, p.y >= 24, p.y <= size.height - 24,
                  !grips.contains(where: { $0.contact == id }) else { return }
            side = p.x < size.width / 2 ? .left : .right
        } else {
            guard let active = Side.allCases.first(where: { grips[$0.rawValue].contact == id }) else { return }
            side = active
        }
        let i = side.rawValue
        if radius > 28 { grips[i] = Grip(); return }
        let pickup = Self.anchor(side, goal: false, in: size)
        let goal = Self.anchor(side, goal: true, in: size)
        let tolerance = min(CGFloat(quota == 1 ? 86 : 66), size.height * 0.22, size.width * 0.20)
        func near(_ q: CGPoint) -> Bool { hypot(p.x - q.x, p.y - q.y) <= tolerance }
        switch phase {
        case .began:
            guard grips[i].contact == nil, !grips[i].delivered,
                  near(pickup) || (grips[i].selected && near(goal)) else { return }
            grips[i].contact = id
            grips[i].point = p
            grips[i].beganAtGoal = near(goal)
        case .moved:
            grips[i].point = p
        case .cancelled:
            grips[i] = Grip()
        case .ended:
            let tap = near(pickup) && !grips[i].beganAtGoal
            grips[i] = Grip(selected: tap)
            if near(goal) { place(side) }
        }
    }

    /// VoiceOver exposes the same pick and place sequence as tapping the two pictures.
    mutating func activate(_ side: Side) {
        guard !finished, !delivered(side), grips[side.rawValue].contact == nil else { return }
        if selected(side) { place(side) } else { grips[side.rawValue].selected = true }
    }

    mutating func cancelContacts() {
        for side in Side.allCases where !delivered(side) { grips[side.rawValue] = Grip() }
    }

    private mutating func place(_ side: Side) {
        grips[side.rawValue] = Grip(delivered: true)
        if grips.allSatisfy(\.delivered) {
            baskets += 1
            if !finished { grips = [Grip(), Grip()] }
        }
    }
}
