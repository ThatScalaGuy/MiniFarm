enum FarmStage: String, Codable, Sendable, CaseIterable {
    case sprout, shoot, bloom
}

enum FarmAssist: Int, Codable, Sendable {
    case cue = 0, hint, ghost, reduced, together

    fileprivate var assisted: Bool { rawValue >= Self.reduced.rawValue }
}

struct FarmAdaptiveRules: Codable, Sendable {
    struct Mastery: Codable, Sendable {
        struct Weights: Codable, Sendable {
            let independent, hinted, assisted: Double
        }
        let initial, alphaStart, alphaNormal, alphaMin: Double
        let bootstrapObservations, stableObservations: Int
        let difficultyStep: Double
        let weights: Weights
    }

    struct Scaffold: Codable, Sendable {
        struct StageSeconds: Codable, Sendable {
            let sprout, shoot, bloom: Int

            subscript(stage: FarmStage) -> Int {
                switch stage {
                case .sprout: sprout
                case .shoot: shoot
                case .bloom: bloom
                }
            }
        }
        let stillnessHintSec: [Int]
        let ghostFails, reduceFails, togetherFails: Int
        let firstHintSec: StageSeconds
        let earlyHintFactor: Double
    }

    struct Thresholds: Codable, Sendable {
        struct LevelUp: Codable, Sendable { let window, minIndependent: Int }
        struct LevelDown: Codable, Sendable { let window, minAssisted: Int }
        struct StageUp: Codable, Sendable { let medianMastery: Double; let days: Int }
        struct LongBreak: Codable, Sendable {
            let afterDays: Int
            let retention: Double
            let warmupTasks: Int
        }
        let levelUp: LevelUp
        let levelDown: LevelDown
        let stageUp: StageUp
        let longBreak: LongBreak
    }

    struct Fatigue: Codable, Sendable {
        let sproutMin, shootMin, bloomMin: [Int]

        subscript(stage: FarmStage) -> [Int] {
            switch stage {
            case .sprout: sproutMin
            case .shoot: shootMin
            case .bloom: bloomMin
            }
        }
    }

    let schemaVersion: Int
    let mastery: Mastery
    let scaffold: Scaffold
    let thresholds: Thresholds
    let fatigue: Fatigue

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        mastery = try values.decode(Mastery.self, forKey: .mastery)
        scaffold = try values.decode(Scaffold.self, forKey: .scaffold)
        thresholds = try values.decode(Thresholds.self, forKey: .thresholds)
        fatigue = try values.decode(Fatigue.self, forKey: .fatigue)

        let up = thresholds.levelUp, down = thresholds.levelDown
        let weights = mastery.weights
        let fractions = [mastery.initial, mastery.alphaStart, mastery.alphaNormal, mastery.alphaMin,
                         mastery.difficultyStep, weights.independent, weights.hinted, weights.assisted,
                         thresholds.stageUp.medianMastery, thresholds.longBreak.retention, scaffold.earlyHintFactor]
        func positivePair(_ values: [Int]) -> Bool {
            values.count == 2 && values[0] > 0 && values[0] <= values[1]
        }
        guard schemaVersion == 1, fractions.allSatisfy({ (0...1).contains($0) }),
              mastery.alphaMin > 0, mastery.alphaMin <= mastery.alphaNormal,
              mastery.alphaNormal <= mastery.alphaStart, mastery.bootstrapObservations > 0,
              mastery.stableObservations > mastery.bootstrapObservations,
              weights.assisted < weights.hinted, weights.hinted < weights.independent,
              up.minIndependent > 0, up.minIndependent <= up.window, up.window <= 20,
              down.minAssisted > 0, down.minAssisted <= down.window, down.window <= 20,
              (1...365).contains(thresholds.stageUp.days), thresholds.longBreak.afterDays >= 0,
              thresholds.longBreak.warmupTasks >= 0, positivePair(scaffold.stillnessHintSec),
              scaffold.ghostFails > 0, scaffold.ghostFails < scaffold.reduceFails,
              scaffold.reduceFails < scaffold.togetherFails,
              FarmStage.allCases.allSatisfy({ (1...20).contains(scaffold.firstHintSec[$0]) && positivePair(fatigue[$0]) })
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid adaptive rules"))
        }
    }
}

/// Local to one profile. Stores short, per-lane outcome windows, not a log of taps or activities.
struct FarmSkills: Codable, Sendable {
    private struct Lane: Codable, Sendable {
        var mastery: Double
        var confidence = 0.0
        var observations = 0
        var recent: [FarmAssist] = []
        var adjustment = 0
        var lastDay: Int
    }

