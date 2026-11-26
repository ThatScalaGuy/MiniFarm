import Foundation

/// A projection of the current profile. The world never advances the day, awards items,
/// or decides which activity, step or bed is available.
struct FarmWorldState: Equatable {
    var locationIDs: [String]
    var offerings: [WorldOffering]
    var active: WorldTurn?
    var locationID: String?
    var beds: [WorldBed] = []
    var book: [WorldSticker] = []
    var inventory: [String: Int] = [:]
    var shelf: [String: Int] = [:]
    var coins = 0
    var caredFor: Set<String> = []
    var farmLevel = 1
    var season = "season.spring"
    var weather = "sun"
    var sunProgress = 0.0
    var caption: String?
    var largeControls = false
    var quiet = false
    var paused = false
    var secondsUntilIdleHint: Int?
    var reduceMotion = false
    var haptics = true
    var stage: WorldStage = .seedling
    var cameraSpeedScale = 1.0
    var particleScale = 1.0
    var decorations: [WorldDecoration] = []
    var invitesRest = false
    var eveningDue = false
    var nightStory: FarmNightStory?

    var hasDrivingJob: Bool {
        guard let active else { return false }
        return FarmDriveWork.job(for: active, farmLevel: farmLevel) != nil
    }
}

struct WorldDecoration: Equatable {
    let positionID: String
    let decorationID: String
    let quarterTurns: Int
}

enum WorldStage { case seedling, shoot, bloom }

struct WorldOffering: Identifiable, Equatable {
    /// Opaque wish/free-play ID; only the host interprets it.
    let id: String
    let activityID: String
    let locationID: String
    var subjectID: String?
    var isWish = true
}

struct WorldTurn: Equatable {
    let offering: WorldOffering
    let stepID: String
    var stepIndex: Int
    var stepCount: Int
    /// Exactly the choices offered by the host for this step. With no choices the
    /// player touches the activity's physical object, emitting `perform(nil)`.
    var choices: [WorldChoice] = []
    var targetID: String?
    var helpLevel = 0
    var workGear: [String] = []
    var workBeds: [String] = []
}

struct WorldChoice: Equatable, Identifiable {
    let id: String
    var modelID: String
    var label: String
    var symbol: String?
}

struct WorldBed: Identifiable, Equatable {
    let id: String
    var locationID = "loc.garden"
    var cropID: String?
    var growth: String = "seed" // model variant: seed, sprout, growing, ripe
    var watered = false
}

struct WorldSticker: Identifiable, Equatable {
    let id: String
    var modelID: String
    var label: String
    var discovered: Bool
    var locationID: String?
}

enum FarmWorldIntent: Equatable {
    case visit(String), begin(String), perform(String?), help, idleHint(seconds: Int), leaveActivity
    case discover(String), readSticker(String), endDay, nextSeason, pause, decorationBox
    case readStory(String), closeNightStory, horn
}
