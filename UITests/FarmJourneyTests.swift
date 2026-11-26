import XCTest

final class FarmJourneyTests: XCTestCase {
    @MainActor
    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.images["farm.opening"].waitForExistence(timeout: 15))
    }
}
