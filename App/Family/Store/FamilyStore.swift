import Foundation
import Observation

/// One play session of one profile. Hand `saves` to gameplay; it stops accepting writes after a reset or deletion.
struct FamilySession: Identifiable, Equatable, Sendable {
    /// New for every session start. `FamilyRootView` uses it as view identity.
    let id: UUID
    let profileID: ProfileID
    /// Profile at session start. Read `FamilyStore.runtimeSettings` for live values.
    let profile: FamilyProfile
    let saves: ProfileSaves

    static func == (lhs: FamilySession, rhs: FamilySession) -> Bool {
        lhs.id == rhs.id
    }
}

enum ParentFlow: Equatable, Sendable {
    case gate
    case parentArea
}

enum FamilyStoreError: Error, Equatable, Sendable {
    case parentAreaLocked
    case tooManyProfiles
    case avatarInUse
    case unknownProfile
}

/// Message for parents, shown in the parent area.
struct FamilyNotice: Identifiable, Equatable, Sendable {
    let id = UUID()
    let message: String
}

/// Profiles, settings, play session, timer and parental gate. One instance per app.
@MainActor
@Observable
final class FamilyStore {
    nonisolated static let maxProfiles = 4
    /// The parent area locks again after this much time without parent input (doc 17 §7).
    nonisolated static let parentIdleTimeout: TimeInterval = 300

    let storage: FamilyStorage

    private(set) var profiles: [FamilyProfile] = []
    private(set) var session: FamilySession? { didSet { updateTimerBaseline() } }
    private(set) var sessionTimer = SessionTimer()
    private(set) var parentFlow: ParentFlow? { didSet { updateTimerBaseline() } }
    private(set) var gate: ParentalGateState
    private(set) var isGamePaused = false { didSet { updateTimerBaseline() } }
    private(set) var isSceneActive = true { didSet { updateTimerBaseline() } }
    private(set) var notices: [FamilyNotice] = []
    /// Some profile folders exist but cannot be read yet, for example before the first unlock.
    private(set) var hasUnavailableProfiles = false

    var systemAccessibility = SystemAccessibility() {
        didSet {
            guard oldValue.voiceOverEnabled != systemAccessibility.voiceOverEnabled, parentFlow == .gate else { return }
            gate.replacePuzzle(makePuzzle())
        }
    }

    /// Optional: qualitative learning lines for the parent area, for example "Übt gerade: Zählen".
    @ObservationIgnored var learningSummary: ((ProfileID) -> [String])?
    /// Optional: plays a short test sound for one bus at the volume of the edited profile.
    @ObservationIgnored var previewSound: ((ProfileID, AudioBus) -> Void)?

    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let monotonicNow: () -> ContinuousClock.Instant
    @ObservationIgnored private var random: SplitMix64
    @ObservationIgnored private var lastParentActivity: Date?
    /// Start of the current counting window. `nil` while the timer does not count, so time
    /// in the background, in the pause menu or behind the gate never counts as play time.
    @ObservationIgnored private var countingSince: ContinuousClock.Instant?

