import Foundation
import Testing
@testable import MiniFarm

struct ProductionTests {
    private struct Yard {
        let catalog: FarmCatalog
        var farm = FarmProduction()
        var day = 1
        var level: Int
        var stage: FarmStage
        var season: String

        init(level: Int = 1, stage: FarmStage = .sprout, season: String = "season.spring") throws {
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().appendingPathComponent("App/Resources/Content")
            let resource = Bundle.main.url(forResource: "crops", withExtension: "json", subdirectory: "Content")
                ?? Bundle.main.url(forResource: "crops", withExtension: "json")
            catalog = try FarmCatalog.load(from: resource?.deletingLastPathComponent() ?? root)
            self.level = level
            self.stage = stage
            self.season = season
            prepare()
        }

        mutating func prepare() {
            farm.prepare(day: day, level: level, stage: stage, season: season, catalog: catalog)
        }

        mutating func sleep() {
            farm.night(day: day, stage: stage, season: season, catalog: catalog)
            day += 1
            prepare()
        }

        func offers(_ activity: String, _ location: String) -> [FarmVariant] {
            farm.variants(activityID: "act.\(activity)", locationID: "loc.\(location)", day: day,
                          level: level, stage: stage, season: season, catalog: catalog) ?? []
        }

        func pick(_ activity: String, _ location: String, item: String? = nil) throws -> FarmVariant {
            try #require(offers(activity, location).first { item == nil || $0.featuredItemID == item })
        }

        mutating func apply(_ offer: FarmVariant, _ activity: String) -> FarmResult? {
            farm.apply(offer, activityID: "act.\(activity)", day: day, level: level, stage: stage, season: season, catalog: catalog)
        }

        @discardableResult
        mutating func work(_ activity: String, _ location: String, item: String? = nil) throws -> FarmResult {
            let selection = try pick(activity, location, item: item)
            return try #require(apply(selection, activity))
        }
    }

    @Test func starterCropWaitsForWaterAndPaysForExactlyOneRadish() throws {
        var yard = try Yard()
        try yard.work("field.sow", "garden", item: "item.radish")
        yard.sleep()
        #expect(yard.offers("field.harvest", "garden").isEmpty)
        try yard.work("field.water", "garden")
        #expect(yard.farm.plots.first { $0.cropID == "crop.radish" }?.phase == "sprouting")
        yard.sleep()
        #expect(yard.farm.plots.first { $0.cropID == "crop.radish" }?.phase == "ripe")
        let harvest = try yard.pick("field.harvest", "garden")
        let picked = yard.apply(harvest, "field.harvest")
        let result = try #require(picked)
        #expect(result.book.contains("hofbook.plant.radish"))
        #expect(yard.apply(harvest, "field.harvest") == nil)
        #expect(yard.farm.inventory["item.radish"] == 3)

        let order = try yard.pick("shop.order", "shop", item: "item.radish")
        yard.farm = try JSONDecoder().decode(FarmProduction.self, from: JSONEncoder().encode(yard.farm))
        #expect(yard.apply(order, "shop.order") != nil)
        #expect(yard.farm.coins == 1)
        #expect(yard.farm.inventory["item.radish"] == 2)
        #expect(yard.apply(order, "shop.order") == nil)
        try yard.work("shop.stock", "shop")
        #expect(yard.farm.shelf["item.radish"] == 2)
        #expect(yard.farm.inventory["item.radish", default: 0] == 0)
        yard.prepare()
        try yard.work("shop.order", "shop")
        #expect(yard.farm.shelf.isEmpty)
        #expect(yard.farm.coins == 3)
    }

    @Test func tractorWorksRowsAndRainDoesNotWaterIndoorBeds() throws {
        var yard = try Yard(level: 4)
        #expect(yard.offers("field.sow", "field").isEmpty)
        try yard.work("field.plow", "field")
        yard.farm.rain()
        try yard.work("field.sow", "field", item: "item.wheat")
        try yard.work("field.sow", "greenhouse", item: "item.tomato")
        let rowSize = yard.farm.plots.filter { $0.cropID == "crop.wheat" }.count
        #expect(rowSize > 1)
        yard.farm.rain()
        yard.sleep()
        #expect(yard.offers("field.combine", "field").isEmpty)
        #expect(yard.farm.plots.first { $0.cropID == "crop.tomato" }?.nightsLeft == 2)
        try yard.work("field.water", "field")
        yard.sleep()
        let result = try yard.work("field.combine", "field")
        #expect(result.book.contains("hofbook.machine.combine"))
        #expect(yard.farm.inventory["item.wheat"] == rowSize * 6)
        yard.season = "season.winter"
        yard.prepare()
        #expect(yard.offers("field.sow", "garden").isEmpty)
        #expect(!yard.offers("field.sow", "greenhouse").isEmpty)
    }

