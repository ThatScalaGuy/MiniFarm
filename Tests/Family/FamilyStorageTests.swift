import Foundation
import Testing
@testable import MiniFarm

@Suite("FamilyStorage")
struct FamilyStorageTests {
    let root = TemporaryFamilyRoot()
    let storage: FamilyStorage
    let profile: FamilyProfile

    init() throws {
        storage = root.makeStorage()
        profile = FamilyProfile(avatar: .cow, stage: .sprout, createdAt: Date(timeIntervalSince1970: 1_800_000_000))
        try storage.createProfileRecord(profile)
    }

    var folder: URL { storage.folder(for: profile.id) }
    var farmURL: URL { folder.appending(path: "Farm.json") }
    var backupURL: URL { folder.appending(path: "Farm.json.bak") }
    var quarantineURL: URL { folder.appending(path: "Quarantine", directoryHint: .isDirectory) }

    func quarantined() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: quarantineURL.path(percentEncoded: false))) ?? []).sorted()
    }

    func load() -> LoadOutcome<FarmStub> {
        storage.saves(for: profile.id).load(FarmStub.self, slot: .farmStub)
    }

    func save(_ coins: Int) throws {
        try storage.saves(for: profile.id).save(FarmStub(coins: coins), slot: .farmStub, schemaVersion: 1)
    }

    @Test func roundTripKeepsTheLastGoodFileAsBackup() throws {
        #expect(load().value == nil)
        try save(1)
        try save(2)
        guard case .loaded(let value) = load() else {
            Issue.record("Expected a loaded value")
            return
        }
        #expect(value == FarmStub(coins: 2))
        #expect(FileManager.default.fileExists(atPath: backupURL.path(percentEncoded: false)))
        let backupEnvelope = try JSONDecoder.iso.decode(FamilyStorage.Envelope.self, from: Data(contentsOf: backupURL))
        #expect(try JSONDecoder().decode(FarmStub.self, from: backupEnvelope.payload) == FarmStub(coins: 1))
    }

    @Test func payloadCarriesSchemaVersionAndDate() throws {
        try storage.saves(for: profile.id).save(FarmStub(coins: 3), slot: .farmStub, schemaVersion: 7)
        let outcome = storage.saves(for: profile.id).load(slot: .farmStub) { $0 }
        let payload = try #require(outcome.value)
        #expect(payload.schemaVersion == 7)
        #expect(abs(payload.savedAt.timeIntervalSinceNow) < 60)
    }

    @Test func brokenCurrentFileIsRestoredFromBackup() throws {
        try save(1)
        try save(2)
        try Data("{\"container\":1,".utf8).write(to: farmURL)
        guard case .recovered(let value, let report) = load() else {
            Issue.record("Expected recovery")
            return
        }
        #expect(value == FarmStub(coins: 1))
        #expect(report.restoredFromBackup)
        #expect(report.quarantinedFiles.count == 1)
        #expect(quarantined() == report.quarantinedFiles)
        #expect(load().value == FarmStub(coins: 1))
        if case .loaded = load() {} else { Issue.record("Restored file should load directly") }
    }

    @Test func checksumMismatchCountsAsBroken() throws {
        try save(1)
        try save(2)
        var envelope = try JSONDecoder.iso.decode(FamilyStorage.Envelope.self, from: Data(contentsOf: farmURL))
        envelope.payload = try JSONEncoder().encode(FarmStub(coins: 999))
        try JSONEncoder.iso.encode(envelope).write(to: farmURL)
        #expect(load().value == FarmStub(coins: 1))
    }

    @Test func decodeErrorUsesTheBackup() throws {
        try save(1)
        try storage.saves(for: profile.id).write(Data("[]".utf8), slot: .farmStub, schemaVersion: 1)
        guard case .recovered(let value, _) = load() else {
            Issue.record("Expected recovery")
            return
        }
        #expect(value == FarmStub(coins: 1))
    }

    @Test func bothFilesBrokenAreQuarantinedAndReportedOnce() throws {
        try save(1)
        try save(2)
        try Data("garbage".utf8).write(to: farmURL)
        try Data("garbage".utf8).write(to: backupURL)
        guard case .unrecoverable(let report) = load() else {
            Issue.record("Expected unrecoverable")
            return
        }
        #expect(!report.restoredFromBackup)
        #expect(report.quarantinedFiles.count == 2)
        #expect(quarantined().count == 2)
        if case .empty = load() {} else { Issue.record("Second load should be empty") }
        try save(5)
        #expect(load().value == FarmStub(coins: 5))
    }

    @Test func unreadableFileIsNeitherQuarantinedNorOverwritten() throws {
        try save(1)
        try save(2)
        let aside = folder.appending(path: "aside.json")
        try FileManager.default.moveItem(at: farmURL, to: aside)
        try FileManager.default.createDirectory(at: farmURL, withIntermediateDirectories: false)
        guard case .unavailable(.notReadable) = load() else {
            Issue.record("Expected unavailable, got \(load())")
            return
        }
        #expect(quarantined().isEmpty)
        #expect(throws: FamilyStorageError.self) { try save(3) }
        do {
            try save(3)
        } catch let error as FamilyStorageError {
            guard case .existingDataUnavailable(.notReadable) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
            #expect(!error.isDiscardable)
        }

        try FileManager.default.removeItem(at: farmURL)
        try FileManager.default.moveItem(at: aside, to: farmURL)
        #expect(load().value == FarmStub(coins: 2))
    }

    @Test func newerContainerIsLeftAlone() throws {
        try save(1)
        var envelope = try JSONDecoder.iso.decode(FamilyStorage.Envelope.self, from: Data(contentsOf: farmURL))
        envelope.container = 2
        let bytes = try JSONEncoder.iso.encode(envelope)
        try bytes.write(to: farmURL)
        guard case .unavailable(.newerContainer(2)) = load() else {
            Issue.record("Expected newer container")
            return
        }
        #expect(throws: FamilyStorageError.existingDataUnavailable(.newerContainer(2))) { try save(3) }
        #expect(try Data(contentsOf: farmURL) == bytes)
        #expect(quarantined().isEmpty)
    }

    @Test func unsupportedSchemaIsLeftAlone() throws {
        try save(1)
        let outcome = storage.saves(for: profile.id).load(slot: .farmStub) { payload -> FarmStub in
            throw SaveDataUnsupported()
        }
        guard case .unavailable(.unsupportedPayload(schemaVersion: 1)) = outcome else {
            Issue.record("Expected unsupported payload")
            return
        }
        #expect(quarantined().isEmpty)
        #expect(load().value == FarmStub(coins: 1))
    }

    @Test func quarantineKeepsOnlyTheNewestFiles() throws {
        for round in 0..<4 {
            try save(round)
            try Data("x".utf8).write(to: farmURL)
            try Data("y".utf8).write(to: backupURL)
            _ = load()
        }
        #expect(quarantined().count == FamilyStorage.quarantineFilesPerSlot)
    }

    @Test func resetInvalidatesOldHandlesAndKeepsTheProfile() throws {
        let stale = storage.saves(for: profile.id)
        try save(1)
        try Data("x".utf8).write(to: farmURL)
        _ = load()
        #expect(quarantined().count == 1)
        try storage.resetProgress(profile: profile.id)
        #expect(!stale.isValid)
        #expect(throws: FamilyStorageError.sessionInvalidated) {
            try stale.save(FarmStub(coins: 9), slot: .farmStub, schemaVersion: 1)
        }
        #expect(throws: FamilyStorageError.sessionInvalidated) { try stale.remove(slot: .farmStub) }
        if case .empty = load() {} else { Issue.record("Farm should be gone") }
        #expect(quarantined().isEmpty)
        #expect(storage.scanProfiles().profiles == [profile])
        try save(2)
        #expect(load().value == FarmStub(coins: 2))
    }

    @Test func deleteAllInvalidatesEveryHandle() throws {
        let stale = storage.saves(for: profile.id)
        try save(1)
        try storage.deleteAllData()
        #expect(!stale.isValid)
        #expect(throws: FamilyStorageError.profileMissing) {
            try stale.save(FarmStub(coins: 9), slot: .farmStub, schemaVersion: 1)
        }
        #expect(storage.scanProfiles().profiles.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: storage.profilesURL.path(percentEncoded: false)))
        try storage.deleteProfile(profile.id)
    }

    @Test func profileRecordIsRestoredFromBackup() throws {
        var changed = profile
        changed.stage = .bloom
        try storage.updateProfileRecord(changed)
        try Data("x".utf8).write(to: folder.appending(path: "Profile.json"))
        let scan = storage.scanProfiles()
        #expect(scan.profiles == [profile])
        #expect(scan.restored == [profile.id])
    }

    @Test func emptyProfileFolderIsRemovedAndDataWithoutRecordIsReported() throws {
        let empty = ProfileID()
        try FileManager.default.createDirectory(at: storage.folder(for: empty), withIntermediateDirectories: true)
        try save(1)
        try FileManager.default.removeItem(at: folder.appending(path: "Profile.json"))
        try? FileManager.default.removeItem(at: folder.appending(path: "Profile.json.bak"))
        let scan = storage.scanProfiles()
        #expect(scan.profiles.isEmpty)
        #expect(scan.lostRecords == [profile.id])
        #expect(!FileManager.default.fileExists(atPath: storage.folder(for: empty).path(percentEncoded: false)))
        #expect(throws: FamilyStorageError.profileMissing) { try save(2) }
    }

    @Test func storedInfoListsProfileFirst() throws {
        try save(1)
        try save(2)
        let info = storage.storedInfo(for: profile.id)
        #expect(info.slots.map(\.slot.name) == ["Profile", "Farm"])
        let farm = try #require(info.slots.last)
        #expect(farm.hasBackup)
        #expect(farm.bytes > 0)
        #expect(farm.savedAt != nil)
        #expect(info.totalBytes == info.slots.reduce(0) { $0 + $1.bytes })
        #expect(info.quarantinedFiles == 0)
    }

    var profileURL: URL { folder.appending(path: "Profile.json") }

    /// Writes a profile record with a valid checksum, like a different app version would.
    func writeProfileRecord(_ json: [String: Any], schemaVersion: Int) throws -> Data {
        let payload = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        let envelope = FamilyStorage.Envelope(
            container: FamilyStorage.containerVersion,
            schemaVersion: schemaVersion,
            savedAt: Date(timeIntervalSince1970: 1_800_000_100),
            checksum: FamilyStorage.checksum(container: FamilyStorage.containerVersion, schemaVersion: schemaVersion, payload: payload),
            payload: payload
        )
        let bytes = try JSONEncoder.iso.encode(envelope)
        try bytes.write(to: profileURL)
        return bytes
    }

    func profileJSON(_ value: FamilyProfile) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: FamilyStorage.profileEncoder.encode(value)) as? [String: Any])
    }

    @Test func olderProfileWithoutNewerSettingsLoadsWithDefaults() throws {
        var expected = profile
        expected.settings.audio.musicVolume = 0.4
        expected.settings.session.timerMinutes = 30
        var json = try profileJSON(expected)
        json["stageRevision"] = nil
        var settings = try #require(json["settings"] as? [String: Any])
        var audio = try #require(settings["audio"] as? [String: Any])
        audio["monoAudio"] = nil
        settings["audio"] = audio
        settings["comfort"] = nil
        json["settings"] = settings
        _ = try writeProfileRecord(json, schemaVersion: FamilyProfile.schemaVersion)

        let scan = storage.scanProfiles()
        #expect(scan.profiles == [expected])
        #expect(scan.lostRecords.isEmpty && scan.unavailable.isEmpty)
        #expect(quarantined().isEmpty)
    }

    @Test(arguments: ["newerSchema", "unknownAvatar", "unknownCalmMode"])
    func profileFromNewerAppIsKeptUntouched(_ variant: String) throws {
        var changed = profile
        changed.stage = .bloom
        try storage.updateProfileRecord(changed)
        let backupURL = folder.appending(path: "Profile.json.bak")
        let backupBytes = try Data(contentsOf: backupURL)

        var json = try profileJSON(changed)
        var schemaVersion = FamilyProfile.schemaVersion
        switch variant {
        case "newerSchema":
            schemaVersion += 1
        case "unknownAvatar":
            json["avatar"] = "animal.unicorn"
        default:
            var settings = try #require(json["settings"] as? [String: Any])
            var comfort = try #require(settings["comfort"] as? [String: Any])
            comfort["calmMode"] = "sleepy"
            settings["comfort"] = comfort
            json["settings"] = settings
        }
        let bytes = try writeProfileRecord(json, schemaVersion: schemaVersion)

        let scan = storage.scanProfiles()
        #expect(scan.profiles.isEmpty)
        #expect(scan.unavailable == [profile.id])
        #expect(scan.lostRecords.isEmpty)
        #expect(try Data(contentsOf: profileURL) == bytes)
        #expect(try Data(contentsOf: backupURL) == backupBytes)
        #expect(quarantined().isEmpty)
    }

    @Test func slotNamesAreRestricted() {
        #expect(SaveSlot.isValid("Farm"))
        #expect(SaveSlot.isValid("Farm_v2-a"))
        #expect(!SaveSlot.isValid(""))
        #expect(!SaveSlot.isValid("../Farm"))
        #expect(!SaveSlot.isValid("Farm.json"))
        #expect(!SaveSlot.isValid("Höfe"))
        #expect(!SaveSlot.isValid(String(repeating: "a", count: 41)))
    }
}

extension JSONDecoder {
    static let iso: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension JSONEncoder {
    static let iso: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
