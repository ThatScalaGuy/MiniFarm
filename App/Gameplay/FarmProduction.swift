import Foundation

struct FarmResult: Sendable {
    let text: String
    let book: Set<String>
    var accepted = true
}

struct FarmPlot: Codable, Sendable, Identifiable {
    let id: String
    let locationID: String
    let title: String
    fileprivate let row: Int
    var cropID: String?
    var isPlowed = false
    var watered = false
    var nightsLeft = 0
    fileprivate var grownNights = 0
    fileprivate var pickedYear: Int?
    fileprivate var harvestSeason: String?
    fileprivate var planting = 0
    var isRipe: Bool { cropID != nil && nightsLeft == 0 && harvestSeason == nil }
    var phase: String {
        guard cropID != nil else { return isPlowed ? "plowed" : "empty" }
        if isRipe { return "ripe" }
        if cropID == "crop.radish", grownNights == 0, watered { return "sprouting" }
        if grownNights == 0 { return "seeded" }
        return grownNights == 1 ? "sprouting" : "growing"
    }
}

struct FarmAnimalInstance: Codable, Sendable, Identifiable {
    let id: String
    let speciesID: String
    let name: String
    let locationID: String
    fileprivate var bornOn: Int?
    fileprivate var actions: [String: Int] = [:]
    var lastFedDay: Int? { actions["feed"] }
    var isBaby: Bool { bornOn != nil }
    var nickname: String?
}

private struct Parcels: Codable, Sendable, Equatable {
    let ids: [String]
    let plantings: [Int]
    let label: String
    let crop: String?
    let gear: [String]
}

private struct Visit: Codable, Sendable, Equatable {
    let animal: String
    let species: String
    let name: String
    let kind: String
    let item: String?
    var fromInventory = false
}

private enum FarmJob: Codable, Sendable, Equatable {
    case land(Parcels)
    case visit(Visit)
    case goods([String: Int], vehicle: String?)
    case recipe(String)
    case outdoor([String])
}

private struct BasketSize {
    let types, perType, pieces: Int

    init(stage: FarmStage, market: Bool) {
        switch stage {
        case .sprout: (types, perType, pieces) = (1, market ? 1 : 2, market ? 1 : 2)
        case .shoot: (types, perType, pieces) = (2, market ? 1 : 3, market ? 2 : 5)
        case .bloom: (types, perType, pieces) = (3, market ? 1 : 5, market ? 3 : 10)
        }
    }

    func order(startingAt index: Int, wares: [FarmItem], available: (String) -> Int,
               target: Int, ceiling: Int) -> [String: Int] {
        guard wares[index].value <= ceiling else { return [:] }
        var goods = [wares[index].id: 1], value = wares[index].value, count = 1
        var selected = [wares[index]]
        for offset in 1..<wares.count {
            guard selected.count < types else { break }
            let next = wares[(index + offset) % wares.count]
            let sum = value + next.value
            // Prefer a mixed basket at the higher tiers, then aim for its normal payout.
            if sum <= ceiling, (types >= 3 && count == 1 || abs(target - sum) <= abs(target - value)) {
                selected.append(next)
                goods[next.id] = 1
                value = sum
                count += 1
            }
        }
        while count < pieces && value < target {
            let next = selected.filter { item in
                let held = goods[item.id, default: 0]
                return held < perType && held < available(item.id) && value + item.value <= ceiling
                    && abs(target - value - item.value) < target - value
            }.min { abs(target - value - $0.value) < abs(target - value - $1.value) }
            guard let next else { break }
            goods[next.id, default: 0] += 1
            value += next.value
            count += 1
        }
        return goods
    }
}

struct FarmVariant: Codable, Sendable, Equatable {
    let subjectID: String
    let title: String
    let symbol: String
    let featuredItemID: String?
    let locationID: String
    fileprivate let activityID: String
    fileprivate let job: FarmJob
    fileprivate let revision: Int

    var workGear: [String] {
        switch job {
        case .land(let patch): patch.gear
        case .outdoor(let gear): gear
        default: []
        }
    }

    var workBeds: [String] {
        if case .land(let patch) = job { patch.ids } else { [] }
    }
}

struct FarmProduction: Codable, Sendable {
    var inventory: [String: Int] = [:]
    var shelf: [String: Int] = [:]
    var animals: [FarmAnimalInstance] = []
    var plots: [FarmPlot] = []
    var coins = 0
    private(set) var nurseryNames: [String: String]?
    private var lastNight: Int?
    private var preparedDay: Int?
    private var rainyDay: Int?
    private var workedDay: [String: Int] = [:]
    // Keep the visible subject stable for wishes, but never redeem a completed selection twice.
    private var revisions: [String: Int] = [:]

    init() {}

