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
