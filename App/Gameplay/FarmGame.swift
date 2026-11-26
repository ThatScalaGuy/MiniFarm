import Foundation

/// Value semantics are intentional: one intent produces one complete, persistable snapshot.
struct FarmGame: Sendable {
    let catalog: FarmCatalog
    private(set) var state: FarmState

    init(catalog: FarmCatalog, stage: FarmStage = .sprout) {
        self.catalog = catalog
        self.state = FarmState(stage: stage)
        prepareFarm()
        startDay()
    }

    init(catalog: FarmCatalog, state: FarmState) {
        self.catalog = catalog
        self.state = state
    }

    mutating func configure(stage: FarmStage?, adaptive: Bool, memory: Bool, earlyHints: Bool) {
        if let stage { state.stage = stage }
        state.fixedStage = stage != nil
        state.adaptive = adaptive
        state.memory = memory
        state.earlyHints = earlyHints
    }

    mutating func applyProfileStage(_ stage: FarmStage, revision: Int, locked: Bool) {
        if locked || revision != state.appliedStageRevision { state.stage = stage }
        state.appliedStageRevision = revision
        state.fixedStage = locked
    }

    var locations: [FarmLocation] { catalog.locations.filter { $0.level <= state.level } }
    var beds: [FarmBedView] {
        state.production.plots.map {
            FarmBedView(id: $0.id, locationID: $0.locationID, cropID: $0.cropID, phase: $0.phase, watered: $0.watered)
        }
    }
    var caredAnimalIDs: Set<String> { state.production.caredAnimalIDs(on: state.day) }
    var season: String {
        ["season.spring", "season.summer", "season.autumn", "season.winter"][((state.day - 1) / 4 + state.seasonOffset) % 4]
    }
    var weather: String {
        guard let values = catalog.seasons.first(where: { $0.id == season })?.weather, !values.isEmpty else { return "sun" }
        if state.day == 1 { return "sun" }
        return values[(state.day * 13 + state.day / 4) % values.count]
    }
    var dailyGoal: Int {
        switch state.stage { case .sprout: 4; case .shoot: 5; case .bloom: 6 }
    }
    var sunProgress: Double { min(1, Double(state.ticks) / Double(4 * dailyGoal)) }
    var wishes: [FarmWish] {
        let cap: Int = switch state.stage { case .sprout: 2; case .shoot: 3; case .bloom: 5 }
        return Array(availableWishes.prefix(cap))
    }

    func activities(at locationID: String) -> [FarmActivity] {
        guard locations.contains(where: { $0.id == locationID }) else { return [] }
        return catalog.activities.compactMap {
            guard playable($0, at: locationID) else { return nil }
            var located = $0
            located.locationID = locationID
            return located
        }
    }

    func discoveries(at locationID: String) -> [FarmBookEntry] {
        catalog.hofbook.filter {
            $0.locationID == locationID && $0.level <= state.level && ($0.seasonID == nil || $0.seasonID == season)
                && ($0.id.hasPrefix("hofbook.discovery.") || $0.guestID != nil || ambientSeasonEntry($0.id) || $0.id.hasPrefix("hofbook.npc."))
        }
    }

    private func ambientSeasonEntry(_ id: String) -> Bool {
        switch id {
        case "hofbook.season.spring.rainbow": weather == "rainbow"
        case "hofbook.season.summer.firefly", "hofbook.season.winter.shootingstar": sunProgress >= 0.75
        case "hofbook.season.spring.tulip", "hofbook.season.spring.bud", "hofbook.season.spring.blossom",
             "hofbook.season.summer.cricket", "hofbook.season.autumn.vformation", "hofbook.season.autumn.gold",
             "hofbook.season.winter.iceflower", "hofbook.season.winter.foxtracks": true
        default: false
        }
    }

    func bookEntry(_ id: String) -> FarmBookEntry? { catalog.hofbook.first { $0.id == id } }

    private func variants(_ id: String, _ location: String) -> [FarmVariant]? {
        state.production.variants(activityID: id, locationID: location, day: state.day, level: state.level,
                                  stage: state.stage, season: season, catalog: catalog)
    }

