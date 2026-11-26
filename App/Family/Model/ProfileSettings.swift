import Foundation

/// Per-profile settings, stored locally in `Profile.json`.
struct ProfileSettings: Codable, Equatable, Sendable {
    var learning = LearningSettings()
    var session = SessionSettings()
    var audio = AudioSettings()
    var comfort = ComfortSettings()

    mutating func apply(_ preset: ComfortPreset) {
        switch preset {
        case .standard:
            comfort = ComfortSettings()
            learning.helpTiming = .normal
        case .visuallyClear:
            comfort.highContrast = true
            comfort.largeSymbols = true
        case .moreHelp:
            learning.helpTiming = .earlier
            comfort.largeSymbols = true
        }
    }
}

struct LearningSettings: Codable, Equatable, Sendable {
    /// Off means the stage stays fixed (doc 10 §9).
    var adaptivityEnabled = true
    var memoryMode = true
    var helpTiming = HelpTiming.normal
}

enum HelpTiming: String, Codable, CaseIterable, Sendable, Identifiable {
    case earlier
    case normal
    case later

    var id: String { rawValue }

    var delayScale: Double {
        switch self {
        case .earlier: 0.5
        case .normal: 1.0
        case .later: 1.5
        }
    }

    var parentLabel: String {
        switch self {
        case .earlier: "Früher"
        case .normal: "Normal"
        case .later: "Später"
        }
    }
}

struct SessionSettings: Codable, Equatable, Sendable {
    static let timerOptions = [15, 30, 45]

    /// `nil` means no play timer.
    var timerMinutes: Int?
}

/// Bus volumes are linear user levels (0...1) on top of the designed mix (doc 12 §6).
struct AudioSettings: Codable, Equatable, Sendable {
    var voiceVolume = 1.0
    var sfxVolume = 1.0
    var ambienceVolume = 1.0
    var musicVolume = 1.0
    /// "Leises Spiel": music and ambience off.
    var quietGame = false
    var slowSpeech = false
    var subtitles = false
    var monoAudio = false

    subscript(bus: AudioBus) -> Double {
        get {
            switch bus {
            case .voice: voiceVolume
            case .sfx: sfxVolume
            case .ambience: ambienceVolume
            case .music: musicVolume
            }
        }
        set {
            let value = min(max(newValue, 0), 1)
            switch bus {
            case .voice: voiceVolume = value
            case .sfx: sfxVolume = value
            case .ambience: ambienceVolume = value
            case .music: musicVolume = value
            }
        }
    }
}

enum AudioBus: String, CaseIterable, Sendable, Identifiable {
    case voice
    case sfx
    case ambience
    case music

    var id: String { rawValue }

    var parentLabel: String {
        switch self {
        case .voice: "Sprache"
        case .sfx: "Geräusche"
        case .ambience: "Umgebung"
        case .music: "Musik"
        }
    }
}

struct ComfortSettings: Codable, Equatable, Sendable {
    var calmMode = CalmMode.standard
    /// Adds to the system Reduce Motion setting, never overrides it.
    var reduceMotion = false
    var effectsIntensity = 1.0
    var highContrast = false
    var largeSymbols = false
    var hapticsEnabled = true
}

// Missing keys fall back to defaults, so records from an older app version still load after a setting is added.

extension KeyedDecodingContainer {
    func decode<T: Decodable>(_ key: Key, default fallback: T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? fallback
    }
}

extension ProfileSettings {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = ProfileSettings()
        learning = try container.decode(.learning, default: fallback.learning)
        session = try container.decode(.session, default: fallback.session)
        audio = try container.decode(.audio, default: fallback.audio)
        comfort = try container.decode(.comfort, default: fallback.comfort)
    }
}

extension LearningSettings {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = LearningSettings()
        adaptivityEnabled = try container.decode(.adaptivityEnabled, default: fallback.adaptivityEnabled)
        memoryMode = try container.decode(.memoryMode, default: fallback.memoryMode)
        helpTiming = try container.decode(.helpTiming, default: fallback.helpTiming)
    }
}

extension AudioSettings {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AudioSettings()
        voiceVolume = try container.decode(.voiceVolume, default: fallback.voiceVolume)
        sfxVolume = try container.decode(.sfxVolume, default: fallback.sfxVolume)
        ambienceVolume = try container.decode(.ambienceVolume, default: fallback.ambienceVolume)
        musicVolume = try container.decode(.musicVolume, default: fallback.musicVolume)
        quietGame = try container.decode(.quietGame, default: fallback.quietGame)
        slowSpeech = try container.decode(.slowSpeech, default: fallback.slowSpeech)
        subtitles = try container.decode(.subtitles, default: fallback.subtitles)
        monoAudio = try container.decode(.monoAudio, default: fallback.monoAudio)
    }
}

extension ComfortSettings {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = ComfortSettings()
        calmMode = try container.decode(.calmMode, default: fallback.calmMode)
        reduceMotion = try container.decode(.reduceMotion, default: fallback.reduceMotion)
        effectsIntensity = try container.decode(.effectsIntensity, default: fallback.effectsIntensity)
        highContrast = try container.decode(.highContrast, default: fallback.highContrast)
        largeSymbols = try container.decode(.largeSymbols, default: fallback.largeSymbols)
        hapticsEnabled = try container.decode(.hapticsEnabled, default: fallback.hapticsEnabled)
    }
}

enum CalmMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case standard
    case calm
    case veryCalm

    var id: String { rawValue }

    var parentLabel: String {
        switch self {
        case .standard: "Standard"
        case .calm: "Ruhig"
        case .veryCalm: "Sehr ruhig"
        }
    }
}

/// Presets from doc 18 §4. "Ruhig" and "Sehr ruhig" are `CalmMode` values.
enum ComfortPreset: String, CaseIterable, Sendable, Identifiable {
    case standard
    case visuallyClear
    case moreHelp

    var id: String { rawValue }

    var parentLabel: String {
        switch self {
        case .standard: "Alles auf Standard"
        case .visuallyClear: "Visuell klar"
        case .moreHelp: "Mehr Hilfe"
        }
    }
}
