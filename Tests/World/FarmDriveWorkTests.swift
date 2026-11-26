import XCTest
@testable import MiniFarm

final class FarmDriveWorkTests: XCTestCase {
    private func turn(_ action: String, site: String = "loc.field", step: String = "field",
                      target: String = "plot.field.2.1", gear: [String]) -> WorldTurn {
        WorldTurn(offering: WorldOffering(id: "wish.1", activityID: "act.field." + action, locationID: site),
                  stepID: step, stepIndex: 2, stepCount: 3, targetID: target,
                  workGear: gear, workBeds: ["plot.field.2.1", "plot.field.2.2"])
    }

    func testOnlyThePlannedMachineAndPhysicalPassOpenTheCab() {
        let plow = ["veh.tractor", "imp.plow"]
        XCTAssertEqual(FarmDriveWork.job(for: turn("plow", gear: plow), farmLevel: 2), .plow)
        XCTAssertNil(FarmDriveWork.job(for: turn("plow", step: "use.plow", gear: plow), farmLevel: 2))
        XCTAssertNil(FarmDriveWork.job(for: turn("sow", step: "seed", gear: ["veh.tractor", "imp.seeder"]), farmLevel: 2))
        XCTAssertNil(FarmDriveWork.job(for: turn("plow", site: "loc.greenhouse", gear: ["tool.hoe"]), farmLevel: 5))
        XCTAssertNil(FarmDriveWork.job(for: turn("water", gear: ["tool.can"]), farmLevel: 5))
        XCTAssertEqual(FarmDriveWork.job(for: turn("water", gear: ["veh.tractor", "imp.watertank"]), farmLevel: 3), .water)
        XCTAssertNil(FarmDriveWork.job(for: turn("plow", target: "plot.field.6.3", gear: plow), farmLevel: 4))
        XCTAssertEqual(FarmDriveWork.job(for: turn("combine", gear: ["veh.combine", "imp.trailer"]), farmLevel: 5), .combine)
        XCTAssertNil(FarmDriveWork.job(for: turn("combine", step: "store", gear: ["veh.combine"]), farmLevel: 5))
        XCTAssertEqual(FarmDriveWork.job(for: turn("snowplow", site: "loc.plaza", step: "path", target: "plaza.path",
                                                   gear: ["veh.tractor", "imp.snowplow"]), farmLevel: 5), .clearSnow)
    }

    func testSeedlingRequestsAVisiblePassRatherThanFinishingOnTap() {
        var drive = FarmDriveMotion()
        drive.tapRow(stage: .seedling)
        XCTAssertEqual(drive.pilot, .rowTap)
        XCTAssertEqual(drive.progress, 0)
        for _ in 0..<18 { drive.tick(seconds: 0.1) }
        XCTAssertTrue((0.4...0.6).contains(drive.progress))
        XCTAssertFalse(drive.takeCompletion())
        drive.assist()
        checkFinish(&drive)
    }

    func testDraggedRowPausesOnReleaseAndPelleCompletesOnlyTheLastPart() {
        var drive = FarmDriveMotion()
        drive.drag(stage: .shoot, along: 0.30, across: 0.5)
        XCTAssertGreaterThan(drive.lateral, 0)
        XCTAssertLessThan(drive.lateral, 0.5)
        drive.releaseDrag()
        for _ in 0..<70 { drive.tick(seconds: 0.1) }
        XCTAssertEqual(drive.progress, 0.30)
        drive.drag(stage: .shoot, along: -0.2, across: 0)
        XCTAssertEqual(drive.progress, 0.30)
        drive.drag(stage: .shoot, along: 1, across: 1)
        XCTAssertEqual(drive.progress, 0.85)
        XCTAssertEqual(drive.pilot, .pelle)
        XCTAssertFalse(drive.takeCompletion())
        checkFinish(&drive)
    }

    func testBloomCanSteerWhileMovingAndStopWithoutLosingCoverage() {
        var drive = FarmDriveMotion()
        drive.tapRow(stage: .bloom)
        drive.drag(stage: .bloom, along: 1, across: 1)
        XCTAssertEqual(drive.progress, 0)
        drive.setGas(stage: .bloom, to: 0.5)
        drive.turnWheel(stage: .bloom, to: 2)
        for _ in 0..<15 { drive.tick(seconds: 0.1) }
        XCTAssertGreaterThan(drive.progress, 0.15)
        XCTAssertGreaterThan(drive.lateral, 0.1)
        XCTAssertEqual(drive.steering, 1)
        drive.turnWheel(stage: .bloom, to: 0)
        drive.setGas(stage: .bloom, to: 0)
        let saved = drive.progress
        for _ in 0..<15 { drive.tick(seconds: 0.1) }
        XCTAssertEqual(drive.progress, saved)
        XCTAssertEqual(drive.steering, 0)
        drive.setGas(stage: .bloom, to: 1)
        drive.suspend()
        drive.tick(seconds: 60)
        XCTAssertEqual(drive.progress, saved)
        drive.assist()
        checkFinish(&drive)
    }

    private func checkFinish(_ drive: inout FarmDriveMotion, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<50 { drive.tick(seconds: 0.1) }
        XCTAssertEqual(drive.progress, 1, file: file, line: line)
        XCTAssertTrue(drive.takeCompletion(), file: file, line: line)
        drive.assist()
        drive.tick(seconds: 1)
        XCTAssertFalse(drive.takeCompletion(), file: file, line: line)
    }
}
