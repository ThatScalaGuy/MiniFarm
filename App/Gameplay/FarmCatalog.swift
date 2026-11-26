import Foundation

struct FarmEconomy: Codable, Sendable {
    let schemaVersion: Int
    let orderPayout, ordersPerDay: [String: Int]
    let decoPrice: [String: [Int]]
    let shelfSlots: [Int]
    let shelfStack, maxOrderValue: Int

    func permits(price: Int, level: Int) -> Bool {
        for key in ["small", "large"] where key == "small" || level >= 3 {
            if let band = decoPrice[key], band.count == 2, price >= band[0], price <= band[1] { return true }
        }
        return false
    }
}

enum FarmContentError: LocalizedError {
    case file(String, Error)
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case let .file(name, error): "\(name): \(error.localizedDescription)"
        case let .invalid(message): "Hofkatalog: \(message)"
        }
    }
}

struct FarmCatalog: Sendable {
    let activities: [FarmActivity]
    let locations: [FarmLocation]
    let crops: [FarmCrop]
    let animals: [FarmAnimal]
    let items: [FarmItem]
    let machines: [FarmMachine]
    let tools: [FarmMachine]
    var fieldMachines: [FarmMachine] { machines.filter { $0.id != "veh.carriage" } }
    let seasons: [FarmSeason]
    let recipes: [FarmRecipe]
    let decorations: [FarmDecoration]
    let hofbook: [FarmBookEntry]
    let adaptive: FarmAdaptiveRules
    let economy: FarmEconomy

    static func load(from directory: URL) throws -> Self {
        func load<T: Decodable>(_ file: String, _: T.Type) throws -> T {
            do {
                let data = try Data(contentsOf: directory.appendingPathComponent(file + ".json"))
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw FarmContentError.file(file + ".json", error)
            }
        }
        func rows<T: Decodable>(_ file: String, _: T.Type) throws -> [T] {
            let envelope = try load(file, FarmRows<T>.self)
            guard envelope.name == file else { throw FarmContentError.invalid("Inhaltsliste in \(file)") }
            return envelope.values
        }
        struct Equipment: Decodable {
            let schemaVersion: Int
            let machines, tools: [FarmMachine]
        }
        let equipment = try load("machines", Equipment.self)
        guard equipment.schemaVersion == 1 else { throw FarmContentError.invalid("Geräteschema") }
        let catalog = try Self(
            activities: rows("activities", FarmActivity.self), locations: rows("locations", FarmLocation.self),
            crops: rows("crops", FarmCrop.self), animals: rows("animals", FarmAnimal.self),
            items: rows("items", FarmItem.self), machines: equipment.machines, tools: equipment.tools,
            seasons: rows("seasons", FarmSeason.self), recipes: rows("recipes", FarmRecipe.self),
            decorations: rows("decorations", FarmDecoration.self), hofbook: rows("hofbook", FarmBookEntry.self),
            adaptive: load("adaptive", FarmAdaptiveRules.self), economy: load("economy", FarmEconomy.self)
        )
        try catalog.validate()
        return catalog
    }