    mutating func prepare(day: Int, level: Int, stage: FarmStage, season: String, catalog: FarmCatalog) {
        preparedDay = day
        rainyDay = nil
        let capacities = [
            ("loc.garden", 1, level < 3 ? 6 : level < 5 ? 12 : 18, 1),
            ("loc.field", 2, level < 4 ? 4 : level < 5 ? 8 : 12, level < 4 ? 4 : level < 5 ? 6 : 8),
            ("loc.orchard", 3, level < 5 ? 4 : 8, 1),
            ("loc.greenhouse", 4, 6, 1)
        ]
        var plotIDs = Set(plots.map(\.id))
        for (location, minimum, width, height) in capacities where level >= minimum {
            for y in 0..<height {
                for x in 0..<width {
                    let id = "plot.\(location.shortID).\(y + 1).\(x + 1)"
                    guard plotIDs.insert(id).inserted else { continue }
                    let title = location == "loc.field" ? "Furche \(y + 1), Platz \(x + 1)"
                        : location == "loc.orchard" ? "Baum \(x + 1)" : "Beet \(x + 1)"
                    plots.append(FarmPlot(id: id, locationID: location, title: title, row: y))
                }
            }
        }
        if let apple = catalog.crops.first(where: { $0.id == "crop.apple" }), level >= apple.level {
            for i in plots.indices where plots[i].locationID == "loc.orchard" {
                plots[i].cropID = apple.id
                plots[i].nightsLeft = plots[i].pickedYear != Self.year(day)
                    && season == apple.harvestSeasonID ? 0 : 1
            }
        }
        for i in plots.indices where plots[i].nightsLeft == 0 && plots[i].harvestSeason == season {
            plots[i].harvestSeason = nil
        }
        for i in animals.indices {
            if let birth = animals[i].bornOn, day - birth >= 16 { animals[i].bornOn = nil }
        }
        for species in catalog.animals where species.level <= level {
            let extra = species.maxCount - species.initialCount
            let family = level >= 3 && season == "season.spring" && species.babyTitle != nil ? min(1, extra) : 0
            let target = level >= 5 ? species.maxCount : species.initialCount
                + max(family, extra * (level - species.level) / max(1, 5 - species.level))
            let count = animals.filter { $0.speciesID == species.id }.count
            guard count < target else { continue }
            for index in count..<target {
                let baby = index >= species.initialCount && species.babyTitle != nil
                if baby && season != "season.spring" { break }
                let name = species.names.indices.contains(index) ? species.names[index] : "\(species.title) \(index + 1)"
                animals.append(FarmAnimalInstance(id: "\(species.id).\(index + 1)", speciesID: species.id,
                                                  name: name, locationID: species.locationID, bornOn: baby ? day : nil))
            }
        }
    }

    mutating func rain() {
        rainyDay = preparedDay
        for i in plots.indices where plots[i].locationID != "loc.greenhouse" && plots[i].locationID != "loc.orchard"
            && plots[i].cropID != nil && plots[i].nightsLeft > 0 {
            plots[i].watered = true
        }
    }

    mutating func night(day: Int, stage: FarmStage, season: String, catalog: FarmCatalog) {
        guard lastNight.map({ $0 < day }) ?? true else { return }
        lastNight = day
        for i in plots.indices where plots[i].watered && plots[i].nightsLeft > 0 {
            guard plots[i].locationID != "loc.orchard",
                  plots[i].locationID == "loc.greenhouse" || season != "season.winter" else { continue }
            if stage == .sprout { plots[i].nightsLeft = min(plots[i].nightsLeft, max(1, 2 - plots[i].grownNights)) }
            plots[i].nightsLeft -= 1
            plots[i].grownNights += 1
            plots[i].watered = false
            if plots[i].nightsLeft == 0 && plots[i].harvestSeason == season { plots[i].harvestSeason = nil }
        }
    }

    func caredAnimalIDs(on day: Int) -> Set<String> {
        Set(animals.filter { animal in
            ["feed", "pet", "water", "bed", "baby"].contains { animal.actions[$0] == day }
        }.map(\.id))
    }

