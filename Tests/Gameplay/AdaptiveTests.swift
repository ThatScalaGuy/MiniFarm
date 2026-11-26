import Foundation
import Testing
@testable import MiniFarm

struct AdaptiveTests {
    private func loadRules() throws -> FarmAdaptiveRules {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let url = Bundle.main.url(forResource: "adaptive", withExtension: "json", subdirectory: "Content")
            ?? Bundle.main.url(forResource: "adaptive", withExtension: "json")
            ?? root.appendingPathComponent("App/Resources/Content/adaptive.json")
        return try JSONDecoder().decode(FarmAdaptiveRules.self, from: Data(contentsOf: url))
    }

    @Test func bootstrapConfidenceAndOutcomeWeights() throws {
        let rules = try loadRules()
        var skills = FarmSkills()
        skills.record(lanes: ["mo.tap", "moTap", "socCare"], assist: .cue, day: 1, rules: rules)
        skills.record(lanes: ["mathCount"], assist: .ghost, day: 1, rules: rules)
        skills.record(lanes: ["cogMemory"], assist: .together, day: 1, rules: rules)
        let tap = try #require(skills.mastery["moTap"])
        #expect(abs(tap - 0.56) < 0.00001)
        #expect(skills.mastery["mathCount"] == 0.5)
        #expect(try #require(skills.mastery["cogMemory"]) < 0.5)

        for _ in 1..<25 { skills.record(lanes: ["math.count"], assist: .hint, day: 1, rules: rules) }
        skills.record(lanes: ["mathCount"], assist: .cue, day: 1, rules: rules)
        #expect(abs(try #require(skills.mastery["mathCount"]) - 0.515) < 0.00001)
        #expect(skills.confidence["mathCount"] == 1)
        #expect(try #require(skills.confidence["moTap"]) < 1)
    }

    @Test func windowGatesAreLaneSpecificAndAsymmetric() throws {
        let rules = try loadRules(), lane = ["cog.matching"]
        var skills = FarmSkills()
        for _ in 0..<7 {
            skills.record(lanes: lane, assist: .cue, day: 1, rules: rules)
            skills.record(lanes: ["moDrag"], assist: .together, day: 1, rules: rules)
        }
        #expect(skills.choiceCount(base: 3, lanes: lane, assist: .cue) == 3)
        skills.record(lanes: lane, assist: .hint, day: 1, rules: rules)
        #expect(skills.choiceCount(base: 3, lanes: lane, assist: .cue) == 4)
        #expect(skills.choiceCount(base: 3, lanes: ["moDrag"], assist: .cue) == 2)
        skills.record(lanes: lane, assist: .reduced, day: 1, rules: rules)
        #expect(skills.choiceCount(base: 3, lanes: lane, assist: .cue) == 4)
        skills.record(lanes: lane, assist: .together, day: 1, rules: rules)
        #expect(skills.choiceCount(base: 3, lanes: lane, assist: .cue) == 2)
        #expect(skills.choiceCount(base: 2, lanes: lane, assist: .reduced) == 1)
        #expect(skills.choiceCount(base: 5, lanes: lane, assist: .together) == 1)
        #expect(skills.hintSeconds(stage: .shoot, lanes: lane, rules: rules) < 8)
    }

    @Test func promotionNeedsTenDistinctPracticedDaysAndFreshEvidenceForNextStage() throws {
        let rules = try loadRules(), core = ["mo.tap", "cog.sequence"]
        var skills = FarmSkills()
        for _ in 0..<80 { skills.record(lanes: core, assist: .cue, day: 1, rules: rules) }
        #expect(skills.recommendedStage(current: .sprout, day: 11) == .sprout)
        for day in 2...9 { skills.record(lanes: core, assist: .cue, day: day, rules: rules) }
        skills.record(lanes: ["mathCount"], assist: .cue, day: 10, rules: rules)
        #expect(skills.recommendedStage(current: .sprout, day: 10) == .sprout)
        skills.record(lanes: core, assist: .cue, day: 11, rules: rules)
        let next = skills.advanceStage(current: .sprout, day: 11)
        #expect(next == .shoot)
        for day in 11...20 { skills.record(lanes: core, assist: .cue, day: day, rules: rules) }
        #expect(skills.recommendedStage(current: next, day: 20) == .shoot)
        skills.record(lanes: core, assist: .cue, day: 21, rules: rules)
        #expect(skills.recommendedStage(current: next, day: 21) == .bloom)
    }

