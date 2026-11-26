import Foundation

private func picture(_ id: String, _ title: String, _ symbol: String) -> FarmChoice {
    FarmChoice(id: id, title: title, symbol: symbol)
}

private func action(_ id: String, _ text: String, _ target: String, _ choices: [FarmChoice]) -> FarmStep {
    FarmStep(id: id, text: text, targetID: target, choices: choices)
}

private func say(_ text: String, book: Set<String> = []) -> FarmResult {
    FarmResult(text: text, book: book)
}

enum FarmMemoryTurn: Equatable, Sendable {
    case ignored, first, mismatch, pair, finished
}

struct FarmLife: Codable, Sendable {
    struct Photo: Codable, Sendable {
        let day: Int
        let season, occasionID, backdrop: String
        let subjects: [String]
    }

    struct Placement: Codable, Sendable {
        let decorationID: String
        var quarterTurns: Int
    }

    static let starterID = "deco.flower.daisy"
    static let positions = [
        picture("tree", "Am Hofbaum", "tree"),
        picture("well", "Neben dem Brunnen", "drop"),
        picture("gate", "Am Hoftor", "door.left.hand.open"),
        picture("mailbox", "Beim Briefkasten", "envelope"),
        picture("path", "Am Wegesrand", "figure.walk"),
        picture("fence", "Vor dem Gartenzaun", "leaf")
    ]

    private(set) var inventory = [starterID: 1]
    private(set) var placements: [String: Placement] = [:]
    private(set) var wishlist: [String] = []
    private(set) var bouquet: [String] = []
    private(set) var bouquetVase: String?
    private(set) var frogsCounted = 0
    private(set) var fedFishAt: String?
    private(set) var birdhouseSeed: String?
    private(set) var birdhouseVisitor: String?
    private(set) var wormsByBed: [String: Int] = [:]
    private(set) var kiteTrail: [String] = []
    private(set) var snowman: [String] = []
    private(set) var lanternLine: [String] = []
    private(set) var deliveredMail: [String: Int] = [:]
    private(set) var moToy: String?
    private(set) var moDrawing: String?
    private(set) var photos: [Photo] = []
    private(set) var contentsByCrate: [String: Set<String>] = [:]
    private(set) var song: [String] = []
    private(set) var shopSign: [String] = []
    private(set) var scarecrow: [String] = []
    private(set) var completedBoards = 0
    private(set) var festivalDisplays: [String: [String]] = [:]
    private(set) var lastObservationAt: [String: String] = [:]
    private(set) var sceneTextAt: [String: String] = [:]

    private var boards: [String: MemoryBoard] = [:]
    private var activeBoard = "memory"

    init() {}

    func steps(activity: FarmActivity, stage: FarmStage, day: Int, season: String, catalog: FarmCatalog) -> [FarmStep] {
        if activity.id == "act.farm.memory" {
            return [memoryStep ?? MemoryBoard(stage: stage, keepRevealed: false, seed: 0).step]
        }
        return playSteps(id: activity.id, stage: stage, day: day, season: season, catalog: catalog) ?? activity.steps
    }