    func variants(activityID: String, locationID: String, day: Int, level: Int, stage: FarmStage,
                  season: String, catalog: FarmCatalog) -> [FarmVariant]? {
        let location = locationID
        let action = activityID.shortID
        let recipes = catalog.recipes.filter { $0.activityID == activityID && $0.locationID == location }
        let isPigCompost = activityID == "act.nature.compost" && location == "loc.pigsty"
        let handled = !recipes.isEmpty || isPigCompost || activityID.hasPrefix("act.kitchen.")
            || activityID.hasPrefix("act.animal.")
            || (activityID.hasPrefix("act.field.") && action != "scarecrow")
            || ["act.shop.stock", "act.shop.order", "act.shop.market"].contains(activityID)
        guard handled else { return nil }
        guard let place = catalog.locations.first(where: { $0.id == location }), place.level <= level,
              let activity = catalog.activities.first(where: { $0.id == activityID }), activity.level <= level else { return [] }

        let items = Dictionary(uniqueKeysWithValues: catalog.items.filter { $0.level <= level }.map { ($0.id, $0) })
        let machines = Set(catalog.machines.filter { $0.level <= level }.map(\.id))
        func equipped(_ gear: [String]) -> Bool {
            gear.allSatisfy { $0.hasPrefix("tool.") || machines.contains($0) }
        }
        func offer(_ subject: String, _ title: String, _ symbol: String, _ featured: String?, _ job: FarmJob) -> FarmVariant {
            FarmVariant(subjectID: subject, title: title, symbol: symbol, featuredItemID: featured, locationID: location,
                        activityID: activityID, job: job, revision: revisions["\(activityID):\(subject)", default: 0])
        }
        if !recipes.isEmpty || activityID.hasPrefix("act.kitchen.") {
            return recipes.compactMap { recipe in
                guard recipe.level <= level, recipe.seasonID == nil || recipe.seasonID == season,
                      let output = items[recipe.output], !recipe.ingredients.isEmpty,
                      recipe.ingredients.allSatisfy({ items[$0.key] != nil && $0.value > 0 && inventory[$0.key, default: 0] >= $0.value })
                else { return nil }
                return offer(recipe.id, recipe.title, output.symbol, output.id, .recipe(recipe.id))
            }
        }

        if activityID.hasPrefix("act.field.") {
            if action == "hay" || action == "snowplow" {
                let hay = action == "hay"
                guard workedDay[activityID] != day,
                      hay ? (location == "loc.sheepmeadow" && season != "season.winter" && items["item.hay"] != nil)
                          : (location == "loc.plaza" && season == "season.winter") else { return [] }
                let gear = hay ? ["veh.tractor", "imp.mower", "imp.baler", "imp.loader"]
                               : ["veh.tractor", "imp.snowplow"]
                guard equipped(gear) else { return [] }
                return [offer(location, hay ? "Heuballen auf der Schafweide" : "Weg am Hofplatz",
                              place.symbol, hay ? "item.hay" : nil, .outdoor(gear))]
            }
            guard season != "season.winter" || location == "loc.greenhouse" else { return [] }
            let field = location == "loc.field"
            let orchard = location == "loc.orchard"
            let local = plots.filter { $0.locationID == location }
            var result: [FarmVariant] = []
            func add(_ candidates: [FarmPlot], crop: FarmCrop?, gear: [String]) {
                guard !candidates.isEmpty, equipped(gear) else { return }
                let batches: [[FarmPlot]]
                if field {
                    let rows = Dictionary(grouping: candidates, by: \.row)
                    batches = rows.keys.sorted().compactMap { rows[$0] }
                } else { batches = candidates.map { [$0] } }
                for batch in batches {
                    let first = batch[0]
                    let patch = field ? "Furche \(first.row + 1)" : first.title
                    let subject = field ? "row.\(location.shortID).\(first.row + 1)" : first.id
                    let title = crop.map { "\($0.title) · \(patch)" } ?? patch
                    result.append(offer([subject, crop?.id].compactMap { $0 }.joined(separator: ":"),
                                        title, crop.flatMap { items[$0.itemID]?.symbol } ?? place.symbol, crop?.itemID,
                                        .land(Parcels(ids: batch.map(\.id), plantings: batch.map(\.planting),
                                                      label: patch, crop: crop?.id, gear: gear))))
                }
            }
            if action == "plow" {
                if field { add(local.filter { $0.cropID == nil && !$0.isPlowed }, crop: nil, gear: ["veh.tractor", "imp.plow"]) }
                else if ["loc.garden", "loc.greenhouse"].contains(location), stage != .sprout {
                    add(local.filter { $0.cropID == nil && !$0.isPlowed }, crop: nil, gear: ["tool.hoe"])
                }
            } else {
                for crop in catalog.crops where crop.level <= level && crop.locations.contains(location) && items[crop.itemID] != nil {
                    switch action {
                    case "sow" where !orchard && crop.nights > 0:
                        guard (crop.seasonsByLocation?[location] ?? crop.seasons).contains(season) else { continue }
                        add(local.filter { $0.cropID == nil && (!field || $0.isPlowed) }, crop: crop,
                            gear: field ? ["veh.tractor", "imp.seeder"] : ["tool.hand"])
                    case "water" where !orchard:
                        add(local.filter { $0.cropID == crop.id && $0.nightsLeft > 0 && !$0.watered }, crop: crop,
                            gear: field && machines.contains("imp.watertank") ? ["veh.tractor", "imp.watertank"] : ["tool.can"])
                    case "harvest", "combine":
                        let grain = ["crop.wheat", "crop.corn"].contains(crop.id)
                        if action == "combine" && !(field && grain) { continue }
                        if action == "harvest" && field && crop.id == "crop.wheat" { continue }
                        if orchard && season != crop.harvestSeasonID { continue }
                        let gear: [String]
                        if action == "combine" { gear = ["veh.combine", "imp.trailer"] }
                        else if field && crop.id == "crop.potato" && machines.contains("imp.potatodigger") {
                            gear = ["veh.tractor", "imp.potatodigger", "imp.trailer"]
                        } else if field && crop.id == "crop.pumpkin" && machines.contains("imp.loader") {
                            gear = ["veh.tractor", "imp.loader", "imp.trailer"]
                        } else { gear = orchard ? ["tool.ladder", "tool.basket"] : ["tool.basket"] }
                        add(local.filter { $0.cropID == crop.id && $0.isRipe }, crop: crop, gear: gear)
                    default: continue
                    }
                }
            }
            // The first booklet page shows several seeds, not four identical radish packets.
            if action == "sow" {
                let byPlot = Dictionary(grouping: result) { $0.subjectID.components(separatedBy: ":")[0] }
                return byPlot.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.flatMap { byPlot[$0] ?? [] }
            }
            return result
        }

        if activityID.hasPrefix("act.animal.") || isPigCompost {
            var result: [FarmVariant] = []
            for animal in animals where animal.locationID == location {
                guard let species = catalog.animals.first(where: { $0.id == animal.speciesID }), species.level <= level else { continue }
                let bee = species.id == "animal.bee"
                let display = animal.nickname ?? animal.name
                let name = animal.isBaby ? "\(display) (\(species.babyTitle ?? species.title))" : display
                func add(_ kind: String, _ itemID: String? = nil, fromInventory: Bool = false) {
                    let item = itemID.flatMap { items[$0] }
                    let dailyProduct = ["milk", "eggs", "shear", "compost", "collect"].contains(kind)
                    guard itemID == nil || item != nil, !dailyProduct || animal.actions[kind] != day else { return }
                    let suffix = item.map { " · \($0.title)" } ?? ""
                    result.append(offer([animal.id, itemID].compactMap { $0 }.joined(separator: ":"), name + suffix,
                                        item?.symbol ?? place.symbol, itemID, .visit(Visit(animal: animal.id, species: species.id,
                                            name: name, kind: kind, item: itemID, fromInventory: fromInventory))))
                }
                switch action {
                case "feed" where !bee:
                    for food in species.foods where items[food] != nil {
                        let pantry = ["item.feed", "item.hay"].contains(food)
                        if pantry || inventory[food, default: 0] > 0 { add("feed", food, fromInventory: !pantry) }
                    }
                    if species.foods.allSatisfy({ !["item.feed", "item.hay"].contains($0) && inventory[$0, default: 0] == 0 }) {
                        add("feed") // The feed bin always has a suitable basic ration; it is not saleable stock.
                    }
                case "milk", "eggs", "shear", "compost":
                    guard !animal.isBaby, action != "shear" || season == "season.summer" else { continue }
                    let accepted = ["milk": ["item.milk", "item.goatmilk"], "eggs": ["item.egg", "item.duckegg"],
                                    "shear": ["item.wool"], "compost": ["item.compost"]]
                    for id in species.products where accepted[action, default: []].contains(id) { add(action, id) }
                case "find":
                    if !animal.isBaby, let product = species.products.first(where: { ["item.feather", "item.honeycomb"].contains($0) }) {
                        add("collect", product)
                    } else { add("find") }
                case "baby" where animal.isBaby: add("baby")
                case "baby" where season == "season.spring":
                    // A spring visitor keeps the nursery playable after all resident young have grown up.
                    if let young = species.babyTitle, !animals.contains(where: { $0.speciesID == species.id && $0.isBaby }),
                       animal.id == "\(species.id).1", animal.actions["nursery"] != day {
                        let guestID = "\(species.id).guest.\(Self.year(day))"
                        let label = nurseryNames?[guestID] ?? "\(young) zu Besuch"
                        result.append(offer(guestID, label, place.symbol, nil, .visit(Visit(animal: animal.id,
                            species: species.id, name: label, kind: "nursery", item: nil))))
                    }
                case "pet", "water", "bed": if !bee { add(action) }
                default: continue
                }
            }
            return result
        }

        let market = action == "market"
        guard market ? ["loc.village", "loc.paddock"].contains(location) : location == "loc.shop" else { return [] }
        let vehicle = market ? (location == "loc.paddock" ? "veh.carriage" : "veh.tractor") : nil
        if market {
            guard location == "loc.paddock" ? animals.contains(where: { $0.speciesID == "animal.horse" && !$0.isBaby })
                    : equipped(["veh.tractor", "imp.trailer"]) else { return [] }
        }
        let stock = action == "stock"
        let economy = catalog.economy
        let limit = economy.shelfSlots[level < 3 ? 0 : 1]
        let shelfSlots = shelf.values.filter { $0 > 0 }.count
        let sellable = items.values.filter { $0.value > 0 && !$0.id.hasPrefix("item.seed.") }.sorted { $0.id < $1.id }
        func available(_ id: String) -> Int {
            inventory[id, default: 0] + (!market && !stock ? shelf[id, default: 0] : 0)
        }
        let ready = sellable.filter { available($0.id) > 0 }
        var offers: [FarmVariant] = []
        if action == "order", let radish = ready.first(where: { $0.id == "item.radish" }),
           revisions["\(activityID):order.firstRadish"] == nil {
            offers.append(offer("order.firstRadish", "1 × \(radish.title)", radish.symbol, radish.id,
                                .goods([radish.id: 1], vehicle: nil)))
        }
        for (index, first) in ready.enumerated() {
            var goods: [String: Int] = [:]
            if stock {
                let held = shelf[first.id, default: 0]
                guard held > 0 || shelfSlots < limit, held < economy.shelfStack else { continue }
                goods[first.id] = min(economy.shelfStack - held, available(first.id))
            } else {
                let size = BasketSize(stage: stage, market: market)
                let target = min(economy.orderPayout[stage.rawValue, default: first.value], economy.maxOrderValue)
                goods = size.order(startingAt: index, wares: ready, available: available, target: target,
                                   ceiling: economy.maxOrderValue)
            }
            guard goods[first.id] != nil,
                  !(goods == ["item.radish": 1] && offers.first?.subjectID == "order.firstRadish") else { continue }
            let orderedIDs = [first.id] + goods.keys.filter { $0 != first.id }.sorted()
            let title = orderedIDs.compactMap { id in items[id].map { "\(goods[id, default: 0]) × \($0.title)" } }
                .joined(separator: " + ")
            offers.append(offer("\(location):\(first.id)", title, first.symbol, first.id, .goods(goods, vehicle: vehicle)))
        }
        return offers
    }

