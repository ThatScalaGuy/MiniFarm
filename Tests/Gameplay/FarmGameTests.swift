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

    @Test(arguments: FarmStage.allCases) func everyCatalogActivityFinishesThroughItsOwnActions(stage: FarmStage) throws {
        let content = try catalog()
        for action in content.activities {
            var snapshot = FarmState(stage: stage)
            snapshot.level = 5
            snapshot.introduction = 6
            let season = switch action.id {
            case "act.animal.shear": "season.summer"
            case "act.nature.kite": "season.autumn"
            case "act.nature.snowman", "act.field.snowplow": "season.winter"
            default: "season.spring"
            }
            snapshot.seasonOffset = ["season.spring", "season.summer", "season.autumn", "season.winter"].firstIndex(of: season) ?? 0
            snapshot.production.prepare(day: 1, level: 5, stage: stage, season: season, catalog: content)
            // A late-game fixture with supplies; production-chain and unlock-path tests start from an empty farm.
            snapshot.production.inventory = Dictionary(uniqueKeysWithValues: content.items.filter { $0.value > 0 }.map { ($0.id, 5) })
            if ["act.field.water", "act.field.harvest", "act.field.combine"].contains(action.id) {
                let location = action.id == "act.field.combine" ? "loc.field" : "loc.garden"
                let index = try #require(snapshot.production.plots.firstIndex { $0.locationID == location })
                snapshot.production.plots[index].cropID = action.id == "act.field.combine" ? "crop.wheat" : "crop.radish"
                snapshot.production.plots[index].nightsLeft = action.id == "act.field.water" ? 1 : 0
            }
            var game = FarmGame(catalog: content, state: snapshot)
            let location = try #require(game.locations.first { location in
                game.activities(at: location.id).contains { $0.id == action.id }
            }, "Kein erreichbarer Ort für \(action.id)")
            game.send(.startActivityAt(action.id, location.id))
            #expect(game.prompt?.activityID == action.id)
            let feedback = try finish(&game)
            #expect(feedback.completed && !feedback.text.isEmpty)
            #expect(game.prompt == nil && game.state.ticks == 1, "\(action.id)")
        }
    }

    @Test func invalidSaveVersionIsNotSilentlyReplaced() throws {
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(FarmState(stage: .shoot))) as? [String: Any])
        json["schemaVersion"] = 42
        let data = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(FarmState.self, from: data) }
    }

    @Test func waitingOrderLeadsToItsOwnIngredientWithoutConsumingTheWish() throws {
        var game = FarmGame(catalog: try catalog())
        let waiting = try #require(game.state.outstanding.first { $0.activityID == "act.shop.order" })
        #expect(game.state.production.inventory["item.radish"] == nil)
        game.send(.startWish(waiting.id))
        #expect(game.prompt?.activityID == "act.field.sow")
        _ = try finish(&game)
        #expect(game.beds.contains { $0.cropID == "crop.radish" })
        #expect(game.state.outstanding.contains { $0.id == waiting.id })
        #expect(game.state.coins == 0)
        game.send(.startWish(waiting.id))
        #expect(game.prompt?.activityID == "act.field.water")
        _ = try finish(&game)
        game.send(.sleep)
        game.send(.startWish(waiting.id))
        #expect(game.prompt?.activityID == "act.field.harvest")
        _ = try finish(&game)
        game.send(.startWish(waiting.id))
        #expect(game.prompt?.activityID == "act.shop.order")
        _ = try finish(&game)
        #expect(game.state.coins > 0)
        #expect(!game.state.outstanding.contains { $0.id == waiting.id })
    }

    @Test func grownAnimalsStayWhileASpringVisitorCanJoinTheNursery() throws {
        let content = try catalog()
        var state = FarmState(stage: .shoot)
        state.level = 5
        state.production.prepare(day: 1, level: 5, stage: state.stage, season: "season.spring", catalog: content)
        let names = state.production.animals.map(\.id)
        state.day = 17
        state.production.prepare(day: 17, level: 5, stage: state.stage, season: "season.spring", catalog: content)
        #expect(state.production.animals.allSatisfy { !$0.isBaby })
        var game = FarmGame(catalog: content, state: state)
        game.send(.startActivityAt("act.animal.baby", "loc.cowbarn"))
        for _ in 0..<6 {
            guard let step = game.prompt, step.stepID != "name" else { break }
            game.send(.choose(step.targetID))
        }
        let nameStep = try #require(game.prompt)
        #expect(nameStep.choices.count == 3)
        game.send(.choose("name.star"))
        #expect(game.state.production.nurseryNames?.values.contains("Sternchen") == true)
        #expect(game.state.production.animals.map(\.id) == names)
    }

    @Test func homeDecorationMovesTheOwnedPieceAndHonorsTheWorkshopUnlock() throws {
        let content = try catalog()
        var game = FarmGame(catalog: content)
        game.send(.placeDecoration(FarmLife.starterID, positionID: "well"))
        #expect(game.state.life.placements.isEmpty)
        var state = game.state
        state.level = 2
        game = FarmGame(catalog: content, state: state)
        game.send(.placeDecoration(FarmLife.starterID, positionID: "well"))
        game.send(.rotateDecoration("well"))
        #expect(game.state.life.placements["well"]?.quarterTurns == 1)
        game.send(.putAwayDecoration("well"))
        #expect(game.state.life.inventory[FarmLife.starterID] == 1 && game.state.life.placements.isEmpty)
        #expect(game.state.coins == 0 && game.state.ticks == 0)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["MINIFARM_LONG_SIMULATION"] == "1"))
    func tenThousandFarmDaysKeepAPlayablePath() throws {
        let content = try catalog()
        for family in 0..<100 {
            let stage = FarmStage.allCases[family % FarmStage.allCases.count]
            var game = FarmGame(catalog: content, stage: stage)
            for day in 1...100 {
                let choices = game.wishes
                let invitation = try #require(choices.isEmpty ? nil : choices[(family + day) % choices.count])
                game.send(.startWish(invitation.id))
                if (family + day).isMultiple(of: 3) {
                    game.send(.idle(seconds: 12))
                    game.send(.askPelle)
                }
                _ = try finish(&game)
                if day.isMultiple(of: 11) {
                    game = FarmGame(catalog: content, state: try JSONDecoder().decode(FarmState.self, from: JSONEncoder().encode(game.state)))
                }
                #expect(!game.wishes.isEmpty && game.state.coins >= 0)
                #expect(game.state.production.inventory.values.allSatisfy { $0 >= 0 })
                #expect(game.state.outstanding.filter { !$0.folded }.count <= 8)
                game.send(.sleep)
                #expect(game.state.day == day + 1)
            }
        }
    }
}
