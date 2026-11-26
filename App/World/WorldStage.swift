import RealityKit
import SwiftUI

struct WorldObject: Equatable, Identifiable {
    let id: String
    let choiceID: String?
    let model: String
    let label: String
    let symbol: String?
    let point: WPoint
    let isTarget: Bool
    let anchored: Bool

    static func targets(turn: WorldTurn?, site: WorldSite?, page: Int, perPage: Int, beds: [WorldBed] = []) -> [Self] {
        guard let turn, let site else { return [] }
        let all: [WorldChoice?] = turn.choices.isEmpty ? [nil] : turn.choices.map(Optional.some)
        let start = min(max(0, all.count - 1) / perPage, max(0, page)) * perPage
        let choices = all.dropFirst(start).prefix(perPage)
        return choices.enumerated().map { i, choice in
            let x = choices.count == 1 ? -0.62 : Float(i) * (3.9 / Float(choices.count-1)) - 1.95
            var local = WPoint(x, 0.16, 1.58 - x * 0.14)
            let prop = turn.physicalModel(choice)
            let model = prop == "friend" ? (site.animal ?? "animal.dog") : prop
            var anchored = false
            let visibleBeds = beds.filter { $0.locationID == site.id }
            if let id = choice?.modelID, let index = visibleBeds.firstIndex(where: { $0.id == id }) {
                local = WorldBedGrid(count: visibleBeds.count, field: site.id == "loc.field").center(index: index) + [0, 0.22, 0]
                anchored = true
            } else if model == site.animal, choices.filter({ turn.physicalModel($0) == model }).count == 1 {
                local = [0.68, 0.12, 0.01]; anchored = true
            }
            return Self(id: choice?.id ?? "action", choiceID: choice?.id, model: model,
                        label: choice?.label ?? turn.vignette?.label ?? "Anfassen", symbol: choice?.symbol,
                        point: site.center + local, isTarget: choice == nil || choice?.id == turn.targetID, anchored: anchored)
        }
    }
}

@MainActor
final class FarmDiorama {
    private let w = WorldWorkshop()
    let root = Entity()
    let camera = PerspectiveCamera()
    private let land = Entity(), furniture = Entity(), objects = Entity(), effects = Entity()
    private var frame: WorldFraming?
    private var sceneryKey: SceneryKey?
    private var lastObjects: [WorldObject] = []
    private var destinationID: String?
    private var focused: WorldSite?
    private var creature: Entity?
    private var creatureBase = WPoint.zero
    private var effectTime: Double = 0
    private var pendulum: Double = 0
    private var subscription: EventSubscription?
    private var still = true
    private var particles = 1.0
    private var activeObject: Entity?
    private var animating: [(entity: Entity, start: WPoint, end: WPoint, arc: Float)] = []
    private var furrow: Entity?
    private var routeStart = WPoint.zero
    private var resident: Entity?
    private var residentRest = Transform()
    private var light: DirectionalLight
    private var landKey = ""

    private struct SceneryKey: Equatable {
        var places: [String]
        var season: String
        var level: Int
        var beds: [WorldBed]
        var shelf: [String: Int]
        var cared: Set<String>
        var focus: String?
        var playing: Bool
        var decorations: [WorldDecoration]
    }

    init() {
        light = DirectionalLight()
        light.light.intensity = 1650
        light.light.color = UIColor(farmRGB: 0xffedce)
        light.shadow = .init(shadowProjection: .automatic(maximumDistance: 110), depthBias: 1.1)
        light.look(at: .zero, from: [-6, 10, 6], relativeTo: nil)
        for entity in [land, furniture, objects, effects, camera, light] { root.addChild(entity) }
        camera.camera = .init(near: 0.05, far: 320, fieldOfViewInDegrees: WorldFraming.fov)
    }

