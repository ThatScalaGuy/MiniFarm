import RealityKit
import UIKit
import XCTest

final class AppResourcesTests: XCTestCase {
    @MainActor
    func testOpeningSceneUsesLoadableBlenderModelsWithVisibleGeometry() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let host = UIViewController()
        window.rootViewController = host
        let viewport = ARView(frame: window.bounds, cameraMode: .nonAR, automaticallyConfigureSession: false)
        host.view.addSubview(viewport)
        window.isHidden = false
        defer { window.isHidden = true }
        let anchor = AnchorEntity(world: .zero)
        viewport.scene.anchors.append(anchor)
        for id in ["animal.cat", "animal.dog", "animal.chicken", "loc.garden", "loc.henhouse", "loc.shop", "crop.radish.sprout", "tool.can"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: "model." + id, withExtension: "usdz", subdirectory: "Models"))
            let entity = try await Entity(contentsOf: url)
            let bounds = entity.visualBounds(relativeTo: nil).extents
            XCTAssertGreaterThan(bounds.x * bounds.y * bounds.z, 0, "\(id) hat keine sichtbare räumliche Ausdehnung")
            var pending = [entity]
            var clips = 0
            while let node = pending.popLast() {
                clips += node.availableAnimations.count
                pending.append(contentsOf: node.children)
            }
            if id.hasPrefix("animal.") {
                anchor.addChild(entity)
                let idle = try XCTUnwrap(entity.findEntity(named: "Idle"), id)
                let clip = try XCTUnwrap(idle.availableAnimations.first, id)
                let initial = idle.transform
                let player = idle.playAnimation(clip.repeat())
                let deadline = ContinuousClock.now.advanced(by: .seconds(5))
                while idle.transform.matrix == initial.matrix && ContinuousClock.now < deadline {
                    try await Task.sleep(for: .milliseconds(85))
                }
                XCTAssertTrue(player.isPlaying, id)
                XCTAssertNotEqual(idle.transform.matrix, initial.matrix, "Keine native Bewegung von \(id)")
                player.stop()
                entity.removeFromParent()
            }
            let report = XCTAttachment(string: "\(id): räumliche Ausdehnung \(bounds); importierte Animationsressourcen: \(clips)")
            report.name = "RealityKit-Import-" + id
            report.lifetime = .keepAlways
            add(report)
        }
    }

    func testPrivacyManifestInInstalledAppDeclaresNoTrackingOrCollection() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let manifest = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual(manifest["NSPrivacyCollectedDataTypes"] as? [[String: String]], [])
    }
}
