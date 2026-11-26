import XCTest
@testable import MiniFarm

final class BasketCoPlayTests: XCTestCase {
    private typealias Carry = BasketCarry<Int>
    private let size = CGSize(width: 800, height: 420)

    func testTwoContactsKeepTheirRolesAcrossCrossingCancellationAndLateDrop() {
        var carry = Carry(host: .bloom, visitor: .sprout)
        XCTAssertEqual(carry.quota, 1)
        let left = Carry.anchor(.left, goal: false, in: size), right = Carry.anchor(.right, goal: false, in: size)
        let a = Carry.anchor(.left, goal: true, in: size), b = Carry.anchor(.right, goal: true, in: size)
        func touch(_ phase: Carry.Phase, _ id: Int, _ point: CGPoint, radius: CGFloat = 9) {
            carry.input(phase, id: id, at: point, radius: radius, in: size)
        }

        touch(.began, 9, right, radius: 31)  // Palm, then a real finger in the same zone.
        touch(.began, 1, left)
        touch(.began, 2, right)
        touch(.began, 3, left)               // A third contact must not take over the circle.
        touch(.moved, 1, b)
        touch(.moved, 2, a)
        XCTAssertEqual(carry.point(.left, in: size), b)
        XCTAssertEqual(carry.point(.right, in: size), a)
        touch(.ended, 3, a)
        touch(.cancelled, 1, b)
        XCTAssertEqual(carry.point(.left, in: size), left)
        touch(.ended, 2, b)
        XCTAssertTrue(carry.delivered(.right))
        XCTAssertFalse(carry.finished)
        carry.cancelContacts()
        touch(.began, 4, left)
        touch(.ended, 4, a)
        touch(.ended, 4, a)
        XCTAssertTrue(carry.finished)
        XCTAssertEqual(carry.baskets, 1)
    }

    func testHelperCannotFinishChildSideAndSequentialTapsNeedNoOverlap() {
        var carry = Carry(host: .shoot, visitor: nil)
        XCTAssertEqual(carry.quota, 2)
        func tap(_ side: Carry.Side, goal: Bool) {
            let point = Carry.anchor(side, goal: goal, in: size)
            carry.input(.began, id: 1, at: point, radius: 8, in: size)
            carry.input(.ended, id: 1, at: point, radius: 8, in: size)
        }
        tap(.right, goal: true)
        XCTAssertFalse(carry.delivered(.right))
        for _ in 0..<2 {
            tap(.right, goal: false)
            tap(.right, goal: true)
            XCTAssertFalse(carry.finished)
            XCTAssertFalse(carry.delivered(.left))
            tap(.left, goal: false)
            tap(.left, goal: true)
        }
        XCTAssertTrue(carry.finished)
    }

    func testVisitorKeepsFarmAndBackupByteForByteAndMergesOnlyNewPractice() throws {
        let root = TemporaryFamilyRoot()
        let storage = root.makeStorage()
        let catalog = try FarmCatalog.load(from: Bundle.main.bundleURL.appending(path: "Content"))
        let guest = FamilyProfile(avatar: .sheep, stage: .sprout)
        try storage.createProfileRecord(guest)
        let saves = storage.saves(for: guest.id)
        var guestFarm = FarmGame(catalog: catalog, stage: .shoot).state
        guestFarm.day = 8
        guestFarm.skills.record(lanes: ["moTap"], assist: .cue, day: 8, rules: catalog.adaptive)
        try saves.save(guestFarm, slot: "Farm", schemaVersion: 1)
        guestFarm.production.coins += 9
        try saves.save(guestFarm, slot: "Farm", schemaVersion: 1)
        let files = ["Farm.json", "Farm.json.bak"].map { storage.folder(for: guest.id).appending(path: $0) }
        let before = try files.map { try Data(contentsOf: $0) }
        let visit = try BasketVisitor(profile: guest, saves: saves)
        XCTAssertEqual(visit.stage, .shoot) // The guest's adapted stage overrides the original default.
        let round = UUID()
        try visit.record(round: round, rules: catalog.adaptive)
        try visit.record(round: round, rules: catalog.adaptive)
        XCTAssertEqual(try files.map { try Data(contentsOf: $0) }, before)

        let practice = try XCTUnwrap(BasketPractice.read(saves))
        XCTAssertEqual(practice.sequence, 1)
        practice.apply(to: &guestFarm)
        XCTAssertNotNil(guestFarm.skills.confidence["cogMatching"])
        XCTAssertNotNil(guestFarm.skills.confidence["moTap"])
        guestFarm.skills.record(lanes: ["moSteer"], assist: .cue, day: 8, rules: catalog.adaptive)
        try saves.save(guestFarm, slot: "Farm", schemaVersion: 1)
        var reopened = try XCTUnwrap(saves.load(slot: "Farm", decode: FarmSavedGame.decode).value?.state)
        practice.apply(to: &reopened)
        XCTAssertNotNil(reopened.skills.confidence["moSteer"], "Old visiting practice must not overwrite later solo play")
        XCTAssertEqual(reopened.coins, guestFarm.coins)
        var lockedGuest = guest
        lockedGuest.settings.learning.adaptivityEnabled = false
        let locked = try BasketVisitor(profile: lockedGuest, saves: saves)
        XCTAssertEqual(locked.stage, .sprout)
        try locked.record(round: UUID(), rules: catalog.adaptive)
        XCTAssertEqual(try BasketPractice.read(saves)?.sequence, 1)
        try storage.resetProgress(profile: guest.id)
        XCTAssertThrowsError(try visit.record(round: UUID(), rules: catalog.adaptive))
        XCTAssertNil(try BasketPractice.read(storage.saves(for: guest.id)))
    }