    mutating func apply(_ variant: FarmVariant, activityID: String, day: Int, level: Int, stage: FarmStage,
                        season: String, catalog: FarmCatalog, selections: [String] = []) -> FarmResult? {
        guard variant.activityID == activityID, let current = variants(activityID: activityID, locationID: variant.locationID,
              day: day, level: level, stage: stage, season: season, catalog: catalog) else { return nil }
        if !current.contains(variant) {
            // Restocking may change the suggested basket, but Tilda's existing order doesn't grow with it.
            let size = BasketSize(stage: stage, market: false)
            guard activityID == "act.shop.order", case let .goods(goods, vehicle) = variant.job, vehicle == nil,
                  current.contains(where: { $0.subjectID == variant.subjectID && $0.revision == variant.revision }),
                  let first = variant.featuredItemID, goods[first] != nil, goods.count <= size.types else { return nil }
            var total = 0, price = 0
            for (id, quantity) in goods {
                guard let item = catalog.items.first(where: { $0.id == id && $0.level <= level && $0.value > 0 }),
                      (1...size.perType).contains(quantity),
                      shelf[id, default: 0] + inventory[id, default: 0] >= quantity else { return nil }
                total += quantity
                price += quantity * item.value
            }
            guard total <= size.pieces, price <= catalog.economy.maxOrderValue else { return nil }
        }
        let action = activityID.shortID
        var book = Set<String>()
        let text: String
        func machineEntries(_ gear: [String]) -> Set<String> {
            Set(gear.filter { $0.hasPrefix("veh.") || $0.hasPrefix("imp.") }.map { "hofbook.machine.\($0.shortID)" })
        }
        switch variant.job {
        case let .land(job):
            let ids = Set(job.ids)
            let crop = catalog.crops.first { $0.id == job.crop }
            let indices = plots.indices.filter { ids.contains(plots[$0].id) }
            guard !indices.isEmpty else { return nil }
            book.formUnion(machineEntries(job.gear))
            switch action {
            case "plow":
                for i in indices { plots[i].isPlowed = true }
                text = "\(job.label): Die Erde ist jetzt locker."
            case "sow":
                guard let crop else { return nil }
                for i in indices {
                    plots[i].cropID = crop.id
                    plots[i].planting += 1
                    plots[i].grownNights = 0
                    plots[i].nightsLeft = stage == .sprout ? min(2, crop.nights) : crop.nights
                    plots[i].harvestSeason = crop.harvestSeasonID
                    plots[i].watered = day == rainyDay && plots[i].locationID != "loc.greenhouse"
                }
                book.insert("hofbook.plant.\(crop.id.shortID)")
                text = "\(job.label): \(crop.title) ist gesät."
            case "water":
                for i in indices { plots[i].watered = true }
                text = "\(variant.title): Die Erde hat getrunken."
            default:
                guard let crop else { return nil }
                let count = crop.yield * indices.count
                for i in indices {
                    if plots[i].locationID == "loc.orchard" {
                        plots[i].pickedYear = Self.year(day)
                        plots[i].nightsLeft = 1
                    } else {
                        plots[i].cropID = nil
                        plots[i].isPlowed = false
                        plots[i].nightsLeft = 0
                    }
                    plots[i].grownNights = 0
                    plots[i].watered = false
                }
                inventory[crop.itemID, default: 0] += count
                book.insert("hofbook.plant.\(crop.id.shortID)")
                text = "Im Lager: \(count) × \(crop.title) aus der Ernte."
            }
        case let .visit(visit):
            guard let i = animals.firstIndex(where: { $0.id == visit.animal }) else { return nil }
            animals[i].actions[visit.kind] = day
            if visit.fromInventory, let id = visit.item { Self.take(1, id, from: &inventory) }
            book.insert("hofbook.animal.\(visit.species.shortID)")
            if animals[i].isBaby { book.insert("hofbook.animal.\(visit.species.shortID).baby") }
            if ["baby", "nursery"].contains(visit.kind) {
                let nickname = selections.last.flatMap { Self.babyNames[$0] } ?? visit.name
                if visit.kind == "nursery" {
                    if nurseryNames == nil { nurseryNames = [:] }
                    nurseryNames?[variant.subjectID] = nickname
                } else {
                    animals[i].nickname = nickname
                }
                book.insert("hofbook.animal.\(visit.species.shortID).baby")
                text = "\(nickname) hat getrunken und kuschelt sich in die Decke."
            } else if let id = visit.item, ["milk", "eggs", "shear", "compost", "collect"].contains(visit.kind) {
                inventory[id, default: 0] += 1
                let product = catalog.items.first { $0.id == id }?.title ?? id
                text = "\(visit.name): 1 × \(product) liegt jetzt im Lager."
            } else {
                let ending = ["feed": "knabbert zufrieden.", "water": "hat frisches Wasser.", "pet": "freut sich über die Pflege.",
                              "baby": "kuschelt sich ein.", "bed": "ist im Schlafplatz angekommen.", "find": "ist wieder bei dir."]
                text = "\(visit.name) \(ending[visit.kind] ?? "freut sich.")"
            }
        case let .recipe(id):
            guard let recipe = catalog.recipes.first(where: { $0.id == id }) else { return nil }
            for (id, amount) in recipe.ingredients { Self.take(amount, id, from: &inventory) }
            inventory[recipe.output, default: 0] += 1
            let name = catalog.items.first { $0.id == recipe.output }?.title ?? recipe.title
            text = "Selbst gemacht: 1 × \(name) für das Lager."
        case let .goods(goods, vehicle):
            if action == "stock" {
                for (id, amount) in goods {
                    Self.take(amount, id, from: &inventory)
                    shelf[id, default: 0] += amount
                }
                text = "Im Regal steht jetzt: \(variant.title)."
            } else {
                var payment = 0
                for (id, amount) in goods {
                    let shelved = action == "order" ? min(shelf[id, default: 0], amount) : 0
                    Self.take(shelved, id, from: &shelf)
                    Self.take(amount - shelved, id, from: &inventory)
                    payment += amount * (catalog.items.first { $0.id == id }?.value ?? 0)
                }
                coins += payment
                if let vehicle { book.formUnion(machineEntries(vehicle == "veh.tractor" ? [vehicle, "imp.trailer"] : [vehicle])) }
                book.insert(action == "market" ? "hofbook.npc.yusuf" : "hofbook.npc.tilda")
                text = "\(variant.title) verkauft. \(payment) Taler sind in der Kasse."
            }
        case let .outdoor(gear):
            workedDay[activityID] = day
            book.formUnion(machineEntries(gear))
            if action == "hay" {
                inventory["item.hay", default: 0] += 3
                text = "Drei Ballen Heu liegen jetzt im Lager."
            } else { text = "Der Weg am Hofplatz ist wieder frei." }
        }
        revisions["\(activityID):\(variant.subjectID)", default: 0] += 1
        let known = Set(catalog.hofbook.filter { $0.level <= level }.map(\.id))
        return FarmResult(text: text, book: book.intersection(known))
    }

