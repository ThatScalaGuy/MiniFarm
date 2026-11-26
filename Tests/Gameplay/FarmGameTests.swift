import Foundation
import Testing
@testable import MiniFarm

struct FarmGameTests {
    private func catalog() throws -> FarmCatalog {
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("App/Resources/Content")
        return try FarmCatalog.load(from: Bundle.main.url(forResource: "Content", withExtension: nil) ?? source)
    }

    private func finish(_ game: inout FarmGame) throws -> FarmFeedback {
        for _ in 0..<100 {
            let prompt = try #require(game.prompt)
            let next = game.send(prompt.activityID == "act.farm.memory" ? .askPelle : .choose(prompt.targetID))
            if next.completed { return next }
        }
        throw FarmContentError.invalid("Handlungsfolge ohne Abschluss: \(game.prompt?.activityID ?? "–")")
    }

    @Test func freshFarmPlaysRadishCycleAndRestoresMidStep() throws {
        let catalog = try catalog()
        var game = FarmGame(catalog: catalog)
        #expect(game.locations.count == 4)
        for (index, id) in ["act.field.sow", "act.field.water", "act.animal.feed"].enumerated() {
            let wish = try #require(game.wishes.first)
            #expect(wish.introduction == index)
            #expect(wish.activityID == id)
            game.send(.startWish(wish.id))
            if index == 0 {
                let first = try #require(game.prompt)
                game.send(.choose(first.targetID))
                let step = try #require(game.prompt).stepID
                game.send(.goHome)
                let data = try JSONEncoder().encode(game.state)
                game = FarmGame(catalog: catalog, state: try JSONDecoder().decode(FarmState.self, from: data))
                game.send(.startWish(wish.id))
                #expect(game.prompt?.stepID == step)
            }
            _ = try finish(&game)
        }
        #expect(game.sunProgress == 1)
        let bed = try #require(game.beds.first { $0.cropID == "crop.radish" })
        #expect(bed.phase == "sprouting" && bed.watered)
        #expect(!game.caredAnimalIDs.isEmpty)
        game.send(.sleep)
        #expect(game.beds.first { $0.id == bed.id }?.phase == "ripe")
        let harvest = try #require(game.wishes.first { $0.introduction == 4 })
        game.send(.startWish(harvest.id))
        _ = try finish(&game)
        #expect(game.state.production.inventory["item.radish"] == 3)
        let order = try #require(game.wishes.first { $0.introduction == 5 })
        game.send(.startWish(order.id))
        _ = try finish(&game)
        let remaining = game.state.production.inventory["item.radish", default: 0] + game.state.production.shelf["item.radish", default: 0]
        #expect(remaining < 3 && remaining > 0)
        #expect(game.state.coins > 0 && game.state.introduction == 6)
        #expect(game.state.book.contains("hofbook.plant.radish"))
    }

    @Test func quietHelpIsNonPunitiveAndFreePlayCannotFarmTicks() throws {
        var game = FarmGame(catalog: try catalog())
        game.send(.startActivity("act.farm.clean"))
        let first = try #require(game.prompt)
        for _ in 0..<5 { game.send(.choose("not-a-visible-object")) }
        #expect(game.prompt?.stepID == first.stepID && game.prompt?.assist == .cue)
        game.send(.idle(seconds: 20))
        #expect(game.prompt?.assist == .hint)
        game.send(.idle(seconds: 20))
        #expect(game.prompt?.assist == .ghost)
        game.send(.askPelle)
        #expect(game.prompt?.assist == .reduced)
        game.send(.askPelle)
        #expect(game.prompt?.stepID != first.stepID)
        _ = try finish(&game)
        #expect(game.state.ticks == 1 && game.state.treeWishes == 0)
        game.send(.startActivity("act.farm.clean"))
        _ = try finish(&game)
        #expect(game.state.ticks == 1 && game.state.treeWishes == 0)
    }

    @Test func festivalIsOptionalAndFoldedInvitationsSurvive() throws {
        var game = FarmGame(catalog: try catalog())
        let first = try #require(game.wishes.first)
        for _ in 0..<3 { game.send(.sleep) }
        let festival = try #require(game.state.outstanding.first { $0.festival == "season.spring" })
        game.send(.sleep)
        #expect(game.season == "season.summer")
        #expect(game.state.outstanding.contains { $0.id == first.id })
        #expect(game.state.outstanding.contains { $0.id == festival.id })
        #expect(game.state.outstanding.filter { !$0.folded }.count <= 8)
        game.send(.startWish(festival.id))
        _ = try finish(&game)
        #expect(game.state.book.contains("hofbook.season.spring.fest"))
        #expect(game.season == "season.summer")
    }

    @Test func discoveryRequiresActualVisitAndUnlock() throws {
        var game = FarmGame(catalog: try catalog())
        let detail = try #require(game.discoveries(at: "loc.garden").first)
        game.send(.discover(detail.id))
        #expect(!game.state.book.contains(detail.id))
        game.send(.visit("loc.garden"))
        #expect(game.send(.discover(detail.id)).text == detail.fact)
        #expect(game.state.book.contains(detail.id))
        game.send(.visit("loc.apiary"))
        #expect(game.state.locationID == "loc.garden")
    }

    @Test func consecutiveDaysReachAllFiveFarmLevelsWithoutBuyingAnything() throws {
        let catalog = try catalog()
        var game = FarmGame(catalog: catalog)
        for _ in 0..<45 {
            for _ in 0..<game.dailyGoal {
                let wish = try #require(game.wishes.first)
                game.send(.startWish(wish.id))
                _ = try finish(&game)
                #expect(!game.state.outstanding.contains { $0.id == wish.id })
            }
            if game.state.level == 5 { break }
            #expect(game.state.outstanding.filter { !$0.folded }.count <= 8)
            game.send(.sleep)
        }
        #expect(game.state.level == 5)
        #expect(game.locations.count == 17 && game.state.activityTypes.count >= 14)
    }
}
