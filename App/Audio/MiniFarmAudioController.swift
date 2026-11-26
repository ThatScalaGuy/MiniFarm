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

private struct GermanVoiceResult: @unchecked Sendable {
    // Voice objects are immutable here and cross actors only after lookup completes.
    let voice: AVSpeechSynthesisVoice?
}

private func findInstalledGermanVoice() -> GermanVoiceResult {
    // Voice discovery can block in system services, so callers run this off the main actor.
    let voices = AVSpeechSynthesisVoice.speechVoices().filter {
        $0.language.lowercased().hasPrefix("de-") || $0.language.lowercased() == "de"
    }
    let voice = voices.sorted {
        let lhsExact = $0.language.lowercased() == "de-de"
        let rhsExact = $1.language.lowercased() == "de-de"
        if lhsExact != rhsExact { return lhsExact }
        return $0.quality.rawValue > $1.quality.rawValue
    }.first
    return GermanVoiceResult(voice: voice)
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

    /// Applies user multipliers once to the designed MiniFarm mix.
    public static func applyingUserMultipliers(
        voice: Float = 1, soundEffects: Float = 1, music: Float = 1, ambient: Float = 1
    ) -> Self {
        func multiplier(_ value: Float) -> Float {
            value.isFinite ? min(max(value, 0), 1) : 0
        }
        return Self(
            voice: multiplier(voice),
            soundEffects: 0.6 * multiplier(soundEffects),
            music: 0.25 * multiplier(music),
            ambient: 0.2 * multiplier(ambient)
        )
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
    case soundEffectLimitReached(id: String, limit: Int)
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
        let peak: Float?
        let variants: [VoiceVariant]?
    }

    private struct VoiceVariant: Decodable {
        let text: String
        let path: String
        let peak: Float?
    }

    private struct Cue {
        let asset: Asset
        let priority: MiniFarmVoicePriority
        let text: String?
        let recordingPath: String?
        let estimatedPeak: Float
    }

    private enum VoicePlayback {
        case resolving(NSObject)
        case recording(AVAudioEngine, AVAudioPlayerNode, AVAudioUnitTimePitch, AVAudioFile)
        case speech(AVSpeechUtterance)

        var identifier: ObjectIdentifier {
            switch self {
            case .resolving(let token): ObjectIdentifier(token)
            case .recording(_, let player, _, _): ObjectIdentifier(player)
            case .speech(let utterance): ObjectIdentifier(utterance)
            }
        }

        var source: MiniFarmVoiceCueEvent.Source? {
            switch self {
            case .resolving: nil
            case .recording: .recording
            case .speech: .localSynthesized
            }
        }
    }

    private enum GermanVoiceLookupState {
        case notStarted
        case resolving
        case resolved(GermanVoiceResult)
        case timedOut
    }

    private struct ActiveVoice {
        let cue: Cue
        let playback: VoicePlayback
    }

    private struct ActiveEffect {
        let id: String
        let player: AVAudioPlayer
        let peak: Float
    }

    private let audioDirectory: URL?
    private let assets: [String: Asset]
    private let manifestError: MiniFarmAudioError?
    private let synthesizer = AVSpeechSynthesizer()
    private var germanVoiceLookupProvider: (@Sendable () async -> String?)?
    private var germanVoiceLookupState = GermanVoiceLookupState.notStarted
    private var profile = MiniFarmAudioProfileSettings()
    private var activeVoice: ActiveVoice?
    private var pendingVoices: [Cue] = []
    private(set) var musicPlayer: AVAudioPlayer?
    private var musicID: String?
    private var musicPeak: Float = 0
    private(set) var ambientPlayer: AVAudioPlayer?
    private var ambientID: String?
    private var ambientPeak: Float = 0
    private var effects: [ObjectIdentifier: ActiveEffect] = [:]
    private var started = false
    private var paused = false
    private var subtitleText: String?
    private let maxConcurrentSoundEffects = 3
    private let maxMixPeak: Float = 0.9
    private let maxSynthesizedVoicePeak: Float = 0.65
    private let maxMusicPeak: Float = 0.105
    private let maxAmbientPeak: Float = 0.05

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

    // Internal seam for delayed voice-lookup tests.
    convenience init(
        bundle: Bundle,
        germanVoiceLookupProvider: @escaping @Sendable () async -> String?
    ) {
        self.init(bundle: bundle)
        self.germanVoiceLookupProvider = germanVoiceLookupProvider
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
        case .resolving:
            let active = activeVoice
            activeVoice = nil
            applyVolumes()
            setSubtitle(nil)
            if let active { emit(active.cue, .interrupted, source: active.playback.source) }
        case .recording(let engine, let player, _, _):
            player.pause()
            engine.pause()
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
            musicPeak = 0
            if let id { onAudioError?(.playbackFailed(id: id, kind: "music")) }
            guard started, !paused else { return }
        }
        if let player = ambientPlayer, !player.play() {
            let id = ambientID
            ambientPlayer = nil
            ambientID = nil
            ambientPeak = 0
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
        case .resolving:
            break
        case .recording(let engine, let player, _, _):
            do {
                try engine.start()
                try playAudioNode(player)
            } catch {
                finishVoice(identifier: ObjectIdentifier(player), state: .failed)
            }
        case .speech: synthesizer.continueSpeaking()
        case nil: startNextVoice()
        }
        applyVolumes()
    }

    /// Stops playback and discards queued cues. The app owns the audio session lifecycle.
    public func stop() {
        guard started else { return }
        started = false
        paused = false
        musicPlayer?.stop()
        musicPlayer = nil
        musicID = nil
        musicPeak = 0
        ambientPlayer?.stop()
        ambientPlayer = nil
        ambientID = nil
        ambientPeak = 0
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
            asset = Asset(
                id: id, kind: "voice", path: nil, subtitle: nil, locale: nil, loop: nil,
                peak: nil, variants: nil
            )
        } else {
            onVoiceCueEvent?(.init(id: id, state: .failed, source: nil))
            return
        }
        let cueText = suppliedText ?? nonemptyText(asset.subtitle)
        let recording = matchingRecording(in: asset, text: cueText)
        let cue = Cue(
            asset: asset, priority: priority, text: cueText,
            recordingPath: recording?.path, estimatedPeak: recording.map { peak($0.peak) } ?? 1
        )
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
        guard started, !paused else { return }
        guard effects.count < maxConcurrentSoundEffects else {
            onAudioError?(.soundEffectLimitReached(id: id, limit: maxConcurrentSoundEffects))
            return
        }
        guard let (asset, player) = makePlayer(id: id, kind: "sfx") else { return }
        player.delegate = self
        effects[ObjectIdentifier(player)] = ActiveEffect(id: id, player: player, peak: peak(asset.peak))
        applyVolumes()
        if !player.play() {
            effects.removeValue(forKey: ObjectIdentifier(player))
            applyVolumes()
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
        let previousPeak = musicPeak
        musicPeak = peak(asset.peak)
        player.volume = musicVolume
        guard player.play() else {
            musicPeak = previousPeak
            onAudioError?(.playbackFailed(id: id, kind: "music"))
            return
        }
        musicPlayer?.stop()
        musicPlayer = player
        musicID = id
        applyVolumes()
    }

    public func playAmbient(id: String) {
        guard started, !paused else { return }
        if ambientID == id, ambientPlayer?.isPlaying == true { return }
        guard let (asset, player) = makePlayer(id: id, kind: "ambient") else { return }
        player.numberOfLoops = asset.loop == true ? -1 : 0
        player.delegate = self
        let previousPeak = ambientPeak
        ambientPeak = peak(asset.peak)
        player.volume = ambientVolume
        guard player.play() else {
            ambientPeak = previousPeak
            onAudioError?(.playbackFailed(id: id, kind: "ambient"))
            return
        }
        ambientPlayer?.stop()
        ambientPlayer = player
        ambientID = id
        applyVolumes()
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
        if let path = cue.recordingPath, let url = resourceURL(for: path),
           let file = try? AVAudioFile(forReading: url) {
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            let timePitch = AVAudioUnitTimePitch()
            timePitch.rate = recordingRate
            do {
                engine.attach(player)
                engine.attach(timePitch)
                try connectAudioNodes(engine, from: player, to: timePitch, format: file.processingFormat)
                try connectAudioNodes(
                    engine, from: timePitch, to: engine.mainMixerNode, format: file.processingFormat
                )
                engine.mainMixerNode.outputVolume = voiceVolume(for: cue)
                try engine.start()
                let identity = PlaybackIdentity(player)
                player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.finishVoice(identifier: identity.identifier, state: .finished)
                    }
                }
                try playAudioNode(player)
                activate(cue, playback: .recording(engine, player, timePitch, file))
                return
            } catch {
                engine.stop()
            }
        }
        // Only installed German voices are considered; no voice is downloaded.
        guard let text = cue.text else {
            setSubtitle(nil)
            emit(cue, .failed)
            startNextVoice()
            return
        }
        guard level(profile.levels.voice) > 0 else {
            setSubtitle(text)
            emit(cue, .unavailable)
            startNextVoice()
            return
        }
        let token = NSObject()
        activeVoice = ActiveVoice(cue: cue, playback: .resolving(token))
        setSubtitle(text)
        applyVolumes()
        switch germanVoiceLookupState {
        case .resolved(let result):
            finishVoiceLookup(result, token: token)
        case .timedOut:
            finishUnavailableVoice(token: token)
        case .notStarted:
            beginGermanVoiceLookup()
        case .resolving:
            break
        }
    }

    private func connectAudioNodes(
        _ engine: AVAudioEngine, from source: AVAudioNode, to destination: AVAudioNode,
        format: AVAudioFormat
    ) throws {
        if #available(iOS 27.0, macOS 27.0, tvOS 27.0, watchOS 27.0, visionOS 27.0, *) {
            try engine.connectNode(source, to: destination, format: format)
        } else {
            engine.connect(source, to: destination, format: format)
        }
    }

    private func playAudioNode(_ player: AVAudioPlayerNode) throws {
        if #available(iOS 27.0, macOS 27.0, tvOS 27.0, watchOS 27.0, visionOS 27.0, *) {
            try player.playAudio()
        } else {
            player.play()
        }
    }

    private func beginGermanVoiceLookup() {
        guard case .notStarted = germanVoiceLookupState else { return }
        germanVoiceLookupState = .resolving
        let provider = germanVoiceLookupProvider
        let lookup = Task.detached(priority: .utility) {
            if let provider {
                let identifier = await provider()
                return GermanVoiceResult(
                    voice: identifier.flatMap(AVSpeechSynthesisVoice.init(identifier:))
                )
            }
            return findInstalledGermanVoice()
        }
        Task { @MainActor [weak self] in
            let result = await lookup.value
            self?.germanVoiceLookupCompleted(result)
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self?.germanVoiceLookupTimedOut()
        }
    }

    private func germanVoiceLookupCompleted(_ result: GermanVoiceResult) {
        germanVoiceLookupState = .resolved(result)
        guard let activeVoice, case .resolving(let token) = activeVoice.playback else { return }
        finishVoiceLookup(result, token: token)
    }

    private func germanVoiceLookupTimedOut() {
        guard case .resolving = germanVoiceLookupState else { return }
        germanVoiceLookupState = .timedOut
        guard let activeVoice, case .resolving(let token) = activeVoice.playback else { return }
        finishUnavailableVoice(token: token)
    }

    private func finishVoiceLookup(_ result: GermanVoiceResult, token: NSObject) {
        guard let activeVoice,
              activeVoice.playback.identifier == ObjectIdentifier(token),
              started, !paused else { return }
        guard level(profile.levels.voice) > 0 else {
            finishUnavailableVoice(token: token)
            return
        }
        guard let voice = result.voice else {
            finishUnavailableVoice(token: token)
            return
        }
        let cue = activeVoice.cue
        guard let text = cue.text else {
            finishUnavailableVoice(token: token)
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = profile.speechRate
        utterance.volume = voiceVolume(for: cue)
        synthesizer.speak(utterance)
        activate(cue, playback: .speech(utterance))
    }

    private func finishUnavailableVoice(token: NSObject) {
        guard let activeVoice,
              activeVoice.playback.identifier == ObjectIdentifier(token) else { return }
        self.activeVoice = nil
        applyVolumes()
        setSubtitle(activeVoice.cue.text)
        emit(activeVoice.cue, .unavailable)
        startNextVoice()
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
        case .resolving: break
        case .recording(let engine, let player, _, _):
            player.stop()
            engine.stop()
        case .speech: synthesizer.stopSpeaking(at: .immediate)
        case nil: break
        }
    }

    private func finishVoice(identifier: ObjectIdentifier, state: MiniFarmVoiceCueEvent.State) {
        guard let active = activeVoice, active.playback.identifier == identifier else { return }
        activeVoice = nil
        if case .recording(let engine, _, _, _) = active.playback { engine.stop() }
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

    private func resourceURL(for asset: Asset) -> URL? {
        guard let path = asset.path else { return nil }
        return resourceURL(for: path)
    }

    private func resourceURL(for path: String) -> URL? {
        guard let directory = audioDirectory, !path.isEmpty,
              !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else { return nil }
        let base = directory.standardizedFileURL.resolvingSymlinksInPath()
        let url = base.appendingPathComponent(path).standardizedFileURL.resolvingSymlinksInPath()
        guard url.path.hasPrefix(base.path + "/"), FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return url
    }

    private func matchingRecording(in asset: Asset, text: String?) -> (path: String, peak: Float?)? {
        guard let text else { return nil }
        if asset.subtitle == text, let path = asset.path { return (path, asset.peak) }
        guard let variant = asset.variants?.first(where: { $0.text == text }) else { return nil }
        return (variant.path, variant.peak)
    }

    private func peak(_ value: Float?) -> Float {
        guard let value, value.isFinite, value > 0 else { return 1 }
        return min(value, 1)
    }

    private var recordingRate: Float {
        let base = AVSpeechUtteranceDefaultSpeechRate
        return min(max(profile.speechRate / base, 0.5), 2)
    }

    private func voiceVolume(for cue: Cue) -> Float {
        min(level(profile.levels.voice), maxSynthesizedVoicePeak / max(cue.estimatedPeak, 0.001))
    }

    private func level(_ value: Float) -> Float {
        value.isFinite ? min(max(value, 0), 1) : 0
    }

    private var voiceIsAudible: Bool {
        guard let activeVoice else { return false }
        if case .resolving = activeVoice.playback { return false }
        return true
    }

    private var musicVolume: Float {
        // Approximately -12 dB while Pelle speaks.
        min(level(profile.levels.music), maxMusicPeak / max(musicPeak, 0.001))
            * (voiceIsAudible ? 0.25 : 1)
    }

    private var ambientVolume: Float {
        min(level(profile.levels.ambient), maxAmbientPeak / max(ambientPeak, 0.001))
            * (voiceIsAudible ? 0.5 : 1)
    }

    private func applyVolumes() {
        if let activeVoice {
            switch activeVoice.playback {
            case .resolving: break
            case .recording(let engine, _, let timePitch, _):
                engine.mainMixerNode.outputVolume = voiceVolume(for: activeVoice.cue)
                timePitch.rate = recordingRate
            case .speech(let utterance):
                utterance.volume = voiceVolume(for: activeVoice.cue)
            }
        }
        musicPlayer?.volume = musicVolume
        ambientPlayer?.volume = ambientVolume
        let voicePeak: Float
        if voiceIsAudible, let cue = activeVoice?.cue {
            voicePeak = cue.estimatedPeak * voiceVolume(for: cue)
        } else {
            voicePeak = 0
        }
        let backgroundPeak = musicPeak * musicVolume + ambientPeak * ambientVolume
        let requestedEffectPeak = effects.values.reduce(Float.zero) {
            $0 + $1.peak * level(profile.levels.soundEffects)
        }
        let remainingPeak = max(0, maxMixPeak - voicePeak - backgroundPeak)
        let effectGain = requestedEffectPeak > 0 ? min(1, remainingPeak / requestedEffectPeak) : 1
        effects.values.forEach { $0.player.volume = level(profile.levels.soundEffects) * effectGain }
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
                self.musicPeak = 0
            }
            if self.ambientPlayer.map(ObjectIdentifier.init) == identifier {
                if !flag, let id = self.ambientID { failure = .playbackFailed(id: id, kind: "ambient") }
                self.ambientPlayer = nil
                self.ambientID = nil
                self.ambientPeak = 0
            }
            self.applyVolumes()
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