    private func playSteps(id: String, stage: FarmStage, day: Int, season: String, catalog: FarmCatalog) -> [FarmStep]? {
        let tier = stage == .sprout ? 0 : stage == .shoot ? 1 : 2
        let flowers = [
            picture("daisy", "Weißes Gänseblümchen", "camera.macro"),
            picture("poppy", "Roter Mohn", "heart"),
            picture("cornflower", "Blaue Kornblume", "star")
        ]
        let lights = [
            picture("sun", "Gelbe Sonnenlaterne", "sun.max"),
            picture("moon", "Blaue Mondlaterne", "moon"),
            picture("heart", "Rote Herzlaterne", "heart")
        ]
        let animals = [
            picture("animal.dog", "Pelle", "dog"), picture("animal.cat", "Minka", "cat"),
            picture("animal.chicken", "Die Henne", "bird")
        ]
        switch id {
        case "act.nature.flowers":
            let words = ["Ein weißes Gänseblümchen", "Eine rote Mohnblüte", "Eine blaue Kornblume"]
            return (0..<(2 + tier)).map { index in
                let next = (max(0, day) % flowers.count + index) % flowers.count
                return action("pluck.\(index)", "\(words[next]) für Tildas Strauß. Welche pflückst du?",
                              flowers[next].id, flowers)
            } + [action("vase", "In welche Vase stellst du Tildas Strauß?", "*", [
                picture("jug", "Bauchiger Krug", "drop.circle"), picture("bottle", "Schmale Flasche", "waterbottle")
            ])]
        case "act.nature.pond":
            let number = tier + 2
            let calls = Array(repeating: "Quak", count: number).joined(separator: " · ")
            return [
                action("frogs", "Jeder Frosch ruft einmal: \(calls)! Wie viele sitzen am Ufer?", "\(number)",
                       (1...4).map { picture("\($0)", "\($0)", "\($0).circle") }),
                action("fish", "Die Fische kommen näher. Was streuen wir ins Wasser?", "flakes", [
                    picture("leaves", "Blätter", "leaf"), picture("flakes", "Fischfutter", "fish")
                ]),
                action("bank", "Wo streust du die Flocken aus?", "*", [
                    picture("reed", "Am Schilf", "leaf"), picture("stone", "Neben dem flachen Stein", "oval")
                ])
            ]
        case "act.nature.birdhouse":
            let birds = [
                picture("robin", "Rotkehlchen", "heart.circle"), picture("blackbird", "Amsel", "music.note"),
                picture("tit", "Blaumeise", "drop.circle")
            ]
            let i = max(0, day) % birds.count
            let clues = ["Wer hat eine orangerote Brust?", "Wer trägt ein schwarzes Federkleid und einen gelben Schnabel?",
                         "Wer trägt ein blaues Käppchen?"]
            return [
                action("pour", "Welche Körner füllst du in das Futterhäuschen?", "*", [
                    picture("sunflower", "Sonnenblumenkerne", "sun.max"), picture("millet", "Hirse", "circle.grid.3x3")
                ]),
                action("watch", "Schau, da landet ein Vogel. \(clues[i])", birds[i].id, birds)
            ]
        case "act.nature.compost":
            return [
                action("worm", "Unter dem großen Blatt raschelt es. Heb es an und finde den Regenwurm!", "leaf", [
                    picture("pot", "Blumentopf", "cup.and.saucer"), picture("leaf", "Großes Blatt", "leaf")
                ]),
                action("bed", "In welchem Beet darf der Wurm die Erde lockern?", "*", [
                    picture("crop.carrot", "Möhrenbeet", "carrot"), picture("crop.lettuce", "Salatbeet", "leaf.circle")
                ])
            ]
        case "act.nature.kite":
            let string = [picture("pull", "Schnur anziehen", "arrow.down"), picture("release", "Schnur geben", "arrow.up")]
            let figures = [picture("loop", "Kringel", "circle"), picture("wave", "Welle", "water.waves"),
                           picture("zigzag", "Zickzack", "bolt")]
            return [action("lift", "Der Wind kommt! Zieh die Schnur ein wenig an.", "pull", string),
                    action("climb", "Der Drachen steigt. Gib ihm mehr Schnur!", "release", string)] +
                (0...tier).map { action("draw.\($0)", "Welche Spur soll dein Drachen in den Himmel malen?", "*", figures) }
        case "act.nature.snowman":
            let balls = [picture("large", "Große Kugel", "l.circle"), picture("medium", "Mittlere Kugel", "m.circle"),
                         picture("small", "Kleine Kugel", "s.circle")]
            return [action("base", "Rolle die größte Kugel für den Bauch.", "large", balls),
                    action("chest", "Setz die mittlere Kugel darauf.", "medium", balls),
                    action("head", "Jetzt kommt die kleinste Kugel als Kopf.", "small", balls),
                    action("face", "Womit bekommt dein Schneemann ein Lächeln?", "*", [
                        picture("stones", "Runde Kiesel", "circle.dotted"), picture("twigs", "Krummer Zweig", "leaf")
                    ])]
        case "act.nature.lantern":
            let pattern = tier == 0 ? [0, 1] : tier == 1 ? [0, 1, 2] : [0, 2, 1]
            let refrain = pattern.map { ["Sonne", "Mond", "Herz"][$0] }.joined(separator: ", ")
            return (pattern + pattern).enumerated().map { index, color in
                action("light.\(index)", "\(refrain) – und wieder von vorn. Welche Laterne kommt auf Platz \(index + 1)?",
                       lights[color].id, lights)
            }
        case "act.village.mail":
            let boxes = [picture("npc.tilda", "Tildas Brotkasten", "birthday.cake"),
                         picture("npc.hanno", "Hannos Holzkasten", "hammer"),
                         picture("npc.mo", "Mos Buntstiftkasten", "pencil")]
            let emblems = ["ein Brot", "einen Hammer", "einen Buntstift"]
            return (0..<(tier == 0 ? 2 : 3)).map { index in
                let i = (max(0, day) % 3 + index) % 3
                return action("letter.\(index)", "Auf Lales Brief siehst du \(emblems[i]). Zu welchem Kasten gehört er?",
                              boxes[i].id, boxes)
            }
        case "act.village.helpmo":
            return [
                action("toy", "Mo sucht etwas Rundes, das hüpfen kann. Was rollt unter der Bank?", "ball", [
                    picture("block", "Holzklotz", "cube"), picture("ball", "Spielball", "soccerball")
                ]),
                action("drawing", "Der Ball ist wieder da! Was malst du zu Mos Bild dazu?", "*", [
                    picture("sun", "Eine strahlende Sonne", "sun.max"), picture("kite", "Einen Drachen", "diamond"),
                    picture("flower", "Eine Blume", "camera.macro")
                ])
            ]
        case "act.farm.decorate":
            let owned = Set(inventory.filter { $0.value > 0 }.keys).union(placements.values.map(\.decorationID))
            let pieces = catalog.decorations.filter { owned.contains($0.id) }.map { picture($0.id, $0.title, "shippingbox") }
            return [
                action("piece", "Welches Stück möchtest du aufstellen oder umsetzen?", "*", pieces),
                action("position", "Wähle einen Platz. Was dort schon steht, kommt zurück in die Kiste.", "*", Self.positions),
                action("direction", "In welche Richtung schaut dein Schmuckstück?", "*", Self.directions)
            ]
        case "act.farm.photo":
            return [
                action("gather", "Pelle hält die Pfote hoch. Ruf ihn zum Hoffoto!", "animal.dog", animals),
                action("friend", "Wer darf neben Pelle aufs Bild?", "*", Array(animals.dropFirst())),
                action("backdrop", "Wo machst du das Gruppenfoto?", "*", Array(Self.positions.prefix(3)))
            ]
        case "act.farm.clean":
            let crates = [picture("tools", "Werkzeugkiste", "wrench"), picture("toys", "Spielsachen", "soccerball"),
                          picture("seeds", "Saatkiste", "leaf")]
            return [action("can", "Die Gießkanne ist ein Gartenwerkzeug. In welche Kiste gehört sie?", "tools", crates),
                    action("ball", "Und wo wohnt der bunte Spielball?", "toys", crates),
                    action("seed", "Jetzt noch die Samentüte. Wohin damit?", "seeds", crates)]
        case "act.farm.sing":
            let sounds = ["Wau", "Miau", "Gack"]
            let order = (0..<(2 + tier)).map { (max(0, day) % 3 + $0) % 3 }
            let melody = order.map { sounds[$0] }.joined(separator: " – ")
            return order.enumerated().map { index, note in
                action("note.\(index)", "Pelles Lied geht so: \(melody)! Spiel den \(index + 1). Laut.", animals[note].id, animals)
            }
        case "act.shop.sign":
            let pictures = [picture("item.apple", "Apfel", "basket"), picture("item.bread", "Brot", "takeoutbag.and.cup.and.straw"),
                            picture("animal.cow", "Kuh", "bell"), picture("item.carrot", "Möhre", "carrot")]
            return ["links", "in der Mitte", "rechts"].enumerated().map { index, place in
                action("sign.\(index)", "Welches Bild soll \(place) auf dem Ladenschild stehen?", "*", pictures)
            }
        case "act.field.scarecrow":
            let parts = [picture("body", "Strohbauch", "tshirt"), picture("arms", "Zweigarme", "arrow.left.and.right"),
                         picture("head", "Strohkopf", "face.smiling"), picture("hat", "Hut", "graduationcap")]
            return [
                action("body", "Fülle das Hemd in der Mitte mit Stroh. Welches Teil wird der Bauch?", "body", parts),
                action("arms", "Was gehört quer in die beiden Ärmel?", "arms", parts),
                action("head", "Was sitzt oben am Kragen?", "head", parts),
                action("hat", "Setz der Vogelscheuche ganz oben etwas auf!", "hat", parts),
                action("ribbon", "Welche Schleife kommt an den Hut?", "*", [
                    picture("leaf", "Grünes Blatt", "leaf"), picture("star", "Gelber Stern", "star"),
                    picture("heart", "Rotes Herz", "heart")
                ])
            ]
        default: return nil
        }
    }