    private func playable(_ activity: FarmActivity, at location: String) -> Bool {
        guard activity.level <= state.level else { return false }
        switch activity.id {
        case "act.nature.kite" where season != "season.autumn": return false
        case "act.nature.snowman", "act.field.snowplow": if season != "season.winter" { return false }
        default: break
        }
        if let variants = variants(activity.id, location) { return !variants.isEmpty }
        return activity.locationID == location
    }

    private func possible(_ wish: FarmWish) -> Bool {
        guard let activity = catalog.activities.first(where: { $0.id == wish.activityID }) else { return false }
        if wish.festival == nil, let requested = wish.itemID, let options = variants(activity.id, wish.locationID) {
            return options.contains { $0.featuredItemID == requested }
        }
        return wish.festival != nil || playable(activity, at: wish.locationID)
    }

    private var availableWishes: [FarmWish] {
        let candidates = state.outstanding.filter { !$0.folded && possible($0) }
        func priority(_ wish: FarmWish) -> Int {
            if wish.introduction == state.introduction { return 0 }
            if wish.festival != nil { return 1 }
            if wish.createdDay == state.day && wish.locationID != state.lastLocation { return 2 }
            return 3
        }
        return candidates.sorted {
            let a = priority($0), b = priority($1)
            if a != b { return a < b }
            if $0.createdDay != $1.createdDay { return $0.createdDay > $1.createdDay }
            return $0.id.localizedStandardCompare($1.id) == .orderedAscending
        }
    }

    var prompt: FarmPrompt? {
        guard let turn = state.active,
              let activity = catalog.activities.first(where: { $0.id == turn.activityID }),
              let params = activity.params[state.stage.rawValue] else { return nil }
        let isMenu = !turn.variants.isEmpty && turn.variant == nil
        let step: FarmStep
        if isMenu {
            let start = min(turn.page, max(0, (turn.variants.count - 1) / 4)) * 4
            let page = turn.variants.dropFirst(start).prefix(4)
            var choices = page.map { FarmChoice(id: $0.subjectID, title: $0.title, symbol: $0.symbol) }
            guard let first = choices.first else { return nil }
            if turn.variants.count > 4 {
                choices.append(FarmChoice(id: "page.next", title: "Weiterblättern", symbol: "arrow.right.circle"))
            }
            step = FarmStep(id: "select", text: "Was möchtest du nehmen?", targetID: first.id, choices: choices)
        } else if activity.id == "act.farm.memory", let board = state.life.memoryStep {
            step = board
        } else {
            guard turn.steps.indices.contains(turn.index) else { return nil }
            step = turn.steps[turn.index]
        }
        let count = state.adaptive ? state.skills.choiceCount(base: params.choiceCount, lanes: activity.lanes, assist: turn.assist)
            : params.choiceCount
        var choices = step.choices
        if !isMenu, step.targetID != "*", let target = step.choices.first(where: { $0.id == step.targetID }) {
            choices = [target] + step.choices.filter { $0.id != target.id }.prefix(max(0, count - 1))
            if choices.count > 1 {
                let index = (state.day + turn.index + activity.id.utf8.count) % choices.count
                choices.swapAt(0, index)
            }
        }
        let guidanceTarget = activity.id == "act.farm.memory" && turn.assist.rawValue >= FarmAssist.ghost.rawValue
            ? state.life.suggestedMemoryCardID() : step.targetID
        guard let target = choices.first(where: { $0.id == guidanceTarget }) ?? choices.first else { return nil }
        let voiceID = "vl.pelle." + activity.id.dropFirst(4) + "." + step.id
        return FarmPrompt(locationID: turn.locationID, activityID: activity.id, stepID: step.id,
                          text: step.text, voiceID: voiceID, targetID: target.id, symbol: target.symbol,
                          stepIndex: turn.index, stepCount: max(1, turn.steps.count), targetSize: params.targetSize,
                          choices: choices, assist: turn.assist)
    }

