import CryptoKit
import Foundation
import Synchronization

/// Local, atomic, offline storage for all family data.
///
/// Layout below `root`:
/// ```
/// Profiles/<uuid>/Profile.json(.bak)   profile and settings
/// Profiles/<uuid>/<Slot>.json(.bak)    gameplay data
/// Profiles/<uuid>/Quarantine/          broken files that could not be recovered
/// Trash/                               short lived, emptied on start
/// ```
/// All file work runs under one lock, so the type is safe to call from any thread.
final class FamilyStorage: Sendable {
    struct Generation: Equatable, Sendable {
        fileprivate let epoch: Int
        fileprivate let counter: Int
    }

    static let containerVersion = 1
    static let quarantineFilesPerSlot = 4

    let root: URL
    private let lock = Mutex(Generations())
    private let now: @Sendable () -> Date

    init(root: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        self.root = root
        self.now = now
        try? FileManager.default.removeItem(at: trashURL)
    }

    static func defaultRoot(folderName: String = "Family", base: URL = .applicationSupportDirectory) -> URL {
        base
            .appending(path: "MiniFarm", directoryHint: .isDirectory)
            .appending(path: folderName, directoryHint: .isDirectory)
    }

    var profilesURL: URL { root.appending(path: "Profiles", directoryHint: .isDirectory) }
    private var trashURL: URL { root.appending(path: "Trash", directoryHint: .isDirectory) }

    func folder(for profile: ProfileID) -> URL {
        profilesURL.appending(path: profile.directoryName, directoryHint: .isDirectory)
    }

    // MARK: Save handles

    func saves(for profile: ProfileID) -> ProfileSaves {
        let generation = lock.withLock { $0.generation(for: profile) }
        return ProfileSaves(storage: self, profile: profile, generation: generation)
    }

    func isCurrent(_ generation: Generation, for profile: ProfileID) -> Bool {
        lock.withLock { $0.generation(for: profile) == generation }
    }

    // MARK: Slots

    func write(_ data: Data, slot: SaveSlot, schemaVersion: Int, profile: ProfileID, generation: Generation) throws {
        let envelope = try makeEnvelope(payload: data, schemaVersion: schemaVersion)
        try lock.withLock { state in
            let folder = folder(for: profile)
            guard Self.hasProfileRecord(in: folder) else { throw FamilyStorageError.profileMissing }
            guard state.generation(for: profile) == generation else { throw FamilyStorageError.sessionInvalidated }
            try replace(slot: slot, in: folder, with: envelope)
        }
    }

    func remove(slot: SaveSlot, profile: ProfileID, generation: Generation) throws {
        try lock.withLock { state in
            let folder = folder(for: profile)
            guard Self.hasProfileRecord(in: folder) else { throw FamilyStorageError.profileMissing }
            guard state.generation(for: profile) == generation else { throw FamilyStorageError.sessionInvalidated }
            for name in [slot.fileName, slot.backupFileName] {
                try Self.removeIfPresent(folder.appending(path: name))
            }
        }
    }

    /// Loads a slot. Bytes are read under the lock; `decode` runs outside it.
    func load<Value>(slot: SaveSlot, profile: ProfileID, repair: Bool = true,
                     decode: (StoredPayload) throws -> Value) -> LoadOutcome<Value> {
        let folder = folder(for: profile)
        for _ in 0..<3 {
            let snapshot = lock.withLock { _ in Self.readPair(slot: slot, in: folder) }
            let current = Self.evaluate(snapshot.current, decode: decode)
            if case .valid(let value) = current { return .loaded(value) }
            if case .unavailable(let failure) = current { return .unavailable(failure) }

            let backup = Self.evaluate(snapshot.backup, decode: decode)
            let currentIsCorrupt = if case .corrupt = current { true } else { false }
            switch backup {
            case .unavailable(let failure):
                return .unavailable(failure)
            case .absent where !currentIsCorrupt:
                return .empty
            case .valid(let value):
                if !repair { return .loaded(value) }
                do {
                    let report = try lock.withLock { _ -> RecoveryReport? in
                        guard Self.readPair(slot: slot, in: folder) == snapshot,
                              case .data(let bytes) = snapshot.backup else { return nil }
                        var moved: [String] = []
                        let file = folder.appending(path: slot.fileName)
                        if currentIsCorrupt, let name = quarantine(file, slot: slot, role: "current") {
                            moved.append(name)
                        }
                        try Self.writeAtomically(bytes, to: file)
                        return RecoveryReport(slot: slot, restoredFromBackup: true, quarantinedFiles: moved)
                    }
                    if let report { return .recovered(value, report) }
                } catch {
                    return .unavailable(.restoreFailed(code: (error as NSError).code))
                }
            case .absent, .corrupt:
                if !repair {
                    return .unrecoverable(RecoveryReport(slot: slot, restoredFromBackup: false, quarantinedFiles: []))
                }
                let report = lock.withLock { _ -> RecoveryReport? in
                    guard Self.readPair(slot: slot, in: folder) == snapshot else { return nil }
                    var moved: [String] = []
                    if let name = quarantine(folder.appending(path: slot.fileName), slot: slot, role: "current") {
                        moved.append(name)
                    }
                    if case .corrupt = backup,
                       let name = quarantine(folder.appending(path: slot.backupFileName), slot: slot, role: "backup") {
                        moved.append(name)
                    }
                    return RecoveryReport(slot: slot, restoredFromBackup: false, quarantinedFiles: moved)
                }
                if let report { return .unrecoverable(report) }
            }
            // Files changed while decoding. Read again.
        }
        return .unavailable(.notReadable(code: CocoaError.fileReadUnknown.rawValue))
    }