    static let directions = [
        picture("north", "Nach Norden", "arrow.up"), picture("east", "Nach Osten", "arrow.right"),
        picture("south", "Nach Süden", "arrow.down"), picture("west", "Nach Westen", "arrow.left")
    ]
}

extension FarmLife {
    mutating func complete(activityID: String, locationID: String, choices: [String], day: Int,
                           season: String, catalog: FarmCatalog) -> FarmResult {
        guard let activity = catalog.activities.first(where: { $0.id == activityID }),
              activity.locationID == locationID || (activityID == "act.village.mail" && locationID == "loc.village")
                || (activityID == "act.nature.pond" && locationID == "loc.pond") else {
            return say("Pelle zeigt dir den Weg zu diesem Wunsch.")
        }
        if activityID == "act.farm.memory" {
            guard boards[activeBoard]?.finished == true else { return say("Auf den Brettern warten noch Bildpaare.") }
            boards.removeValue(forKey: activeBoard)
            completedBoards += 1
            sceneTextAt[locationID] = "Alle Bildpaare auf der Holztafel sind aufgedeckt."
            return say("Du hast alle Bildpaare gefunden!")
        }

        // A paused turn keeps its original sequence even across a night or a stage change.
        guard let picks = acceptedChoices(choices, id: activityID, day: day, season: season, catalog: catalog),
              let first = picks.first, let last = picks.last else {
            return say("Der Wunsch wartet hier auf dich.")
        }
        let titles = picks.map(\.title)
        var entries: Set<String> = []
        let text: String
        switch activityID {
        case "act.nature.flowers":
            bouquet = Array(choices.dropLast())
            bouquetVase = last.id
            text = "Tildas Strauß hat \(bouquet.count) Blüten. Er steht jetzt in deinem Gefäß: \(last.title)."
            entries = ["hofbook.npc.tilda"]
        case "act.nature.pond":
            frogsCounted = Int(first.id) ?? 0
            fedFishAt = last.id
            text = "Du hast \(frogsCounted) Frösche gezählt. Die Fische schnappen nach den Flocken: \(last.title)."
            entries = ["hofbook.animal.frog"]
        case "act.nature.birdhouse":
            birdhouseSeed = first.id
            birdhouseVisitor = last.id
            text = "Du hast das Futterhäuschen gefüllt. Wer pickt jetzt die Körner auf? Ein Gast: \(last.title)!"
            if season == "season.winter" { entries = ["hofbook.season.winter.birdfeeder"] }
        case "act.nature.compost":
            wormsByBed[last.id, default: 0] += 1
            text = "Der Regenwurm gräbt jetzt Gänge im \(last.title)."
        case "act.nature.kite":
            kiteTrail = Array(choices.dropFirst(2))
            text = "Deine Drachenspur am Himmel: \(titles.dropFirst(2).joined(separator: " – "))."
        case "act.nature.snowman":
            snowman = choices
            text = "Dein Schneemann steht auf drei Kugeln. Sein Lächeln: \(last.title)!"
            if season == "season.winter" { entries = ["hofbook.season.winter.snowman"] }
        case "act.nature.lantern":
            lanternLine = choices
            text = "Am Hofweg leuchten deine \(lanternLine.count) Laternen der Reihe nach."
        case "act.village.mail":
            for recipient in choices { deliveredMail[recipient, default: 0] += 1 }
            text = "Die Post ist da! Hier steckt jetzt ein Brief: \(titles.joined(separator: ", "))."
            entries = ["hofbook.npc.lale"]
        case "act.village.helpmo":
            moToy = first.id
            moDrawing = last.id
            text = "Mo hat den Ball wieder. Auf Mos Bild ist etwas Neues zu sehen: \(last.title)!"
            entries = ["hofbook.npc.mo"]
        case "act.farm.decorate":
            arrange(decorationID: first.id, positionID: choices[1], quarterTurns: Self.directions.firstIndex { $0.id == last.id } ?? 0)
            text = "\(first.title) steht jetzt hier: \(titles[1]). Ausrichtung: \(last.title)."
        case "act.farm.photo":
            photos.append(Photo(day: day, season: season, occasionID: activityID, backdrop: last.id,
                                subjects: Array(choices.prefix(2))))
            text = "Klick! Dein Hoffoto ist fertig. Mit dabei: \(titles.prefix(2).joined(separator: ", "))."
            entries = ["hofbook.npc.pelle", "hofbook.animal.dog"]
            if choices.contains("animal.cat") { entries.formUnion(["hofbook.npc.minka", "hofbook.animal.cat"]) }
        case "act.farm.clean":
            for (object, crate) in zip(["tool.can", "ball", "item.seed.carrot"], choices) {
                contentsByCrate[crate, default: []].insert(object)
            }
            text = "Die Gießkanne liegt beim Werkzeug, der Ball bei den Spielsachen und die Tüte bei der Saat."
        case "act.farm.sing":
            song = choices
            let sounds = ["animal.dog": "Wau", "animal.cat": "Miau", "animal.chicken": "Gack"]
            text = "Auf dem Hof klingt jetzt dein Tierlied: \(song.compactMap { sounds[$0] }.joined(separator: " – "))!"
        case "act.shop.sign":
            shopSign = choices
            text = "Über der Ladentür hängt dein Schild: \(titles.joined(separator: " – "))."
        case "act.field.scarecrow":
            scarecrow = choices
            text = "Die Vogelscheuche breitet die Arme über dem Acker aus. Am Hut leuchtet dein Zeichen: \(last.title)."
        default: return say(activity.result)
        }
        sceneTextAt[locationID] = text
        let present = catalog.hofbook.filter { entries.contains($0.id) && $0.locationID == locationID }
        return say(text, book: Set(present.map(\.id)))
    }