    private static func year(_ day: Int) -> Int { max(0, day - 1) / 16 }

    fileprivate static let babyNames = ["name.star": "Sternchen", "name.cloud": "Wölkchen", "name.flower": "Blümchen"]

    private static func take(_ amount: Int, _ item: String, from stock: inout [String: Int]) {
        guard amount > 0, let old = stock[item] else { return }
        if old == amount { stock.removeValue(forKey: item) } else { stock[item] = old - amount }
    }
}

private extension String {
    var shortID: String { split(separator: ".").last.map(String.init) ?? self }
}

extension FarmVariant {
    func steps(base: [FarmStep], catalog: FarmCatalog) -> [FarmStep] {
        let guide = WorkGuide(catalog: catalog)
        let action = activityID.shortID
        switch job {
        case let .land(patch):
            let crop = catalog.crops.first { $0.id == patch.crop }
            let bed = guide.choice(patch.ids[0], patch.label, "square.grid.3x3")
            var result: [FarmStep] = []
            if action == "sow", let crop {
                let seeds = guide.choice(crop.seedItemID ?? crop.id, crop.title,
                                         catalog.items.first { $0.id == crop.itemID }?.symbol ?? "leaf")
                result.append(guide.step("seed", "Finde die Samentüte: \(crop.title).", seeds,
                                         [guide.tool("tool.can"), guide.tool("tool.basket")]))
            }
            result += guide.gearSteps(patch.gear, task: title)
            let text: String
            switch action {
            case "plow": text = "Lockere jetzt die Erde: \(patch.label)."
            case "sow": text = "Lege die Samen für \(crop?.title ?? title) hier in die Erde: \(patch.label)."
            case "water": text = "Hier wächst \(crop?.title ?? title). Gib der Erde in \(patch.label) Wasser."
            default: text = "Die Ernte ist reif: \(crop?.title ?? title). Ernte hier: \(patch.label)."
            }
            result.append(guide.step("field", text, bed, [guide.tool("tool.bucket")]))
            if action == "harvest" || action == "combine", let crop, let item = guide.item(crop.itemID) {
                result.append(guide.step("store", "Bringe die Ernte ins Lager: \(patch.ids.count * crop.yield) × \(item.title).",
                                         item, [guide.tool("tool.can"), bed]))
            }
            return result
        case let .visit(visit):
            return guide.visit(visit)
        case let .recipe(id):
            guard let recipe = catalog.recipes.first(where: { $0.id == id }), let output = guide.item(recipe.output) else { return [] }
            let ingredients = recipe.ingredients.keys.sorted().compactMap(guide.item)
            let station = guide.choice("station.\(recipe.id.shortID)", recipe.station, "gearshape")
            var result = ingredients.map { ingredient in
                guide.step("add.\(ingredient.id.shortID)", "\(recipe.title): Gib \(recipe.ingredients[ingredient.id, default: 0]) × \(ingredient.title) dazu.",
                           ingredient, ingredients + [guide.tool("tool.basket")])
            }
            for (i, supply) in (recipe.supplies ?? []).enumerated() {
                result.append(guide.step("supply.\(i)", "Gib jetzt \(supply) vom Arbeitsplatz dazu.",
                                         guide.choice("supply.\(i)", supply, "drop"), [station]))
            }
            result.append(guide.step("process", "\(recipe.title): Arbeite an der Station „\(recipe.station)“.", station, ingredients))
            result.append(guide.step("finish", "Was ist fertig? Nimm \(output.title) mit ins Lager.", output, ingredients))
            return result
        case let .goods(goods, vehicle):
            let wares = goods.keys.sorted().compactMap(guide.item)
            let stock = action == "stock"
            let market = action == "market"
            var result: [FarmStep] = []
            if stock, goods.values.contains(where: { $0 >= 3 }) {
                let barrow = guide.tool("tool.wheelbarrow")
                result.append(guide.step("carry", "Fahre \(title) mit der Schubkarre zum Laden.", barrow,
                                         [guide.tool("tool.bucket")]))
            }
            for ware in wares {
                let amount = goods[ware.id, default: 0]
                let text = stock ? "Stelle \(amount) × \(ware.title) ins Regal."
                    : market ? "Lade für den Markt ein: \(amount) × \(ware.title)."
                    : "Tildas Bestellung: Lege \(amount) × \(ware.title) in den Korb."
                result.append(guide.step("pack.\(ware.id.shortID)", text, ware, wares + [guide.tool("tool.can")]))
            }
            if let vehicle {
                let transport = guide.tool(vehicle)
                result.append(guide.step("ride", "Fahre mit: \(transport.title). Ziel ist der Dorfmarkt.", transport,
                                         [guide.tool("tool.basket")]))
                result.append(guide.step("display", "Lege \(title) auf Yusufs Markttisch.",
                                         guide.choice("market.table", "Markttisch", "storefront"), wares))
            }
            if !stock {
                result.append(guide.step("ring", "Der Korb ist gefüllt. Klingele für \(market ? "Yusuf" : "Tilda")!",
                                         guide.choice("shop.bell", "Klingel", "bell"), wares))
            } else {
                result.append(guide.step("shelf", "Zeige den eingeräumten Platz für \(title).",
                                         guide.choice("shop.shelf", "Warenregal", "cabinet"), [guide.tool("tool.bucket")]))
            }
            return result
        case let .outdoor(gear):
            let equipment = guide.gearSteps(gear, task: title)
            if action == "hay", let hay = guide.item("item.hay") {
                return equipment + [guide.step("store", "Bringe drei Ballen Heu ins Lager.", hay,
                                               [guide.tool("tool.bucket")])]
            }
            return equipment + [guide.step("path", "Schiebe den Schnee vom Hofweg zur Seite.",
                                           guide.choice("plaza.path", "Verschneiter Hofweg", "snowflake"),
                                           [guide.tool("tool.basket")])]
        }
    }
}

