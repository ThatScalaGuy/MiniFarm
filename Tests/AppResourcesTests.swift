import XCTest

final class AppResourcesTests: XCTestCase {
    func testPrivacyManifestInInstalledAppDeclaresNoTrackingOrCollection() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let manifest = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual(manifest["NSPrivacyCollectedDataTypes"] as? [[String: String]], [])
    }
}
