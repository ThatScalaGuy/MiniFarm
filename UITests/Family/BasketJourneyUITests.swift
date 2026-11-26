import UIKit
import XCTest

@MainActor
final class BasketJourneyUITests: XCTestCase {
    func testTwoChildrenAndHelperReturnToTheSameFarmStep() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "Gemeinsamer Hof ist ein iPad-Angebot.")
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-MiniFarmFamilyUITesting", "-MiniFarmFamilyReset"]
        app.launch()
        func node(_ id: String) -> XCUIElement {
            app.descendants(matching: .any).matching(identifier: id).firstMatch
        }
        func tap(_ id: String, line: UInt = #line) {
            let target = node(id)
            XCTAssertTrue(target.waitForExistence(timeout: 18), id, line: line)
            target.tap()
        }
        func picture(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        tap("family.picker.setupButton")
        let prompt = node("family.gate.prompt")
        XCTAssertTrue(prompt.waitForExistence(timeout: 12))
        let number = try XCTUnwrap(GermanNumbers.value(of: String(prompt.label.split(separator: " ").last ?? "")))
        for digit in String(number) { tap("family.gate.key.\(digit)") }
        tap("family.gate.submit")
        for avatar in ["animal.cow", "animal.sheep"] {
            tap("family.parent.addProfile")
            tap("family.newProfile.avatar.\(avatar)")
            tap("family.newProfile.stage.sprout")
            tap("family.newProfile.create")
            XCTAssertTrue(node("family.profile.stage").waitForExistence(timeout: 15))
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        tap("family.parent.done")
        tap("family.picker.profile.animal.cow")
        tap("world.help")
        tap("world.target.item.seed.radish")
        let step = node("world.target.tool.hand")
        XCTAssertTrue(step.waitForExistence(timeout: 12))
        tap("world.pause")
        tap("pause.coPlay")
        picture("iPad-01-Partnerwahl")
        XCTAssertFalse(node("coop.join.animal.cow").exists)
        tap("coop.join.animal.sheep")
        let board = node("coop.board")
        XCTAssertTrue(board.waitForExistence(timeout: 10))
        XCTAssertTrue(node("coop.grip.left").exists)
        XCTAssertTrue(node("coop.grip.right").exists)
        picture("iPad-02-Zwei-Kinderhaende")
        func pos(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
            board.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
        }
        pos(0.26, 0.76).press(forDuration: 0.15, thenDragTo: pos(0.26, 0.23))
        XCTAssertEqual(board.value as? String, "Kreis liegt am Ziel")
        picture("iPad-03-Erster-Griff-am-Ziel")
        pos(0.74, 0.76).tap()
        pos(0.74, 0.23).tap()
        XCTAssertTrue(node("coop.delivered").waitForExistence(timeout: 10))
        picture("iPad-04-Gemeinsam-angekommen")
        tap("coop.finish")
        XCTAssertTrue(step.waitForExistence(timeout: 10))
        tap("world.pause")
        tap("pause.coPlay")
        tap("coop.join.helper")
        XCTAssertTrue(board.waitForExistence(timeout: 10))
        picture("iPad-05-Graue-Hilfshand")
        pos(0.74, 0.76).press(forDuration: 0.15, thenDragTo: pos(0.74, 0.23))
        XCTAssertEqual(board.value as? String, "Raute liegt am Ziel")
        XCTAssertFalse(node("coop.delivered").exists)
        tap("coop.close")
        XCTAssertTrue(step.waitForExistence(timeout: 10))
        step.tap()
        XCTAssertTrue(node("world.target.plot.garden.1.1").waitForExistence(timeout: 10))
    }
}
