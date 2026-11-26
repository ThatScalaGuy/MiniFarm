import Foundation

extension FarmGame {
    private var worldOffers: [WorldOffering] {
        let wishes = wishes.map {
            WorldOffering(id: $0.id, activityID: $0.activityID, locationID: $0.locationID, subjectID: $0.giver)
        }
        let freePlay = locations.flatMap { location in
            activities(at: location.id).map { activity in
                WorldOffering(
                    id: "\(location.id)/\(activity.id)", activityID: activity.id,
                    locationID: location.id, isWish: false
                )
            }
        }
        return wishes + freePlay
    }

    func worldSnapshot(settings: FamilyRuntimeSettings, caption: String?, showPlaza: Bool = false,
                       timer: SessionTimer.Phase = .off, story: FarmNightStory? = nil, paused: Bool = false) -> FarmWorldState {
        let offers = worldOffers
        var view = FarmWorldState(locationIDs: locations.map(\.id), offerings: offers, active: nil)
        view.locationID = state.locationID == "loc.plaza" && !showPlaza ? nil : state.locationID
        if let prompt {
            let id = state.active?.wishID ?? "\(prompt.locationID)/\(prompt.activityID)"
            let offer = offers.first { $0.id == id }
                ?? WorldOffering(id: id, activityID: prompt.activityID, locationID: prompt.locationID, isWish: state.active?.wishID != nil)
            view.active = WorldTurn(
                offering: offer, stepID: prompt.stepID, stepIndex: prompt.stepIndex, stepCount: prompt.stepCount,
                choices: prompt.choices.map { WorldChoice(id: $0.id, modelID: $0.modelID, label: $0.title, symbol: $0.symbol) },
                targetID: prompt.targetID, helpLevel: prompt.assist.rawValue,
                workGear: prompt.workGear, workBeds: prompt.workBeds
            )
        }
        view.beds = beds.map {
            let phase = switch $0.phase {
            case "seeded": "seed"
            case "sprouting": "sprout"
            default: $0.phase
            }
            return WorldBed(id: $0.id, locationID: $0.locationID, cropID: $0.cropID, growth: phase, watered: $0.watered)
        }
        view.inventory = state.production.inventory
        view.decorations = state.life.placements.sorted { $0.key < $1.key }.map {
            WorldDecoration(positionID: $0.key, decorationID: $0.value.decorationID, quarterTurns: $0.value.quarterTurns)
        }
        view.shelf = state.production.shelf
        view.coins = state.coins
        view.nightStory = story
        view.paused = paused
        view.secondsUntilIdleHint = secondsUntilIdleHint
        view.caredFor = caredAnimalIDs
        let discoverable = Set(locations.flatMap { discoveries(at: $0.id) }.map(\.id))
        view.book = catalog.hofbook.map { entry in
            var sticker = WorldSticker(id: entry.id, modelID: entry.modelID, label: entry.title, discovered: state.book.contains(entry.id))
            sticker.locationID = discoverable.contains(entry.id) ? entry.locationID : nil
            return sticker
        }
        view.farmLevel = state.level
        view.season = season
        view.weather = weather
        view.sunProgress = sunProgress
        view.invitesRest = suggestsRest || sunProgress >= 1
        switch timer {
        case .tired: view.invitesRest = true
        case .windDown: view.invitesRest = true; view.eveningDue = true
        default: break
        }
        view.caption = settings.subtitles ? caption : nil
        view.largeControls = settings.touchTargetScale > 1
        view.quiet = settings.essentialSFXOnly
        view.reduceMotion = settings.reduceMotion
        view.haptics = settings.hapticsEnabled
        view.cameraSpeedScale = settings.cameraSpeedScale
        view.particleScale = settings.weatherParticles ? settings.particleScale : 0
        switch state.stage {
        case .sprout: view.stage = .seedling
        case .shoot: view.stage = .shoot
        case .bloom: view.stage = .bloom
        }
        return view
    }

    func gameIntent(for input: FarmWorldIntent) -> FarmIntent? {
        switch input {
        case let .visit(id): return .visit(id)
        case let .begin(id):
            guard let offer = worldOffers.first(where: { $0.id == id }) else { return nil }
            return offer.isWish ? .startWish(offer.id) : .startActivityAt(offer.activityID, offer.locationID)
        case let .perform(choice):
            guard let prompt else { return nil }
            return .choose(choice ?? prompt.targetID)
        case .help: return .askPelle
        case .idleHint(let seconds): return .idle(seconds: seconds)
        case .leaveActivity: return .goHome
        case .discover(let id): return .discover(id)
        case .endDay: return .sleep
        case .nextSeason: return .nextSeason
        case .pause, .readSticker, .decorationBox, .readStory, .closeNightStory, .horn: return nil
        }
    }
}