    // Activity files use Doc 16 identifiers; the catalog also uses Doc 02 dotted names.
    private static let aliases = [
        "mo.tap": "moTap", "mo.drag": "moDrag", "mo.steer": "moSteer", "cog.memory": "cogMemory",
        "cog.sequence": "cogSequence", "cog.matching": "cogMatching", "math.count": "mathCount",
        "perc.shape": "percShape", "lang.vocab": "langVocab", "world.time": "worldTime"
    ]
    private static let measured = Set(aliases.values)
    private static let motor: Set<String> = ["moTap", "moDrag", "moSteer"]
    private static let cognitive: Set<String> = ["cogMemory", "cogSequence", "cogMatching"]

    private(set) var schemaVersion = 1
    private(set) var lastPlayedDay: Int?
    private var lanes: [String: Lane] = [:]
    private var qualifyingDays: [Int] = []
    private var requiredDays: Int?
    private var lastPromotionDay: Int?
    private var longBreak: FarmAdaptiveRules.Thresholds.LongBreak?
    private var warmupRemaining = 0
    private var sessionDay: Int?
    private(set) var todaySessionSec = 0

    init() {}

    var mastery: [String: Double] { lanes.mapValues(\.mastery) }
    var confidence: [String: Double] { lanes.mapValues(\.confidence) }

    private static func measuredIDs(_ ids: [String]) -> [String] {
        Set(ids.map { aliases[$0] ?? $0 }).intersection(measured).sorted()
    }

    mutating func record(lanes ids: [String], assist: FarmAssist, day: Int, rules: FarmAdaptiveRules) {
        let measuredIDs = Self.measuredIDs(ids)
        guard !measuredIDs.isEmpty, day >= 0, day >= lastPlayedDay ?? 0 else { return }
        lastPlayedDay = day
        newSessionDayIfNeeded(day)
        longBreak = rules.thresholds.longBreak
        requiredDays = rules.thresholds.stageUp.days

        let model = rules.mastery
        let up = rules.thresholds.levelUp, down = rules.thresholds.levelDown
        let weight: Double = switch assist {
        case .cue: model.weights.independent
        case .hint, .ghost: model.weights.hinted
        case .reduced, .together: model.weights.assisted
        }
        for id in measuredIDs {
            var lane = lanes[id] ?? Lane(mastery: model.initial, lastDay: day)
            let stableFraction = min(1, Double(max(0, lane.observations - model.bootstrapObservations)) /
                                     Double(model.stableObservations - model.bootstrapObservations))
            let alpha = lane.observations < model.bootstrapObservations ? model.alphaStart :
                model.alphaNormal + (model.alphaMin - model.alphaNormal) * stableFraction
            // The same independent outcome is stronger evidence on a harder variant.
            let expected = min(1, max(0, lane.mastery - Double(lane.adjustment) * model.difficultyStep))
            lane.mastery = min(1, max(0, lane.mastery + alpha * (weight - expected)))
            if lane.observations < model.stableObservations { lane.observations += 1 }
            lane.confidence = min(1, Double(lane.observations) / Double(model.stableObservations))
            lane.lastDay = day
            lane.recent.append(assist)
            lane.recent = Array(lane.recent.suffix(max(up.window, down.window)))
            if lane.recent.count >= down.window,
               lane.recent.suffix(down.window).filter(\.assisted).count >= down.minAssisted {
                lane.adjustment = -1
            } else if lane.recent.count >= up.window,
                      lane.recent.suffix(up.window).filter({ $0 == .cue }).count >= up.minIndependent {
                lane.adjustment = 1
            }
            lanes[id] = lane
        }
        warmupRemaining = max(0, warmupRemaining - 1)
        if measuredIDs.contains(where: { Self.motor.contains($0) || Self.cognitive.contains($0) }) {
            recordStageEvidence(day: day, rules: rules)
        }
    }

    private mutating func recordStageEvidence(day: Int, rules: FarmAdaptiveRules) {
        guard day > (lastPromotionDay ?? -1) else { return }
        let sampled = lanes.filter { $0.value.observations >= rules.mastery.bootstrapObservations }
        let ids = Set(sampled.keys)
        guard !ids.isDisjoint(with: Self.motor), !ids.isDisjoint(with: Self.cognitive) else { return }
        let values = sampled.filter { Self.motor.contains($0.key) || Self.cognitive.contains($0.key) }
            .values.map(\.mastery).sorted()
        let median = (values[(values.count - 1) / 2] + values[values.count / 2]) / 2
        guard median > rules.thresholds.stageUp.medianMastery else {
            qualifyingDays.removeAll()
            return
        }
        if day != qualifyingDays.last {
            qualifyingDays.append(day)
            qualifyingDays = Array(qualifyingDays.suffix(rules.thresholds.stageUp.days))
        }
    }