    func validate() throws {
        func require(_ condition: Bool, _ detail: String) throws {
            guard condition else { throw FarmContentError.invalid(detail) }
        }
        let groups = [activities.map(\.id), locations.map(\.id), crops.map(\.id), animals.map(\.id),
                      items.map(\.id), machines.map(\.id), tools.map(\.id), seasons.map(\.id),
                      recipes.map(\.id), decorations.map(\.id), hofbook.map(\.id)]
        let all = groups.flatMap { $0 }
        try require(economy.schemaVersion == 1 && economy.shelfSlots.count == 2 && economy.shelfSlots.allSatisfy { $0 > 0 }
            && economy.shelfStack > 0 && economy.maxOrderValue > 0
            && FarmStage.allCases.allSatisfy { economy.orderPayout[$0.rawValue, default: 0] > 0
                && economy.ordersPerDay[$0.rawValue, default: 0] > 0 }
            && ["small", "large"].allSatisfy { economy.decoPrice[$0]?.count == 2 }, "Wirtschaftswerte")
        try require(Set(all).count == all.count, "Doppelte ID")
        try require(activities.count == 39 && locations.count == 17 && crops.count == 14
            && animals.count == 11 && fieldMachines.count == 11 && seasons.count == 4, "Umfang der Stammdaten")
        let locationsByID = Dictionary(uniqueKeysWithValues: locations.map { ($0.id, $0.level) })
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.level) })
        let npc = hofbook.filter { $0.id.hasPrefix("hofbook.npc.") }.map { (String($0.id.dropFirst(8)), $0.level) }
        let levels = itemsByID.merging(locationsByID) { _, b in b }
            .merging(Dictionary(uniqueKeysWithValues: machines.map { ($0.id, $0.level) })) { _, b in b }
            .merging(Dictionary(uniqueKeysWithValues: crops.map { ($0.id, $0.level) })) { _, b in b }
            .merging(Dictionary(uniqueKeysWithValues: animals.map { ($0.id, $0.level) })) { _, b in b }
            .merging(Dictionary(uniqueKeysWithValues: tools.map { ($0.id, $0.level) })) { _, b in b }
            .merging(Dictionary(uniqueKeysWithValues: npc)) { _, b in b }
        try require(levels.values.allSatisfy { (1...5).contains($0) }, "Hofstufe außerhalb von 1–5")
        let seasonsByID = Set(seasons.map(\.id))
        try require(seasonsByID == Set(["season.spring", "season.summer", "season.autumn", "season.winter"]), "Jahreskreis")
        for activity in activities {
            try require((1...5).contains(activity.level) && locationsByID[activity.locationID, default: 6] <= activity.level,
                        "Ort/Hofstufe von \(activity.id)")
            for id in activity.participants {
                try require(levels[id, default: 6] <= activity.level, "\(activity.id) braucht \(id)")
            }
            try require(!activity.steps.isEmpty && activity.params.keys.sorted() == ["bloom", "shoot", "sprout"],
                        "Schritte oder Stufen von \(activity.id)")
            for step in activity.steps {
                let ids = step.choices.map(\.id)
                try require(!ids.isEmpty && Set(ids).count == ids.count
                    && (step.targetID == "*" || ids.contains(step.targetID)),
                            "\(activity.id): Ziel \(step.targetID) in Schritt \(step.id)")
            }
        }
        for season in seasons {
            try require(!season.weather.isEmpty && season.festivalDay == 4 && season.festivalID == season.id + ".fest"
                && Set(season.weather).isSubset(of: ["sun", "cloud", "rain", "rainbow", "fog", "snow", "wind"]), season.id)
        }
        for decoration in decorations {
            try require((1...5).contains(decoration.level) && economy.permits(price: decoration.price, level: decoration.level), decoration.id)
        }
        for crop in crops {
            try require(itemsByID[crop.itemID] == crop.level && crop.yield > 0 && crop.nights >= 0
                && crop.stageModels.count == 4 && (crop.id == "crop.apple" || crop.seedItemID.flatMap { itemsByID[$0] } == crop.level)
                && !crop.locations.isEmpty && crop.locations.allSatisfy { locationsByID[$0] != nil }
                && Set(crop.seasons).isSubset(of: seasonsByID), crop.id)
        }
        for animal in animals {
            try require(locationsByID[animal.locationID, default: 6] <= animal.level && animal.initialCount >= 1
                && animal.maxCount >= animal.initialCount && (animal.foods + animal.products).allSatisfy { itemsByID[$0] != nil }, animal.id)
        }
        for entry in hofbook {
            try require(locationsByID[entry.locationID] != nil && (1...5).contains(entry.level) && !entry.fact.isEmpty, entry.id)
        }
        for recipe in recipes {
            try require(activities.contains { $0.id == recipe.activityID && $0.level <= recipe.level }
                && itemsByID[recipe.output] == recipe.level && !recipe.ingredients.isEmpty
                && recipe.ingredients.allSatisfy { itemsByID[$0.key, default: 6] <= recipe.level && $0.value > 0 }, recipe.id)
        }
        var producible = Set(crops.map(\.itemID) + animals.flatMap(\.products) + ["item.hay", "item.feed"])
        for _ in recipes {
            for recipe in recipes where Set(recipe.ingredients.keys).isSubset(of: producible) {
                producible.insert(recipe.output)
            }
        }
        try require(items.filter { $0.value > 0 && !$0.id.hasPrefix("item.seed.") }.allSatisfy { producible.contains($0.id) },
                    "Nicht herstellbare Ware")
    }
}

private struct FarmRows<T: Decodable>: Decodable {
    struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
    let name: String
    let values: [T]

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: Key.self)
        let version = try box.decode(Int.self, forKey: Key(stringValue: "schemaVersion"))
        let keys = box.allKeys.filter { $0.stringValue != "schemaVersion" }
        guard version == 1, keys.count == 1, let key = keys.first else {
            throw FarmContentError.invalid("Unbekanntes Inhaltsschema (\(version))")
        }
        name = key.stringValue
        values = try box.decode([T].self, forKey: key)
    }
}
