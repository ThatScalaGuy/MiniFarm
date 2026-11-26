import XCTest

/// End-to-end checks of the family area: first setup, re-entry, the written gate and deletion.
///
/// Every launch passes `-MiniFarmFamilyUITesting`, so the app uses its own debug-only folder.
/// `-MiniFarmFamilyReset` empties only that folder, never the regular farms.
final class FamilyJourneyUITests: XCTestCase {
    private let timeout: TimeInterval = 20

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstSetupAndReentry() throws {
        let app = launch(reset: true)
        tap(app, "family.picker.setupButton")
        try solveGate(app)
        createProfile(app, avatar: "animal.cow")
        tap(app, "family.parent.done")

        let cow = element(app, "family.picker.profile.animal.cow")
        XCTAssertTrue(cow.waitForExistence(timeout: timeout))
        XCTAssertFalse(element(app, "family.picker.setupButton").exists)
        cow.tap()
        XCTAssertTrue(element(app, "family.picker").waitForNonExistence(timeout: timeout))

        app.terminate()
        let again = launch(reset: false)
        let savedCow = element(again, "family.picker.profile.animal.cow")
        XCTAssertTrue(savedCow.waitForExistence(timeout: timeout))
        XCTAssertFalse(element(again, "family.picker.setupButton").exists)

        tap(again, "family.picker.parentButton")
        XCTAssertTrue(element(again, "family.gate").waitForExistence(timeout: timeout))
        tap(again, "family.gate.cancel")
        XCTAssertTrue(element(again, "family.gate").waitForNonExistence(timeout: timeout))
        XCTAssertFalse(element(again, "family.parent").exists)

        savedCow.tap()
        XCTAssertTrue(element(again, "family.picker").waitForNonExistence(timeout: timeout))
    }

    @MainActor
    func testWrongAnswersLockTheGate() throws {
        let app = launch(reset: true)
        tap(app, "family.picker.setupButton")
        XCTAssertTrue(element(app, "family.gate.prompt").waitForExistence(timeout: timeout))
        for _ in 0..<3 {
            let wrong = try readAnswer(app) == 99 ? 98 : 99
            enter(wrong, in: app)
        }
        XCTAssertTrue(element(app, "family.gate.lockout").waitForExistence(timeout: timeout))
        XCTAssertFalse(element(app, "family.parent").exists)
        tap(app, "family.gate.cancel")
        tap(app, "family.picker.setupButton")
        XCTAssertTrue(element(app, "family.gate.lockout").waitForExistence(timeout: timeout))
    }

    @MainActor
    func testDeletingTheLastProfileReturnsToSetup() throws {
        let app = launch(reset: true)
        tap(app, "family.picker.setupButton")
        try solveGate(app)
        createProfile(app, avatar: "animal.sheep")
        tap(app, "family.parent.profile.animal.sheep")

        let delete = element(app, "family.profile.delete")
        scroll(app, to: delete)
        delete.tap()
        confirm(app, "family.confirm.delete", label: "Profil löschen")
        XCTAssertTrue(element(app, "family.parent.addProfile").waitForExistence(timeout: timeout))
        XCTAssertFalse(element(app, "family.parent.profile.animal.sheep").exists)
        tap(app, "family.parent.done")
        XCTAssertTrue(element(app, "family.picker.setupButton").waitForExistence(timeout: timeout))

        app.terminate()
        let again = launch(reset: false)
        XCTAssertTrue(element(again, "family.picker.setupButton").waitForExistence(timeout: timeout))
        XCTAssertFalse(element(again, "family.picker.profile.animal.sheep").exists)
    }

    // MARK: Steps

    @MainActor
    private func launch(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-MiniFarmFamilyUITesting", "-MiniFarmFamilyManagementUITesting"] + (reset ? ["-MiniFarmFamilyReset"] : [])
        app.launch()
        return app
    }

    @MainActor
    private func solveGate(_ app: XCUIApplication) throws {
        XCTAssertTrue(element(app, "family.gate.prompt").waitForExistence(timeout: timeout))
        enter(try readAnswer(app), in: app)
        XCTAssertTrue(element(app, "family.parent").waitForExistence(timeout: timeout))
    }

    @MainActor
    private func readAnswer(_ app: XCUIApplication) throws -> Int {
        let prompt = element(app, "family.gate.prompt").label
        let word = prompt.split(separator: " ").last.map(String.init) ?? ""
        return try XCTUnwrap(GermanNumbers.value(of: word), "Unbekanntes Zahlwort in: \(prompt)")
    }

    @MainActor
    private func enter(_ number: Int, in app: XCUIApplication) {
        for digit in String(number) {
            tap(app, "family.gate.key.\(digit)")
        }
        tap(app, "family.gate.submit")
    }

    @MainActor
    private func createProfile(_ app: XCUIApplication, avatar: String) {
        tap(app, "family.parent.addProfile")
        tap(app, "family.newProfile.avatar.\(avatar)")
        tap(app, "family.newProfile.stage.sprout")
        tap(app, "family.newProfile.create")
        XCTAssertTrue(element(app, "family.profile.stage").waitForExistence(timeout: timeout))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element(app, "family.parent.profile.\(avatar)").waitForExistence(timeout: timeout))
    }

    @MainActor
    private func confirm(_ app: XCUIApplication, _ identifier: String, label: String) {
        let byID = app.buttons.matching(identifier: identifier).firstMatch
        if byID.waitForExistence(timeout: 3) {
            byID.tap()
            return
        }
        let byLabel = app.buttons.matching(NSPredicate(format: "label == %@", label))
        XCTAssertTrue(byLabel.element(boundBy: byLabel.count - 1).waitForExistence(timeout: timeout))
        byLabel.element(boundBy: byLabel.count - 1).tap()
    }

    @MainActor
    private func scroll(_ app: XCUIApplication, to target: XCUIElement) {
        for _ in 0..<8 where !(target.exists && target.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(target.exists && target.isHittable, "Nicht erreichbar: \(target)")
    }

    @MainActor
    private func tap(_ app: XCUIApplication, _ identifier: String) {
        let target = element(app, identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Nicht gefunden: \(identifier)")
        target.tap()
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}

/// Reads the German number words of the gate, written independently from the app code.
enum GermanNumbers {
    static func value(of word: String) -> Int? {
        table[word.lowercased().trimmingCharacters(in: .punctuationCharacters)]
    }

    private static let table: [String: Int] = {
        let units = ["ein", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun"]
        let small = [
            "eins", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun", "zehn",
            "elf", "zwölf", "dreizehn", "vierzehn", "fünfzehn", "sechzehn", "siebzehn", "achtzehn", "neunzehn",
        ]
        let tens = ["zwanzig", "dreißig", "vierzig", "fünfzig", "sechzig", "siebzig", "achtzig", "neunzig"]
        var table: [String: Int] = [:]
        for (index, word) in small.enumerated() { table[word] = index + 1 }
        for (tenIndex, ten) in tens.enumerated() {
            let base = (tenIndex + 2) * 10
            table[ten] = base
            for (unitIndex, unit) in units.enumerated() {
                table["\(unit)und\(ten)"] = base + unitIndex + 1
            }
        }
        return table
    }()
}
