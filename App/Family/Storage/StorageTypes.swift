import CryptoKit
import Foundation

/// Name of a save file inside a profile folder, for example `"Farm"`.
struct SaveSlot: Hashable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
    static let profile = SaveSlot(uncheckedName: "Profile")

    let name: String

    /// Allowed: `A-Z a-z 0-9 _ -`, 1 to 40 characters. `"Profile"` is reserved for the family store.
    init(_ name: String) {
        precondition(Self.isValid(name), "Invalid save slot name: \(name)")
        precondition(name != Self.profile.name, "The slot name Profile is reserved")
        self.name = name
    }

    init(stringLiteral value: String) {
        self.init(value)
    }

    private init(uncheckedName: String) {
        name = uncheckedName
    }

    static func isValid(_ name: String) -> Bool {
        guard (1...40).contains(name.count) else { return false }
        return name.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || scalar == "-")
        }
    }

    var description: String { name }
    var fileName: String { name + ".json" }
    var backupFileName: String { name + ".json.bak" }
}

/// Bytes handed to the decode closure of `load`.
struct StoredPayload: Sendable {
    var data: Data
    /// Version the caller passed when saving. Migrate or throw.
    var schemaVersion: Int
    var savedAt: Date
}

/// Throw this from a decode closure when the data comes from a newer app version.
/// The file is kept untouched and `load` returns `.unavailable(.unsupportedPayload)`.
struct SaveDataUnsupported: Error, Sendable {
    init() {}
}

/// Why existing data could not be read right now. Never quarantined, the file stays as it is.
enum FamilyStorageReadFailure: Error, Equatable, Sendable {
    /// File exists but reading failed, for example data protection before first unlock or an I/O error.
    case notReadable(code: Int)
    /// Written by a newer storage container format.
    case newerContainer(Int)
    /// The decode closure threw `SaveDataUnsupported`.
    case unsupportedPayload(schemaVersion: Int)
}

enum FamilyStorageError: Error, Equatable, Sendable {
    /// The profile was deleted or never existed. Late writes are refused.
    case profileMissing
    /// The handle is from before a reset or deletion. Late writes are refused.
    case sessionInvalidated
    /// The current file could not be checked, so it is not overwritten.
    case existingDataUnavailable(FamilyStorageReadFailure)

    /// True when the write can be dropped silently, for example a late autosave after a reset.
    var isDiscardable: Bool {
        switch self {
        case .profileMissing, .sessionInvalidated: true
        default: false
        }
    }
}

struct RecoveryReport: Equatable, Sendable {
    var slot: SaveSlot
    /// True when the backup was used and written back as the current file.
    var restoredFromBackup: Bool
    /// Names of files moved into `Quarantine/`.
    var quarantinedFiles: [String]
}

enum LoadOutcome<Value> {
    /// Nothing saved yet.
    case empty
    case loaded(Value)
    /// The current file was broken. The backup was used and restored. Continue silently.
    case recovered(Value, RecoveryReport)
    /// Current file and backup were broken and moved to quarantine. Start fresh.
    case unrecoverable(RecoveryReport)
    /// Data exists but cannot be read now. Do not save fresh state over it; try again later.
    case unavailable(FamilyStorageReadFailure)

    var value: Value? {
        switch self {
        case .loaded(let value), .recovered(let value, _): value
        default: nil
        }
    }
}

extension LoadOutcome: Sendable where Value: Sendable {}

struct StoredSlotInfo: Equatable, Sendable, Identifiable {
    var slot: SaveSlot
    var bytes: Int
    var savedAt: Date?
    var hasBackup: Bool

    var id: String { slot.name }
}

struct StoredProfileInfo: Equatable, Sendable {
    var slots: [StoredSlotInfo]
    var quarantinedFiles: Int
    var totalBytes: Int
}

/// Save handle for one profile and one play session.
///
/// A reset, profile deletion or full deletion makes older handles stale. Their writes then throw
/// `FamilyStorageError.sessionInvalidated` or `.profileMissing`, so a late autosave cannot bring old data back.
struct ProfileSaves: Sendable {
    let storage: FamilyStorage
    let profile: ProfileID
    let generation: FamilyStorage.Generation

    var isValid: Bool { storage.isCurrent(generation, for: profile) }

    func write(_ data: Data, slot: SaveSlot, schemaVersion: Int) throws {
        try storage.write(data, slot: slot, schemaVersion: schemaVersion, profile: profile, generation: generation)
    }

    func save<T: Encodable>(_ value: T, slot: SaveSlot, schemaVersion: Int, encoder: JSONEncoder = JSONEncoder()) throws {
        try write(encoder.encode(value), slot: slot, schemaVersion: schemaVersion)
    }

    /// Visiting another farm may read a valid backup, but must not restore or quarantine either copy.
    func load<Value>(slot: SaveSlot, repair: Bool = true, decode: (StoredPayload) throws -> Value) -> LoadOutcome<Value> {
        storage.load(slot: slot, profile: profile, repair: repair, decode: decode)
    }

    func load<T: Decodable>(
        _ type: T.Type,
        slot: SaveSlot,
        decoder: JSONDecoder = JSONDecoder()
    ) -> LoadOutcome<T> {
        load(slot: slot) { payload in try decoder.decode(type, from: payload.data) }
    }

    func remove(slot: SaveSlot) throws {
        try storage.remove(slot: slot, profile: profile, generation: generation)
    }
}
