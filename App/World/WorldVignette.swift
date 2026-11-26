import Foundation

/// Art direction for a *visible* activity. Ordering and validity of steps come
/// exclusively from the current prompt; these props never change farm state.
struct WorldVignette {
    let picture: String
    let label: String
    let props: [String]
    let destination: String
    let effect: String

    init(_ picture: String, _ label: String, _ props: [String], _ destination: String, _ effect: String) {
        self.picture = picture
        self.label = label
        self.props = props
        self.destination = destination
        self.effect = effect
    }

    func prop(step: Int) -> String { props[min(max(0, step), props.count - 1)] }

    static let all: [String: Self] = [
        "act.field.plow": .init("🚜", "Furchen ziehen", ["veh.tractor", "imp.plow", "veh.tractor"], "bed", "soil"),
        "act.field.sow": .init("🌱", "Samen ins Beet legen", ["item.seed.radish", "bed"], "bed", "seed"),
        "act.field.water": .init("💧", "Das Beet gießen", ["tool.can", "bed"], "bed", "water"),
        "act.field.harvest": .init("🥕", "Gemüse pflücken", ["crop.radish.ripe", "tool.basket"], "tool.basket", "crop"),
        "act.field.combine": .init("🌾", "Korn ernten", ["veh.combine", "imp.trailer"], "imp.trailer", "soil"),
        "act.field.hay": .init("🌾", "Heu einbringen", ["imp.mower", "item.hay", "imp.baler", "imp.loader"], "imp.trailer", "soil"),
        "act.field.scarecrow": .init("👒", "Vogelscheuche anziehen", ["post", "hat", "scarecrow"], "scarecrow", "gift"),
        "act.field.snowplow": .init("❄️", "Den Weg freischieben", ["imp.snowplow", "veh.tractor"], "lane", "soil"),
        "act.animal.feed": .init("🌽", "Futter zum Tier bringen", ["item.feed", "trough"], "trough", "feed"),
        "act.animal.water": .init("🪣", "Die Tränke füllen", ["tool.bucket", "trough"], "trough", "water"),
        "act.animal.pet": .init("🖐️", "Das Tier streicheln", ["friend", "tool.brush"], "friend", "care"),
        "act.animal.milk": .init("🥛", "Milch in den Eimer melken", ["tool.bucket", "friend", "item.milk"], "tool.bucket", "milk"),
        "act.animal.eggs": .init("🥚", "Das Ei ins Nest legen", ["item.egg", "tool.basket"], "tool.basket", "egg"),
        "act.animal.shear": .init("✂️", "Weiche Wolle sammeln", ["tool.shears", "item.wool"], "tool.basket", "wool"),
        "act.animal.bed": .init("🌙", "Das Tier zudecken", ["friend", "item.hay", "quilt"], "nest", "care"),
        "act.animal.find": .init("🐾", "Das Tier finden", ["friend", "friend"], "friend", "care"),
        "act.animal.baby": .init("🍼", "Das Tierkind versorgen", ["quilt", "item.milk", "friend"], "nest", "care"),
        "act.shop.stock": .init("🧺", "Das Regal einräumen", ["item.carrot", "crate"], "crate", "crop"),
        "act.shop.order": .init("🛎️", "Den Einkaufskorb packen", ["item.egg", "tool.basket", "bell"], "tool.basket", "egg"),
        "act.shop.sign": .init("🎨", "Das Ladenschild schmücken", ["flower", "sign"], "sign", "gift"),
        "act.shop.market": .init("🏘️", "Zum Markt fahren", ["imp.trailer", "veh.tractor", "crate", "tool.basket"], "crate", "gift"),
        "act.kitchen.bake": .init("🍞", "Brot backen", ["item.flour", "bowl", "oven", "item.bread"], "oven", "flour"),
        "act.kitchen.press": .init("🍎", "Äpfel pressen", ["item.apple", "press", "item.applejuice"], "press", "crop"),
        "act.kitchen.churn": .init("🧈", "Butter rühren", ["item.milk", "churn", "item.butter"], "churn", "milk"),
        "act.kitchen.jam": .init("🍓", "Marmelade kochen", ["item.strawberry", "bowl", "item.jam"], "bowl", "crop"),
        "act.nature.flowers": .init("🌷", "Blumen pflücken", ["flower", "tool.basket"], "tool.basket", "flower"),
        "act.nature.pond": .init("🐸", "Den Teich entdecken", ["animal.frog", "item.feed"], "pond", "water"),
        "act.nature.birdhouse": .init("🐦", "Das Vogelhaus füllen", ["item.feed", "birdhouse"], "birdhouse", "feed"),
        "act.nature.compost": .init("🪱", "Den Wurm ins Beet bringen", ["worm", "bed"], "bed", "soil"),
        "act.nature.kite": .init("🪁", "Den Drachen steigen lassen", ["kite", "spool"], "kite", "kite"),
        "act.nature.snowman": .init("⛄️", "Einen Schneemann bauen", ["snowball", "snowman", "item.carrot"], "snowman", "snow"),
        "act.nature.lantern": .init("🏮", "Laternen aufstellen", ["lantern", "lantern"], "post", "light"),
        "act.village.mail": .init("✉️", "Den Brief einwerfen", ["mail", "mailbox"], "mailbox", "mail"),
        "act.village.helpmo": .init("🧸", "Mo das Spielzeug bringen", ["ball", "npc.mo"], "npc.mo", "gift"),
        "act.farm.decorate": .init("🌼", "Den Hof schmücken", ["flower", "deco.bench"], "sign", "flower"),
        "act.farm.photo": .init("📷", "Freunde fürs Bild versammeln", ["friend", "camera"], "camera", "care"),
        "act.farm.clean": .init("🧹", "Das Spielzeug aufräumen", ["ball", "crate"], "crate", "gift"),
        "act.farm.memory": .init("🖼️", "Bildpaare aufdecken", ["tile", "tile"], "tile", "gift"),
        "act.farm.sing": .init("🎵", "Mit Pelle musizieren", ["bell", "friend"], "bell", "music"),
    ]
}

extension WorldTurn {
    var vignette: WorldVignette? { WorldVignette.all[offering.activityID] }

    func physicalModel(_ choice: WorldChoice?) -> String {
        let fallback = vignette?.prop(step: stepIndex) ?? "tile"
        guard let id = choice?.modelID, !id.isEmpty else { return fallback }
        let key = id.hasPrefix("model.") ? String(id.dropFirst(6)) : id
        if key.hasPrefix("plot.") { return "bed" }
        if key.hasPrefix("animal."), let kind = key.split(separator: ".").dropFirst().first { return "animal." + kind }
        if key.hasPrefix("card.") || key.hasPrefix("page.") { return "tile" }
        if key.hasPrefix("station.") {
            return ["station.oven":"oven", "station.press":"press", "station.churn":"churn",
                    "station.kettle":"bowl", "station.mill":"item.flour"][key] ?? vignette?.destination ?? fallback
        }
        if key == "shop.bell" { return "bell" }
        if key.hasPrefix("loc.") { return vignette?.destination ?? "sign" }
        if key.hasPrefix("tool.") || key.hasPrefix("item.") || key.hasPrefix("crop.") ||
            key.hasPrefix("veh.") || key.hasPrefix("imp.") || key.hasPrefix("npc.") { return key }
        return fallback
    }
}
