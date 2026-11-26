import Foundation

struct FarmLocation: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let level: Int
}

struct FarmCrop: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let level: Int
    let locations: [String]
    let seasons: [String]
    let nights: Int
    let yield: Int
    let itemID: String
    let seedItemID: String?
    let stageModels: [String]
    // At a listed location these sowing seasons replace the default seasons.
    let seasonsByLocation: [String: [String]]?
    let bloomSeasonID: String?
    let harvestSeasonID: String?

    var nameKey: String { "vl.vocab.\(id)" }
}

struct FarmAnimal: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let level: Int
    // For Pelle and Minka this is their home, not a restriction on roaming.
    let locationID: String
    let foods: [String]
    let products: [String]
    let initialCount: Int
    let maxCount: Int
    let names: [String]
    let babyTitle: String?
    let sounds: [String]

    var nameKey: String { "vl.vocab.\(id)" }
    var model: String { "model.\(id)" }
}

struct FarmItem: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let level: Int
    let value: Int
    let shelfType: String

    var nameKey: String { "vl.vocab.\(id)" }
    var accusativeKey: String { "\(nameKey).acc" }
    var pluralKey: String { "\(nameKey).pl" }
    var icon: String { "icon.\(id)" }
    var model: String { "model.\(id)" }
}

struct FarmMachine: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let level: Int
    let purpose: String
    let upgradeLevel: Int?
    var model: String { "model.\(id)" }
}

struct FarmSeason: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let festivalID: String
    let festivalTitle: String
    let weather: [String]
    let festivalDay: Int
}

struct FarmBookEntry: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let fact: String
    let level: Int
    let locationID: String
    let seasonID: String?
    // Visiting wildlife belongs to the book, not to the livestock roster.
    let guestID: String?

    var modelID: String {
        let parts = id.split(separator: ".")
        guard parts.count >= 3, parts[0] == "hofbook" else { return id }
        let subject = parts[2]
        switch parts[1] {
        case "plant": return "crop.\(subject)"
        case "animal": return "animal.\(subject)"
        case "machine":
            let isVehicle = ["tractor", "combine", "carriage"].contains(subject)
            return "\(isVehicle ? "veh" : "imp").\(subject)"
        case "npc":
            if subject == "pelle" { return "animal.dog" }
            if subject == "minka" { return "animal.cat" }
            return "npc.\(subject)"
        default: return id
        }
    }
}

struct FarmDecoration: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let level: Int
    let price: Int
    let category: String
}

struct FarmRecipe: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let activityID: String
    let output: String
    let ingredients: [String: Int]
    let level: Int
    let locationID: String
    let station: String
    let seasonID: String?
    // Supplies at the station do not consume inventory items.
    let supplies: [String]?
}