    @discardableResult
    mutating func send(_ intent: FarmIntent) -> FarmFeedback {
        switch intent {
        case let .startActivity(id):
            guard let activity = catalog.activities.first(where: { $0.id == id }) else { return unavailable }
            let here = playable(activity, at: state.locationID) ? state.locationID : activity.locationID
            return begin(activity, location: here, wish: nil)
        case let .startActivityAt(id, location):
            guard let activity = catalog.activities.first(where: { $0.id == id }) else { return unavailable }
            return begin(activity, location: location, wish: nil)
        case let .startWish(id):
            guard let wish = state.outstanding.first(where: { $0.id == id }),
                  let activity = catalog.activities.first(where: { $0.id == wish.activityID }) else { return unavailable }
            guard possible(wish) else { return prerequisite(for: wish) }
            return begin(activity, location: wish.locationID, wish: wish)
        case let .visit(id):
            guard let place = locations.first(where: { $0.id == id }) else { return unavailable }
            if state.locationID != id { pauseTurn() }
            state.locationID = id
            return FarmFeedback(text: place.title, voiceID: "vl.vocab.\(id)")
        case let .discover(id):
            guard let entry = bookEntry(id),
                  discoveries(at: state.locationID).contains(where: { $0.id == id }) || state.book.contains(id) else { return unavailable }
            state.book.insert(entry.id)
            if let guest = entry.guestID { state.book.insert("hofbook.animal." + guest.dropFirst(7)) }
            if entry.guestID == "animal.hedgehog", season == "season.autumn" { state.book.insert("hofbook.season.autumn.hedgehog") }
            if entry.id.hasPrefix("hofbook.discovery.") {
                _ = state.life.observe(entryID: id, locationID: state.locationID, level: state.level, catalog: catalog, season: season)
            }
            state.seen.insert(entry.id)
            return FarmFeedback(text: entry.fact, voiceID: "vl.book." + id.dropFirst(8))
        case let .choose(id): return choose(id)
        case .askPelle: return help()
        case let .idle(seconds):
            guard seconds > 0, var turn = state.active,
                  let activity = catalog.activities.first(where: { $0.id == turn.activityID }) else { return currentFeedback }
            turn.idleSeconds += min(seconds, 120)
            state.active = turn
            let delay = state.earlyHints ? 4 : state.skills.hintSeconds(stage: state.stage, lanes: activity.lanes, rules: catalog.adaptive)
            guard turn.idleSeconds >= delay else { return currentFeedback }
            // Stillness can show the way, but never decides on the child's behalf.
            guard turn.assist.rawValue < FarmAssist.ghost.rawValue else { return currentFeedback }
            return help()
        case .goHome:
            pauseTurn()
            state.locationID = "loc.plaza"
            return FarmFeedback(text: "Da ist unser Hofbaum.", voiceID: "vl.pelle.home")
        case .sleep:
            pauseTurn()
            let oldSeason = season
            state.production.night(day: state.day, stage: state.stage, season: oldSeason, catalog: catalog)
            state.day += 1
            state.ticks = 0
            state.creditedToday.removeAll()
            state.freeToday.removeAll()
            if state.adaptive && !state.fixedStage {
                state.stage = state.skills.advanceStage(current: state.stage, day: state.day)
            }
            if state.introduction == 3 { state.introduction = 4 }
            prepareFarm()
            startDay()
            return FarmFeedback(text: "Guten Morgen! Der Hof wacht auf.", voiceID: "vl.pelle.greet.morning")
        case .nextSeason:
            pauseTurn()
            state.seasonOffset = (state.seasonOffset + 1) % 4
            prepareFarm()
            ensureWishes()
            let title = catalog.seasons.first { $0.id == season }?.title ?? season
            return FarmFeedback(text: "Schau, jetzt ist \(title)!", voiceID: "vl.\(season).greet")
        case let .requestDecoration(id):
            let result = state.life.purchase(decorationID: id, level: state.level, coins: &state.production.coins, catalog: catalog)
            return FarmFeedback(text: result.text, voiceID: "vl.pelle.deco.wish")
        case let .rotateDecoration(id):
            return FarmFeedback(text: state.life.rotate(positionID: id).text, voiceID: "vl.pelle.deco.turn")
        case let .putAwayDecoration(id):
            return FarmFeedback(text: state.life.remove(positionID: id).text, voiceID: "vl.pelle.deco.store")
        }
    }