    init(
        storage: FamilyStorage,
        now: @escaping () -> Date = { Date() },
        monotonicNow: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now },
        seed: UInt64 = UInt64.random(in: .min ... .max)
    ) {
        self.storage = storage
        self.now = now
        self.monotonicNow = monotonicNow
        var random = SplitMix64(seed: seed)
        gate = ParentalGateState(puzzle: .numberWord(using: &random))
        self.random = random
        reloadProfiles()
    }

    /// Store for the app. In DEBUG builds, `-MiniFarmFamilyUITesting` uses a separate folder and
    /// `-MiniFarmFamilyReset` empties only that folder.
    static func live(arguments: [String] = ProcessInfo.processInfo.arguments) -> FamilyStore {
        FamilyStore(storage: FamilyStorage(root: liveRoot(arguments: arguments)))
    }

    static func liveRoot(arguments: [String], base: URL = .applicationSupportDirectory) -> URL {
        #if DEBUG
        if arguments.contains("-MiniFarmFamilyUITesting") {
            let name = arguments.contains("-MiniFarmFamilyManagementUITesting") ? "FamilyManagementUITesting" : "FamilyUITesting"
            let root = FamilyStorage.defaultRoot(folderName: name, base: base)
            if arguments.contains("-MiniFarmFamilyReset") {
                try? FileManager.default.removeItem(at: root)
            }
            return root
        }
        #endif
        return FamilyStorage.defaultRoot(base: base)
    }

    // MARK: Reading

    var activeProfileID: ProfileID? { session?.profileID }
    var activeProfile: FamilyProfile? { activeProfileID.flatMap(profile(_:)) }
    var isParentFlowActive: Bool { parentFlow != nil }
    var isParentAreaUnlocked: Bool { parentFlow == .parentArea }
    var canAddProfile: Bool { profiles.count < Self.maxProfiles && !freeAvatars.isEmpty }
    var freeAvatars: [ProfileAvatar] {
        let used = Set(profiles.map(\.avatar))
        return ProfileAvatar.allCases.filter { !used.contains($0) }
    }

    /// Effective settings of the active profile, merged with system accessibility. `nil` without a session.
    var runtimeSettings: FamilyRuntimeSettings? {
        activeProfile.map { FamilyRuntimeSettings(profile: $0, system: systemAccessibility) }
    }

    /// True while the timer counts: session running, app active, no pause menu, no gate or parent area.
    var isTimerCounting: Bool {
        session != nil && isSceneActive && !isGamePaused && parentFlow == nil
    }

    func profile(_ id: ProfileID) -> FamilyProfile? {
        profiles.first { $0.id == id }
    }

    func gateLockRemaining() -> TimeInterval? {
        guard let until = gate.lockedUntil else { return nil }
        let remaining = until.timeIntervalSince(now())
        return remaining > 0 ? remaining : nil
    }

    func storedInfo(for id: ProfileID) -> StoredProfileInfo {
        storage.storedInfo(for: id)
    }

    // MARK: Session

    func startSession(_ id: ProfileID) {
        guard parentFlow == nil, session == nil, let profile = profile(id) else { return }
        session = FamilySession(id: UUID(), profileID: id, profile: profile, saves: storage.saves(for: id))
        isGamePaused = false
        sessionTimer.start(limitMinutes: profile.settings.session.timerMinutes)
    }

    /// Back to the profile picker. Gameplay saves in its `onDisappear`.
    func endSession() {
        session = nil
        isGamePaused = false
        sessionTimer.stop()
    }

    /// Pause menu open or closed. Pauses only the play timer.
    func setGamePaused(_ paused: Bool) {
        isGamePaused = paused
    }

    /// Call when the evening ritual is done after `windDown`. Ends the session.
    func windDownFinished() {
        switch sessionTimer.phase {
        case .windDown, .fallbackSleep, .finished:
            endSession()
        default:
            break
        }
    }

    /// Counts play time since the last tick of the current counting window.
    /// `FamilyRootView` calls this about once per second.
    func tick() {
        tick(at: monotonicNow())
    }

    func tick(at instant: ContinuousClock.Instant) {
        if isTimerCounting, let last = countingSince {
            countingSince = instant
            sessionTimer.advance(by: last.duration(to: instant).timeInterval)
            if sessionTimer.phase == .finished {
                endSession()
            }
        }
        expireParentAreaIfIdle()
    }

    func sceneBecameActive() {
        isSceneActive = true
        if hasUnavailableProfiles {
            reloadProfiles()
        }
    }

    func sceneBecameInactive() {
        isSceneActive = false
    }

    /// Locks the parent area and closes the gate.
    func sceneEnteredBackground() {
        isSceneActive = false
        parentFlow = nil
        lastParentActivity = nil
    }

    // MARK: Parental gate

    /// Shows the gate. Works from the picker and from the game pause menu.
    func requestParentArea() {
        guard parentFlow == nil else { return }
        if gateLockRemaining() == nil {
            gate.replacePuzzle(makePuzzle())
        }
        parentFlow = .gate
    }

    @discardableResult
    func submitGate(answer: Int) -> ParentalGateState.Result {
        guard parentFlow == .gate else { return .wrong(attemptsLeft: 0) }
        let result = gate.submit(answer, now: now()) { makePuzzle() }
        if result == .unlocked {
            parentFlow = .parentArea
            lastParentActivity = now()
        }
        return result
    }

    func cancelGate() {
        if parentFlow == .gate {
            parentFlow = nil
        }
    }

    func closeParentArea() {
        parentFlow = nil
        lastParentActivity = nil
    }

    /// Any parent input in the parent area. Keeps it unlocked for another five minutes.
    func noteParentActivity() {
        guard parentFlow == .parentArea else { return }
        if expireParentAreaIfIdle() { return }
        lastParentActivity = now()
    }

    // MARK: Profiles (parent area only)

    @discardableResult
    func createProfile(avatar: ProfileAvatar, stage: ProfileStage) throws -> FamilyProfile {
        try requireParentArea()
        guard profiles.count < Self.maxProfiles else { throw FamilyStoreError.tooManyProfiles }
        guard !profiles.contains(where: { $0.avatar == avatar }) else { throw FamilyStoreError.avatarInUse }
        let profile = FamilyProfile(avatar: avatar, stage: stage, createdAt: now())
        try storage.createProfileRecord(profile)
        profiles.append(profile)
        return profile
    }

    /// Changes a profile and saves it. A new stage raises `stageRevision`.
    func updateProfile(_ id: ProfileID, _ change: (inout FamilyProfile) -> Void) throws {
        try requireParentArea()
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { throw FamilyStoreError.unknownProfile }
        let old = profiles[index]
        var updated = old
        change(&updated)
        if updated.avatar != old.avatar, profiles.contains(where: { $0.id != id && $0.avatar == updated.avatar }) {
            throw FamilyStoreError.avatarInUse
        }
        if updated.stage != old.stage {
            updated.stageRevision = old.stageRevision + 1
        }
        guard updated != old else { return }
        try storage.updateProfileRecord(updated)
        profiles[index] = updated
        if session?.profileID == id, updated.settings.session.timerMinutes != old.settings.session.timerMinutes {
            sessionTimer.setLimit(minutes: updated.settings.session.timerMinutes)
        }
    }

    func updateSettings(_ id: ProfileID, _ change: (inout ProfileSettings) -> Void) throws {
        try updateProfile(id) { change(&$0.settings) }
    }

    /// Deletes all gameplay data of the profile. Settings stay.
    func resetProgress(_ id: ProfileID) throws {
        try requireParentArea()
        guard profile(id) != nil else { throw FamilyStoreError.unknownProfile }
        if session?.profileID == id { endSession() }
        try storage.resetProgress(profile: id)
    }

    func deleteProfile(_ id: ProfileID) throws {
        try requireParentArea()
        if session?.profileID == id { endSession() }
        try storage.deleteProfile(id)
        profiles.removeAll { $0.id == id }
    }

    func deleteAllData() throws {
        try requireParentArea()
        endSession()
        try storage.deleteAllData()
        profiles = []
        notices = []
        hasUnavailableProfiles = false
    }

    // MARK: Notices

    /// Lets gameplay report a parent note, for example after an unrecoverable save.
    func addNotice(_ message: String) {
        notices.append(FamilyNotice(message: message))
    }

    func dismissNotice(_ id: FamilyNotice.ID) {
        notices.removeAll { $0.id == id }
    }

    // MARK: Internals

    private func updateTimerBaseline() {
        if !isTimerCounting {
            countingSince = nil
        } else if countingSince == nil {
            countingSince = monotonicNow()
        }
    }

    private func requireParentArea() throws {
        guard parentFlow == .parentArea, !expireParentAreaIfIdle() else { throw FamilyStoreError.parentAreaLocked }
        lastParentActivity = now()
    }

    @discardableResult
    private func expireParentAreaIfIdle() -> Bool {
        guard parentFlow == .parentArea, let last = lastParentActivity else { return false }
        guard now().timeIntervalSince(last) >= Self.parentIdleTimeout else { return false }
        closeParentArea()
        return true
    }

    private func makePuzzle() -> GatePuzzle {
        systemAccessibility.voiceOverEnabled ? .sumChoice(using: &random) : .numberWord(using: &random)
    }

    private func reloadProfiles() {
        let scan = storage.scanProfiles()
        var loaded = scan.profiles
        var used = Set<ProfileAvatar>()
        for index in loaded.indices {
            guard used.contains(loaded[index].avatar) else {
                used.insert(loaded[index].avatar)
                continue
            }
            guard let free = ProfileAvatar.allCases.first(where: { !used.contains($0) }) else { continue }
            loaded[index].avatar = free
            used.insert(free)
            try? storage.updateProfileRecord(loaded[index])
        }
        for id in scan.lostRecords {
            let avatar = ProfileAvatar.allCases.first { !used.contains($0) } ?? .cow
            used.insert(avatar)
            let rebuilt = FamilyProfile(id: id, avatar: avatar, stage: .sprout, createdAt: now())
            guard (try? storage.createProfileRecord(rebuilt)) != nil else { continue }
            loaded.append(rebuilt)
            notices.append(FamilyNotice(
                message: "Die Einstellungen von Profil \(avatar.displayName) waren beschädigt und wurden zurückgesetzt. "
                    + "Bitte Stufe und Einstellungen prüfen."
            ))
        }
        let activeID = session?.profileID
        profiles = loaded
        hasUnavailableProfiles = !scan.unavailable.isEmpty
        if let activeID, profile(activeID) == nil {
            endSession()
        }
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}
