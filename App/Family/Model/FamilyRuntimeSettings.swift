import Foundation

/// System accessibility flags that change gameplay presentation. Read from the SwiftUI environment.
struct SystemAccessibility: Equatable, Sendable {
    var reduceMotion = false
    var increaseContrast = false
    var differentiateWithoutColor = false
    var voiceOverEnabled = false
}

/// Effective values for gameplay and audio. Already merges profile settings, calm mode and system flags.
struct FamilyRuntimeSettings: Equatable, Sendable {
    /// Start stage set by a parent. Use it for a new farm, when `stageLocked`, or when `stageRevision` changed.
    var startStage: ProfileStage
    /// True when adaptivity is off, so the stage stays at `startStage`.
    var stageLocked: Bool
    var stageRevision: Int
    var adaptivityEnabled: Bool
    var memoryMode: Bool
    /// Multiplier for scaffold hint delays (doc 10). Smaller means help comes earlier.
    var hintDelayScale: Double

    /// Linear gains 0...1 per bus on top of the designed mix.
    var voiceVolume: Double
    var sfxVolume: Double
    var ambienceVolume: Double
    var musicVolume: Double
    /// "Sehr ruhig": only voice guidance and central interaction sounds.
    var essentialSFXOnly: Bool
    var monoAudio: Bool
    var slowSpeech: Bool
    var subtitles: Bool

    var reduceMotion: Bool
    var particleScale: Double
    var weatherParticles: Bool
    var idleSoundScale: Double
    var cameraSpeedScale: Double
    var highContrast: Bool
    var touchTargetScale: Double
    var hapticsEnabled: Bool

    /// Calm music is lowered by 8 dB (doc 18 §4).
    static let calmMusicGain = pow(10.0, -8.0 / 20.0)
    static let calmParticleScale = 0.3
    static let reduceMotionParticleScale = 0.5
    static let largeSymbolScale = 1.25

    init(profile: FamilyProfile, system: SystemAccessibility) {
        let settings = profile.settings
        let audio = settings.audio
        let comfort = settings.comfort
        let calm = comfort.calmMode

        startStage = profile.stage
        stageLocked = !settings.learning.adaptivityEnabled
        stageRevision = profile.stageRevision
        adaptivityEnabled = settings.learning.adaptivityEnabled
        memoryMode = settings.learning.memoryMode
        hintDelayScale = settings.learning.helpTiming.delayScale

        let quiet = audio.quietGame || calm == .veryCalm
        voiceVolume = Self.clamp(audio.voiceVolume)
        sfxVolume = Self.clamp(audio.sfxVolume)
        ambienceVolume = quiet ? 0 : Self.clamp(audio.ambienceVolume)
        musicVolume = switch calm {
        case _ where quiet: 0
        case .calm: Self.clamp(audio.musicVolume) * Self.calmMusicGain
        default: Self.clamp(audio.musicVolume)
        }
        essentialSFXOnly = calm == .veryCalm
        monoAudio = audio.monoAudio
        slowSpeech = audio.slowSpeech
        subtitles = audio.subtitles

        reduceMotion = comfort.reduceMotion || system.reduceMotion
        var particles = Self.clamp(comfort.effectsIntensity)
        if calm != .standard { particles *= Self.calmParticleScale }
        if reduceMotion { particles *= Self.reduceMotionParticleScale }
        particleScale = particles
        weatherParticles = calm != .veryCalm && particles > 0
        idleSoundScale = switch calm {
        case .standard: 1.0
        case .calm: 0.5
        case .veryCalm: 0.0
        }
        cameraSpeedScale = calm == .standard ? 1.0 : 0.7
        highContrast = comfort.highContrast || system.increaseContrast || system.differentiateWithoutColor
        touchTargetScale = comfort.largeSymbols ? Self.largeSymbolScale : 1.0
        hapticsEnabled = comfort.hapticsEnabled
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