    private func acceptedChoices(_ ids: [String], id: String, day: Int, season: String, catalog: FarmCatalog) -> [FarmChoice]? {
        // Daily patterns cycle through three starting pictures.
        for variantDay in [max(0, day) % 3, 0, 1, 2] {
            for stage in FarmStage.allCases {
                guard let plan = playSteps(id: id, stage: stage, day: variantDay, season: season, catalog: catalog),
                      plan.count == ids.count else { continue }
                let picks: [FarmChoice] = zip(plan, ids).compactMap { step, pick in
                    guard step.targetID == "*" || step.targetID == pick else { return nil }
                    return step.choices.first { $0.id == pick }
                }
                if picks.count == ids.count { return picks }
            }
        }
        return nil
    }

    func observations(locationID: String, level: Int, catalog: FarmCatalog, season: String? = nil) -> [FarmBookEntry] {
        catalog.hofbook.filter {
            ($0.id.hasPrefix("hofbook.discovery.") || $0.guestID != nil) && $0.locationID == locationID
                && $0.level <= level && (season == nil || $0.seasonID == nil || $0.seasonID == season)
        }
    }

    mutating func observe(entryID: String, locationID: String, level: Int, catalog: FarmCatalog, season: String? = nil) -> FarmResult {
        guard let entry = observations(locationID: locationID, level: level, catalog: catalog, season: season)
            .first(where: { $0.id == entryID }) else { return say("Schau mal, was du hier entdecken kannst.") }
        lastObservationAt[locationID] = entryID
        return say(entry.fact, book: [entryID])
    }

