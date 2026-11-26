import Foundation
import Testing
@testable import MiniFarm

/// Temporary family root that removes itself.
final class TemporaryFamilyRoot {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appending(path: "FamilyTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    func makeStorage(now: @escaping @Sendable () -> Date = { Date() }) -> FamilyStorage {
        FamilyStorage(root: url, now: now)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

/// Mutable test clock.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        value = start
    }

    var now: Date {
        lock.withLock { value }
    }

    func advance(_ seconds: TimeInterval) {
        lock.withLock { value = value.addingTimeInterval(seconds) }
    }
}

/// Monotonic test clock for the play timer.
final class TestMonotonicClock: @unchecked Sendable {
    private let lock = NSLock()
    private let base = ContinuousClock.now
    private var offset = Duration.zero

    var now: ContinuousClock.Instant {
        lock.withLock { base.advanced(by: offset) }
    }

    func advance(_ seconds: Double) {
        lock.withLock { offset += .milliseconds(Int64(seconds * 1000)) }
    }
}

struct FarmStub: Codable, Equatable {
    var schemaVersion = 1
    var coins: Int
}

extension SaveSlot {
    static let farmStub: SaveSlot = "Farm"
}

@MainActor
func unlock(_ store: FamilyStore) {
    store.requestParentArea()
    let puzzle = store.gate.puzzle
    #expect(store.submitGate(answer: puzzle.answer) == .unlocked)
    #expect(store.isParentAreaUnlocked)
}

@MainActor
@Suite("FamilyStore")
struct FamilyStoreTests {
    let root = TemporaryFamilyRoot()

