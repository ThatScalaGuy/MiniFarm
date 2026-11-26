struct FarmActivity: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let symbol: String
    var locationID: String
    let level: Int
    let lanes: [String]
    let participants: [String]
    let steps: [FarmStep]
    let result: String
    let params: [String: FarmActivityParams]
}

struct FarmStep: Codable, Sendable {
    let id: String
    let text: String
    let targetID: String
    let choices: [FarmChoice]
}

struct FarmChoice: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let symbol: String

    var modelID: String {
        switch id {
        case "seed": "item.seed.carrot"
        case "can": "tool.can"
        case "bucket": "tool.bucket"
        case "brush": "tool.brush"
        case "shears": "tool.shears"
        case "basket": "tool.basket"
        case "tractor": "veh.tractor"
        case "combine": "veh.combine"
        case "trailer": "imp.trailer"
        case "plow": "imp.plow"
        case "feed": "item.feed"
        case "hay": "item.hay"
        case "egg": "item.egg"
        case "milk": "item.milk"
        case "wool": "item.wool"
        case "carrot": "item.carrot"
        case "daisy": "deco.flower.daisy"
        case "pelle", "dog": "animal.dog"
        case "minka", "cat": "animal.cat"
        case "hen": "animal.chicken"
        default: id
        }
    }
}

struct FarmActivityParams: Codable, Sendable {
    let choiceCount: Int
    let targetSize: Int
}