    mutating func purchase(decorationID: String, level: Int, coins: inout Int, catalog: FarmCatalog) -> FarmResult {
        guard let item = catalog.decorations.first(where: { $0.id == decorationID && $0.level <= level && $0.price >= 0 }) else {
            return say("In deiner Kiste wartet schon ein Schmuckstück auf dich.")
        }
        guard coins >= item.price else {
            if !wishlist.contains(item.id) { wishlist.append(item.id) }
            return say("\(item.title) steht auf deinem Wunschzettel. Lale behält es für dich im Blick!")
        }
        coins -= item.price
        inventory[item.id, default: 0] += 1
        wishlist.removeAll { $0 == item.id }
        return say("Lale bringt dir ein Paket: \(item.title) liegt in deiner Dekokiste!")
    }

    /// Call after earning coins. Unaffordable wishes stay on the list; no money is reserved.
    mutating func deliverWishlist(level: Int, coins: inout Int, catalog: FarmCatalog) -> FarmResult {
        var delivered: [String] = []
        for id in wishlist {
            guard let item = catalog.decorations.first(where: {
                $0.id == id && $0.level <= level && $0.price >= 0 && $0.price <= coins
            }) else { continue }
            _ = purchase(decorationID: id, level: level, coins: &coins, catalog: catalog)
            delivered.append(item.title)
        }
        return say(delivered.isEmpty ? "" : "Post von Lale! In der Dekokiste liegt jetzt: \(delivered.joined(separator: ", ")).")
    }