    @Test func mutationsNeedTheParentArea() throws {
        let store = FamilyStore(storage: root.makeStorage(), seed: 1)
        #expect(throws: FamilyStoreError.parentAreaLocked) {
            try store.createProfile(avatar: .cow, stage: .sprout)
        }
        store.requestParentArea()
        #expect(store.parentFlow == .gate)
        #expect(throws: FamilyStoreError.parentAreaLocked) {
            try store.createProfile(avatar: .cow, stage: .sprout)
        }
    }

    @Test func createsUpToFourProfilesWithUniqueAnimals() throws {
        let store = FamilyStore(storage: root.makeStorage(), seed: 2)
        unlock(store)
        try store.createProfile(avatar: .cow, stage: .sprout)
        #expect(throws: FamilyStoreError.avatarInUse) {
            try store.createProfile(avatar: .cow, stage: .bloom)
        }
        try store.createProfile(avatar: .sheep, stage: .shoot)
        try store.createProfile(avatar: .pig, stage: .bloom)
        try store.createProfile(avatar: .duck, stage: .sprout)
        #expect(!store.canAddProfile)
        #expect(throws: FamilyStoreError.tooManyProfiles) {
            try store.createProfile(avatar: .rabbit, stage: .sprout)
        }
        let reloaded = FamilyStore(storage: root.makeStorage(), seed: 3)
        #expect(reloaded.profiles.map(\.avatar) == [.cow, .sheep, .pig, .duck])
        #expect(reloaded.profiles.map(\.stage) == [.sprout, .shoot, .bloom, .sprout])
    }

    @Test func settingsArePerProfileAndPersist() throws {
        let store = FamilyStore(storage: root.makeStorage(), seed: 4)
        unlock(store)
        let cow = try store.createProfile(avatar: .cow, stage: .sprout)
        let sheep = try store.createProfile(avatar: .sheep, stage: .sprout)
        try store.updateSettings(cow.id) {
            $0.audio[.music] = 0.25
            $0.comfort.calmMode = .veryCalm
            $0.session.timerMinutes = 15
        }
        try store.updateProfile(cow.id) { $0.stage = .bloom }
        let reloaded = FamilyStore(storage: root.makeStorage(), seed: 5)
        let loadedCow = try #require(reloaded.profile(cow.id))
        let loadedSheep = try #require(reloaded.profile(sheep.id))
        #expect(loadedCow.settings.audio.musicVolume == 0.25)
        #expect(loadedCow.settings.comfort.calmMode == .veryCalm)
        #expect(loadedCow.settings.session.timerMinutes == 15)
        #expect(loadedCow.stage == .bloom)
        #expect(loadedCow.stageRevision == cow.stageRevision + 1)
        #expect(loadedSheep.settings == ProfileSettings())
        #expect(loadedSheep.stageRevision == sheep.stageRevision)
    }

    @Test func sessionSavesAndLoadsTheFarm() throws {
        let store = FamilyStore(storage: root.makeStorage(), seed: 6)
        unlock(store)
        let cow = try store.createProfile(avatar: .cow, stage: .sprout)
        store.closeParentArea()
        store.startSession(cow.id)
        let session = try #require(store.session)
        #expect(session.profileID == cow.id)
        #expect(session.saves.load(FarmStub.self, slot: .farmStub).value == nil)
        try session.saves.save(FarmStub(coins: 7), slot: .farmStub, schemaVersion: 1)
        store.endSession()
        store.startSession(cow.id)
        let next = try #require(store.session)
        #expect(next.id != session.id)
        #expect(next.saves.load(FarmStub.self, slot: .farmStub).value == FarmStub(coins: 7))
    }

    @Test func lateAutosaveAfterResetDoesNotRestoreTheOldFarm() throws {
        let store = FamilyStore(storage: root.makeStorage(), seed: 7)
        unlock(store)
        let cow = try store.createProfile(avatar: .cow, stage: .sprout)
        store.closeParentArea()
        store.startSession(cow.id)
        let stale = try #require(store.session).saves
        try stale.save(FarmStub(coins: 99), slot: .farmStub, schemaVersion: 1)

        unlock(store)
        try store.resetProgress(cow.id)
        #expect(store.session == nil)
        #expect(!stale.isValid)
        #expect(throws: FamilyStorageError.sessionInvalidated) {
            try stale.save(FarmStub(coins: 99), slot: .farmStub, schemaVersion: 1)
        }
        store.closeParentArea()
        store.startSession(cow.id)
        let fresh = try #require(store.session).saves
        #expect(fresh.load(FarmStub.self, slot: .farmStub).value == nil)
        #expect(store.profile(cow.id) != nil)
    }

    @Test func lateAutosaveAfterDeleteIsRefused() throws {
        let store = FamilyStore(storage: root.makeStorage(), seed: 8)
        unlock(store)
        let cow = try store.createProfile(avatar: .cow, stage: .sprout)
        store.closeParentArea()
        store.startSession(cow.id)
        let stale = try #require(store.session).saves
        unlock(store)
        try store.deleteProfile(cow.id)
        #expect(store.profiles.isEmpty)
        #expect(throws: FamilyStorageError.self) {
            try stale.save(FarmStub(coins: 1), slot: .farmStub, schemaVersion: 1)
        }
        let reloaded = FamilyStore(storage: root.makeStorage(), seed: 9)
        #expect(reloaded.profiles.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: root.makeStorage().folder(for: cow.id).path))
    }

    @Test func parentFlowPausesTheTimerAndTheGameSignal() throws {
        let store = FamilyStore(storage: root.makeStorage(), seed: 10)
        unlock(store)
        let cow = try store.createProfile(avatar: .cow, stage: .sprout)
        try store.updateSettings(cow.id) { $0.session.timerMinutes = 15 }
        store.closeParentArea()
        store.startSession(cow.id)
        #expect(store.isTimerCounting)
        store.requestParentArea()
        #expect(store.isParentFlowActive)
        #expect(!store.isTimerCounting)
        store.cancelGate()
        store.setGamePaused(true)
        #expect(!store.isTimerCounting)
        store.setGamePaused(false)
        #expect(store.isTimerCounting)
    }

    @Test func firstTickAfterLongSuspendDoesNotCountTheAbsence() throws {
        let clock = TestMonotonicClock()
        let store = FamilyStore(storage: root.makeStorage(), monotonicNow: { clock.now }, seed: 11)
        unlock(store)
        let cow = try store.createProfile(avatar: .cow, stage: .sprout)
        try store.updateSettings(cow.id) { $0.session.timerMinutes = 15 }
        store.closeParentArea()
        store.startSession(cow.id)
        for _ in 0..<600 {
            clock.advance(1)
            store.tick()
        }
        #expect(store.sessionTimer.elapsed == 600)

        store.sceneBecameInactive()
        store.sceneEnteredBackground()
        clock.advance(20 * 60)
        store.sceneBecameActive()
        clock.advance(1)
        store.tick()
        #expect(store.sessionTimer.elapsed == 601)
        #expect(store.sessionTimer.phase == .running(remaining: 299))
        #expect(store.session != nil)
    }

    @Test func tickBeforeTheActiveSceneAfterSuspendCountsNothing() throws {
        let clock = TestMonotonicClock()
        let store = FamilyStore(storage: root.makeStorage(), monotonicNow: { clock.now }, seed: 12)
        unlock(store)
        let cow = try store.createProfile(avatar: .cow, stage: .sprout)
        try store.updateSettings(cow.id) { $0.session.timerMinutes = 15 }
        store.closeParentArea()
        store.startSession(cow.id)
        clock.advance(1)
        store.tick()
        store.sceneEnteredBackground()
        clock.advance(20 * 60)
        store.tick()
        store.sceneBecameActive()
        store.tick()
        #expect(store.sessionTimer.elapsed == 1)
    }

    @Test func pauseMenuAndGateTimeDoNotCount() throws {
        let clock = TestMonotonicClock()
        let store = FamilyStore(storage: root.makeStorage(), monotonicNow: { clock.now }, seed: 13)
        unlock(store)
        let cow = try store.createProfile(avatar: .cow, stage: .sprout)
        try store.updateSettings(cow.id) { $0.session.timerMinutes = 15 }
        store.closeParentArea()
        store.startSession(cow.id)
        clock.advance(1)
        store.tick()
        store.setGamePaused(true)
        clock.advance(600)
        store.tick()
        store.setGamePaused(false)
        clock.advance(1)
        store.tick()
        store.requestParentArea()
        clock.advance(600)
        store.tick()
        store.cancelGate()
        clock.advance(1)
        store.tick()
        #expect(store.sessionTimer.elapsed == 3)
    }

    // MARK: Gate and parent area

    @Test func gateLockoutSurvivesCancel() throws {
        let clock = TestClock()
        let store = FamilyStore(storage: root.makeStorage(), now: { clock.now }, seed: 20)
        store.requestParentArea()
        for _ in 0..<3 { store.submitGate(answer: 0) }
        #expect(store.gateLockRemaining() == ParentalGateState.lockout)
        #expect(store.submitGate(answer: store.gate.puzzle.answer) != .unlocked)
        store.cancelGate()
        store.requestParentArea()
        #expect(store.parentFlow == .gate)
        #expect(store.submitGate(answer: store.gate.puzzle.answer) != .unlocked)
        clock.advance(ParentalGateState.lockout)
        #expect(store.gateLockRemaining() == nil)
        #expect(store.submitGate(answer: store.gate.puzzle.answer) == .unlocked)
    }

    @Test func parentAreaLocksAfterFiveIdleMinutes() throws {
        let clock = TestClock()
        let store = FamilyStore(storage: root.makeStorage(), now: { clock.now }, seed: 21)
        unlock(store)
        clock.advance(299)
        store.noteParentActivity()
        clock.advance(299)
        store.tick()
        #expect(store.isParentAreaUnlocked)
        clock.advance(2)
        #expect(throws: FamilyStoreError.parentAreaLocked) {
            try store.createProfile(avatar: .cow, stage: .sprout)
        }
        #expect(store.parentFlow == nil)
        unlock(store)
        clock.advance(FamilyStore.parentIdleTimeout)
        store.tick()
        #expect(store.parentFlow == nil)
    }

    @Test func backgroundLocksTheParentArea() {
        let store = FamilyStore(storage: root.makeStorage(), seed: 22)
        unlock(store)
        store.sceneEnteredBackground()
        #expect(store.parentFlow == nil)
        store.sceneBecameActive()
        #expect(!store.isParentAreaUnlocked)
    }

    @Test func voiceOverSwitchesToTheChoicePuzzle() {
        let store = FamilyStore(storage: root.makeStorage(), seed: 23)
        store.requestParentArea()
        #expect(store.gate.puzzle.kind == .numberWord)
        store.systemAccessibility.voiceOverEnabled = true
        #expect(store.gate.puzzle.kind == .sumChoice)
        store.cancelGate()
        store.requestParentArea()
        #expect(store.gate.puzzle.kind == .sumChoice)
    }

    @Test func childCannotStartPlayingBehindTheGate() throws {
        let store = FamilyStore(storage: root.makeStorage(), seed: 24)
        unlock(store)
        let cow = try store.createProfile(avatar: .cow, stage: .sprout)
        store.startSession(cow.id)
        #expect(store.session == nil)
        store.closeParentArea()
        store.startSession(cow.id)
        #expect(store.activeProfileID == cow.id)
        #expect(store.runtimeSettings?.startStage == .sprout)
    }

    // MARK: Timer integration

    @Test func timerChangeAppliesToTheRunningSession() throws {
        let store = FamilyStore(storage: root.makeStorage(), seed: 25)
        unlock(store)
        let cow = try store.createProfile(avatar: .cow, stage: .sprout)
        try store.updateSettings(cow.id) { $0.session.timerMinutes = 15 }
        store.closeParentArea()
        store.startSession(cow.id)
        #expect(store.sessionTimer.limit == 900)
        unlock(store)
        try store.updateSettings(cow.id) { $0.session.timerMinutes = 30 }
        #expect(store.sessionTimer.limit == 1800)
        try store.updateSettings(cow.id) { $0.session.timerMinutes = nil }
        #expect(store.sessionTimer.phase == .off)
        #expect(store.session != nil)
    }

    @Test func sessionEndsSoftlyAfterTheFallback() throws {
        let clock = TestMonotonicClock()
        let store = FamilyStore(storage: root.makeStorage(), monotonicNow: { clock.now }, seed: 26)
        unlock(store)
        let cow = try store.createProfile(avatar: .cow, stage: .sprout)
        try store.updateSettings(cow.id) { $0.session.timerMinutes = 15 }
        store.closeParentArea()
        store.startSession(cow.id)
        var sawWindDown = false
        var sawFallback = false
        for _ in 0..<(900 + 200) {
            clock.advance(1)
            store.tick()
            switch store.sessionTimer.phase {
            case .windDown: sawWindDown = true
            case .fallbackSleep: sawFallback = true
            default: break
            }
            if store.session == nil { break }
        }
        #expect(sawWindDown && sawFallback)
        #expect(store.session == nil)
    }

    @Test func eveningRitualEndsTheSessionOnlyAfterTimeIsUp() throws {
        let clock = TestMonotonicClock()
        let store = FamilyStore(storage: root.makeStorage(), monotonicNow: { clock.now }, seed: 27)
        unlock(store)
        let cow = try store.createProfile(avatar: .cow, stage: .sprout)
        try store.updateSettings(cow.id) { $0.session.timerMinutes = 15 }
        store.closeParentArea()
        store.startSession(cow.id)
        store.windDownFinished()
        #expect(store.session != nil)
        for _ in 0..<900 {
            clock.advance(1)
            store.tick()
        }
        #expect(store.sessionTimer.phase == .windDown(graceRemaining: 180))
        store.windDownFinished()
        #expect(store.session == nil)
    }

    // MARK: Recovery on start

    @Test func duplicateAnimalsAreFixedOnLoad() throws {
        let storage = root.makeStorage()
        let first = FamilyProfile(avatar: .cow, stage: .sprout, createdAt: Date(timeIntervalSince1970: 1))
        let second = FamilyProfile(avatar: .cow, stage: .bloom, createdAt: Date(timeIntervalSince1970: 2))
        try storage.createProfileRecord(first)
        try storage.createProfileRecord(second)
        let store = FamilyStore(storage: storage, seed: 28)
        #expect(store.profiles.map(\.avatar) == [.cow, .sheep])
        #expect(FamilyStore(storage: root.makeStorage(), seed: 29).profiles.map(\.avatar) == [.cow, .sheep])
    }

    @Test func lostProfileRecordIsRebuiltAndKeepsTheFarm() throws {
        let storage = root.makeStorage()
        let cow = FamilyProfile(avatar: .cow, stage: .bloom, createdAt: Date())
        try storage.createProfileRecord(cow)
        try storage.saves(for: cow.id).save(FarmStub(coins: 4), slot: .farmStub, schemaVersion: 1)
        try Data("x".utf8).write(to: storage.folder(for: cow.id).appending(path: "Profile.json"))
        let store = FamilyStore(storage: storage, seed: 30)
        let rebuilt = try #require(store.profile(cow.id))
        #expect(rebuilt.stage == .sprout)
        #expect(store.notices.count == 1)
        #expect(storage.saves(for: cow.id).load(FarmStub.self, slot: .farmStub).value == FarmStub(coins: 4))
    }

    @Test func unreadableProfileIsKeptAndLoadedLater() throws {
        let storage = root.makeStorage()
        let cow = FamilyProfile(avatar: .cow, stage: .bloom, createdAt: Date())
        try storage.createProfileRecord(cow)
        let record = storage.folder(for: cow.id).appending(path: "Profile.json")
        let aside = storage.folder(for: cow.id).appending(path: "aside")
        try FileManager.default.moveItem(at: record, to: aside)
        try FileManager.default.createDirectory(at: record, withIntermediateDirectories: false)

        let store = FamilyStore(storage: storage, seed: 31)
        #expect(store.profiles.isEmpty)
        #expect(store.hasUnavailableProfiles)
        #expect(store.notices.isEmpty)
        #expect(FileManager.default.fileExists(atPath: aside.path(percentEncoded: false)))

        try FileManager.default.removeItem(at: record)
        try FileManager.default.moveItem(at: aside, to: record)
        store.sceneBecameInactive()
        store.sceneBecameActive()
        #expect(store.profiles == [cow])
        #expect(!store.hasUnavailableProfiles)
    }

    @Test func deleteAllRemovesEverything() throws {
        let store = FamilyStore(storage: root.makeStorage(), seed: 32)
        unlock(store)
        let cow = try store.createProfile(avatar: .cow, stage: .sprout)
        try store.createProfile(avatar: .pig, stage: .sprout)
        store.closeParentArea()
        store.startSession(cow.id)
        let stale = try #require(store.session).saves
        unlock(store)
        try store.deleteAllData()
        #expect(store.profiles.isEmpty)
        #expect(store.session == nil)
        #expect(throws: FamilyStorageError.self) {
            try stale.save(FarmStub(coins: 1), slot: .farmStub, schemaVersion: 1)
        }
        #expect(FamilyStore(storage: root.makeStorage(), seed: 33).profiles.isEmpty)
    }

    // MARK: Launch arguments

    @Test func uiTestingUsesItsOwnFolderAndResetsOnlyThat() throws {
        let base = root.url.appending(path: "Support", directoryHint: .isDirectory)
        let regular = FamilyStore.liveRoot(arguments: [], base: base)
        let testing = FamilyStore.liveRoot(arguments: ["-MiniFarmFamilyUITesting"], base: base)
        let managementArgs = ["-MiniFarmFamilyUITesting", "-MiniFarmFamilyManagementUITesting"]
        let management = FamilyStore.liveRoot(arguments: managementArgs, base: base)
        #expect(regular.lastPathComponent == "Family")
        #expect(testing.lastPathComponent == "FamilyUITesting")
        #expect(regular.deletingLastPathComponent() == testing.deletingLastPathComponent())
        for folder in [regular, testing, management] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data("keep".utf8).write(to: folder.appending(path: "marker"))
        }
        _ = FamilyStore.liveRoot(arguments: ["-MiniFarmFamilyReset"], base: base)
        _ = FamilyStore.liveRoot(arguments: managementArgs + ["-MiniFarmFamilyReset"], base: base)
        #expect(!FileManager.default.fileExists(atPath: management.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: testing.appending(path: "marker").path(percentEncoded: false)))
        _ = FamilyStore.liveRoot(arguments: ["-MiniFarmFamilyUITesting", "-MiniFarmFamilyReset"], base: base)
        #expect(!FileManager.default.fileExists(atPath: testing.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: regular.appending(path: "marker").path(percentEncoded: false)))
    }
}