    @Test func socialCareAndUnknownTagsLeaveNoTrace() throws {
        let rules = try loadRules()
        var skills = FarmSkills()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let before = try encoder.encode(skills)
        for day in 1...30 {
            skills.record(lanes: ["soc.care", "socCare", "unknown"], assist: .together, day: day, rules: rules)
        }
        #expect(try encoder.encode(skills) == before)
        skills.record(lanes: ["moTap", "soc.care", "mo.tap"], assist: .cue, day: 1, rules: rules)
        var motorOnly = FarmSkills()
        motorOnly.record(lanes: ["moTap"], assist: .cue, day: 1, rules: rules)
        #expect(try encoder.encode(skills) == encoder.encode(motorOnly))
    }

    @Test func growthRequiresSustainedMotorAndCognitiveEvidence() throws {
        let rules = try loadRules(), core = ["moDrag", "cogMemory"]
        var skills = FarmSkills()
        for day in 1...20 {
            skills.record(lanes: ["moDrag", "mathCount"], assist: .cue, day: day, rules: rules)
        }
        #expect(skills.recommendedStage(current: .sprout, day: 20) == .sprout)
        for _ in 0..<20 { skills.record(lanes: core, assist: .cue, day: 21, rules: rules) }
        for day in 22...29 { skills.record(lanes: core, assist: .cue, day: day, rules: rules) }
        for _ in 0..<60 { skills.record(lanes: core, assist: .together, day: 30, rules: rules) }
        #expect(skills.recommendedStage(current: .sprout, day: 30) == .sprout)
        for _ in 0..<80 { skills.record(lanes: core, assist: .cue, day: 31, rules: rules) }
        #expect(skills.recommendedStage(current: .sprout, day: 31) == .sprout)
    }

    @Test func timeAwayAndFatigueChangeSupportWithoutLockingOutPlay() throws {
        let rules = try loadRules(), lane = ["moTap"]
        var skills = FarmSkills()
        for _ in 0..<10 { skills.record(lanes: lane, assist: .cue, day: 1, rules: rules) }
        let mastery = try #require(skills.mastery["moTap"])
        let usualHint = skills.hintSeconds(stage: .shoot, lanes: lane, rules: rules)
        skills.recordSession(seconds: 15 * 60, day: 1)
        #expect(skills.prefersQuiet(stage: .shoot, rules: rules))
        #expect(!skills.suggestsRest(stage: .shoot, rules: rules))
        skills.recordSession(seconds: 10 * 60, day: 1)
        #expect(skills.suggestsRest(stage: .shoot, rules: rules))
        skills.resume(afterDays: 14)
        #expect(skills.mastery["moTap"] == mastery)
        #expect(!skills.prefersQuiet(stage: .shoot, rules: rules))
        skills.resume(afterDays: 15)
        #expect(skills.mastery["moTap"] == mastery * 0.9)
        #expect(skills.hintSeconds(stage: .shoot, lanes: lane, rules: rules) < usualHint)
        #expect(!skills.isReadyForChallenge(lanes: lane))
        skills.recordSession(seconds: Int.max, day: 16)
        skills.recordSession(seconds: 100, day: 16)
        skills.record(lanes: lane, assist: .cue, day: 17, rules: rules)
        #expect(!skills.prefersQuiet(stage: .sprout, rules: rules))
    }

    @Test func persistentEvidenceStaysBoundedAndReplaysDeterministically() throws {
        let rules = try loadRules()
        var skills = FarmSkills()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let lanes = ["moTap", "cogMemory", "mathCount"]
        for _ in 0..<120 { skills.record(lanes: lanes, assist: .cue, day: 2, rules: rules) }
        let saved = try encoder.encode(skills)
        var restored = try JSONDecoder().decode(FarmSkills.self, from: saved)
        for day in 3..<303 {
            let assist: FarmAssist = day.isMultiple(of: 7) ? .hint : .cue
            skills.record(lanes: lanes, assist: assist, day: day, rules: rules)
            restored.record(lanes: Array(lanes.reversed()), assist: assist, day: day, rules: rules)
        }
        let final = try encoder.encode(skills)
        #expect(final == (try encoder.encode(restored)))
        #expect(final.count < saved.count + 256)
        #expect(skills.priority(lanes: ["moSteer"], day: 303) > skills.priority(lanes: lanes, day: 303))
    }
}