private struct WorkGuide {
    let catalog: FarmCatalog

    func choice(_ id: String, _ title: String, _ symbol: String) -> FarmChoice {
        FarmChoice(id: id, title: title, symbol: symbol)
    }

    func item(_ id: String) -> FarmChoice? {
        catalog.items.first { $0.id == id }.map { choice($0.id, $0.title, $0.symbol) }
    }

    func step(_ id: String, _ text: String, _ target: FarmChoice, _ alternatives: [FarmChoice]) -> FarmStep {
        var seen: Set<String> = []
        return FarmStep(id: id, text: text, targetID: target.id,
                        choices: ([target] + alternatives).filter { seen.insert($0.id).inserted })
    }

    func tool(_ id: String) -> FarmChoice {
        if let machine = catalog.machines.first(where: { $0.id == id }) {
            return choice(id, machine.title, "gearshape.2")
        }
        let labels: [String: (String, String)] = [
            "tool.can": ("Gießkanne", "drop"), "tool.hand": ("Handschuh", "hand.raised"),
            "tool.basket": ("Korb", "basket"), "tool.bucket": ("Eimer", "drop.circle"),
            "tool.ladder": ("Leiter", "stairs"), "tool.hoe": ("Hacke", "hammer"),
            "tool.brush": ("Bürste", "comb"), "tool.shears": ("Schermaschine", "scissors"),
            "tool.wheelbarrow": ("Schubkarre", "cart"), "veh.carriage": ("Pferdekutsche", "figure.equestrian.sports")
        ]
        let (name, symbol) = labels[id] ?? (id, "wrench")
        return choice(id, name, symbol)
    }

