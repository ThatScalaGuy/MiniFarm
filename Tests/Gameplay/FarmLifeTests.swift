import Foundation
import XCTest
@testable import MiniFarm

final class FarmLifeTests: XCTestCase {
    private func catalog() throws -> FarmCatalog {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let directory = Bundle.main.url(forResource: "activities", withExtension: "json", subdirectory: "Content")?
            .deletingLastPathComponent() ?? Bundle.main.url(forResource: "activities", withExtension: "json")?
            .deletingLastPathComponent() ?? root.appendingPathComponent("App/Resources/Content")
        return try FarmCatalog.load(from: directory)
    }

    func testCreativeChoicesAndInterruptedBouquetChangeTheScene() throws {
        let catalog = try catalog()
        var life = FarmLife()
        let sign = try XCTUnwrap(catalog.activities.first { $0.id == "act.shop.sign" })
        let steps = life.steps(activity: sign, stage: .shoot, day: 1, season: "season.spring", catalog: catalog)
        let motifs = try [2, 0, 2].enumerated().map { step, index in
            try XCTUnwrap(steps[step].choices.dropFirst(index).first?.id)
        }
        _ = life.complete(activityID: sign.id, locationID: "loc.garden", choices: motifs,
                          day: 2, season: "season.spring", catalog: catalog)
        XCTAssertTrue(life.shopSign.isEmpty)
        _ = life.complete(activityID: sign.id, locationID: sign.locationID, choices: motifs,
                          day: 2, season: "season.spring", catalog: catalog)
        XCTAssertEqual(life.shopSign, motifs)

        let flowers = try XCTUnwrap(catalog.activities.first { $0.id == "act.nature.flowers" })
        let bouquet = try life.steps(activity: flowers, stage: .bloom, day: 4, season: "season.spring", catalog: catalog).map {
            try $0.targetID == "*" ? XCTUnwrap($0.choices.last?.id) : $0.targetID
        }
        _ = life.complete(activityID: flowers.id, locationID: flowers.locationID, choices: bouquet,
                          day: 5, season: "season.summer", catalog: catalog)
        XCTAssertEqual(life.bouquet, Array(bouquet.dropLast()))
        XCTAssertEqual(life.bouquetVase, bouquet.last)
    }

    func testDecoratingWithoutCoinsAndDeliveringWithoutDuplicateCharges() throws {
        let catalog = try catalog()
        let piece = try XCTUnwrap(catalog.decorations.first { $0.level == 1 && $0.price > 0 && $0.id != FarmLife.starterID })
        var life = FarmLife(), coins = 0
        let starter = FarmLife.starterID, tile = "well"
        life.place(decorationID: starter, positionID: tile)
        life.rotate(positionID: tile)
        XCTAssertEqual(life.placements[tile]?.quarterTurns, 1)
        _ = life.purchase(decorationID: piece.id, level: 1, coins: &coins, catalog: catalog)
        _ = life.purchase(decorationID: piece.id, level: 1, coins: &coins, catalog: catalog)
        XCTAssertEqual(life.wishlist, [piece.id])
        XCTAssertNil(life.inventory[piece.id])
        coins = piece.price + 1
        _ = life.deliverWishlist(level: 1, coins: &coins, catalog: catalog)
        _ = life.deliverWishlist(level: 1, coins: &coins, catalog: catalog)
        XCTAssertEqual(coins, 1)
        XCTAssertTrue(life.wishlist.isEmpty)
        life.place(decorationID: piece.id, positionID: tile)
        XCTAssertEqual(life.inventory[starter], 1)
        life.place(decorationID: piece.id, positionID: "tree")
        XCTAssertNil(life.placements[tile])
        life.remove(positionID: "tree")
        life.remove(positionID: "tree")
        XCTAssertEqual(life.inventory, [starter: 1, piece.id: 1])
        XCTAssertTrue(life.placements.isEmpty)
    }

    func testMailGoesToItsPicturedRecipientsAndWormsToTheChosenBed() throws {
        let catalog = try catalog()
        var life = FarmLife()
        let mail = try XCTUnwrap(catalog.activities.first { $0.id == "act.village.mail" })
        let steps = life.steps(activity: mail, stage: .sprout, day: 1, season: "season.spring", catalog: catalog)
        let recipients = steps.map(\.targetID)
        _ = life.complete(activityID: mail.id, locationID: mail.locationID, choices: Array(recipients.prefix(1)),
                          day: 1, season: "season.spring", catalog: catalog)
        XCTAssertTrue(life.deliveredMail.isEmpty)
        _ = life.complete(activityID: mail.id, locationID: mail.locationID, choices: recipients,
                          day: 1, season: "season.spring", catalog: catalog)
        XCTAssertEqual(Set(recipients), Set(life.deliveredMail.keys))
        XCTAssertEqual(life.deliveredMail.values.reduce(0, +), recipients.count)

        let compost = try XCTUnwrap(catalog.activities.first { $0.id == "act.nature.compost" })
        let worm = life.steps(activity: compost, stage: .shoot, day: 1, season: "season.spring", catalog: catalog)
        let bed = try XCTUnwrap(worm.last?.choices.last?.id)
        let found = try XCTUnwrap(worm.first?.targetID)
        for _ in 0..<2 {
            _ = life.complete(activityID: compost.id, locationID: compost.locationID, choices: [found, bed],
                              day: 1, season: "season.spring", catalog: catalog)
        }
        XCTAssertEqual(life.wormsByBed, [bed: 2])
    }

