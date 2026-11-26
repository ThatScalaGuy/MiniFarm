import Foundation

struct ProfileID: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    init?(directoryName: String) {
        guard let uuid = UUID(uuidString: directoryName) else { return nil }
        self.rawValue = uuid
    }

    var directoryName: String { rawValue.uuidString }
    var description: String { rawValue.uuidString }

    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(UUID.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Picture avatar of a child profile. Raw values are content IDs from doc 21.
enum ProfileAvatar: String, Codable, CaseIterable, Sendable, Identifiable {
    case cow = "animal.cow"
    case sheep = "animal.sheep"
    case pig = "animal.pig"
    case chicken = "animal.chicken"
    case duck = "animal.duck"
    case rabbit = "animal.rabbit"

    var id: String { rawValue }

    /// Name for parents and VoiceOver. Children never need to read it.
    var displayName: String {
        switch self {
        case .cow: "Kuh"
        case .sheep: "Schaf"
        case .pig: "Schwein"
        case .chicken: "Huhn"
        case .duck: "Ente"
        case .rabbit: "Kaninchen"
        }
    }

    var fallbackEmoji: String {
        switch self {
        case .cow: "🐄"
        case .sheep: "🐑"
        case .pig: "🐖"
        case .chicken: "🐔"
        case .duck: "🦆"
        case .rabbit: "🐇"
        }
    }
}

/// Starting stage of a profile. Raw values match `GrowthStage` in doc 16.
enum ProfileStage: String, Codable, CaseIterable, Sendable, Identifiable {
    case sprout
    case shoot
    case bloom

    var id: String { rawValue }

    var parentLabel: String {
        switch self {
        case .sprout: "Keimling (3 bis 4 Jahre)"
        case .shoot: "Spross (5 bis 6 Jahre)"
        case .bloom: "Blüte (ab 7 Jahren)"
        }
    }
}

/// One child profile. Holds no name, photo or other personal data.
struct FamilyProfile: Codable, Equatable, Sendable, Identifiable {
    static let schemaVersion = 1

    let id: ProfileID
    var avatar: ProfileAvatar
    /// Start stage chosen by a parent. The stage reached through adaptivity lives in gameplay data.
    var stage: ProfileStage
    /// Grows each time a parent picks a stage, so gameplay can tell a new choice from an old one.
    var stageRevision: Int
    let createdAt: Date
    var settings: ProfileSettings

    init(
        id: ProfileID = ProfileID(),
        avatar: ProfileAvatar,
        stage: ProfileStage = .sprout,
        stageRevision: Int = 0,
        createdAt: Date = Date(),
        settings: ProfileSettings = ProfileSettings()
    ) {
        self.id = id
        self.avatar = avatar
        self.stage = stage
        self.stageRevision = stageRevision
        self.createdAt = createdAt
        self.settings = settings
    }
}
