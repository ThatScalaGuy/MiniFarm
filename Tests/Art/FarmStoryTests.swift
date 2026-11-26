import Foundation
import Testing
@testable import MiniFarm

struct FarmStoryTests {
    private func catalog() throws -> FarmCatalog {
        let directory = try #require(Bundle.main.url(forResource: "Content", withExtension: nil))
        return try FarmCatalog.load(from: directory)
    }

    private func finish(_ game: inout FarmGame) throws {
        for _ in 0..<100 {
            let prompt = try #require(game.prompt)
            if game.send(prompt.activityID == "act.farm.memory" ? .askPelle : .choose(prompt.targetID)).completed { return }
        }
        throw FarmContentError.invalid("Spielhandlung nicht beendet.")
    }

    @Test func actualDeedsAndWateredBedSurviveTheDayResetInPictures() throws {
        var game = FarmGame(catalog: try catalog())
        let quiet = game
        var next = quiet
        next.send(.sleep)
        let empty = try #require(FarmNightStory(before: quiet, after: next))
        #expect(empty.deeds.isEmpty && empty.growth == nil)
        for _ in 0..<3 {
            let wish = try #require(game.wishes.first)
            game.send(.startWish(wish.id))
            try finish(&game)
        }
        game.send(.startActivity("act.farm.clean"))
        try finish(&game)
        let evening = game
        game.send(.sleep)
        let story = try #require(FarmNightStory(before: evening, after: game))
        #expect(Set(story.deeds) == ["act.field.sow", "act.field.water", "act.animal.feed", "act.farm.clean"])
        #expect(story.growth == .init(cropID: "crop.radish", from: .sprouting, to: .ripe))
        #expect(FarmNightStory(before: game, after: game) == nil)
        #expect(FarmLevelParcel(before: evening, after: game) == nil)
        #expect(game.state.day == evening.state.day + 1 && game.state.creditedToday.isEmpty)
    }

    @Test func onlyAnActualPromotionProducesANonMutatingParcel() throws {
        let catalog = try catalog()
        var game = FarmGame(catalog: catalog)
        var levels: [Int] = []
        while game.state.level < 5, game.state.day <= 50 {
            for _ in 0..<game.dailyGoal {
                let before = game
                let wish = try #require(game.wishes.first)
                game.send(.startWish(wish.id))
                try finish(&game)
                if let parcel = FarmLevelParcel(before: before, after: game) {
                    levels.append(parcel.id)
                    let unlocks = catalog.animals.filter { $0.level == parcel.id }.map(\.id)
                        + catalog.crops.filter { $0.level == parcel.id }.compactMap(\.seedItemID)
                        + catalog.machines.filter { $0.level == parcel.id }.map(\.id)
                    #expect(!parcel.gifts.isEmpty && Set(parcel.gifts).isSubset(of: unlocks))
                    let data = try JSONEncoder().encode(game.state)
                    let reopened = FarmGame(catalog: catalog, state: try JSONDecoder().decode(FarmState.self, from: data))
                    #expect(FarmLevelParcel(before: game, after: reopened) == nil)
                    #expect(reopened.state.production.inventory == game.state.production.inventory)
                } else {
                    #expect(before.state.level == game.state.level)
                }
            }
            game.send(.sleep)
        }
        #expect(levels == [2,3,4,5])
    }

    @Test func albumRequiresTheEarnedEntryAndEachPersistedOccasion() throws {
        let catalog = try catalog()
        var game = FarmGame(catalog: catalog)
        let spring = "hofbook.season.spring.fest"
        let summer = "hofbook.season.summer.fest"
        var noPhotos = game.state
        noPhotos.book = [spring]
        #expect(FarmFestivalAlbum(entryID: spring, game: FarmGame(catalog: catalog, state: noPhotos)) == nil)
        for day in 1...20 {
            if day % 4 == 0 {
                let wish = try #require(game.state.outstanding.first { $0.festival == game.season })
                game.send(.startWish(wish.id))
                try finish(&game)
            }
            game.send(.sleep)
        }
        let data = try JSONEncoder().encode(game.state)
        let restored = FarmGame(catalog: catalog, state: try JSONDecoder().decode(FarmState.self, from: data))
        let album = try #require(FarmFestivalAlbum(entryID: spring, game: restored))
        #expect(album.photos.map(\.day) == [4,20])
        #expect(album.photos.allSatisfy { $0.backdrop == "tree" && $0.subjects.contains("animal.dog") })
        #expect(FarmFestivalAlbum(entryID: summer, game: restored)?.photos.map(\.day) == [8])
        #expect(FarmFestivalAlbum(entryID: "hofbook.season.winter.fest", game: restored)?.photos.first?.backdrop == "lantern.path")
        #expect(FarmFestivalAlbum(entryID: "hofbook.season.autumn.fest", game: restored)?.photos.first?.backdrop == "feast.table")
        #expect(FarmFestivalAlbum(entryID: spring, game: FarmGame(catalog: catalog)) == nil)
    }
}