    private var unavailable: FarmFeedback {
        FarmFeedback(text: "Komm, wir schauen bei Pelle nach.", voiceID: "vl.pelle.home")
    }
    private var currentFeedback: FarmFeedback {
        guard let prompt else { return FarmFeedback(text: "Was möchtest du entdecken?", voiceID: "vl.pelle.greet.explore") }
        return FarmFeedback(text: prompt.text, voiceID: prompt.voiceID)
    }

    private mutating func pauseTurn() {
        if let turn = state.active { state.paused[turn.key] = turn }
        state.active = nil
    }

    private mutating func prepareFarm() {
        state.production.prepare(day: state.day, level: state.level, stage: state.stage, season: season, catalog: catalog)
        if weather == "rain" { state.production.rain() }
    }

    private mutating func begin(_ activity: FarmActivity, location: String, wish: FarmWish?) -> FarmFeedback {
        guard locations.contains(where: { $0.id == location }),
              wish?.festival != nil || playable(activity, at: location) else { return unavailable }
        let key = wish?.id ?? "\(location)/\(activity.id)"
        if state.active?.key == key { return currentFeedback }
        pauseTurn()
        state.locationID = location
        if activity.id == "act.farm.memory" {
            state.life.startMemory(stage: state.stage, key: key, keepRevealed: !state.memory, day: state.day)
        }
        if let saved = state.paused.removeValue(forKey: key),
           saved.variant.map({ variants(activity.id, location)?.contains($0) == true }) ?? true {
            state.active = saved
            return currentFeedback
        }
        var turn = FarmTurn(activityID: activity.id, locationID: location, wishID: wish?.id, steps: activity.steps)
        if let festival = wish?.festival {
            turn.steps = state.life.festivalSteps(season: festival)
        } else if var options = variants(activity.id, location) {
            if let requested = wish?.itemID { options = options.filter { $0.featuredItemID == requested } }
            if let intro = wish?.introduction, [0, 1, 4, 5].contains(intro),
               let radish = options.first(where: { $0.featuredItemID == "item.radish" }) { options = [radish] }
            guard let first = options.first(where: { $0.subjectID == wish?.subjectID }) ?? options.first else { return unavailable }
            if wish != nil || options.count == 1 {
                bind(&turn, to: first, activity: activity)
            } else {
                turn.variants = options
            }
        } else {
            turn.steps = state.life.steps(activity: activity, stage: state.stage, day: state.day, season: season, catalog: catalog)
        }
        state.active = turn
        return currentFeedback
    }

    private func bind(_ turn: inout FarmTurn, to variant: FarmVariant, activity: FarmActivity) {
        turn.variant = variant
        turn.variants = []
        turn.steps = variant.steps(base: activity.steps, catalog: catalog)
        turn.index = 0
        turn.page = 0
        turn.picked = []
    }

    private mutating func help() -> FarmFeedback {
        guard var turn = state.active, let prompt else {
            if let wish = wishes.first { return send(.startWish(wish.id)) }
            return unavailable
        }
        let level = FarmAssist(rawValue: min(FarmAssist.together.rawValue, turn.assist.rawValue + 1)) ?? .together
        turn.assist = level
        if turn.mostHelp.rawValue < level.rawValue { turn.mostHelp = level }
        turn.idleSeconds = 0
        state.active = turn
        if level == .together {
            let assisted = turn.activityID == "act.farm.memory" ? state.life.suggestedMemoryCardID() : nil
            return choose(assisted ?? prompt.targetID)
        }
        let target = prompt.choices.first { $0.id == prompt.targetID }
        return FarmFeedback(text: "Schau mal: \(target?.title ?? prompt.text).", voiceID: "vl.hint." + prompt.activityID.dropFirst(4))
    }