    func install(_ content: inout RealityViewCameraContent) {
        content.camera = .virtual
        content.renderingEffects.motionBlur = .disabled
        content.renderingEffects.depthOfField = .disabled
        content.add(root)
        subscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] e in self?.tick(e.deltaTime) }
    }

    func render(state: FarmWorldState, site: WorldSite?, targets: [WorldObject], framing: WorldFraming, motion: Bool) {
        still = !motion
        particles = max(0, min(1, state.particleScale))
        let key = SceneryKey(places: state.locationIDs, season: state.season, level: state.farmLevel, beds: state.beds,
                             shelf: state.shelf, cared: state.caredFor, focus: site?.id, playing: state.active != nil,
                             decorations: state.decorations)
        let sites = WorldSite.all.filter { key.places.contains($0.id) }
        let newLand = "\(key.level)|\(key.season)|\(key.places.joined(separator: ","))"
        if landKey != newLand {
            landKey = newLand
            land.children.removeAll()
            let size = WorldFraming.island(level: key.level)
            w.soil(land, size, season: key.season)
            for s in sites {
                // The short branch joins the main east–west lane at a walkable gate.
                w.lane(land, from: [s.center.x, 0, 0], to: s.center + [0, 0, s.center.z < 0 ? 1.22 : -1.22])
            }
            let xs = sites.map(\.center.x)
            if let lo = xs.min(), let hi = xs.max(), hi > lo { w.lane(land, from: [lo, 0, 0], to: [hi, 0, 0], width: 0.83) }
            let hw = size.x / 2, hd = size.y / 2
            for side: Float in [-1, 1] {
                w.fence(land, from: [side*(hw-1), 0, -hd + 1.65], to: [side*(hw-1), 0, -hd + 3.85], posts: 3)
                w.fence(land, from: [side*(hw-1), 0, -hd + 1.65], to: [side*(hw-3.4), 0, -hd + 1.65], posts: 3)
                for j in 0..<5 {
                    let x = side * (hw - 1.5 - Float(j)*0.43)
                    if key.season != "season.winter" {
                        w.flower(land, at: [x, 0, hd - 1.2 - 0.21*sin(Float(j)*3)], color: j.isMultiple(of: 2) ? 0xe9bb68 : 0xdd8b85)
                    }
                }
                let plant = w.group(land, at: [side*(hw-2), 0, -hd+1.8])
                w.tree(plant, season: key.season, fruit: false)
                plant.scale = .init(repeating: 0.71)
            }
        }
        if key != sceneryKey {
            furniture.children.removeAll()
            for place in sites {
                // Cut away foreground buildings when looking into a place.
                if let site, place.id != site.id, place.center.z >= site.center.z - 1 { continue }
                w.place(place, in: furniture, state: state, focus: place == site, active: place == site && state.active != nil)
            }
            let pos = site.map { $0.center + [-2.05, 0.08, 0.48] } ?? [-0.63, 0.075, 0.31]
            creature = w.toy("animal.dog", in: furniture, at: pos, span: site == nil ? 1.68 : 1.28, yaw: 0.43)
            creatureBase = pos
            activeObject = nil
            sceneryKey = key
        }
        let dest = state.active?.vignette?.destination
        if targets != lastObjects || dest != destinationID || focused != site {
            objects.children.removeAll()
            lastObjects = targets
            destinationID = dest
            if let site, let dest {
                let resolved = dest == "friend" ? (site.animal ?? "animal.dog") : dest
                if !resolved.hasPrefix("animal."), !(resolved == "bed" && state.beds.contains(where: { $0.locationID == site.id })) {
                    w.toy(resolved, in: objects, at: dropPoint(site), span: dest == "bed" || dest == "lane" ? 1.54 : 0.85)
                }
            }
            for obj in targets {
                if obj.anchored {
                    if obj.isTarget {
                        let p = obj.point
                        for i in 0..<10 {
                            let a = Float(i) * .pi / 5
                            w.oval(objects, p + [0.54*cos(a), 0.025, 0.46*sin(a)], [0.12, 0.055, 0.12], 0xffe09b)
                        }
                    }
                    continue
                }
                let g = w.group(objects, at: obj.point - [0, 0.09, 0])
                w.drum(g, .zero, [1.13, 0.09, 0.87], obj.isTarget ? 0xf0cc7c : 0xc3a87b)
                w.drum(g, [0, 0.047, 0], [1.02, 0.05, 0.76], 0xf5e3b9)
                let e = w.toy(obj.model, in: objects, at: obj.point, span: targets.count == 1 ? 1.16 : 0.96, yaw: -0.12)
                e.name = "pick:" + obj.id
                e.components.set(InputTargetComponent())
                e.components.set(CollisionComponent(shapes: [.generateBox(size: [1.28, 1.25, 1.16]).offsetBy(translation: [0, 0.56, 0])]))
            }
        }
        let old = frame
        if old != framing {
            let dest = Entity()
            dest.look(at: framing.center, from: framing.eye, relativeTo: nil)
            if motion, old?.size == framing.size {
                camera.move(to: dest.transform, relativeTo: root, duration: 0.9 / max(0.5, min(1.3, state.cameraSpeedScale)), timingFunction: .easeInOut)
            } else {
                camera.stopAllAnimations()
                camera.transform = dest.transform
            }
            frame = framing
        } else if !motion, let frame {
            camera.stopAllAnimations()
            camera.look(at: frame.center, from: frame.eye, relativeTo: root)
        }
        light.light.color = UIColor(farmRGB: state.sunProgress > 0.72 ? 0xffdbaf : (state.season == "season.winter" ? 0xeaf3ff : 0xffefd6))
        focused = site
    }

    func drag(_ obj: WorldObject, translation: CGSize) {
        guard let f = frame, let e = objects.findEntity(named: "pick:" + obj.id) else { return }
        let units = 2 * simd_distance(f.center, f.eye) * tan(WorldFraming.fov * .pi / 360) / Float(max(1, f.size.height))
        e.position = obj.point + units * (Float(translation.width) * f.right - Float(translation.height) * f.up)
        activeObject = e
    }

    func resetDrag() {
        if let activeObject, let obj = lastObjects.first(where: { activeObject.name == "pick:" + $0.id }) {
            activeObject.position = obj.point
        }
        activeObject = nil
    }

    func dropPoint(_ site: WorldSite) -> WPoint { site.center + [1.48, 0.095, 0.8] }

    func respond(to obj: WorldObject, turn: WorldTurn, site: WorldSite, motion: Bool) {
        effects.children.removeAll()
        animating.removeAll()
        furrow = nil
        resident?.transform = residentRest
        resident = nil
        effectTime = 0
        let dest = dropPoint(site) + [0, 0.32, 0]
        let tag = turn.vignette?.effect
        let particleColor = tag == "water" ? 0x6db9cb : (tag == "care" ? 0xe8a08e : 0xefd074)
        let machine = WorldVignette.driving.contains(turn.offering.activityID)
        if machine {
            let id = turn.offering.activityID == "act.field.combine" ? "veh.combine" : "veh.tractor"
            let rig = w.group(effects)
            w.toy(id, in: rig, span: 1.36)
            if id == "veh.tractor" {
                w.toy(obj.model.hasPrefix("imp.") ? obj.model : "imp.plow", in: rig, at: [0.98, 0.02, 0], span: 0.79)
            }
            routeStart = site.center + [1.44, 0.3, 0.77]
            let end = routeStart - [2.83, 0, 0]
            rig.position = motion ? routeStart : end
            animating.append((rig, rig.position, end, 0))
            furrow = w.box(effects, routeStart, [1, 0.055, 0.19], 0x8c6849)
            return
        }
        if let species = site.animal, let animal = furniture.findEntity(named: "resident." + species) {
            resident = animal
            residentRest = animal.transform
        }
        let n = motion && !machine ? max(1, Int(5 * particles)) : 1
        for i in 0..<n {
            let end = dest + WPoint(0.21 * cos(Float(i)*2.1), Float(i)*0.065, 0.18 * sin(Float(i)*2.1))
            let e: Entity
            if machine { e = w.toy(obj.model, in: effects, span: 1.12) }
            else if ["egg", "crop", "gift", "mail", "wool", "flower"].contains(tag), i == 0 {
                e = w.toy(tag == "egg" ? "item.egg" : obj.model, in: effects, span: 0.46)
            } else { e = w.oval(effects, .zero, [0.13, tag == "water" ? 0.22 : 0.13, 0.13], particleColor) }
            let start = motion ? obj.point + [0, 0.52, 0] : end
            e.position = start
            animating.append((e, start, end, motion && !machine ? 0.5 + Float(i)*0.045 : 0))
        }
    }

    private func tick(_ dt: Double) {
        pendulum += min(dt, 0.05)
        if let creature {
            creature.position = creatureBase + [0, still ? 0 : 0.017 * Float(sin(pendulum * 1.7)), 0]
        }
        guard !animating.isEmpty else { return }
        effectTime += min(dt, 0.12)
        let t = min(1, Float(effectTime / 0.78))
        for fx in animating {
            fx.entity.position = fx.start + (fx.end - fx.start) * t + [0, fx.arc * sin(t * .pi), 0]
        }
        if let furrow {
            let width = max(0.06, (still ? 1 : t) * 2.83)
            furrow.scale.x = width
            furrow.position = routeStart - [width * 0.5, 0.025, 0]
        }
        if let resident, !still {
            resident.orientation = residentRest.rotation * simd_quatf(angle: 0.165 * sin(t * .pi * 2), axis: [1,0,0])
        }
        if effectTime > 1.3 {
            resident?.transform = residentRest; resident = nil
            animating.removeAll(); effects.children.removeAll(); furrow = nil
        }
    }
}
