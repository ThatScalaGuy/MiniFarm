import RealityKit
import UIKit
import XCTest
@testable import MiniFarm

@MainActor final class WorldModelTests: XCTestCase {
    private func liveScene() throws -> (ARView, AnchorEntity) {
        let window = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow))
        let view = ARView(frame: CGRect(x: 0, y: 0, width: 160, height: 160), cameraMode: .nonAR, automaticallyConfigureSession: false)
        window.addSubview(view)
        let anchor = AnchorEntity(world: .zero)
        view.scene.addAnchor(anchor)
        return (view, anchor)
    }

    private func awaitCondition(_ condition: () -> Bool) async throws {
        let end = ContinuousClock.now.advanced(by: .seconds(12))
        while !condition(), ContinuousClock.now < end { try await Task.sleep(for: .milliseconds(35)) }
        XCTAssertTrue(condition())
    }

    private func assertMoves(_ joint: Entity) async throws {
        let first = joint.transform
        var delta: Float = 0
        let end = ContinuousClock.now.advanced(by: .seconds(1))
        while delta < 0.002, ContinuousClock.now < end {
            try await Task.sleep(for: .milliseconds(45))
            let current = joint.transform
            delta = simd_length(current.translation-first.translation) + 1 - abs(simd_dot(first.rotation.vector, current.rotation.vector))
        }
        XCTAssertGreaterThan(delta, 0.002, joint.name)
        let sample = XCTAttachment(string: "\(joint.name): sampled transform delta \(delta)")
        sample.name = joint.name; sample.lifetime = .keepAlways; add(sample)
    }

    func testFeedingPecksOnTheRebuiltHenAndReturnsToRest() async throws {
        let (view, anchor) = try liveScene()
        defer { view.removeFromSuperview() }
        let stage = FarmDiorama()
        anchor.addChild(stage.root)
        let site = try XCTUnwrap(WorldSite.at("loc.henhouse"))
        let offer = WorldOffering(id: "meal", activityID: "act.animal.feed", locationID: site.id)
        let choice = WorldChoice(id: "animal.chicken", modelID: "animal.chicken", label: "Frieda")
        let turn = WorldTurn(offering: offer, stepID: "animal", stepIndex: 1, stepCount: 2, choices: [choice], targetID: choice.id)
        var state = FarmWorldState(locationIDs: [site.id], offerings: [offer], active: turn)
        let targets = WorldObject.targets(turn: turn, site: site, page: 0, perPage: 2)
        let target = try XCTUnwrap(targets.first)
        let frame = WorldFraming(size: view.bounds.size, site: site, level: 1)
        stage.render(state: state, site: site, targets: targets, framing: frame, motion: true, detail: nil)
        stage.respond(to: target, turn: turn, site: site, motion: true)
        state.active = nil; state.caredFor = ["animal.chicken.1"]
        stage.render(state: state, site: site, targets: [], framing: frame, motion: true, detail: nil)
        let hen = try XCTUnwrap(stage.root.findEntity(named: "resident.animal.chicken"))
        let action = "anim.animal.chicken.eat"
        try await awaitCondition { hen.findEntity(named: action) != nil }
        let variant = try XCTUnwrap(hen.findEntity(named: action))
        try await assertMoves(XCTUnwrap(variant.findEntity(named: "Eat")))
        try await awaitCondition { hen.findEntity(named: action) == nil }
        XCTAssertTrue(try XCTUnwrap(hen.findEntity(named: "animal.chicken")).isEnabledInHierarchy)

        stage.greetPelle(at: site, motion: true)
        stage.render(state: state, site: site, targets: [], framing: frame, motion: false, detail: nil)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertNil(stage.root.findEntity(named: "anim.animal.dog.tailwag"), "A late load must not animate a paused scene")
    }

    func testWheelVariantAndParkedModelFaceTheSameRowWhileTildaFacesTheChild() async throws {
        let (view, anchor) = try liveScene()
        defer { view.removeFromSuperview() }
        let w = WorldWorkshop()
        let tractor = w.toy("veh.tractor", in: anchor, facing: .negativeX)
        let tilda = w.toy("npc.tilda", in: anchor)
        try await awaitCondition { tilda.findEntity(named: "npc.tilda") != nil && tractor.findEntity(named: "veh.tractor") != nil }
        let person = try XCTUnwrap(tilda.findEntity(named: "npc.tilda"))
        let rest = try XCTUnwrap(tractor.findEntity(named: "veh.tractor"))
        XCTAssertEqual(person.orientation.act([0,0,1]).z, 1, accuracy: 0.001)
        XCTAssertEqual(rest.orientation.act([-1,0,0]).x, -1, accuracy: 0.001)
        w.setAction("wheels", on: tractor, looping: true)
        try await awaitCondition { tractor.findEntity(named: "anim.veh.tractor.wheels") != nil }
        let variant = try XCTUnwrap(tractor.findEntity(named: "anim.veh.tractor.wheels"))
        XCTAssertEqual(variant.orientation.act([0,0,1]).x, -1, accuracy: 0.001)
        try await assertMoves(XCTUnwrap(variant.findEntity(named: "Rolling_wheel")))
        w.setAction(nil, on: tractor)
        XCTAssertNil(tractor.findEntity(named: "anim.veh.tractor.wheels"))
        XCTAssertTrue(rest.isEnabledInHierarchy)
    }
}