    @Test func eachAnimalSuppliesItsOwnDailyProductAndBlockedVisitsDoNothing() throws {
        var yard = try Yard(level: 5)
        let egg = try yard.pick("animal.eggs", "pond")
        #expect(egg.featuredItemID == "item.duckegg")
        let adults = yard.offers("animal.eggs", "pond").count
        #expect(yard.apply(egg, "animal.milk") == nil)
        #expect(yard.apply(egg, "animal.eggs") != nil)
        yard.prepare()
        #expect(yard.offers("animal.eggs", "pond").count == adults - 1)
        #expect(yard.apply(egg, "animal.eggs") == nil)
        try yard.work("animal.find", "pond", item: "item.feather")
        try yard.work("animal.find", "apiary", item: "item.honeycomb")
        try yard.work("kitchen.churn", "apiary", item: "item.honey")
        #expect(yard.farm.inventory["item.honeycomb", default: 0] == 0)
        #expect(yard.farm.inventory["item.honey"] == 1)
        #expect(yard.offers("animal.shear", "sheepmeadow").isEmpty)
        yard.sleep()
        #expect(yard.offers("animal.eggs", "pond").count == adults)
        try yard.work("animal.pet", "paddock")
        #expect(yard.farm.caredAnimalIDs(on: yard.day).count == 1)
    }

    @Test func recipesConsumeOnlyTheirOwnIngredientsAndStaleOrdersNeverPay() throws {
        var yard = try Yard(level: 4, stage: .bloom)
        yard.farm.inventory = ["item.flour": 1, "item.egg": 1, "item.milk": 1]
        let order = try yard.pick("shop.order", "shop")
        let cake = try yard.pick("kitchen.bake", "kitchen", item: "item.cake")
        let steps = cake.steps(base: [], catalog: yard.catalog)
        #expect(Set(["item.flour", "item.egg", "item.milk", "item.cake"]).isSubset(of: Set(steps.map(\.targetID))))
        #expect(steps.contains { $0.text.contains("Backofen") })
        #expect(yard.apply(cake, "kitchen.bake") != nil)
        #expect(yard.farm.inventory == ["item.cake": 1])
        #expect(yard.apply(order, "shop.order") == nil)
        #expect(yard.farm.coins == 0)
        #expect(yard.apply(cake, "kitchen.bake") == nil)
        try yard.work("shop.order", "shop", item: "item.cake")
        #expect(yard.farm.coins == 6)
    }

    @Test func orchardRefillsByYearRatherThanPrepareCalls() throws {
        var yard = try Yard(level: 3, season: "season.autumn")
        let trees = yard.offers("field.harvest", "orchard").count
        try yard.work("field.harvest", "orchard")
        yard.prepare()
        #expect(yard.offers("field.harvest", "orchard").count == trees - 1)
        #expect(yard.farm.inventory["item.apple"] == 4)
        yard.season = "season.spring"
        yard.prepare()
        #expect(yard.offers("field.harvest", "orchard").isEmpty)
        yard.day += 16
        yard.season = "season.autumn"
        yard.prepare()
        #expect(yard.offers("field.harvest", "orchard").count == trees)
    }

    @Test func restockingDoesNotRewriteAnOpenOrderAndCarriageSellsRealCargo() throws {
        var yard = try Yard(level: 5, stage: .bloom)
        yard.farm.inventory = ["item.honey": 1]
        let smallOrder = try yard.pick("shop.order", "shop")
        yard.farm.inventory["item.honey"] = 3
        yard.farm.inventory["item.egg"] = 2
        #expect(yard.apply(smallOrder, "shop.order") != nil)
        #expect(yard.farm.inventory == ["item.honey": 2, "item.egg": 2])
        #expect(yard.farm.coins == 5)
        let cargo = try yard.pick("shop.market", "paddock")
        #expect(cargo.steps(base: [], catalog: yard.catalog).contains { $0.targetID == "veh.carriage" })
        #expect(yard.apply(cargo, "shop.market") != nil)
        #expect(yard.apply(cargo, "shop.market") == nil)
        #expect(yard.farm.inventory == ["item.honey": 1, "item.egg": 1])
        #expect(yard.farm.coins == 12)
    }
}