    func testSeparateMemoryBoardsPersistWithoutLeakingUnturnedFaces() throws {
        var life = FarmLife()
        life.startMemory(stage: .shoot, key: "wish.7", day: 3)
        let masked = try XCTUnwrap(life.memoryStep)
        XCTAssertEqual(masked.targetID, "*")
        XCTAssertEqual(Set(masked.choices.map(\.symbol)), ["square.dashed"])
        let first = try XCTUnwrap(masked.choices.first?.id)
        XCTAssertEqual(life.turnMemory(cardID: first), .first)
        XCTAssertEqual(life.turnMemory(cardID: first), .ignored)
        let mate = try XCTUnwrap(life.suggestedMemoryCardID())
        let other = try XCTUnwrap(masked.choices.first { $0.id != first && $0.id != mate }?.id)
        XCTAssertEqual(life.turnMemory(cardID: other), .mismatch)
        XCTAssertEqual(life.memoryStep?.choices.filter { $0.symbol != "square.dashed" }.count, 2)
        life.startMemory(stage: .sprout, key: "free", day: 3)
        XCTAssertEqual(life.memoryStep?.choices.filter { $0.symbol != "square.dashed" }.count, 0)

        life = try JSONDecoder().decode(FarmLife.self, from: JSONEncoder().encode(life))
        life.startMemory(stage: .bloom, key: "wish.7", day: 4)
        XCTAssertEqual(life.memoryStep?.choices.count, masked.choices.count)
        XCTAssertEqual(life.turnMemory(cardID: first), .first)
        XCTAssertEqual(life.memoryStep?.choices.filter { $0.symbol != "square.dashed" }.count, 1)
        XCTAssertEqual(life.turnMemory(cardID: mate), .pair)
        XCTAssertEqual(life.turnMemory(cardID: first), .ignored)
        var last = FarmMemoryTurn.pair
        for _ in 2..<masked.choices.count {
            let next = try XCTUnwrap(life.suggestedMemoryCardID())
            last = life.turnMemory(cardID: next)
        }
        XCTAssertEqual(last, .finished)
        let catalog = try catalog()
        let game = try XCTUnwrap(catalog.activities.first { $0.id == "act.farm.memory" })
        _ = life.complete(activityID: game.id, locationID: game.locationID, choices: [], day: 4,
                          season: "season.spring", catalog: catalog)
        XCTAssertEqual(life.completedBoards, 1)
        XCTAssertNil(life.memoryStep)
        life.startMemory(stage: .sprout, key: "free", day: 4)
        XCTAssertEqual(life.memoryStep?.choices.count, 6)
    }

    func testDeckIsReproducibleAndActuallyShuffled() throws {
        func faces(day: Int, key: String) throws -> [String] {
            var life = FarmLife()
            life.startMemory(stage: .bloom, key: key, day: day)
            return try XCTUnwrap(life.memoryStep).choices.map { card in
                var copy = life
                XCTAssertEqual(copy.turnMemory(cardID: card.id), .first)
                return try XCTUnwrap(copy.memoryStep?.choices.first(where: { $0.id == card.id })?.symbol)
            }
        }
        let deck = try faces(day: 2, key: "free")
        XCTAssertEqual(try faces(day: 2, key: "free"), deck)
        XCTAssertNotEqual(try faces(day: 3, key: "free"), deck)
        XCTAssertNotEqual(try faces(day: 2, key: "wish"), deck)
        XCTAssertEqual(Set(Dictionary(grouping: deck, by: { $0 }).values.map(\.count)), [2])
    }

    func testLocalDiscoveriesAndSeasonalGroupPhotos() throws {
        var life = FarmLife()
        let catalog = try catalog()
        let detail = try XCTUnwrap(catalog.hofbook.first { $0.id.hasPrefix("hofbook.discovery.") && $0.level > 1 })
        let elsewhere = detail.locationID == "loc.plaza" ? "loc.garden" : "loc.plaza"
        XCTAssertTrue(life.observe(entryID: detail.id, locationID: elsewhere, level: 5, catalog: catalog).book.isEmpty)
        XCTAssertTrue(life.observe(entryID: detail.id, locationID: detail.locationID, level: 1, catalog: catalog).book.isEmpty)
        let found = life.observe(entryID: detail.id, locationID: detail.locationID, level: detail.level, catalog: catalog)
        XCTAssertEqual(found.book, [detail.id])
        XCTAssertEqual(found.text, detail.fact)
        for (index, season) in catalog.seasons.enumerated() {
            let activity = life.festivalSteps(season: season.id)
            XCTAssertTrue(activity.allSatisfy { step in step.choices.contains { $0.id == step.targetID } })
            XCTAssertEqual(activity.last?.targetID, "photo")
            let day = 4 * (index + 1)
            let result = life.celebrate(season: season.id, day: day, catalog: catalog)
            XCTAssertEqual(result.book, ["hofbook.\(season.festivalID)"])
            _ = life.celebrate(season: season.id, day: day, catalog: catalog)
        }
        XCTAssertEqual(life.photos.count, 4)
        XCTAssertEqual(Set(life.photos.map(\.backdrop)).count, 4)
        XCTAssertTrue(life.photos.allSatisfy { $0.subjects.count > 1 })
        XCTAssertEqual(life.inventory, [FarmLife.starterID: 1])
    }
}