    // MARK: Profiles

    struct ProfileScan: Sendable {
        var profiles: [FamilyProfile] = []
        /// Profile record was broken and restored from its backup.
        var restored: [ProfileID] = []
        /// Folder holds data but no readable profile record. Needs a new record.
        var lostRecords: [ProfileID] = []
        /// Profile data exists but cannot be read now.
        var unavailable: [ProfileID] = []
    }

    func scanProfiles() -> ProfileScan {
        var scan = ProfileScan()
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: profilesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for folder in folders {
            guard let id = ProfileID(directoryName: folder.lastPathComponent) else { continue }
            let outcome = load(slot: .profile, profile: id, decode: Self.decodeProfile)
            switch outcome {
            case .loaded(let profile):
                scan.profiles.append(profile.withID(id))
            case .recovered(let profile, _):
                scan.profiles.append(profile.withID(id))
                scan.restored.append(id)
            case .unavailable:
                scan.unavailable.append(id)
            case .unrecoverable:
                scan.lostRecords.append(id)
            case .empty:
                if removeFolderIfItHoldsNoData(folder) == false {
                    scan.lostRecords.append(id)
                }
            }
        }
        scan.profiles.sort { ($0.createdAt, $0.id.directoryName) < ($1.createdAt, $1.id.directoryName) }
        return scan
    }

    /// Creates the folder if needed and writes the profile record.
    func createProfileRecord(_ profile: FamilyProfile) throws {
        let envelope = try makeEnvelope(payload: Self.profileEncoder.encode(profile), schemaVersion: FamilyProfile.schemaVersion)
        try lock.withLock { _ in
            let folder = folder(for: profile.id)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try replace(slot: .profile, in: folder, with: envelope)
        }
    }

    /// Updates an existing profile record. Throws `profileMissing` after deletion.
    func updateProfileRecord(_ profile: FamilyProfile) throws {
        let envelope = try makeEnvelope(payload: Self.profileEncoder.encode(profile), schemaVersion: FamilyProfile.schemaVersion)
        try lock.withLock { _ in
            let folder = folder(for: profile.id)
            guard Self.hasProfileRecord(in: folder) else { throw FamilyStorageError.profileMissing }
            try replace(slot: .profile, in: folder, with: envelope)
        }
    }

    /// Removes all gameplay data of a profile. Keeps the profile and its settings.
    func resetProgress(profile: ProfileID) throws {
        try lock.withLock { state in
            state.invalidate(profile)
            let folder = folder(for: profile)
            guard Self.hasProfileRecord(in: folder) else { throw FamilyStorageError.profileMissing }
            let keep: Set = [SaveSlot.profile.fileName, SaveSlot.profile.backupFileName]
            let items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                .filter { !keep.contains($0.lastPathComponent) }
            guard !items.isEmpty else { return }
            let bin = try makeTrashFolder()
            for item in items {
                try FileManager.default.moveItem(at: item, to: bin.appending(path: item.lastPathComponent))
            }
            try? FileManager.default.removeItem(at: bin)
        }
    }

