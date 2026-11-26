import XCTest
import UIKit

@MainActor
final class FarmJourneyTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func node(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = node(id)
        XCTAssertTrue(element.waitForExistence(timeout: 12), "Nicht sichtbar: \(id)\n\(app.debugDescription)", file: file, line: line)
        element.tap()
    }

    private func createFarm() throws {
        app.launchArguments = ["-MiniFarmFamilyUITesting", "-MiniFarmFamilyReset"]
        app.launch()
        tap("family.picker.setupButton")
        let prompt = node("family.gate.prompt")
        XCTAssertTrue(prompt.waitForExistence(timeout: 10))
        let words = NumberFormatter()
        words.locale = Locale(identifier: "de_DE")
        words.numberStyle = .spellOut
        let question = prompt.label
        let spelledNumber = question.components(separatedBy: CharacterSet.letters.inverted).last(where: { !$0.isEmpty })
        let answer = try XCTUnwrap((21...99).first { n in
            guard let word = words.string(from: NSNumber(value: n)) else { return false }
            return word.filter(\.isLetter).lowercased() == spelledNumber?.lowercased()
        }, "Zahlwort fehlt: \(question)")
        for digit in String(answer) { tap("family.gate.key.\(digit)") }
        tap("family.gate.submit")
        tap("family.parent.addProfile")
        tap("family.newProfile.avatar.animal.cow")
        tap("family.newProfile.stage.sprout")
        tap("family.newProfile.create")
        if !node("family.parent.done").exists {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            XCTAssertTrue(back.waitForExistence(timeout: 8))
            back.tap()
        }
        tap("family.parent.done")
        tap("family.picker.profile.animal.cow")
    }

    private func photo(_ name: String) {
        // The AX app rectangle is expressed in rotated coordinates. Cropping the
        // screen to it a second time can truncate landscape screenshots.
        let screen = XCUIScreen.main.screenshot().image
        let format = UIGraphicsImageRendererFormat()
        format.scale = screen.scale
        format.opaque = true
        let pixels = UIGraphicsImageRenderer(size: screen.size, format: format).pngData { _ in
            screen.draw(in: CGRect(origin: .zero, size: screen.size))
        }
        let evidence = XCTAttachment(data: pixels, uniformTypeIdentifier: "public.png")
        evidence.name = name + ".png"
        evidence.lifetime = .keepAlways
        add(evidence)
    }

    func testFirstHarvestAndRestoredStep() throws {
        XCUIDevice.shared.orientation = .portrait
        try createFarm()
        let garden = node("world.place.loc.garden")
        XCTAssertTrue(garden.waitForExistence(timeout: 20))
        photo("Hofplatz-Hochformat")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(garden.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(app.frame.width, app.frame.height)
        photo("Hofplatz-Querformat")
        tap("world.help")
        tap("world.target.item.seed.radish")
        let nextID = "world.target.tool.hand"
        XCTAssertTrue(node(nextID).waitForExistence(timeout: 10))
        app.terminate()
        app.launchArguments = ["-MiniFarmFamilyUITesting"]
        app.launch()
        tap("family.picker.profile.animal.cow")
        XCTAssertTrue(node(nextID).waitForExistence(timeout: 20), "Nach Neustart fehlt der nächste Schritt")
        photo("Saat-nach-Neustart")
        node(nextID).tap()
        let plot = "plot.garden.1.1"
        tap("world.target." + plot)
        let bed = node("world.bed." + plot)
        XCTAssertTrue(bed.waitForExistence(timeout: 10))
        XCTAssertEqual(bed.value as? String, "seed, nicht gegossen")
        tap("world.help")
        tap("world.target.tool.can")
        tap("world.target." + plot)
        XCTAssertEqual(bed.value as? String, "sprout, gegossen")
        photo("Gegossenes-Radieschen")
        tap("world.home")
        tap("world.help")
        tap("world.target.item.feed")
        tap("world.target.animal.chicken")
        XCTAssertEqual(node("world.resident").value as? String, "Heute versorgt")
        tap("world.day")
        tap("world.sleep")
        tap("ritual.night.read")
        photo("Tagesbild-nach-dem-Schlafen")
        tap("world.wake")
        tap("world.map")
        tap("world.map.loc.garden")
        XCTAssertEqual(bed.value as? String, "ripe, nicht gegossen")
        photo("Reife-Radieschen")
        tap("world.help")
        tap("world.target.tool.basket")
        tap("world.target." + plot)
        tap("world.target.item.radish")
        XCTAssertEqual(bed.value as? String, "Erde")
        tap("world.home")
        tap("world.help")
        tap("world.target.item.radish")
        let wallet = node("world.wallet")
        XCTAssertTrue(wallet.waitForExistence(timeout: 8))
        XCTAssertEqual(wallet.value as? String, "0")
        tap("world.target.shop.bell")
        XCTAssertTrue(node("world.shelf").waitForExistence(timeout: 10))
        XCTAssertEqual(wallet.value as? String, "1")
        photo("Nach-Verkauf-an-Tilda")
        app.terminate()
        app.launch()
        tap("family.picker.profile.animal.cow")
        XCTAssertTrue(wallet.waitForExistence(timeout: 12))
        XCTAssertEqual(wallet.value as? String, "1", "Der Verkauf muss nach einem Neustart erhalten bleiben")
    }
}