    /// An occupied tile's piece goes back into the box. With an empty box, move an already placed copy.
    @discardableResult
    mutating func place(decorationID: String, positionID: String) -> FarmResult {
        guard let position = Self.positions.first(where: { $0.id == positionID }),
              inventory[decorationID, default: 0] > 0 || placements.values.contains(where: { $0.decorationID == decorationID }) else {
            return say("Such dir ein Stück aus deiner Kiste und einen Platz auf dem Hof aus.")
        }
        arrange(decorationID: decorationID, positionID: positionID, quarterTurns: 0)
        let text = "Dein Schmuckstück steht hier: \(position.title)."
        sceneTextAt["loc.plaza"] = text
        return say(text)
    }

    private mutating func arrange(decorationID: String, positionID: String, quarterTurns: Int) {
        if placements[positionID]?.decorationID != decorationID {
            if let count = inventory[decorationID], count > 0 {
                if count == 1 { inventory.removeValue(forKey: decorationID) } else { inventory[decorationID] = count - 1 }
            } else if let source = placements.keys.sorted().first(where: { placements[$0]?.decorationID == decorationID }) {
                placements.removeValue(forKey: source)
            } else { return }
            if let other = placements[positionID] { inventory[other.decorationID, default: 0] += 1 }
        }
        placements[positionID] = Placement(decorationID: decorationID, quarterTurns: quarterTurns)
    }

    @discardableResult
    mutating func rotate(positionID: String) -> FarmResult {
        guard var piece = placements[positionID] else { return say("Hier ist noch Platz für deine Deko.") }
        piece.quarterTurns = (piece.quarterTurns % 4 + 5) % 4
        placements[positionID] = piece
        let text = "Eine Vierteldrehung! \(Self.directions[piece.quarterTurns].title)."
        sceneTextAt["loc.plaza"] = text
        return say(text)
    }

    @discardableResult
    mutating func remove(positionID: String) -> FarmResult {
        guard let piece = placements.removeValue(forKey: positionID) else { return say("Dieser Platz ist frei.") }
        inventory[piece.decorationID, default: 0] += 1
        let text = "Dein Schmuckstück liegt wieder in der Dekokiste."
        sceneTextAt["loc.plaza"] = text
        return say(text)
    }
}

extension FarmLife {
    // Supply the turn key again on resume: a free-play board and a requested board can coexist.
    mutating func startMemory(stage: FarmStage, key: String = "memory", keepRevealed: Bool = false, day: Int = 1) {
        activeBoard = key
        if boards[key] == nil {
            let seed = "\(key)/\(day)/\(completedBoards)".utf8.reduce(UInt64(0xcbf29ce484222325)) {
                ($0 ^ UInt64($1)) &* 0x100000001b3
            }
            boards[key] = MemoryBoard(stage: stage, keepRevealed: keepRevealed, seed: seed)
        }
    }

    var memoryStep: FarmStep? { boards[activeBoard]?.step }

    @discardableResult
    mutating func turnMemory(cardID: String) -> FarmMemoryTurn {
        boards[activeBoard]?.flip(cardID) ?? .ignored
    }

    /// For an explicitly requested "together" turn, never as a target in the ordinary prompt.
    func suggestedMemoryCardID() -> String? { boards[activeBoard]?.suggestion }