    /// Removes a profile with all its files. Safe to call twice.
    func deleteProfile(_ profile: ProfileID) throws {
        try lock.withLock { state in
            state.invalidate(profile)
            let folder = folder(for: profile)
            guard FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) else { return }
            let bin = try makeTrashFolder()
            try FileManager.default.moveItem(at: folder, to: bin.appending(path: profile.directoryName))
            try? FileManager.default.removeItem(at: bin)
        }
    }

    /// Removes every profile and all family data.
    func deleteAllData() throws {
        try lock.withLock { state in
            state.invalidateAll()
            if FileManager.default.fileExists(atPath: profilesURL.path(percentEncoded: false)) {
                let bin = try makeTrashFolder()
                try FileManager.default.moveItem(at: profilesURL, to: bin.appending(path: "Profiles"))
            }
            try? FileManager.default.removeItem(at: trashURL)
        }
    }

    /// What is stored for one profile, for the parent area.
    func storedInfo(for profile: ProfileID) -> StoredProfileInfo {
        lock.withLock { _ in
            let folder = folder(for: profile)
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            var slots: [String: StoredSlotInfo] = [:]
            var total = 0
            for file in files where !file.hasDirectoryPath {
                let name = file.lastPathComponent
                let size = Self.fileSize(file)
                total += size
                let isBackup = name.hasSuffix(".json.bak")
                guard isBackup || name.hasSuffix(".json") else { continue }
                let slotName = String(name.dropLast(isBackup ? 9 : 5))
                guard SaveSlot.isValid(slotName) else { continue }
                let slot = slotName == SaveSlot.profile.name ? SaveSlot.profile : SaveSlot(slotName)
                var info = slots[slotName] ?? StoredSlotInfo(slot: slot, bytes: 0, savedAt: nil, hasBackup: false)
                info.bytes += size
                if isBackup {
                    info.hasBackup = true
                } else if let bytes = try? Data(contentsOf: file), case .valid(let envelope) = Self.inspect(bytes) {
                    info.savedAt = envelope.savedAt
                }
                slots[slotName] = info
            }
            let quarantined = (try? FileManager.default.contentsOfDirectory(
                at: folder.appending(path: "Quarantine", directoryHint: .isDirectory),
                includingPropertiesForKeys: [.fileSizeKey]
            )) ?? []
            total += quarantined.reduce(0) { $0 + Self.fileSize($1) }
            let ordered = slots.values.sorted { lhs, rhs in
                if lhs.slot == .profile { return rhs.slot != .profile }
                if rhs.slot == .profile { return false }
                return lhs.slot.name < rhs.slot.name
            }
            return StoredProfileInfo(slots: ordered, quarantinedFiles: quarantined.count, totalBytes: total)
        }
    }

    // MARK: Internals

    private struct Generations {
        var epoch = 0
        var counters: [ProfileID: Int] = [:]

        func generation(for profile: ProfileID) -> Generation {
            Generation(epoch: epoch, counter: counters[profile, default: 0])
        }

        mutating func invalidate(_ profile: ProfileID) {
            counters[profile, default: 0] += 1
        }

        mutating func invalidateAll() {
            epoch += 1
        }
    }

    struct Envelope: Codable, Sendable {
        var container: Int
        var schemaVersion: Int
        var savedAt: Date
        var checksum: String
        var payload: Data
    }

    private struct EnvelopeHeader: Decodable {
        var container: Int
    }

    enum FileRead: Equatable, Sendable {
        case absent
        case data(Data)
        case failed(code: Int)
    }

    private struct FilePair: Equatable, Sendable {
        var current: FileRead
        var backup: FileRead
    }

    private enum Inspection {
        case valid(Envelope)
        case corrupt
        case newerContainer(Int)
    }

    private enum Evaluation<Value> {
        case absent
        case valid(Value)
        case corrupt
        case unavailable(FamilyStorageReadFailure)
    }

    static let profileEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let profileDecoder = JSONDecoder()

    /// The checksum already proved that the bytes are intact. A record this build cannot read comes from a
    /// newer app version, so it stays untouched as unavailable instead of being quarantined and replaced.
    static func decodeProfile(_ payload: StoredPayload) throws -> FamilyProfile {
        guard payload.schemaVersion <= FamilyProfile.schemaVersion else { throw SaveDataUnsupported() }
        do {
            return try profileDecoder.decode(FamilyProfile.self, from: payload.data)
        } catch is DecodingError {
            throw SaveDataUnsupported()
        }
    }

    private static let envelopeEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let envelopeDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func checksum(container: Int, schemaVersion: Int, payload: Data) -> String {
        var hasher = SHA256()
        hasher.update(data: Data("minifarm:\(container):\(schemaVersion):".utf8))
        hasher.update(data: payload)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func makeEnvelope(payload: Data, schemaVersion: Int) throws -> Data {
        let envelope = Envelope(
            container: Self.containerVersion,
            schemaVersion: schemaVersion,
            savedAt: now(),
            checksum: Self.checksum(container: Self.containerVersion, schemaVersion: schemaVersion, payload: payload),
            payload: payload
        )
        return try Self.envelopeEncoder.encode(envelope)
    }

    private static func inspect(_ bytes: Data) -> Inspection {
        guard let header = try? envelopeDecoder.decode(EnvelopeHeader.self, from: bytes) else { return .corrupt }
        if header.container > containerVersion { return .newerContainer(header.container) }
        guard header.container >= 1,
              let envelope = try? envelopeDecoder.decode(Envelope.self, from: bytes),
              envelope.checksum == checksum(
                  container: envelope.container,
                  schemaVersion: envelope.schemaVersion,
                  payload: envelope.payload
              )
        else { return .corrupt }
        return .valid(envelope)
    }

    private static func evaluate<Value>(_ read: FileRead, decode: (StoredPayload) throws -> Value) -> Evaluation<Value> {
        switch read {
        case .absent:
            return .absent
        case .failed(let code):
            return .unavailable(.notReadable(code: code))
        case .data(let bytes):
            switch inspect(bytes) {
            case .corrupt:
                return .corrupt
            case .newerContainer(let version):
                return .unavailable(.newerContainer(version))
            case .valid(let envelope):
                let payload = StoredPayload(data: envelope.payload, schemaVersion: envelope.schemaVersion, savedAt: envelope.savedAt)
                do {
                    return .valid(try decode(payload))
                } catch let error as SaveDataUnsupported {
                    return .unavailable(.unsupportedPayload(schemaVersion: error.schemaVersion ?? envelope.schemaVersion))
                } catch {
                    return .corrupt
                }
            }
        }
    }

    static func read(_ url: URL) -> FileRead {
        do {
            return .data(try Data(contentsOf: url))
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain, nsError.code == CocoaError.fileReadNoSuchFile.rawValue {
                return .absent
            }
            if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(ENOENT) {
                return .absent
            }
            return .failed(code: nsError.code)
        }
    }

    private static func readPair(slot: SaveSlot, in folder: URL) -> FilePair {
        FilePair(
            current: read(folder.appending(path: slot.fileName)),
            backup: read(folder.appending(path: slot.backupFileName))
        )
    }

    /// Keeps the last good file as backup, then replaces the current file atomically.
    /// A current file that cannot be checked is never overwritten.
    private func replace(slot: SaveSlot, in folder: URL, with envelope: Data) throws {
        let current = folder.appending(path: slot.fileName)
        switch Self.read(current) {
        case .absent:
            break
        case .failed(let code):
            throw FamilyStorageError.existingDataUnavailable(.notReadable(code: code))
        case .data(let bytes):
            switch Self.inspect(bytes) {
            case .valid:
                try Self.writeAtomically(bytes, to: folder.appending(path: slot.backupFileName))
            case .newerContainer(let version):
                throw FamilyStorageError.existingDataUnavailable(.newerContainer(version))
            case .corrupt:
                break
            }
        }
        try Self.writeAtomically(envelope, to: current)
    }

    static func writeAtomically(_ data: Data, to url: URL) throws {
        var options: Data.WritingOptions = [.atomic]
        #if os(iOS)
        options.insert(.completeFileProtectionUntilFirstUserAuthentication)
        #endif
        try data.write(to: url, options: options)
    }

    /// Moves a broken file into `Quarantine/`. Returns the new file name.
    private func quarantine(_ file: URL, slot: SaveSlot, role: String) -> String? {
        guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else { return nil }
        let folder = file.deletingLastPathComponent().appending(path: "Quarantine", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let stamp = String(format: "%015.0f", (now().timeIntervalSince1970 * 1000).rounded())
            let name = "\(slot.name).\(stamp).\(UUID().uuidString.prefix(8)).\(role).json"
            try FileManager.default.moveItem(at: file, to: folder.appending(path: name))
            pruneQuarantine(folder, slot: slot)
            return name
        } catch {
            return nil
        }
    }

    private func pruneQuarantine(_ folder: URL, slot: SaveSlot) {
        let prefix = slot.name + "."
        let files = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for file in files.dropFirst(Self.quarantineFilesPerSlot) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func makeTrashFolder() throws -> URL {
        let bin = trashURL.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        return bin
    }

    /// Removes a profile folder that holds no slot data. Returns false if data was found.
    private func removeFolderIfItHoldsNoData(_ folder: URL) -> Bool {
        lock.withLock { _ in
            let items = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            let hasData = items.contains { item in
                let name = item.lastPathComponent
                return name.hasSuffix(".json") || name.hasSuffix(".json.bak")
            }
            guard !hasData else { return false }
            try? FileManager.default.removeItem(at: folder)
            return true
        }
    }

    private static func hasProfileRecord(in folder: URL) -> Bool {
        let manager = FileManager.default
        return manager.fileExists(atPath: folder.appending(path: SaveSlot.profile.fileName).path(percentEncoded: false))
            || manager.fileExists(atPath: folder.appending(path: SaveSlot.profile.backupFileName).path(percentEncoded: false))
    }

    private static func removeIfPresent(_ url: URL) throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch CocoaError.fileNoSuchFile {
            return
        }
    }

    private static func fileSize(_ url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }
}

private extension FamilyProfile {
    func withID(_ id: ProfileID) -> FamilyProfile {
        guard self.id != id else { return self }
        return FamilyProfile(
            id: id,
            avatar: avatar,
            stage: stage,
            stageRevision: stageRevision,
            createdAt: createdAt,
            settings: settings
        )
    }
}
