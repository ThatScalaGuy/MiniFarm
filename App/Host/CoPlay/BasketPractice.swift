import Foundation

/// Only a visitor's learning snapshot is written during a visit. Their Farm slot, its
/// backup, date, stock and unfinished turn stay untouched until they open it themselves.
struct BasketPractice: Codable {
    let sequence: UInt64
    let round: UUID
    let skills: FarmSkills

    static let slot: SaveSlot = "BasketPractice"

    static func read(_ saves: ProfileSaves) throws -> Self? {
        switch saves.load(slot: slot, decode: { payload -> Self in
            guard payload.schemaVersion == 1 else { throw SaveDataUnsupported() }
            return try JSONDecoder().decode(Self.self, from: payload.data)
        }) {
        case .empty: return nil
        case .loaded(let receipt), .recovered(let receipt, _): return receipt
        case .unavailable, .unrecoverable: throw BasketReadError.practice
        }
    }

    func apply(to state: inout FarmState) {
        guard sequence > (state.appliedBasketPractice ?? 0) else { return }
        state.skills = skills
        state.appliedBasketPractice = sequence
    }

    static func visibleSkills(in saves: ProfileSaves) throws -> FarmSkills? {
        let visit = try read(saves)
        switch saves.load(slot: "Farm", repair: false, decode: FarmSavedGame.decode) {
        case .loaded(let saved), .recovered(let saved, _):
            return (visit?.sequence ?? 0) > (saved.state.appliedBasketPractice ?? 0) ? visit?.skills : saved.state.skills
        case .empty: return visit?.skills
        case .unavailable, .unrecoverable: throw BasketReadError.farm
        }
    }
}

enum BasketReadError: LocalizedError {
    case practice, farm

    var errorDescription: String? {
        switch self {
        case .practice: "Die gemeinsame Übung konnte nicht gelesen werden."
        case .farm: "Der Hof des zweiten Profils ist gerade nicht lesbar."
        }
    }
}

struct BasketVisitor {
    let avatar: ProfileAvatar
    let stage: FarmStage
    let saves: ProfileSaves
    let adaptive: Bool
    private let state: FarmState

    init(profile: FamilyProfile, saves: ProfileSaves) throws {
        precondition(profile.id == saves.profile)
        self.saves = saves
        avatar = profile.avatar
        adaptive = profile.settings.learning.adaptivityEnabled
        let initial: FarmStage = switch profile.stage {
        case .sprout: .sprout
        case .shoot: .shoot
        case .bloom: .bloom
        }
        switch saves.load(slot: "Farm", repair: false, decode: FarmSavedGame.decode) {
        case .empty: state = FarmState(stage: initial)
        case .loaded(let saved), .recovered(let saved, _): state = saved.state
        case .unavailable, .unrecoverable: throw BasketReadError.farm
        }
        stage = !adaptive || profile.stageRevision != state.appliedStageRevision ? initial : state.stage
    }

    func record(round: UUID, rules: FarmAdaptiveRules) throws {
        guard adaptive else { return }
        var latest = state
        if let previous = try BasketPractice.read(saves) {
            guard previous.round != round else { return }
            previous.apply(to: &latest)
        }
        let sequence = latest.appliedBasketPractice ?? 0
        guard sequence < UInt64.max else { throw BasketReadError.practice }
        latest.skills.record(lanes: ["cogMatching"], assist: .cue, day: latest.day, rules: rules)
        let receipt = BasketPractice(sequence: sequence + 1, round: round, skills: latest.skills)
        try saves.save(receipt, slot: BasketPractice.slot, schemaVersion: 1)
    }
}
