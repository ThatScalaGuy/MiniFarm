import Foundation

// Compiled together with the app's own gameplay, world-bridge and family-storage sources by
// Tools/Performance/measure.sh, so the QA save uses the real envelope, checksum and schema.

/// Fixed so repeated runs replace the same labelled QA profile instead of adding new ones.
let qaProfileID = ProfileID(UUID(uuidString: "0A0A0A0A-F00D-4A0A-8A0A-00000000C0DE")!)
let qaAvatar = ProfileAvatar.rabbit

func fullyUnlockedGame(content: URL) throws -> FarmGame {
    let catalog = try FarmCatalog.load(from: content)
    let start = FarmGame(catalog: catalog, stage: .bloom)
    guard var fields = try JSONSerialization.jsonObject(with: JSONEncoder().encode(start.state)) as? [String: Any] else {
        throw QAFarmError("FarmState is not a JSON object")
    }
    // The last level milestone in FarmGame.updateLevel: 100 tree wishes and 14 activity types.
    fields["level"] = 5
    fields["treeWishes"] = 100
    fields["activityTypes"] = Array(catalog.activities.map(\.id).sorted().prefix(14))
    fields["introduction"] = 6
    let state = try JSONDecoder().decode(FarmState.self, from: JSONSerialization.data(withJSONObject: fields))
    var game = FarmGame(catalog: catalog, state: state)
    // A real night prepares beds, animals and wishes for the new level through the game rules.
    _ = game.send(.sleep)
    guard game.state.level == 5, game.locations.count == catalog.locations.count else {
        throw QAFarmError("QA farm unlocked \(game.locations.count) of \(catalog.locations.count) locations")
    }
    return game
}

func writeFarm(content: URL, familyRoot: URL) throws {
    let game = try fullyUnlockedGame(content: content)
    let storage = FamilyStorage(root: familyRoot)
    try? FileManager.default.removeItem(at: storage.folder(for: qaProfileID))
    try storage.createProfileRecord(FamilyProfile(id: qaProfileID, avatar: qaAvatar, stage: .bloom))
    try storage.saves(for: qaProfileID).save(game.state, slot: "Farm", schemaVersion: 1)
    let scan = storage.scanProfiles()
    guard scan.profiles.contains(where: { $0.id == qaProfileID }),
          storage.saves(for: qaProfileID).load(slot: "Farm", decode: { try JSONDecoder().decode(FarmState.self, from: $0.data) }).value?.level == 5
    else { throw QAFarmError("QA farm could not be read back") }
    print(#"{"qaFarm":"\#(qaAvatar.rawValue)","level":5,"locations":\#(game.locations.count),"profiles":\#(scan.profiles.count)}"#)
}

func benchmarkProjection(content: URL, iterations: Int) throws {
    let game = try fullyUnlockedGame(content: content)
    let settings = FamilyRuntimeSettings(profile: FamilyProfile(avatar: qaAvatar, stage: .bloom), system: .init())
    var checksum = 0
    for _ in 0..<min(20, iterations) {
        checksum &+= game.worldSnapshot(settings: settings, caption: nil).offerings.count
    }
    let clock = ContinuousClock()
    var samples: [Double] = []
    samples.reserveCapacity(iterations)
    for _ in 0..<iterations {
        let start = clock.now
        let world = game.worldSnapshot(settings: settings, caption: nil)
        samples.append((clock.now - start) / .microseconds(1))
        checksum &+= world.offerings.count + world.locationIDs.count
    }
    let sorted = samples.sorted()
    func quantile(_ q: Double) -> Double { sorted[min(sorted.count - 1, Int((Double(sorted.count - 1) * q).rounded()))] }
    let world = game.worldSnapshot(settings: settings, caption: nil)
    let fields: [String: Any] = [
        "metric": "projection", "unit": "us", "samples": iterations,
        "median": quantile(0.5), "p95": quantile(0.95), "min": sorted[0], "max": sorted[sorted.count - 1],
        "locations": world.locationIDs.count, "offerings": world.offerings.count, "checksum": checksum,
    ]
    let line = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    print("MINIFARM_PERF " + String(decoding: line, as: UTF8.self))
}

struct QAFarmError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

let arguments = CommandLine.arguments
do {
    switch (arguments.count > 1 ? arguments[1] : "", arguments.count) {
    case ("farm", 4):
        try writeFarm(content: URL(fileURLWithPath: arguments[2]), familyRoot: URL(fileURLWithPath: arguments[3]))
    case ("projection", 3), ("projection", 4):
        let iterations = arguments.count == 4 ? Int(arguments[3]) ?? 0 : 500
        guard iterations > 0 else { throw QAFarmError("iterations must be positive") }
        try benchmarkProjection(content: URL(fileURLWithPath: arguments[2]), iterations: iterations)
    default:
        throw QAFarmError("usage: qafarm farm <Content> <Family root> | qafarm projection <Content> [iterations]")
    }
} catch {
    FileHandle.standardError.write(Data("qafarm: \(error)\n".utf8))
    exit(1)
}