    private mutating func choose(_ id: String) -> FarmFeedback {
        guard var turn = state.active, let prompt,
              let activity = catalog.activities.first(where: { $0.id == turn.activityID }) else { return unavailable }
        if !turn.variants.isEmpty && turn.variant == nil {
            if id == "page.next", turn.variants.count > 4 {
                turn.page = (turn.page + 1) % ((turn.variants.count + 3) / 4)
                state.active = turn
                return currentFeedback
            }
            guard prompt.choices.contains(where: { $0.id == id }),
                  let variant = turn.variants.first(where: { $0.subjectID == id }) else { return currentFeedback }
            bind(&turn, to: variant, activity: activity)
            state.active = turn
            return currentFeedback
        }
        if activity.id == "act.farm.memory" {
            switch state.life.turnMemory(cardID: id) {
            case .finished: return finish(turn, activity: activity)
            case .mismatch: return help()
            case .first, .pair:
                turn.idleSeconds = 0
                turn.assist = .cue
                state.active = turn
                return currentFeedback
            case .ignored: return currentFeedback
            }
        }
        let step = turn.steps[turn.index]
        guard prompt.choices.contains(where: { $0.id == id }) else { return currentFeedback }
        guard step.targetID == "*" || step.targetID == id else { return help() }
        turn.picked.append(id)
        turn.index += 1
        turn.idleSeconds = 0
        turn.assist = .cue
        if turn.index < turn.steps.count {
            state.active = turn
            return currentFeedback
        }
        return finish(turn, activity: activity)
    }

    private mutating func finish(_ turn: FarmTurn, activity: FarmActivity) -> FarmFeedback {
        let wish = state.outstanding.first { $0.id == turn.wishID }
        let result: FarmResult
        if let festival = wish?.festival {
            result = state.life.celebrate(season: festival, day: state.day, catalog: catalog)
        } else if let variant = turn.variant {
            guard let applied = state.production.apply(variant, activityID: activity.id, day: state.day, level: state.level,
                                                       stage: state.stage, season: season, catalog: catalog) else {
                // A different activity may have used the stock while this one was put aside.
                state.active = nil
                ensureWishes()
                if let wish { return prerequisite(for: wish) }
                return FarmFeedback(text: "Wir schauen, was gerade bereitliegt.", voiceID: "vl.pelle.greet.explore")
            }
            result = applied
        } else {
            result = state.life.complete(activityID: activity.id, locationID: turn.locationID, choices: turn.picked,
                                         day: state.day, season: season, catalog: catalog)
        }
        state.active = nil
        state.book.formUnion(result.book)
        recordEncounter(turn, book: result.book)
        if !state.life.wishlist.isEmpty {
            _ = state.life.deliverWishlist(level: state.level, coins: &state.production.coins, catalog: catalog)
        }
        state.lastLocation = turn.locationID
        if state.adaptive {
            state.skills.record(lanes: activity.lanes, assist: turn.mostHelp, day: state.day, rules: catalog.adaptive)
        }
        if let wish {
            state.outstanding.removeAll { $0.id == wish.id }
            state.ticks += 4
            if state.creditedToday.insert(activity.id).inserted {
                state.treeWishes += 1
                state.activityTypes.insert(activity.id)
            }
        } else {
            let object = turn.variant?.subjectID ?? turn.locationID
            if state.freeToday.insert("\(activity.id)/\(object)").inserted { state.ticks += 1 }
        }
        advanceIntroduction(after: turn)
        updateLevel()
        ensureWishes()
        return FarmFeedback(text: result.text, voiceID: "vl.praise." + activity.id.dropFirst(4), completed: true)
    }

    private mutating func updateLevel() {
        let milestones = [(10, 3), (30, 6), (60, 10), (100, 14)]
        let level = 1 + milestones.prefix { state.treeWishes >= $0.0 && state.activityTypes.count >= $0.1 }.count
        if level > state.level {
            state.level = level
            prepareFarm()
        }
    }

    private mutating func recordEncounter(_ turn: FarmTurn, book: Set<String>) {
        if book.contains("hofbook.animal.dog") { state.book.insert("hofbook.npc.pelle") }
        if book.contains("hofbook.animal.cat") { state.book.insert("hofbook.npc.minka") }
        let id: String?
        switch (season, turn.activityID, turn.variant?.featuredItemID) {
        case ("season.spring", _, _) where book.contains("hofbook.animal.chicken.baby"): id = "spring.chick"
        case ("season.summer", "act.field.harvest", "item.sunflower"): id = "summer.sunflower"
        case ("season.summer", "act.kitchen.churn", "item.icecream"): id = "summer.icecream"
        case ("season.summer", "act.field.hay", _): id = "summer.hay"
        case ("season.autumn", "act.field.harvest", "item.pumpkin"): id = "autumn.pumpkin"
        case ("season.autumn", "act.nature.kite", _): id = "autumn.kite"
        case ("season.winter", "act.nature.snowman", _): id = "winter.snowman"
        case ("season.winter", "act.nature.birdhouse", _): id = "winter.birdfeeder"
        default: id = nil
        }
        if let id { state.book.insert("hofbook.season.\(id)") }
    }

}

