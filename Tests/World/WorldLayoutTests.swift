import XCTest
@testable import MiniFarm

final class WorldLayoutTests: XCTestCase {
    func testIslandAndNearObjectsStayInViewAcrossRotations() {
        for size in [CGSize(width: 361, height: 572), CGSize(width: 715, height: 192),
                     CGSize(width: 800, height: 940), CGSize(width: 1110, height: 616)] {
            let rect = CGRect(origin: .zero, size: size)
            for level in 1...5 {
                let f = WorldFraming(size: size, site: nil, level: level)
                let span = WorldFraming.island(level: level) / 2
                for x in [-span.x, span.x] {
                    for z in [-span.y, span.y] {
                        for y: Float in [-0.8, 2.5] { XCTAssertTrue(rect.contains(f.project([x,y,z]))) }
                    }
                }
            }
            for site in WorldSite.all {
                let f = WorldFraming(size: size, site: site, level: 5)
                for x: Float in [-1.95, 1.95] {
                    XCTAssertTrue(rect.contains(f.project(site.center + [x, 0.6, 1.58-x*0.14])))
                }
            }
        }
    }

    func testPagingNeverDropsAHostChoiceAndUsesItsOpaqueID() {
        let w = WorldOffering(id: "wish.1", activityID: "act.animal.feed", locationID: "loc.henhouse")
        let choices = (0..<7).map { WorldChoice(id: "slot.\($0)", modelID: "model.item.feed", label: "Futter") }
        let turn = WorldTurn(offering: w, stepID: "choose", stepIndex: 0, stepCount: 2, choices: choices, targetID: "slot.5")
        let objects = (0..<4).flatMap { WorldObject.targets(turn: turn, site: WorldSite.at(w.locationID), page: $0, perPage: 2) }
        XCTAssertEqual(objects.compactMap(\.choiceID), choices.map(\.id))
        XCTAssertEqual(objects.filter(\.isTarget).map(\.id), ["slot.5"])
        XCTAssertEqual(objects.first?.model, "item.feed")
    }

    func testNoChoiceStepIsAnObjectNotANextButton() {
        let w = WorldOffering(id: "wish.2", activityID: "act.field.water", locationID: "loc.garden")
        var turn = WorldTurn(offering: w, stepID: "fill", stepIndex: 0, stepCount: 2)
        let first = WorldObject.targets(turn: turn, site: WorldSite.at(w.locationID), page: 2, perPage: 2)
        XCTAssertEqual(first.first?.model, "tool.can")
        XCTAssertNil(first.first?.choiceID)
        turn.stepIndex = 1
        XCTAssertEqual(WorldObject.targets(turn: turn, site: WorldSite.at(w.locationID), page: 0, perPage: 2).first?.model, "bed")
    }
}
