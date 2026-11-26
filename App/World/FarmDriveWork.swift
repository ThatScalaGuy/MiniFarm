import Foundation

/// A driving turn describes a visible pass over a row. The host remains the only
/// owner of the real plots, implements, inventory and successful choice.
enum FarmDriveWork: Equatable {
    case plow, sow, water, dig, lift, combine, clearSnow

    static func job(for turn: WorldTurn, farmLevel: Int) -> Self? {
        guard farmLevel >= 2, let target = turn.targetID else { return nil }
        let gear = turn.workGear
        if turn.offering.activityID == "act.field.snowplow", turn.offering.locationID == "loc.plaza",
           turn.stepID == "path", target == "plaza.path", gear.contains("imp.snowplow") { return .clearSnow }
        guard turn.stepID == "field", turn.offering.locationID == "loc.field", turn.workBeds.contains(target)
        else { return nil }
        if turn.offering.activityID == "act.field.combine", gear.contains("veh.combine") { return .combine }
        guard gear.contains("veh.tractor") else { return nil }
        switch turn.offering.activityID {
        case "act.field.plow" where gear.contains("imp.plow"): return .plow
        case "act.field.sow" where gear.contains("imp.seeder"): return .sow
        case "act.field.water" where gear.contains("imp.watertank"): return .water
        case "act.field.harvest" where gear.contains("imp.potatodigger"): return .dig
        case "act.field.harvest" where gear.contains("imp.loader"): return .lift
        default: return nil
        }
    }

    var vehicle: String { self == .combine ? "veh.combine" : "veh.tractor" }
    var implement: String? {
        switch self {
        case .plow: "imp.plow"
        case .sow: "imp.seeder"
        case .water: "imp.watertank"
        case .dig: "imp.potatodigger"
        case .lift: "imp.loader"
        case .combine: nil
        case .clearSnow: "imp.snowplow"
        }
    }
}

struct FarmDriveMotion: Equatable {
    enum Pilot: Equatable { case child, rowTap, pelle, finished }
    private(set) var pilot = Pilot.child
    private(set) var progress = 0.0
    private(set) var travel = 0.0
    private(set) var fastRow = false
    private(set) var lateral = 0.0
    private(set) var steering = 0.0
    private(set) var throttle = 0.0
    private var wheelTarget = 0.0
    private var dragStart: Double?
    private var dragWheelSeconds = 0.0
    private(set) var reported = false
    private let strips: [ClosedRange<Double>]
    private let workLength: Double

    init(strips: [ClosedRange<Double>] = [0...1]) {
        self.strips = strips.sorted { $0.lowerBound < $1.lowerBound }
        workLength = strips.reduce(0) { $0 + $1.upperBound - $1.lowerBound }
    }

    var needsTicks: Bool {
        pilot == .pelle || pilot == .rowTap ||
        (pilot == .child && (throttle > 0 || dragWheelSeconds > 0 || abs(steering - wheelTarget) > 0.001))
    }

    var wheelsTurning: Bool {
        switch pilot {
        case .rowTap, .pelle: true
        case .child: throttle > 0 || dragWheelSeconds > 0
        case .finished: false
        }
    }

    mutating func tapRow(stage: WorldStage) {
        if stage == .seedling, pilot == .child { pilot = .rowTap }
    }

    mutating func setRowPace(fast: Bool) { fastRow = fast }

    /// Translation is relative to touch-down, so grabbing a partway-worked row
    /// never jumps back to the child's finger. Sideways misses cannot undo work.
    mutating func drag(stage: WorldStage, along: Double, across: Double) {
        guard stage == .shoot, pilot == .child else { return }
        let start = dragStart ?? travel
        dragStart = start
        let offset = min(1, max(-1, across))
        let magnet = 0.20 + 0.70 * (1 - abs(offset))
        lateral = offset * (1 - magnet)
        let next = max(travel, start + along)
        // Touch updates stop arriving when a finger rests on the glass.
        dragWheelSeconds = next > travel ? 0.12 : 0
        advance(to: next)
    }

    mutating func releaseDrag() {
        dragStart = nil
        dragWheelSeconds = 0
    }

    mutating func turnWheel(stage: WorldStage, to value: Double) {
        guard stage == .bloom, pilot == .child else { return }
        wheelTarget = min(1, max(-1, value))
    }

    mutating func setGas(stage: WorldStage, to value: Double) {
        guard stage == .bloom, pilot == .child else { return }
        throttle = min(1, max(0, value))
    }

    mutating func assist() {
        guard pilot == .child || pilot == .rowTap else { return }
        pilot = .pelle
        releaseDrag()
        wheelTarget = 0
        throttle = 0
    }

    mutating func suspend() {
        throttle = 0
        steering = 0
        wheelTarget = 0
        releaseDrag()
        // A tap or an explicit Pelle takeover stays requested. Its clock only
        // runs while the farm is visible; no catch-up after a night in the dock.
    }

    mutating func tick(seconds: Double) {
        guard pilot != .finished else { return }
        let dt = min(0.10, max(0, seconds))
        dragWheelSeconds = max(0, dragWheelSeconds - dt)
        steering += (wheelTarget - steering) * (1 - exp(-dt * 9))
        if abs(steering - wheelTarget) <= 0.001 { steering = wheelTarget }
        let speed: Double
        switch pilot {
        case .pelle, .rowTap:
            speed = pilot == .pelle ? 0.27 : (fastRow ? 0.32 : 0.22)
            lateral *= exp(-dt * 5)
        case .child:
            speed = throttle * 0.30
            lateral = max(-1, min(1, lateral + (steering * 2.6 - lateral) * speed * dt))
        case .finished: return
        }
        advance(to: travel + speed * dt)
    }

    private mutating func advance(to value: Double) {
        guard workLength > 0 else { return }
        let worked = strips.reduce(0.0) { sum, strip in
            sum + max(0, min(value, strip.upperBound) - strip.lowerBound)
        }
        if value >= 1, pilot == .pelle {
            travel = 1
            progress = 1
            pilot = .finished
        } else if worked >= workLength * 0.85, pilot != .pelle {
            var remaining = workLength * 0.85
            for strip in strips {
                let width = strip.upperBound - strip.lowerBound
                if remaining <= width { travel = strip.lowerBound + remaining; break }
                remaining -= width
            }
            progress = 0.85
            assist()
        } else {
            travel = min(value, 1)
            progress = min(1, worked / workLength)
        }
    }

    /// Called after the last visible frame, not when the child reaches 85%.
    mutating func takeCompletion() -> Bool {
        guard pilot == .finished, !reported else { return false }
        reported = true
        return true
    }
}