    private struct MemoryBoard: Codable, Sendable {
        static let faces = [
            picture("cat", "Katze", "cat"), picture("dog", "Hund", "dog"), picture("hen", "Huhn", "bird"),
            picture("carrot", "Möhre", "carrot"), picture("leaf", "Blatt", "leaf"), picture("fish", "Fisch", "fish"),
            picture("sun", "Sonne", "sun.max"), picture("moon", "Mond", "moon")
        ]

        let deck: [String]
        let keepRevealed: Bool
        var matched: Set<Int> = []
        var seen: Set<Int> = []
        var up: [Int] = []
        var finished: Bool { !deck.isEmpty && matched.count == deck.count }

        init(stage: FarmStage, keepRevealed: Bool, seed: UInt64) {
            let pairCount = stage == .sprout ? 3 : stage == .shoot ? 5 : 8
            let faces = Self.faces.prefix(pairCount).map(\.id)
            var cards = faces + faces, state = seed
            // Fisher–Yates with SplitMix64, independent of Swift's per-process hash seed.
            for i in stride(from: cards.count - 1, through: 1, by: -1) {
                state &+= 0x9e3779b97f4a7c15
                var z = state
                z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
                z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
                cards.swapAt(i, Int((z ^ (z >> 31)) % UInt64(i + 1)))
            }
            deck = cards
            self.keepRevealed = keepRevealed || stage == .sprout
        }

        var step: FarmStep {
            let cards: [FarmChoice] = deck.indices.map { i in
                let number = i + 1
                if (matched.contains(i) || up.contains(i) || keepRevealed && seen.contains(i)),
                   let face = Self.faces.first(where: { $0.id == deck[i] }) {
                    let state = matched.contains(i) ? ", Paar gefunden" : ""
                    return picture("card.\(number)", "Brett \(number): \(face.title)\(state)", face.symbol)
                }
                return picture("card.\(number)", "Verdecktes Brett \(number)", "square.dashed")
            }
            let text: String
            if finished { text = "Alle Paare liegen offen!" }
            else if up.count == 2 { text = "Zwei verschiedene Bilder! Schau sie dir an. Dann wähle wieder ein Brett." }
            else if let i = up.first, cards.indices.contains(i) {
                text = "\(cards[i].title). Wo versteckt sich dasselbe Bild?"
            } else { text = "Auf welchen Bildern ist das Gleiche zu sehen? Wähle ein Brett." }
            return action("wooden.board", text, "*", cards)
        }

        mutating func flip(_ id: String) -> FarmMemoryTurn {
            guard let i = deck.indices.first(where: { id == "card.\($0 + 1)" }), !matched.contains(i) else { return .ignored }
            if up.count == 2 { up.removeAll() }
            guard !up.contains(i) else { return .ignored }
            seen.insert(i)
            if let first = up.first, deck.indices.contains(first) {
                if deck[first] == deck[i] {
                    matched.formUnion([first, i])
                    up.removeAll()
                    return finished ? .finished : .pair
                }
                up.append(i)
                return .mismatch
            }
            up = [i]
            return .first
        }

        var suggestion: String? {
            let next: Int?
            if up.count == 1, let first = up.first, deck.indices.contains(first) {
                next = deck.indices.first { $0 != first && !matched.contains($0) && deck[$0] == deck[first] }
            } else {
                next = deck.indices.first { !matched.contains($0) }
            }
            return next.map { "card.\($0 + 1)" }
        }
    }
}

extension FarmLife {
    private struct Festival {
        let steps: [FarmStep]
        let display: [String]
        let guests: [String]
        let backdrop: String
        let caption: String
    }

