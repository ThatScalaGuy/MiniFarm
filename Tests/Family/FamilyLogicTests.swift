import Foundation
import Testing
@testable import MiniFarm

extension SessionTimer {
    mutating func play(_ seconds: Int) {
        var left = seconds
        while left > 0 {
            let step = min(left, Int(Self.maxStep))
            advance(by: TimeInterval(step))
            left -= step
        }
    }
}

@Suite("SessionTimer")
struct SessionTimerTests {
    @Test func runsToASoftEnd() {
        var timer = SessionTimer()
        timer.start(limitMinutes: 15)
        #expect(timer.phase == .running(remaining: 900))
        timer.play(779)
        #expect(timer.phase == .running(remaining: 121))
        timer.play(1)
        #expect(timer.phase == .tired(remaining: 120))
        timer.play(120)
        #expect(timer.phase == .windDown(graceRemaining: 180))
        timer.play(180)
        #expect(timer.phase == .fallbackSleep(remaining: 8))
        timer.play(8)
        #expect(timer.phase == .finished)
    }

    @Test func noLimitMeansOff() {
        var timer = SessionTimer()
        #expect(timer.phase == .off)
        timer.start(limitMinutes: nil)
        timer.play(3600)
        #expect(timer.phase == .off)
        timer.stop()
        #expect(timer.elapsed == 0)
    }

    @Test func largeOrInvalidStepsAreClamped() {
        var timer = SessionTimer()
        timer.start(limitMinutes: 15)
        timer.advance(by: 20 * 60)
        #expect(timer.elapsed == SessionTimer.maxStep)
        timer.advance(by: -30)
        timer.advance(by: .nan)
        timer.advance(by: .infinity)
        #expect(timer.elapsed == SessionTimer.maxStep)
    }

    @Test func lowerLimitStartsTheWindDownInsteadOfEnding() {
        var timer = SessionTimer()
        timer.start(limitMinutes: 30)
        timer.play(20 * 60)
        timer.setLimit(minutes: 15)
        #expect(timer.phase == .windDown(graceRemaining: 180))
        timer.setLimit(minutes: 45)
        #expect(timer.phase == .running(remaining: 1500))
        timer.setLimit(minutes: nil)
        #expect(timer.phase == .off)
        timer.setLimit(minutes: 30)
        #expect(timer.phase == .running(remaining: 600))
    }

    @Test func skipToFallbackOnlyDuringWindDown() {
        var timer = SessionTimer()
        timer.start(limitMinutes: 15)
        timer.skipToFallback()
        #expect(timer.phase == .running(remaining: 900))
        timer.play(900 + 30)
        timer.skipToFallback()
        #expect(timer.phase == .fallbackSleep(remaining: 8))
    }
}

@Suite("Parental gate")
struct ParentalGateTests {
    @Test(arguments: [
        (16, "sechzehn"), (17, "siebzehn"), (21, "einundzwanzig"), (30, "dreißig"),
        (47, "siebenundvierzig"), (60, "sechzig"), (71, "einundsiebzig"), (99, "neunundneunzig"),
    ])
    func germanNumberWords(value: Int, word: String) {
        #expect(GermanNumberWords.word(for: value) == word)
    }

    @Test func numberWordPuzzleShowsNoDigits() {
        var random = SplitMix64(seed: 42)
        for _ in 0..<300 {
            let puzzle = GatePuzzle.numberWord(using: &random)
            #expect((21...99).contains(puzzle.answer))
            #expect(puzzle.prompt.hasSuffix(GermanNumberWords.word(for: puzzle.answer)))
            #expect(!puzzle.prompt.contains { $0.isNumber })
            #expect(puzzle.kind == .numberWord)
        }
    }

    @Test func sumPuzzleHasFourDistinctChoices() {
        var random = SplitMix64(seed: 7)
        for _ in 0..<300 {
            let puzzle = GatePuzzle.sumChoice(using: &random)
            #expect(puzzle.choices.count == 4)
            #expect(Set(puzzle.choices).count == 4)
            #expect(puzzle.choices.contains(puzzle.answer))
            #expect(puzzle.choices.allSatisfy { $0 > 0 })
            #expect(puzzle.kind == .sumChoice)
        }
    }

