import AppKit
import Foundation
import RealityKit
import simd

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let view = ARView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "--aggregate" {
    guard arguments.count >= 4 else {
        fatalError("Pass a USDZ path and at least two animated entity names")
    }
    let path = arguments[1]
    let entity = try Entity.load(contentsOf: URL(fileURLWithPath: path))
    guard let animation = entity.availableAnimations.first else {
        fatalError("\(path): no playable root animation")
    }
    let targets = arguments.dropFirst(2).map { name in
        guard let child = entity.findEntity(named: name) else {
            fatalError("\(path): missing \(name)")
        }
        return child
    }
    let anchor = AnchorEntity(world: .zero)
    view.scene.anchors.append(anchor)
    anchor.addChild(entity)
    let initial = targets.map(\.transform)
    let playback = entity.playAnimation(animation.repeat())
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.6))
    for (target, before) in zip(targets, initial) {
        let after = target.transform
        let delta = simd_length(after.scale - before.scale)
            + simd_length(after.translation - before.translation)
            + (1 - abs(simd_dot(after.rotation.vector, before.rotation.vector)))
        guard playback.isPlaying && delta > 0.0001 else {
            fatalError("\(path): root animation did not advance \(target.name)")
        }
        print("\(path): root animation advanced \(target.name)")
    }
    playback.stop()
    exit(0)
}
if arguments.first == "--clips" {
    let pairs = Array(arguments.dropFirst())
    guard !pairs.isEmpty, pairs.count.isMultiple(of: 2) else {
        fatalError("Pass pairs of USDZ path and animated entity name")
    }
    for index in stride(from: 0, to: pairs.count, by: 2) {
        let path = pairs[index]
        let entityName = pairs[index + 1]
        let entity = try Entity.load(contentsOf: URL(fileURLWithPath: path))
        guard let target = entity.findEntity(named: entityName), !target.availableAnimations.isEmpty else {
            fatalError("\(path): no playable animation on \(entityName)")
        }
        let anchor = AnchorEntity(world: .zero)
        view.scene.anchors.append(anchor)
        anchor.addChild(entity)
        let original = target.transform
        var changed = false
        for animation in target.availableAnimations {
            target.transform = original
            let playback = target.playAnimation(animation.repeat())
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.45))
            let after = target.transform
            let delta = simd_length(after.scale - original.scale)
                + simd_length(after.translation - original.translation)
                + (1 - abs(simd_dot(after.rotation.vector, original.rotation.vector)))
            if playback.isPlaying && delta > 0.0001 {
                changed = true
                playback.stop()
                break
            }
            playback.stop()
        }
        guard changed else {
            fatalError("\(path): RealityKit did not advance \(entityName)")
        }
        print("\(path): RealityKit advanced \(entityName)")
        view.scene.anchors.remove(anchor)
    }
    exit(0)
}
if arguments.first == "--parts" {
    let models = [
        ("dog", "App/Resources/Models/model.animal.dog.usdz", ["Head", "Tail"]),
        ("cat", "App/Resources/Models/model.animal.cat.usdz", ["Head", "Tail_base", "Tail_tip"]),
        ("chicken", "App/Resources/Models/model.animal.chicken.usdz", ["Head", "Beak"]),
        ("tractor", "App/Resources/Models/model.veh.tractor.usdz", ["Wheel", "Wheel_001", "Wheel_002", "Wheel_003"]),
    ]
    for (name, path, parts) in models {
        let entity = try Entity.load(contentsOf: URL(fileURLWithPath: path))
        for partName in parts {
            guard let part = entity.findEntity(named: partName) else {
                fatalError("\(name): missing part \(partName)")
            }
            let before = part.transform.rotation
            var transform = part.transform
            transform.rotation = before * simd_quatf(angle: 0.2, axis: SIMD3<Float>(0, 1, 0))
            part.transform = transform
            guard abs(simd_dot(before.vector, part.transform.rotation.vector)) < 0.99999 else {
                fatalError("\(name): could not rotate \(partName)")
            }
            print("\(name): \(partName) is individually addressable and rotatable")
        }
    }
    exit(0)
}
let staticOnly = arguments.first == "--static"
let specifiedPaths = staticOnly ? Array(arguments.dropFirst()) : arguments
let paths = specifiedPaths.isEmpty
    ? ["dog", "cat", "chicken"].map { "App/Resources/Models/model.animal.\($0).usdz" }
    : specifiedPaths

func modelCount(_ entity: Entity) -> Int {
    (entity.components[ModelComponent.self] == nil ? 0 : 1)
        + entity.children.reduce(0) { $0 + modelCount($1) }
}

for path in paths {
    let entity = try Entity.load(contentsOf: URL(fileURLWithPath: path))
    guard modelCount(entity) > 0 else {
        fatalError("\(path): RealityKit found no model geometry")
    }
    if staticOnly {
        print("\(path): RealityKit loaded \(modelCount(entity)) models")
        continue
    }
    guard let idle = entity.findEntity(named: "Idle"),
          let animation = idle.availableAnimations.first else {
        fatalError("\(path): no playable Idle animation")
    }

    let anchor = AnchorEntity(world: .zero)
    view.scene.anchors.append(anchor)
    anchor.addChild(entity)
    let before = idle.transform
    let playback = idle.playAnimation(animation.repeat())
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.6))
    let after = idle.transform
    let delta = simd_length(after.scale - before.scale)
        + simd_length(after.translation - before.translation)
    guard playback.isPlaying, delta > 0.0001 else {
        fatalError("\(path): RealityKit did not advance the Idle transform")
    }
    print("\(path): RealityKit loaded and advanced Idle (delta \(delta))")
    playback.stop()
    view.scene.anchors.remove(anchor)
}
