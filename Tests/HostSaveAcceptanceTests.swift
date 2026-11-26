import Foundation
import XCTest
@testable import MiniFarm

final class HostSaveAcceptanceTests: XCTestCase {
    private struct Fixture {
        let root = TemporaryFamilyRoot()
        let storage: FamilyStorage
        let profile = FamilyProfile(avatar: .cow)
        let saves: ProfileSaves
        let current: URL
        let backup: URL
        let farm: FarmState

        init() throws {
            storage = root.makeStorage()
            try storage.createProfileRecord(profile)
            saves = storage.saves(for: profile.id)
            let folder = storage.folder(for: profile.id)
            current = folder.appending(path: "Farm.json")
            backup = folder.appending(path: "Farm.json.bak")
            let catalog = try FarmCatalog.load(from: Bundle.main.bundleURL.appending(path: "Content"))
            farm = FarmGame(catalog: catalog).state
            try saves.save(farm, slot: "Farm", schemaVersion: 1)
        }

        func writePayload(_ edit: (inout [String: Any]) throws -> Void) throws {
            let data = try JSONEncoder().encode(farm)
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            try edit(&json)
            try saves.write(JSONSerialization.data(withJSONObject: json), slot: "Farm", schemaVersion: 1)
        }

        func reopen() -> LoadOutcome<FarmSavedGame> {
            root.makeStorage().saves(for: profile.id).load(slot: "Farm", decode: FarmSavedGame.decode)
        }
    }

    func testFutureInnerVersionsRemainUntouchedAcrossTwoOpens() throws {
        for variant in ["farm", "skills", "reshapedSkills"] {
            let f = try Fixture()
            try f.writePayload { json in
                switch variant {
                case "farm": json = ["schemaVersion": 2]
                case "skills":
                    var skills = try XCTUnwrap(json["skills"] as? [String: Any])
                    skills["schemaVersion"] = 2
                    json["skills"] = skills
                default: json["skills"] = ["schemaVersion": 2, "newFormat": []]
                }
            }
            let current = try Data(contentsOf: f.current), backup = try Data(contentsOf: f.backup)
            for _ in 0..<2 {
                guard case .unavailable(.unsupportedPayload(schemaVersion: 2)) = f.reopen() else {
                    return XCTFail("Host did not block the newer \(variant) payload")
                }
                XCTAssertEqual(try Data(contentsOf: f.current), current, variant)
                XCTAssertEqual(try Data(contentsOf: f.backup), backup, variant)
            }
            try FileManager.default.removeItem(at: f.backup)
            guard case .unavailable(.unsupportedPayload(schemaVersion: 2)) = f.reopen() else {
                return XCTFail("A newer \(variant) payload without a backup is not an empty farm")
            }
            XCTAssertEqual(try Data(contentsOf: f.current), current, variant)
            XCTAssertFalse(FileManager.default.fileExists(atPath: f.current.deletingLastPathComponent().appending(path: "Quarantine").path))
        }
    }

    func testRestoreWriteFailureIsNotSuccessAndCanBeRetried() throws {
        let f = try Fixture()
        try f.saves.save(f.farm, slot: "Farm", schemaVersion: 1)
        let backup = try Data(contentsOf: f.backup)
        try FileManager.default.removeItem(at: f.current)
        let folder = f.current.deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path) }
        guard case .unavailable(.restoreFailed) = f.reopen() else {
            return XCTFail("A readable backup is not a successful restore if Farm.json cannot be written")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.current.path))
        XCTAssertEqual(try Data(contentsOf: f.backup), backup)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)
        guard case .recovered(_, let report) = f.reopen() else { return XCTFail("Expected a successful retry") }
        XCTAssertTrue(report.restoredFromBackup)
        XCTAssertEqual(try Data(contentsOf: f.current), backup)
        XCTAssertEqual(try Data(contentsOf: f.backup), backup)
    }

    func testDamagedCurrentFormatUsesTheRealBackup() throws {
        let f = try Fixture()
        try f.writePayload { $0["day"] = -1 }
        let backup = try Data(contentsOf: f.backup)
        guard case .recovered(let saved, let report) = f.reopen() else { return XCTFail("Expected genuine corruption to recover") }
        XCTAssertEqual(saved.state.day, f.farm.day)
        XCTAssertTrue(report.restoredFromBackup)
        XCTAssertEqual(report.quarantinedFiles.count, 1)
        XCTAssertEqual(try Data(contentsOf: f.current), backup)
        XCTAssertEqual(try Data(contentsOf: f.backup), backup)
    }

    @MainActor
    func testReopeningTwoFarmsKeepsTheirHarvestAndSaleSeparate() throws {
        let root = TemporaryFamilyRoot(), storage = root.makeStorage()
        let first = FamilyProfile(avatar: .cow), second = FamilyProfile(avatar: .sheep)
        for profile in [first, second] { try storage.createProfileRecord(profile) }
        let catalog = try FarmCatalog.load(from: Bundle.main.bundleURL.appending(path: "Content"))

        func finishWish(_ game: inout FarmGame, _ activity: String) throws {
            let wish = try XCTUnwrap(game.wishes.first)
            XCTAssertEqual(wish.activityID, activity)
            game.send(.startWish(wish.id))
            for _ in 0..<30 {
                guard let target = game.prompt?.targetID else { break }
                game.send(.choose(target))
            }
            XCTAssertNil(game.prompt)
        }
        func open(_ profile: FamilyProfile) throws -> FarmGame {
            let store = FamilyStore(storage: root.makeStorage())
            store.startSession(profile.id)
            let session = try XCTUnwrap(store.session)
            let saved = try XCTUnwrap(session.saves.load(slot: "Farm", decode: FarmSavedGame.decode).value)
            return FarmGame(catalog: catalog, state: saved.state)
        }
        func stock(_ game: FarmGame) -> Int {
            game.state.production.inventory["item.radish", default: 0] + game.state.production.shelf["item.radish", default: 0]
        }
        for profile in [first, second] {
            var game = FarmGame(catalog: catalog)
            for wish in ["act.field.sow", "act.field.water", "act.animal.feed"] { try finishWish(&game, wish) }
            game.send(.sleep)
            try finishWish(&game, "act.field.harvest")
            game.send(.visit("loc.shop"))
            try storage.saves(for: profile.id).save(game.state, slot: "Farm", schemaVersion: 1)
        }
        let before = try open(first)
        XCTAssertGreaterThan(stock(before), 0)
        let firstFile = storage.folder(for: first.id).appending(path: "Farm.json")
        let untouched = try Data(contentsOf: firstFile)
        var selling = try open(second)
        XCTAssertEqual(before.state.locationID, "loc.shop")
        XCTAssertEqual(selling.state.locationID, before.state.locationID)
        XCTAssertEqual(stock(selling), stock(before))
        try finishWish(&selling, "act.shop.order")
        try storage.saves(for: second.id).save(selling.state, slot: "Farm", schemaVersion: 1)
        let kept = try open(first), sold = try open(second)
        XCTAssertEqual(try Data(contentsOf: firstFile), untouched)
        XCTAssertEqual(kept.state.locationID, sold.state.locationID)
        XCTAssertEqual(stock(kept), stock(before))
        XCTAssertEqual(kept.state.coins, before.state.coins)
        XCTAssertEqual(stock(sold), stock(selling))
        XCTAssertEqual(stock(sold), stock(kept) - 1)
        XCTAssertEqual(sold.state.coins, kept.state.coins + 1)
    }
}