    @Test func threeWrongAnswersLockForThirtySeconds() {
        var random = SplitMix64(seed: 1)
        var state = ParentalGateState(puzzle: .numberWord(using: &random))
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let first = state.puzzle
        #expect(state.submit(first.answer + 1, now: start) { .numberWord(using: &random) } == .wrong(attemptsLeft: 2))
        #expect(state.puzzle != first)
        #expect(state.submit(0, now: start) { .numberWord(using: &random) } == .wrong(attemptsLeft: 1))
        let until = start.addingTimeInterval(ParentalGateState.lockout)
        #expect(state.submit(0, now: start) { .numberWord(using: &random) } == .locked(until: until))
        let answer = state.puzzle.answer
        #expect(state.submit(answer, now: start.addingTimeInterval(29)) { .numberWord(using: &random) } == .locked(until: until))
        #expect(state.submit(answer, now: until) { .numberWord(using: &random) } == .unlocked)
        #expect(state.failures == 0)
    }
}

@Suite("Runtime settings")
struct FamilyRuntimeSettingsTests {
    func runtime(_ change: (inout FamilyProfile) -> Void = { _ in }, system: SystemAccessibility = .init()) -> FamilyRuntimeSettings {
        var profile = FamilyProfile(avatar: .pig, stage: .shoot, createdAt: Date())
        change(&profile)
        return FamilyRuntimeSettings(profile: profile, system: system)
    }

    @Test func defaultsAreNeutral() {
        let value = runtime()
        #expect(value.startStage == .shoot)
        #expect(!value.stageLocked)
        #expect(value.hintDelayScale == 1)
        #expect([value.voiceVolume, value.sfxVolume, value.ambienceVolume, value.musicVolume] == [1, 1, 1, 1])
        #expect(value.particleScale == 1)
        #expect(value.weatherParticles)
        #expect(!value.essentialSFXOnly)
        #expect(!value.highContrast)
        #expect(value.touchTargetScale == 1)
    }

    @Test func calmModesDampenButKeepVoice() {
        let calm = runtime { $0.settings.comfort.calmMode = .calm }
        #expect(abs(calm.musicVolume - 0.398) < 0.001)
        #expect(calm.ambienceVolume == 1)
        #expect(abs(calm.particleScale - 0.3) < 0.0001)
        #expect(calm.idleSoundScale == 0.5)
        let veryCalm = runtime { $0.settings.comfort.calmMode = .veryCalm }
        #expect(veryCalm.musicVolume == 0)
        #expect(veryCalm.ambienceVolume == 0)
        #expect(veryCalm.voiceVolume == 1)
        #expect(veryCalm.essentialSFXOnly)
        #expect(!veryCalm.weatherParticles)
        let quiet = runtime { $0.settings.audio.quietGame = true }
        #expect(quiet.musicVolume == 0 && quiet.ambienceVolume == 0 && quiet.voiceVolume == 1 && quiet.sfxVolume == 1)
    }

    @Test func systemFlagsAddToProfileSettings() {
        let value = runtime(system: SystemAccessibility(reduceMotion: true, increaseContrast: true))
        #expect(value.reduceMotion)
        #expect(value.particleScale == 0.5)
        #expect(value.highContrast)
        let colorBlind = runtime(system: SystemAccessibility(differentiateWithoutColor: true))
        #expect(colorBlind.highContrast)
    }

    @Test func stageLockAndRevision() {
        let locked = runtime {
            $0.settings.learning.adaptivityEnabled = false
            $0.stageRevision = 3
        }
        #expect(locked.stageLocked)
        #expect(locked.stageRevision == 3)
    }

    @Test func presetsChangeOnlyTheirSettings() {
        var settings = ProfileSettings()
        settings.audio[.music] = 0.2
        settings.apply(.moreHelp)
        #expect(settings.learning.helpTiming == .earlier)
        #expect(settings.comfort.largeSymbols)
        settings.apply(.standard)
        #expect(settings.comfort == ComfortSettings())
        #expect(settings.learning.helpTiming == .normal)
        #expect(settings.audio.musicVolume == 0.2)
        settings.audio[.voice] = 3
        #expect(settings.audio.voiceVolume == 1)
    }
}
