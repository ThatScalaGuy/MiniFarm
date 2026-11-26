import Foundation

/// Transient presentation data, constructed from the two sides of one saved
/// intent on the same profile. None of the story controls receives a FarmGame.
struct FarmNightStory: Equatable {
    struct Growth: Equatable {
        enum Phase: String {
            case seeded, sprouting, growing, ripe
        }

        let cropID: String
        let from, to: Phase
    }

    let day: Int
    let deeds: [String]
    let growth: Growth?

    init?(before: FarmGame, after: FarmGame) {
        guard after.state.day == before.state.day + 1 else { return nil }
        day = before.state.day
        let activities = before.state.creditedToday.union(before.state.freeToday.compactMap {
            $0.split(separator: "/", maxSplits: 1).first.map(String.init)
        })
        deeds = before.catalog.activities.map(\.id).filter(activities.contains)

        let oldPlots = Dictionary(uniqueKeysWithValues: before.state.production.plots.map { ($0.id, $0) })
        let changes = after.state.production.plots.compactMap { plot -> Growth? in
            guard let old = oldPlots[plot.id], let crop = plot.cropID, old.cropID == crop,
                  plot.nightsLeft < old.nightsLeft || (!old.isRipe && plot.isRipe),
                  let from = Growth.Phase(rawValue: old.phase),
                  let to = Growth.Phase(rawValue: plot.phase) else { return nil }
            return Growth(cropID: crop, from: from, to: to)
        }
        growth = changes.first { $0.to == .ripe } ?? changes.first
    }
}

struct FarmLevelParcel: Identifiable {
    let id: Int
    let gifts: [String]

    init?(before: FarmGame, after: FarmGame) {
        guard before.state.day == after.state.day, after.state.level > before.state.level else { return nil }
        id = after.state.level
        let unlocked = (before.state.level + 1)...after.state.level
        // One example of each kind of actual unlock, not an inventory award.
        gifts = [
            after.catalog.animals.first { unlocked.contains($0.level) }?.id,
            after.catalog.crops.first { unlocked.contains($0.level) && $0.seedItemID != nil }?.seedItemID,
            after.catalog.machines.first { unlocked.contains($0.level) }?.id,
        ].compactMap { $0 }
    }
}

struct FarmFestivalAlbum: Identifiable {
    let id: String
    let title: String
    let photos: [FarmLife.Photo]

    init?(entryID: String, game: FarmGame) {
        guard game.state.book.contains(entryID),
              let season = game.catalog.seasons.first(where: { "hofbook." + $0.festivalID == entryID }) else { return nil }
        let earned = game.state.life.photos.filter { $0.occasionID == season.festivalID && $0.season == season.id }
        guard !earned.isEmpty else { return nil }
        id = entryID
        title = season.festivalTitle
        photos = earned.sorted { $0.day < $1.day }
    }
}
