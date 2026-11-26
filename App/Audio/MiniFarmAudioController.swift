@preconcurrency import AVFoundation
import Foundation

// Delegate callbacks can arrive off-main. Retain the object until its identity
// is checked on the main actor, without accessing the object across actors.
private struct PlaybackIdentity: @unchecked Sendable {
    let identifier: ObjectIdentifier
    private let retainedObject: AnyObject

    init(_ object: AnyObject) {
        identifier = ObjectIdentifier(object)
        retainedObject = object
    }
}

public struct MiniFarmAudioLevels: Sendable {
    public var voice: Float
    public var soundEffects: Float
    public var music: Float
    public var ambient: Float

    public init(voice: Float = 1, soundEffects: Float = 0.6, music: Float = 0.25, ambient: Float = 0.2) {
        self.voice = voice
        self.soundEffects = soundEffects
        self.music = music
        self.ambient = ambient
    }
}

public struct MiniFarmAudioProfileSettings: Sendable {
    public var levels: MiniFarmAudioLevels
    public var subtitlesEnabled: Bool
    private var storedSpeechRate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.9

    /// AVSpeechUtterance rate, clamped to the platform-supported range.
    public var speechRate: Float {
        get { storedSpeechRate }
        set {
            storedSpeechRate = newValue.isFinite
                ? min(max(newValue, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
                : AVSpeechUtteranceDefaultSpeechRate * 0.9
        }
    }

    public init(
        levels: MiniFarmAudioLevels = .init(), subtitlesEnabled: Bool = true,
        speechRate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.9
    ) {
        self.levels = levels
        self.subtitlesEnabled = subtitlesEnabled
        self.speechRate = speechRate
    }
}

public enum MiniFarmVoicePriority: Int, Sendable {
    case low
    case normal
    case high
}

public enum MiniFarmSeason: String, Sendable {
    case spring, summer, autumn, winter
}

public struct MiniFarmVoiceCueEvent: Sendable {
    public enum State: Sendable {
        case queued, started, finished, interrupted, dropped, failed, unavailable
    }

    public enum Source: Sendable {
        case recording, localSynthesized
    }

    public let id: String
    public let state: State
    public let source: Source?
}

public enum MiniFarmAudioError: Sendable {
    case manifestMissing
    case manifestInvalid
    case assetUnavailable(id: String, kind: String)
    case playbackFailed(id: String, kind: String)
}

/// All methods and callbacks are confined to the main actor.
@MainActor
public final class MiniFarmAudioController: NSObject {
    public var onSubtitleChange: (@MainActor (String?) -> Void)?
    public var onVoiceCueEvent: (@MainActor (MiniFarmVoiceCueEvent) -> Void)?
    public var onAudioError: (@MainActor (MiniFarmAudioError) -> Void)?

    private struct Manifest: Decodable {
        let schemaVersion: Int
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let id: String
        let kind: String
        let path: String?
        let subtitle: String?
        let locale: String?
        let loop: Bool?
    }

    private struct Cue {
        let asset: Asset
        let priority: MiniFarmVoicePriority
        let text: String?
    }

    private enum VoicePlayback {
        case file(AVAudioPlayer)
        case speech(AVSpeechUtterance)

        var identifier: ObjectIdentifier {
            switch self {
            case .file(let player): ObjectIdentifier(player)
            case .speech(let utterance): ObjectIdentifier(utterance)
            }
        }

        var source: MiniFarmVoiceCueEvent.Source {
            switch self {
            case .file: .recording
            case .speech: .localSynthesized
            }
        }
    }

    private struct ActiveVoice {
        let cue: Cue
        let playback: VoicePlayback
    }

    private let audioDirectory: URL?
    private let assets: [String: Asset]
    private let manifestError: MiniFarmAudioError?
    private let synthesizer = AVSpeechSynthesizer()
    private var germanVoiceProvider: (@MainActor () -> AVSpeechSynthesisVoice?)?
    private var profile = MiniFarmAudioProfileSettings()
    private var activeVoice: ActiveVoice?
    private var pendingVoices: [Cue] = []
    private(set) var musicPlayer: AVAudioPlayer?
    private var musicID: String?
    private(set) var ambientPlayer: AVAudioPlayer?
    private var ambientID: String?
    private var effects: [ObjectIdentifier: (id: String, player: AVAudioPlayer)] = [:]
    private var started = false
    private var paused = false
    private var subtitleText: String?

    /// The bundle must contain an unchanged `Audio` folder, including manifest.json.
    public init(bundle: Bundle = .main) {
        let directory = bundle.resourceURL?.appendingPathComponent("Audio", isDirectory: true)
        self.audioDirectory = directory
        let manifestURL = directory?.appendingPathComponent("manifest.json")
        if let manifestURL, let data = try? Data(contentsOf: manifestURL),
           let manifest = try? JSONDecoder().decode(Manifest.self, from: data), manifest.schemaVersion == 1 {
            self.assets = manifest.assets.reduce(into: [:]) { result, asset in
                // Keep the first occurrence if a malformed manifest repeats an ID.
                if result[asset.id] == nil { result[asset.id] = asset }
            }
            self.manifestError = nil
        } else {
            self.assets = [:]
            self.manifestError = manifestURL.map { FileManager.default.fileExists(atPath: $0.path) } == true
                ? .manifestInvalid : .manifestMissing
        }
        super.init()
        synthesizer.delegate = self
    }

    // Internal seam for deterministic tests on machines with different installed voices.
    convenience init(bundle: Bundle, germanVoiceProvider: @escaping @MainActor () -> AVSpeechSynthesisVoice?) {
        self.init(bundle: bundle)
        self.germanVoiceProvider = germanVoiceProvider
    }

    /// Configure the app's audio session and allow playback. Call again after stop.
    public func start() throws {
        guard !started else { return }
        #if os(iOS) || os(tvOS) || os(visionOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default)
        try session.setActive(true)
        #endif
        started = true
        paused = false
        if let manifestError { onAudioError?(manifestError) }
    }

    /// Pauses current playback. New playback requests are dropped until resumed.
    public func pause() {
        guard started, !paused else { return }
        paused = true
        musicPlayer?.pause()
        ambientPlayer?.pause()
        effects.values.forEach { $0.player.pause() }
        switch activeVoice?.playback {
        case .file(let player): player.pause()
        case .speech: synthesizer.pauseSpeaking(at: .immediate)
        case nil: break
        }
    }

    public func resume() {
        guard started, paused else { return }
        paused = false
        if let player = musicPlayer, !player.play() {
            let id = musicID
            musicPlayer = nil
            musicID = nil
            if let id { onAudioError?(.playbackFailed(id: id, kind: "music")) }
            guard started, !paused else { return }
        }
        if let player = ambientPlayer, !player.play() {
            let id = ambientID
            ambientPlayer = nil
            ambientID = nil
            if let id { onAudioError?(.playbackFailed(id: id, kind: "ambient")) }
            guard started, !paused else { return }
        }
        for identifier in Array(effects.keys) {
            if let effect = effects[identifier], !effect.player.play() {
                effects.removeValue(forKey: identifier)
                onAudioError?(.playbackFailed(id: effect.id, kind: "sfx"))
                guard started, !paused else { return }
            }
        }
        switch activeVoice?.playback {
        case .file(let player):
            if !player.play() { finishVoice(identifier: ObjectIdentifier(player), state: .failed) }
        case .speech: synthesizer.continueSpeaking()
        case nil: startNextVoice()
        }
    }

    /// Stops playback and discards queued cues. The app owns the audio session lifecycle.
    public func stop() {
        guard started else { return }
        started = false
        paused = false
        musicPlayer?.stop()
        musicPlayer = nil
        musicID = nil
        ambientPlayer?.stop()
        ambientPlayer = nil
        ambientID = nil
        effects.values.forEach { $0.player.stop() }
        effects.removeAll()
        clearVoiceCues()
    }

    /// Cancels the active voice cue and drops queued cues without changing other playback.
    public func clearVoiceCues() {
        let active = activeVoice
        let pending = pendingVoices
        activeVoice = nil
        pendingVoices.removeAll()
        stopPlayback(active?.playback)
        applyVolumes()
        setSubtitle(nil)
        if let active { emit(active.cue, .interrupted, source: active.playback.source) }
        pending.forEach { emit($0, .dropped) }
    }

    public func updateProfileSettings(_ settings: MiniFarmAudioProfileSettings) {
        profile = settings
        applyVolumes()
        onSubtitleChange?(settings.subtitlesEnabled ? subtitleText : nil)
    }

    public func setLevels(_ levels: MiniFarmAudioLevels) {
        var settings = profile
        settings.levels = levels
        updateProfileSettings(settings)
    }

    /// Higher priority interrupts lower priority; queued cues are ordered by priority, then FIFO.
    /// Low-priority cues are dropped whenever another cue is active or queued.
    public func playVoiceCue(
        id: String, priority: MiniFarmVoicePriority = .normal, text: String? = nil
    ) {
        let suppliedText = nonemptyText(text)
        let asset: Asset
        if let found = assets[id] {
            guard found.kind == "voice" else {
                onVoiceCueEvent?(.init(id: id, state: .failed, source: nil))
                return
            }
            asset = found
        } else if suppliedText != nil {
            asset = Asset(id: id, kind: "voice", path: nil, subtitle: nil, locale: nil, loop: nil)
        } else {
            onVoiceCueEvent?(.init(id: id, state: .failed, source: nil))
            return
        }
        let cue = Cue(asset: asset, priority: priority, text: suppliedText ?? nonemptyText(asset.subtitle))
        guard started, !paused else {
            emit(cue, .dropped)
            return
        }
        if let active = activeVoice {
            if priority.rawValue > active.cue.priority.rawValue {
                activeVoice = nil
                stopPlayback(active.playback)
                applyVolumes()
                setSubtitle(nil)
                emit(active.cue, .interrupted, source: active.playback.source)
                guard started, !paused else {
                    emit(cue, .dropped)
                    return
                }
                // A callback may have started another cue.
                if activeVoice != nil {
                    enqueue(cue)
                } else {
                    startVoice(cue)
                }
            } else if priority == .low {
                emit(cue, .dropped)
            } else {
                enqueue(cue)
            }
        } else if !pendingVoices.isEmpty {
            if priority == .low {
                emit(cue, .dropped)
            } else {
                enqueue(cue)
                startNextVoice()
            }
        } else {
            startVoice(cue)
        }
    }

    public func playVoice(id: String, priority: MiniFarmVoicePriority = .normal) {
        playVoiceCue(id: id, priority: priority)
    }

    public func playSoundEffect(id: String) {
        guard started, !paused, let (_, player) = makePlayer(id: id, kind: "sfx") else { return }
        player.delegate = self
        player.volume = level(profile.levels.soundEffects)
        effects[ObjectIdentifier(player)] = (id, player)
        if !player.play() {
            effects.removeValue(forKey: ObjectIdentifier(player))
            onAudioError?(.playbackFailed(id: id, kind: "sfx"))
        }
    }

    public func playMusic(season: MiniFarmSeason) {
        guard started, !paused else { return }
        let id = "music.season.\(season.rawValue)"
        if musicID == id, musicPlayer?.isPlaying == true { return }
        guard let (asset, player) = makePlayer(id: id, kind: "music") else { return }
        player.numberOfLoops = asset.loop == true ? -1 : 0
        player.delegate = self
        player.volume = musicVolume
        guard player.play() else {
            onAudioError?(.playbackFailed(id: id, kind: "music"))
            return
        }
        musicPlayer?.stop()
        musicPlayer = player
        musicID = id
    }

    public func playAmbient(id: String) {
        guard started, !paused else { return }
        if ambientID == id, ambientPlayer?.isPlaying == true { return }
        guard let (asset, player) = makePlayer(id: id, kind: "ambient") else { return }
        player.numberOfLoops = asset.loop == true ? -1 : 0
        player.delegate = self
        player.volume = ambientVolume
        guard player.play() else {
            onAudioError?(.playbackFailed(id: id, kind: "ambient"))
            return
        }
        ambientPlayer?.stop()
        ambientPlayer = player
        ambientID = id
    }

    private func makePlayer(id: String, kind: String) -> (Asset, AVAudioPlayer)? {
        guard let asset = assets[id], asset.kind == kind, let url = resourceURL(for: asset) else {
            onAudioError?(.assetUnavailable(id: id, kind: kind))
            return nil
        }
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            onAudioError?(.playbackFailed(id: id, kind: kind))
            return nil
        }
        return (asset, player)
    }

    private func enqueue(_ cue: Cue) {
        let index = pendingVoices.firstIndex { $0.priority.rawValue < cue.priority.rawValue }
            ?? pendingVoices.endIndex
        pendingVoices.insert(cue, at: index)
        emit(cue, .queued)
    }

    private func startNextVoice() {
        guard started, !paused, activeVoice == nil, !pendingVoices.isEmpty else { return }
        startVoice(pendingVoices.removeFirst())
    }

    private func startVoice(_ cue: Cue) {
        if let url = resourceURL(for: cue.asset),
           let player = try? AVAudioPlayer(contentsOf: url) {
            player.delegate = self
            player.volume = level(profile.levels.voice)
            if player.play() {
                activate(cue, playback: .file(player))
                return
            }
        }
        // Only installed German voices are considered; no voice is downloaded.
        guard let text = cue.text else {
            setSubtitle(nil)
            emit(cue, .failed)
            startNextVoice()
            return
        }
        let voice: AVSpeechSynthesisVoice?
        if let germanVoiceProvider {
            voice = germanVoiceProvider()
        } else {
            voice = installedGermanVoice()
        }
        guard let voice else {
            setSubtitle(text)
            emit(cue, .unavailable)
            startNextVoice()
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = profile.speechRate
        utterance.volume = level(profile.levels.voice)
        synthesizer.speak(utterance)
        activate(cue, playback: .speech(utterance))
    }

    private func activate(_ cue: Cue, playback: VoicePlayback) {
        activeVoice = ActiveVoice(cue: cue, playback: playback)
        applyVolumes()
        setSubtitle(cue.text)
        guard activeVoice?.playback.identifier == playback.identifier else { return }
        emit(cue, .started, source: playback.source)
    }

    private func stopPlayback(_ playback: VoicePlayback?) {
        switch playback {
        case .file(let player): player.stop()
        case .speech: synthesizer.stopSpeaking(at: .immediate)
        case nil: break
        }
    }

    private func finishVoice(identifier: ObjectIdentifier, state: MiniFarmVoiceCueEvent.State) {
        guard let active = activeVoice, active.playback.identifier == identifier else { return }
        activeVoice = nil
        applyVolumes()
        setSubtitle(nil)
        emit(active.cue, state, source: active.playback.source)
        startNextVoice()
    }

    private func emit(
        _ cue: Cue, _ state: MiniFarmVoiceCueEvent.State, source: MiniFarmVoiceCueEvent.Source? = nil
    ) {
        onVoiceCueEvent?(.init(id: cue.asset.id, state: state, source: source))
    }

    private func nonemptyText(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    private func setSubtitle(_ text: String?) {
        subtitleText = text
        onSubtitleChange?(profile.subtitlesEnabled ? text : nil)
    }

    private func installedGermanVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.lowercased().hasPrefix("de-") || $0.language.lowercased() == "de"
        }
        return voices.sorted {
            let lhsExact = $0.language.lowercased() == "de-de"
            let rhsExact = $1.language.lowercased() == "de-de"
            if lhsExact != rhsExact { return lhsExact }
            return $0.quality.rawValue > $1.quality.rawValue
        }.first
    }

    private func resourceURL(for asset: Asset) -> URL? {
        guard let directory = audioDirectory, let path = asset.path, !path.isEmpty,
              !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else { return nil }
        let base = directory.standardizedFileURL.resolvingSymlinksInPath()
        let url = base.appendingPathComponent(path).standardizedFileURL.resolvingSymlinksInPath()
        guard url.path.hasPrefix(base.path + "/"), FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return url
    }

    private func level(_ value: Float) -> Float {
        value.isFinite ? min(max(value, 0), 1) : 0
    }

    private var musicVolume: Float {
        // Approximately -12 dB while Pelle speaks.
        level(profile.levels.music) * (activeVoice == nil ? 1 : 0.25)
    }

    private var ambientVolume: Float {
        level(profile.levels.ambient) * (activeVoice == nil ? 1 : 0.5)
    }

    private func applyVolumes() {
        if case .file(let player) = activeVoice?.playback { player.volume = level(profile.levels.voice) }
        effects.values.forEach { $0.player.volume = level(profile.levels.soundEffects) }
        musicPlayer?.volume = musicVolume
        ambientPlayer?.volume = ambientVolume
    }
}

extension MiniFarmAudioController: AVAudioPlayerDelegate {
    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let identity = PlaybackIdentity(player)
        Task { @MainActor [weak self] in
            guard let self else { return }
            let identifier = identity.identifier
            let effect = self.effects.removeValue(forKey: identifier)
            var failure: MiniFarmAudioError?
            if !flag, let effect { failure = .playbackFailed(id: effect.id, kind: "sfx") }
            if self.musicPlayer.map(ObjectIdentifier.init) == identifier {
                if !flag, let id = self.musicID { failure = .playbackFailed(id: id, kind: "music") }
                self.musicPlayer = nil
                self.musicID = nil
            }
            if self.ambientPlayer.map(ObjectIdentifier.init) == identifier {
                if !flag, let id = self.ambientID { failure = .playbackFailed(id: id, kind: "ambient") }
                self.ambientPlayer = nil
                self.ambientID = nil
            }
            if let failure { self.onAudioError?(failure) }
            self.finishVoice(identifier: identifier, state: flag ? .finished : .failed)
        }
    }

    nonisolated public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        audioPlayerDidFinishPlaying(player, successfully: false)
    }
}

extension MiniFarmAudioController: AVSpeechSynthesizerDelegate {
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let identity = PlaybackIdentity(utterance)
        Task { @MainActor [weak self] in
            self?.finishVoice(identifier: identity.identifier, state: .finished)
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let identity = PlaybackIdentity(utterance)
        Task { @MainActor [weak self] in
            self?.finishVoice(identifier: identity.identifier, state: .interrupted)
        }
    }
}
