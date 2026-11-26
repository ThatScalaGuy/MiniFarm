import Foundation

enum FarmIntent: Sendable {
    case visit(String), discover(String), startWish(String), startActivity(String), startActivityAt(String, String)
    case choose(String), askPelle, idle(seconds: Int), goHome, sleep, nextSeason
    case requestDecoration(String), rotateDecoration(String), putAwayDecoration(String)
}

struct FarmFeedback: Sendable {
    let text: String
    let voiceID: String
    var completed = false
}

struct FarmPrompt: Sendable {
    let locationID, activityID, stepID, text, voiceID, targetID, symbol: String
    let stepIndex, stepCount, targetSize: Int
    let choices: [FarmChoice]
    let assist: FarmAssist
}

struct FarmBedView: Identifiable, Sendable {
    let id, locationID: String
    let cropID: String?
    let phase: String
    let watered: Bool
}

struct FarmWish: Codable, Sendable, Identifiable {
    let id, activityID, locationID, giver, title: String
    let createdDay: Int
    var folded: Bool = false
    var festival: String?
    var introduction: Int?
    var subjectID: String?
    var itemID: String?
}

struct FarmTurn: Codable, Sendable {
    let activityID, locationID: String
    let wishID: String?
    var steps: [FarmStep]
    var variants: [FarmVariant] = []
    var variant: FarmVariant?
    var index = 0
    var picked: [String] = []
    var assist: FarmAssist = .cue
    var mostHelp: FarmAssist = .cue
    var page = 0
    var idleSeconds = 0

    var key: String { wishID ?? "\(locationID)/\(activityID)" }
}

struct FarmState: Codable, Sendable {
    let schemaVersion: Int
    var day = 1
    var level = 1
    var stage: FarmStage
    var locationID = "loc.plaza"
    var seasonOffset = 0
    var ticks = 0 // Quarter-wishes, so free play never accumulates rounding error.
    var treeWishes = 0
    var activityTypes: Set<String> = []
    var creditedToday: Set<String> = []
    var freeToday: Set<String> = []
    var book: Set<String> = []
    var seen: Set<String> = []
    var outstanding: [FarmWish] = []
    var nextWish = 1
    var introduction = 0
    var skills = FarmSkills()
    var production = FarmProduction()
    var life = FarmLife()
    var active: FarmTurn?
    var paused: [String: FarmTurn] = [:]
    var adaptive = true
    var memory = true
    var earlyHints = false
    var fixedStage = false
    var appliedStageRevision = 0
    var lastLocation: String?
    var coins: Int { production.coins }

    init(stage: FarmStage) {
        schemaVersion = 1
        self.stage = stage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else {
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: c, debugDescription: "Unbekannte Hofversion")
        }
        day = try c.decode(Int.self, forKey: .day)
        level = try c.decode(Int.self, forKey: .level)
        stage = try c.decode(FarmStage.self, forKey: .stage)
        locationID = try c.decode(String.self, forKey: .locationID)
        seasonOffset = try c.decode(Int.self, forKey: .seasonOffset)
        ticks = try c.decode(Int.self, forKey: .ticks)
        treeWishes = try c.decode(Int.self, forKey: .treeWishes)
        activityTypes = try c.decode(Set<String>.self, forKey: .activityTypes)
        creditedToday = try c.decode(Set<String>.self, forKey: .creditedToday)
        freeToday = try c.decode(Set<String>.self, forKey: .freeToday)
        book = try c.decode(Set<String>.self, forKey: .book)
        seen = try c.decode(Set<String>.self, forKey: .seen)
        outstanding = try c.decode([FarmWish].self, forKey: .outstanding)
        nextWish = try c.decode(Int.self, forKey: .nextWish)
        introduction = try c.decode(Int.self, forKey: .introduction)
        skills = try c.decode(FarmSkills.self, forKey: .skills)
        production = try c.decode(FarmProduction.self, forKey: .production)
        life = try c.decode(FarmLife.self, forKey: .life)
        active = try c.decodeIfPresent(FarmTurn.self, forKey: .active)
        paused = try c.decode([String: FarmTurn].self, forKey: .paused)
        adaptive = try c.decode(Bool.self, forKey: .adaptive)
        memory = try c.decode(Bool.self, forKey: .memory)
        earlyHints = try c.decode(Bool.self, forKey: .earlyHints)
        fixedStage = try c.decode(Bool.self, forKey: .fixedStage)
        appliedStageRevision = try c.decodeIfPresent(Int.self, forKey: .appliedStageRevision) ?? 0
        lastLocation = try c.decodeIfPresent(String.self, forKey: .lastLocation)
        guard (1...1_000_000).contains(day), (1...5).contains(level), (0...3).contains(seasonOffset),
              (0...7).contains(introduction), nextWish > 0, ticks >= 0, treeWishes >= 0,
              coins >= 0, production.inventory.values.allSatisfy({ $0 >= 0 }),
              production.shelf.values.allSatisfy({ $0 >= 0 }),
              Set(outstanding.map(\.id)).count == outstanding.count,
              (Array(paused.values) + [active].compactMap { $0 }).allSatisfy({
                  $0.index >= 0 && $0.page >= 0 && ($0.steps.indices.contains($0.index) || !$0.variants.isEmpty)
              }) else {
            throw DecodingError.dataCorruptedError(forKey: .day, in: c, debugDescription: "Unstimmiger Hofzustand")
        }
    }
}