    private func festival(_ season: String) -> Festival? {
        let camera = action("group.photo", "Alle sind zusammen. Drück auf den Auslöser für euer Festfoto!", "photo", [
            picture("photo", "Festfoto machen", "camera")
        ])
        let guests = ["animal.dog", "animal.cat", "animal.chicken"]
        switch season {
        case "season.spring":
            let flowers = [picture("daisy", "Weißes Gänseblümchen", "camera.macro"),
                           picture("buttercup", "Gelbe Butterblume", "sun.max")]
            let chain = ["daisy", "buttercup", "daisy", "buttercup"]
            let steps = chain.enumerated().map { i, flower in
                action("chain.\(i)", "Weiß, gelb, weiß, gelb: Fädle Blüte \(i + 1) auf Pelles Kette.", flower, flowers)
            } + [action("garland", "Wem legen wir die Blütenkette zum Tanz um?", "animal.dog", [
                picture("animal.cat", "Minka", "cat"), picture("animal.dog", "Pelle", "dog")
            ]), camera]
            return Festival(steps: steps, display: chain, guests: guests, backdrop: "tree",
                            caption: "Pelle trägt die selbst gefädelte Blütenkette zum Tanz am Hofbaum.")
        case "season.summer":
            return Festival(steps: [
                action("wafer", "Der Eisstand öffnet! Stell eine Waffel unter den Löffel.", "cone", [
                    picture("cone", "Eiswaffel", "triangle"), picture("box", "Obstkiste", "shippingbox")
                ]),
                action("scoop", "Tilda wünscht sich eine rote Kugel. Welches Eis schöpfst du?", "berry", [
                    picture("lemon", "Zitroneneis", "sun.max"), picture("berry", "Erdbeereis", "heart")
                ]),
                action("dance", "Tilda hat ihr Eis. Ruf die Hofbande zum Sommertanz!", "dance", [
                    picture("dance", "Alle tanzen zusammen", "music.note.list")
                ]), camera
            ], display: ["cone", "berry", "ice.stand"], guests: guests + ["npc.tilda"], backdrop: "ice.stand",
                            caption: "Tildas Erdbeereis ist fertig. Neben dem Eisstand tanzt die ganze Hofbande.")
        case "season.autumn":
            let food = [picture("item.feed", "Eine Handvoll Körner", "circle.grid.3x3"),
                        picture("dog.biscuit", "Ein Hundekeks", "pawprint")]
            return Festival(steps: [
                action("hen.plate", "Die Henne pickt am Festtisch. Was legst du auf ihren Teller?", "item.feed", food),
                action("dog.plate", "Jetzt ist Pelles Teller dran. Was mag er?", "dog.biscuit", food),
                action("thanks", "Ein Licht für Pelle, eins für Minka, eins für die Henne. Wie viele Lichter leuchten?", "3", [
                    picture("2", "Zwei", "2.circle"), picture("3", "Drei", "3.circle")
                ]), camera
            ], display: ["hen.plate", "dog.plate", "three.lights"], guests: guests, backdrop: "feast.table",
                            caption: "Am gedeckten Tisch strahlen drei Danke-Lichter für die Hofbande.")
        case "season.winter":
            let lamps = [picture("star", "Sternlaterne", "star"), picture("moon", "Mondlaterne", "moon")]
            let row = ["star", "moon", "star", "moon"]
            let steps = row.enumerated().map { i, lamp in
                action("glow.\(i)", "Stern, Mond, Stern, Mond. Welche Laterne hängt an Haken \(i + 1)?", lamp, lamps)
            } + [action("snuggle", "Die Tiere kuscheln sich zusammen. Was breiten wir für alle aus?", "blanket", [
                picture("blanket", "Warme Wolldecke", "square.grid.3x3"), picture("bucket", "Holzeimer", "drop")
            ]), camera]
            return Festival(steps: steps, display: row + ["blanket"], guests: guests, backdrop: "lantern.path",
                            caption: "Über der Kuscheldecke leuchten Stern- und Mondlaternen im Wechsel.")
        default: return nil
        }
    }

    func festivalSteps(season: String) -> [FarmStep] { festival(season)?.steps ?? [] }

    /// The engine offers the invitation on festival day. It may also be finished later.
    mutating func celebrate(season: String, day: Int, catalog: FarmCatalog) -> FarmResult {
        guard let design = festival(season), let entry = catalog.seasons.first(where: { $0.id == season }) else {
            return say("Am Hofbaum ist immer Platz für ein gemeinsames Spiel.")
        }
        festivalDisplays[entry.festivalID] = design.display
        if !photos.contains(where: { $0.day == day && $0.occasionID == entry.festivalID }) {
            photos.append(Photo(day: day, season: season, occasionID: entry.festivalID, backdrop: design.backdrop,
                               subjects: design.guests))
        }
        let text = "\(design.caption) Das Festfoto vom \(entry.festivalTitle) kommt ins Hofbuch!"
        sceneTextAt["loc.plaza"] = text
        let bookID = "hofbook.\(entry.festivalID)"
        return say(text, book: catalog.hofbook.contains { $0.id == bookID } ? [bookID] : [])
    }
}