    func recommendedStage(current: FarmStage, day: Int) -> FarmStage {
        guard let requiredDays, qualifyingDays.count >= requiredDays, let latest = qualifyingDays.last,
              day >= latest, let longBreak, day - latest <= longBreak.afterDays else { return current }
        return current == .sprout ? .shoot : .bloom
    }

    /// Use when applying an unlocked recommendation, so two promotions cannot reuse the same observations.
    mutating func advanceStage(current: FarmStage, day: Int) -> FarmStage {
        let next = recommendedStage(current: current, day: day)
        if next != current {
            qualifyingDays.removeAll()
            lastPromotionDay = day
        }
        return next
    }

    func isReadyForChallenge(lanes ids: [String]) -> Bool {
        let assessed = Self.measuredIDs(ids)
        return warmupRemaining == 0 && !assessed.isEmpty && assessed.allSatisfy { lanes[$0]?.adjustment == 1 }
    }

    func needsSupport(lanes ids: [String]) -> Bool {
        let assessed = Self.measuredIDs(ids)
        return !assessed.isEmpty && (warmupRemaining > 0 || assessed.contains { lanes[$0]?.adjustment == -1 })
    }

    func choiceCount(base: Int, lanes ids: [String], assist: FarmAssist) -> Int {
        let base = min(6, max(1, base))
        if assist == .together { return 1 }
        let adjustment = needsSupport(lanes: ids) ? -1 : (isReadyForChallenge(lanes: ids) ? 1 : 0)
        let count = min(6, max(1, base + adjustment))
        return assist == .reduced ? min(count, 2) : count
    }

    func hintSeconds(stage: FarmStage, lanes ids: [String], rules: FarmAdaptiveRules) -> Int {
        let base = Double(rules.scaffold.firstHintSec[stage])
        let weakest = Self.measuredIDs(ids).map { lanes[$0]?.mastery ?? rules.mastery.initial }.min()
        let m = weakest ?? rules.mastery.initial
        func smooth(_ value: Double) -> Double { value * value * (3 - 2 * value) }
        let delta = smooth(m) - smooth(rules.mastery.initial)
        let early = rules.scaffold.earlyHintFactor
        var factor = 1 + (isReadyForChallenge(lanes: ids) ? delta : min(0, delta)) * (1 - early) * 2
        if needsSupport(lanes: ids) || prefersQuiet(stage: stage, rules: rules) { factor = min(factor, early) }
        return min(20, max(1, Int((base * factor).rounded())))
    }

    /// Larger means more due for a visit. Use the *least* due lane so one neglected tag can't mask recent practice.
    func priority(lanes ids: [String], day: Int) -> Int {
        Self.measuredIDs(ids).map { id in
            guard let lane = lanes[id] else { return 15 }
            let daysSince = day > lane.lastDay ? day - lane.lastDay : 0
            return min(15, daysSince)
        }.min() ?? 0
    }

    mutating func resume(afterDays: Int) {
        guard afterDays > 0 else { return }
        todaySessionSec = 0
        guard let longBreak, afterDays > longBreak.afterDays else { return }
        for id in Array(lanes.keys) {
            lanes[id]?.mastery *= longBreak.retention
            lanes[id]?.adjustment = 0
            lanes[id]?.recent.removeAll()
        }
        qualifyingDays.removeAll()
        warmupRemaining = longBreak.warmupTasks
    }

    private mutating func newSessionDayIfNeeded(_ day: Int) {
        if day > (sessionDay ?? -1) {
            todaySessionSec = 0
            sessionDay = day
        }
    }

    /// The caller supplies elapsed active-play time, never wall-clock timestamps or input traces.
    mutating func recordSession(seconds: Int, day: Int) {
        guard day >= 0, day >= sessionDay ?? 0, seconds > 0 else { return }
        newSessionDayIfNeeded(day)
        todaySessionSec += min(seconds, Int.max - todaySessionSec)
    }

    func prefersQuiet(stage: FarmStage, rules: FarmAdaptiveRules) -> Bool {
        todaySessionSec / 60 >= rules.fatigue[stage][0]
    }

    func suggestsRest(stage: FarmStage, rules: FarmAdaptiveRules) -> Bool {
        todaySessionSec / 60 >= rules.fatigue[stage][1]
    }
}