    func testHostGetsOneFreePlayTickNotTwoHarvestsOrTwoObservations() throws {
        let catalog = try FarmCatalog.load(from: Bundle.main.bundleURL.appending(path: "Content"))
        var owner = FarmGame(catalog: catalog)
        let before = owner.state
        let round = UUID()
        owner.deliverSharedBasket(round: round)
        let confidence = owner.state.skills.confidence["cogMatching"]
        XCTAssertNotNil(confidence)
        owner.deliverSharedBasket(round: round)
        XCTAssertEqual(owner.state.skills.confidence["cogMatching"], confidence)
        owner.deliverSharedBasket(round: UUID())
        XCTAssertEqual(owner.state.ticks, before.ticks + 1)
        XCTAssertEqual(owner.state.coins, before.coins)
        XCTAssertEqual(owner.state.production.inventory, before.production.inventory)
        XCTAssertEqual(owner.state.outstanding.map(\.id), before.outstanding.map(\.id))
        XCTAssertEqual(owner.state.treeWishes, before.treeWishes)
    }

    func testVisitingDoesNotRepairOrQuarantineTheSecondFarm() throws {
        let root = TemporaryFamilyRoot()
        let storage = root.makeStorage()
        let guest = FamilyProfile(avatar: .sheep)
        try storage.createProfileRecord(guest)
        let saves = storage.saves(for: guest.id)
        let state = FarmState(stage: .bloom)
        try saves.save(state, slot: "Farm", schemaVersion: 1)
        try saves.save(state, slot: "Farm", schemaVersion: 1)
        let folder = storage.folder(for: guest.id)
        let current = folder.appending(path: "Farm.json"), backup = folder.appending(path: "Farm.json.bak")
        let backupBytes = try Data(contentsOf: backup), broken = Data([0])
        try broken.write(to: current)
        XCTAssertEqual(try BasketVisitor(profile: guest, saves: saves).stage, .bloom)
        XCTAssertEqual(try Data(contentsOf: current), broken)
        XCTAssertEqual(try Data(contentsOf: backup), backupBytes)
        try broken.write(to: backup)
        XCTAssertThrowsError(try BasketVisitor(profile: guest, saves: saves))
        XCTAssertEqual(try Data(contentsOf: current), broken)
        XCTAssertEqual(try Data(contentsOf: backup), broken)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appending(path: "Quarantine").path))
    }

    func testSoloSaveKeepsItsOriginalSchemaAndGuestWithoutFarmStartsWithOnlyPractice() throws {
        let root = TemporaryFamilyRoot()
        let storage = root.makeStorage()
        let catalog = try FarmCatalog.load(from: Bundle.main.bundleURL.appending(path: "Content"))
        let guest = FamilyProfile(avatar: .duck)
        try storage.createProfileRecord(guest)
        let saves = storage.saves(for: guest.id)
        XCTAssertNil(try BasketPractice.visibleSkills(in: saves))

        var solo = FarmGame(catalog: catalog)
        solo.send(.startWish(try XCTUnwrap(solo.wishes.first?.id)))
        let bytes = try JSONEncoder().encode(solo.state)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertNil(json["appliedBasketPractice"])
        XCTAssertNil(json["lastBasketRound"])
        let restored = try JSONDecoder().decode(FarmState.self, from: bytes)
        XCTAssertEqual(restored.active?.key, solo.state.active?.key)
        XCTAssertEqual(restored.active?.index, solo.state.active?.index)
        XCTAssertEqual(restored.production.inventory, solo.state.production.inventory)
        XCTAssertEqual(restored.schemaVersion, 1)

        let visitor = try BasketVisitor(profile: guest, saves: saves)
        try visitor.record(round: UUID(), rules: catalog.adaptive)
        XCTAssertNotNil(try BasketPractice.visibleSkills(in: saves)?.confidence["cogMatching"])
        if case .empty = saves.load(slot: "Farm", decode: FarmSavedGame.decode) {} else {
            XCTFail("A first visit must not create a farm")
        }
    }
}
