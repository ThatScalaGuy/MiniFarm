import XCTest
@testable import MiniFarm

final class FirstHarvestIntegrationTests: XCTestCase {
    func testTimeLimitAllowsTheLastWishButStopsTheWorldBehindGoodNight() throws {
        let catalog = try FarmCatalog.load(from: Bundle.main.bundleURL.appendingPathComponent("Content"))
        var game = FarmGame(catalog: catalog, stage: .sprout)
        game.send(.startWish(try XCTUnwrap(game.wishes.first?.id)))
        let settings = FamilyRuntimeSettings(profile: FamilyProfile(avatar: .cow), system: .init())
        let lastWish = game.worldSnapshot(settings: settings, caption: nil, timer: .windDown(graceRemaining: 10))
        XCTAssertTrue(lastWish.eveningDue)
        XCTAssertFalse(lastWish.paused)
        let bedtime = game.worldSnapshot(settings: settings, caption: nil, timer: .fallbackSleep(remaining: 8))
        XCTAssertTrue(bedtime.paused)
        XCTAssertEqual(bedtime.active?.stepID, lastWish.active?.stepID)
    }

    func testParentHintTimingChangesTheActualDelayBeforePelleHelps() throws {
        let catalog = try FarmCatalog.load(from: Bundle.main.bundleURL.appendingPathComponent("Content"))
        for (timing, delay) in [(HelpTiming.earlier, 4), (.normal, 8), (.later, 12)] {
            var game = FarmGame(catalog: catalog, stage: .shoot)
            game.configure(stage: nil, adaptive: true, memory: true, hintDelayScale: timing.delayScale)
            game.send(.startWish(try XCTUnwrap(game.wishes.first?.id)))
            XCTAssertEqual(game.secondsUntilIdleHint, delay)
            game.send(.idle(seconds: delay - 1))
            XCTAssertEqual(game.prompt?.assist, .cue)
            game.send(.idle(seconds: 1))
            XCTAssertEqual(game.prompt?.assist, .hint)
        }
    }
    func testReturningToProfileKeepsLearnedStageUntilParentsChangeIt() throws {
        let catalog = try FarmCatalog.load(from: Bundle.main.bundleURL.appendingPathComponent("Content"))
        var game = FarmGame(catalog: catalog, stage: .shoot)
        game.applyProfileStage(.sprout, revision: 0, locked: false)
        XCTAssertEqual(game.state.stage, .shoot)
        game.applyProfileStage(.bloom, revision: 1, locked: false)
        XCTAssertEqual(game.state.stage, .bloom)
        XCTAssertFalse(game.state.fixedStage)
        game.applyProfileStage(.sprout, revision: 2, locked: true)
        XCTAssertEqual(game.state.stage, .sprout)
        XCTAssertTrue(game.state.fixedStage)
    }

    func testFreshFarmsFirstRadishEndsInTildasBasket() throws {
        let catalog = try FarmCatalog.load(from: Bundle.main.bundleURL.appendingPathComponent("Content"))
        var game = FarmGame(catalog: catalog, stage: .sprout)
        let initialDay = game.state.day

        func send(_ gesture: FarmWorldIntent) throws {
            let intent = try XCTUnwrap(game.gameIntent(for: gesture))
            _ = game.send(intent)
        }
        func start(_ activity: String, expectedGiver: String? = nil) throws {
            let wish = try XCTUnwrap(game.wishes.first)
            XCTAssertEqual(wish.activityID, activity)
            if let expectedGiver { XCTAssertTrue(wish.giver.hasPrefix(expectedGiver)) }
            try send(.visit(wish.locationID))
            try send(.begin(wish.id))
            XCTAssertEqual(game.prompt?.activityID, activity)
        }
        func finish() throws {
            for _ in 0..<30 {
                guard let prompt = game.prompt else { return }
                try send(.perform(prompt.targetID))
            }
            XCTFail("Der Wunsch erreicht nach 30 richtigen Interaktionen keinen Abschluss")
        }

        try start("act.field.sow")
        let first = try XCTUnwrap(game.prompt)
        try send(.perform(first.targetID))
        let next = try XCTUnwrap(game.prompt)
        XCTAssertNotEqual(next.stepIndex, first.stepIndex)
        let serialized = try JSONEncoder().encode(game.state)
        game = FarmGame(catalog: catalog, state: try JSONDecoder().decode(FarmState.self, from: serialized))
        XCTAssertEqual(game.prompt?.stepID, next.stepID)
        try finish()
        let bed = try XCTUnwrap(game.beds.first { $0.cropID == "crop.radish" })
        try start("act.field.water")
        try finish()
        let watered = try XCTUnwrap(game.beds.first { $0.id == bed.id })
        XCTAssertTrue(watered.watered)
        XCTAssertNotEqual(bed.phase, watered.phase)
        try start("act.animal.feed")
        try finish()
        XCTAssertTrue(game.caredAnimalIDs.contains { $0.hasPrefix("animal.chicken") })

        try send(.endDay)
        XCTAssertEqual(game.state.day, initialDay + 1)
        XCTAssertEqual(game.beds.first { $0.id == bed.id }?.phase, "ripe")
        let initialStock = game.state.production.inventory["item.radish", default: 0]
        try start("act.field.harvest")
        try finish()
        XCTAssertGreaterThan(game.state.production.inventory["item.radish", default: 0], initialStock)
        func radishes() -> Int {
            game.state.production.inventory["item.radish", default: 0] + game.state.production.shelf["item.radish", default: 0]
        }
        let beforeSale = radishes()
        let coins = game.state.coins
        try start("act.shop.order", expectedGiver: "npc.tilda")
        try finish()
        XCTAssertLessThan(radishes(), beforeSale)
        XCTAssertGreaterThan(game.state.coins, coins)
        XCTAssertEqual(game.state.introduction, 6)
    }
}