extension FarmGame {
        private static let introduction: [String?] = [
            "act.field.sow", "act.field.water", "act.animal.feed", nil, "act.field.harvest", "act.shop.order"
        ]

        private mutating func advanceIntroduction(after turn: FarmTurn) {
            guard Self.introduction.indices.contains(state.introduction),
                  Self.introduction[state.introduction] == turn.activityID else { return }
            if [0, 1, 4, 5].contains(state.introduction) && turn.variant?.featuredItemID != "item.radish" { return }
            let previous = state.introduction
            state.introduction += 1
            // Completing the same practical task in free play also advances Pelle's invitation.
            state.outstanding.removeAll { $0.introduction == previous }
            if state.introduction == 3 { state.ticks = max(state.ticks, 4 * dailyGoal) }
        }

        private mutating func offerIntroduction() {
            guard Self.introduction.indices.contains(state.introduction), let id = Self.introduction[state.introduction],
                  !state.outstanding.contains(where: { $0.introduction == state.introduction }),
                  let activity = catalog.activities.first(where: { $0.id == id }), playable(activity, at: activity.locationID) else { return }
            let words = ["Säen wir Radieschen!", "Wasser für das Radieschen!", "Körner für die Hühner!", "",
                         "Die Radieschen sind reif!", "Ein Radieschen für Tilda!"]
            if [0, 1, 4, 5].contains(state.introduction),
               variants(id, activity.locationID)?.contains(where: { $0.featuredItemID == "item.radish" }) != true { return }
            appendWish(activity: activity, title: words[state.introduction], intro: state.introduction)
        }

        private func giver(for activity: FarmActivity) -> String {
            switch activity.id {
            case "act.shop.market": return "npc.yusuf"
            case "act.village.mail": return "npc.lale"
            case "act.village.helpmo": return "npc.mo"
            case "act.farm.sing", "act.farm.photo": return "animal.dog"
            default:
                if activity.id.hasPrefix("act.shop.") || activity.id.hasPrefix("act.kitchen.") { return "npc.tilda" }
                if activity.id.hasPrefix("act.animal.") {
                    return catalog.animals.first(where: { $0.locationID == activity.locationID && $0.level <= state.level })?.id ?? "animal.dog"
                }
                return activity.locationID
            }
        }

        private mutating func appendWish(activity: FarmActivity, title: String? = nil, intro: Int? = nil,
                                         festival: String? = nil, location: String? = nil) {
            let place = location ?? activity.locationID
            let options = festival == nil ? variants(activity.id, place) ?? [] : []
            let focus: FarmVariant?
            if let intro, [0, 1, 4, 5].contains(intro) {
                focus = options.first { $0.featuredItemID == "item.radish" }
            } else if !options.isEmpty {
                focus = options[(state.nextWish + state.day) % options.count]
            } else { focus = nil }
            let requested = focus?.featuredItemID ?? (activity.id == "act.shop.order" ? "item.radish" : nil)
            let label = focus.map { "\(activity.title): \($0.title)" } ?? activity.title
            let wish = FarmWish(id: "wish.\(state.nextWish)", activityID: activity.id, locationID: place,
                                giver: giver(for: activity), title: title ?? label, createdDay: state.day,
                                festival: festival, introduction: intro, subjectID: focus?.subjectID, itemID: requested)
            state.nextWish += 1
            state.outstanding.append(wish)
            // Only the display folds. The invitation and even its half-finished steps remain addressable by ID.
            if state.outstanding.filter({ !$0.folded }).count > 8,
               let oldest = state.outstanding.firstIndex(where: { !$0.folded && $0.introduction == nil && $0.id != wish.id }) {
                state.outstanding[oldest].folded = true
            }
        }

