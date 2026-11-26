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
    private(set) var lateral = 0.0
    private(set) var steering = 0.0
    private(set) var throttle = 0.0
    private var wheelTarget = 0.0
    private var dragStart: Double?
    private(set) var reported = false

    var needsTicks: Bool {
        pilot == .pelle || pilot == .rowTap ||
        (pilot == .child && (throttle > 0 || abs(steering - wheelTarget) > 0.001))
    }

    mutating func tapRow(stage: WorldStage) {
        if stage == .seedling, pilot == .child { pilot = .rowTap }
    }

    /// Translation is relative to touch-down, so grabbing a partway-worked row
    /// never jumps back to the child's finger. Sideways misses cannot undo work.
    mutating func drag(stage: WorldStage, along: Double, across: Double) {
        guard stage == .shoot, pilot == .child else { return }
        let start = dragStart ?? progress
        dragStart = start
        let offset = min(1, max(-1, across))
        let magnet = 0.20 + 0.70 * (1 - abs(offset))
        lateral = offset * (1 - magnet)
        advance(to: max(progress, start + along))
    }

    mutating func releaseDrag() { dragStart = nil }

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
        steering += (wheelTarget - steering) * (1 - exp(-dt * 9))
        if abs(steering - wheelTarget) <= 0.001 { steering = wheelTarget }
        let speed: Double
        switch pilot {
        case .pelle, .rowTap:
            speed = 0.27
            lateral *= exp(-dt * 5)
        case .child:
            speed = throttle * 0.30
            lateral = max(-1, min(1, lateral + (steering * 2.6 - lateral) * speed * dt))
        case .finished: return
        }
        advance(to: progress + speed * dt)
    }

    private mutating func advance(to value: Double) {
        if value >= 1, pilot == .pelle {
            progress = 1
            pilot = .finished
        } else if value >= 0.85, pilot != .pelle {
            progress = 0.85
            assist()
        } else {
            progress = min(value, 1)
        }
    }

    /// Called after the last visible frame, not when the child reaches 85%.
    mutating func takeCompletion() -> Bool {
        guard pilot == .finished, !reported else { return false }
        reported = true
        return true
    }
}