    func gearSteps(_ ids: [String], task: String) -> [FarmStep] {
        let verbs = ["veh.tractor": "Fahre mit dem Traktor los", "veh.combine": "Starte den Mähdrescher",
                     "imp.plow": "Senke den Pflug ab", "imp.seeder": "Fülle die Sämaschine",
                     "imp.watertank": "Fülle das Wasserfass", "imp.mower": "Mähe das Gras mit dem Mähwerk",
                     "imp.baler": "Presse das Heu mit der Ballenpresse", "imp.loader": "Hebe die Last mit dem Frontlader",
                     "imp.trailer": "Stelle den Anhänger bereit", "imp.potatodigger": "Hebe die Kartoffeln mit dem Roder",
                     "imp.snowplow": "Senke das Schneeschild ab", "tool.ladder": "Stelle die Leiter am Baum auf",
                     "tool.can": "Fülle die Gießkanne am Brunnen"]
        return ids.map { id in
            let gear = tool(id)
            let phrase = verbs[id] ?? "Nimm das Werkzeug „\(gear.title)“"
            return step("use.\(id.shortID)", "\(task): \(phrase).", gear, [tool("tool.can"), tool("tool.basket"), tool("tool.hand")])
        }
    }

    func visit(_ visit: Visit) -> [FarmStep] {
        let name = visit.name
        let animal = choice(visit.species, name, catalog.locations.first { location in
            location.id == catalog.animals.first { $0.id == visit.species }?.locationID
        }?.symbol ?? "pawprint")
        let supply = visit.item.flatMap(item)
        let bucket = tool("tool.bucket"), hand = tool("tool.hand"), basket = tool("tool.basket")
        let end: String
        let object: FarmChoice
        let first: String
        switch visit.kind {
        case "feed":
            object = supply ?? choice("animal.ration", "Futternapf", "takeoutbag.and.cup.and.straw")
            first = "Was bekommt \(name)? Nimm \(object.title)."
            end = "Bring das Futter zu \(name)."
        case "water":
            object = bucket; first = "Fülle den Wassereimer für \(name)."; end = "Fülle den Trog bei \(name)."
        case "pet":
            let brush = ["animal.cow", "animal.horse", "animal.goat"].contains(visit.species)
            object = brush ? tool("tool.brush") : hand
            first = brush ? "Welche Bürste nehmen wir für \(name)?" : "Streicheln wir \(name) mit der Hand."
            end = brush ? "Bürste \(name) ganz sanft." : "Streichle \(name) ganz sanft."
        case "bed":
            object = choice("stall.bed", "Schlafplatz", "moon.stars"); first = "Zeige den Schlafplatz für \(name)."
            end = visit.species == "animal.duck" ? "Der Entenmarsch beginnt! Begleite \(name) zum Schlafplatz." : "Begleite \(name) zum Schlafplatz."
        case "baby", "nursery":
            let blanket = choice("stall.blanket", "Kuscheldecke", "bed.double")
            let drink = choice("stall.drink", "Trinkschale", "drop")
            return [step("warm", "Kuschle \(name) in die warme Decke.", blanket, [basket]),
                    step("drink", "Was stellen wir \(name) zum Trinken hin?", drink, [blanket, basket]),
                    FarmStep(id: "name", text: "Welchen Kosenamen bekommt das Kleine?", targetID: "*",
                             choices: FarmProduction.babyNames.sorted { $0.key < $1.key }.map { id, title in
                                 choice(id, title, id == "name.star" ? "star" : id == "name.cloud" ? "cloud" : "camera.macro")
                             })]
        case "find":
            object = choice("animal.tracks", "Tierspuren", "pawprint"); first = "Welche Spuren führen zu \(name)?"
            end = "Da ist \(name)! Begrüße das Tier."
        default:
            guard let product = supply else { return [] }
            let gear: FarmChoice
            let task: String
            switch visit.kind {
            case "milk": gear = bucket; task = "Stelle den Eimer für die Milch von \(name) bereit."
            case "shear": gear = tool("tool.shears"); task = "Nimm die Schermaschine für \(name)."
            case "compost": gear = tool("tool.wheelbarrow"); task = "Fahre mit der Schubkarre zum Koben von \(name)."
            case "eggs": gear = basket; task = "Nimm den Korb zum Nest von \(name)."
            default: gear = basket; task = "Bei \(name) kannst du \(product.title) sammeln. Nimm einen Korb."
            }
            return [
                step("tool", task, gear, [basket, hand, bucket]),
                step("animal", "Zeige, wo \(name) zu Hause ist.", animal, [gear]),
                step("collect", "Sammle für das Lager: \(product.title) von \(name).", product, [gear, hand])
            ]
        }
        return [step("prepare", first, object, [hand, basket, bucket]),
                step("animal", end, animal, [object, basket])]
    }
}