        private mutating func startDay() {
            offerIntroduction()
            if let order = catalog.activities.first(where: { $0.id == "act.shop.order" }),
               variants(order.id, order.locationID)?.isEmpty == true {
                // Tilda waits for a real harvest; an empty shelf is never a source of free saleable stock.
                appendWish(activity: order, title: "Tilda wartet auf ein Radieschen.")
            }
            if state.day.isMultiple(of: 4), let current = catalog.seasons.first(where: { $0.id == season }),
               let shared = catalog.activities.first(where: { $0.id == "act.nature.flowers" }) {
                appendWish(activity: shared, title: current.festivalTitle, festival: current.id, location: "loc.plaza")
            }
            generateWishes(count: dailyGoal)
        }

        private mutating func ensureWishes() {
            offerIntroduction()
            if availableWishes.isEmpty { generateWishes(count: 1) }
        }

        private mutating func generateWishes(count: Int) {
            var offered = state.outstanding.filter { $0.createdDay == state.day && !$0.folded }
            let needed = count == 1 ? 1 : max(0, count - offered.count)
            guard needed > 0 else { return }
            let pool = locations.flatMap { activities(at: $0.id) }
            guard !pool.isEmpty else { return }
            // Rotate ties deterministically. Different subjects of the same activity never crowd the daily selection.
            let offset = (state.day * 7 + state.nextWish) % pool.count
            let candidates = Array(pool[offset...]) + pool[..<offset]
            let seasonalIDs: [String: [String]] = [
                "season.spring": ["act.animal.baby", "act.nature.flowers", "act.nature.pond"],
                "season.summer": ["act.field.hay", "act.animal.water", "act.field.harvest"],
                "season.autumn": ["act.kitchen.press", "act.nature.kite", "act.nature.compost"],
                "season.winter": ["act.field.snowplow", "act.nature.snowman", "act.nature.birdhouse", "act.animal.bed"]
            ]
            for _ in 0..<needed {
                let taken = Set(offered.map(\.activityID)).union(state.creditedToday)
                let groups = ["act.animal.", "act.field.", "act.shop."]
                let wanted = groups.first { group in
                    !taken.contains(where: { $0.hasPrefix(group) }) && candidates.contains(where: { $0.id.hasPrefix(group) })
                }
                let last = offered.last?.locationID ?? state.lastLocation
                let seasonal = seasonalIDs[season, default: []]
                func score(_ a: FarmActivity) -> Int {
                    var score = 0
                    if let wanted, a.id.hasPrefix(wanted) { score += 1_000 }
                    if !taken.contains(a.id) { score += 500 }
                    if !state.activityTypes.contains(a.id) { score += 80 }
                    if seasonal.contains(a.id) && !offered.contains(where: { seasonal.contains($0.activityID) }) { score += 50 }
                    if a.locationID != last { score += 32 }
                    if state.adaptive { score += min(25, state.skills.priority(lanes: a.lanes, day: state.day)) }
                    return score
                }
                guard let next = candidates.max(by: { score($0) < score($1) }) else { return }
                appendWish(activity: next)
                offered.append(state.outstanding[state.outstanding.count - 1])
            }
        }

        private mutating func prerequisite(for wish: FarmWish) -> FarmFeedback {
            let routes: [String]
            switch wish.activityID {
            case "act.shop.stock", "act.shop.order", "act.shop.market":
                routes = ["act.field.harvest", "act.animal.eggs", "act.field.water", "act.field.sow"]
            case "act.field.harvest", "act.field.combine", "act.field.water":
                routes = ["act.field.water", "act.field.sow", "act.field.plow"]
            default:
                routes = ["act.field.harvest", "act.animal.milk", "act.field.sow", "act.animal.feed"]
            }
            for id in routes {
                guard let predecessor = catalog.activities.first(where: { $0.id == id }),
                      playable(predecessor, at: predecessor.locationID) else { continue }
                if !state.outstanding.contains(where: { !$0.folded && $0.activityID == id }) { appendWish(activity: predecessor) }
                return FarmFeedback(text: "Dein Wunsch wartet. Zuerst: \(predecessor.title).", voiceID: "vl.pelle.wish.prepare")
            }
            return FarmFeedback(text: "Dein Wunsch bleibt hier. Komm, wir drehen am Jahreskreis.", voiceID: "vl.pelle.wish.season")
        }
}
