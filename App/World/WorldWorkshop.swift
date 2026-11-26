import Combine
import OSLog
import RealityKit
import UIKit

extension UIColor {
    convenience init(farmRGB v: Int) {
        self.init(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255,
                  blue: CGFloat(v & 255) / 255, alpha: 1)
    }
}

enum WorldFront: String, Decodable {
    case positiveX = "+X", negativeX = "-X", positiveZ = "+Z", negativeZ = "-Z"

    private var bearing: Float {
        switch self { case .positiveX: .pi/2; case .negativeX: -.pi/2; case .positiveZ: 0; case .negativeZ: .pi }
    }
    func turn(to target: Self) -> simd_quatf {
        simd_quatf(angle: target.bearing - bearing, axis: [0, 1, 0])
    }
}

private struct WorldModelLibrary {
    struct Asset: Decodable {
        let id, file: String
        let variantOf: String?
        let frontAxis: WorldFront?
        let boundsMin, boundsMax: WPoint
    }
    private struct Manifest: Decodable { let assets: [Asset] }
    let assets: [String: Asset]
    let folder: URL?

    init(bundle: Bundle) {
        let log = Logger(subsystem: "MiniFarm", category: "WorldModels")
        let folders: [String?] = ["Models", "Resources/Models", "App/Resources/Models", nil]
        guard let file = folders.lazy.compactMap({ bundle.url(forResource: "manifest", withExtension: "json", subdirectory: $0) }).first else {
            log.error("Model manifest missing; using handcrafted farm props")
            folder = nil; assets = [:]; return
        }
        do {
            let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: file))
            assets = Dictionary(uniqueKeysWithValues: manifest.assets.map { ($0.id, $0) })
            folder = file.deletingLastPathComponent()
        } catch {
            log.error("Invalid model manifest: \(error.localizedDescription, privacy: .public)")
            assets = [:]; folder = nil
        }
    }
}

@MainActor private final class WorldToySocket: Entity {
    var assetID = ""
    var front = WorldFront.positiveZ
    var span: Float = 1
    let rest = Entity()
    var action: String?
    var generation = 0
    var variant: Entity?
    var player: AnimationPlaybackController?
    var completion: (any Cancellable)?
}

/// Shared toy parts and normalized, locally bundled USDZ instances. The receiver
/// is kept when its model arrives so input targets and animations do not jump.
@MainActor
final class WorldWorkshop {
    static let cream = 0xffedcd, timber = 0xa56a40, darkWood = 0x704932, leaf = 0x699752
    static let straw = 0xe9b657, clay = 0xc65b43, teal = 0x479a99, ink = 0x372f30
    private var meshes: [String: MeshResource] = [:]
    private var materials: [Int: SimpleMaterial] = [:]
    private var templates: [URL: Task<Entity?, Never>] = [:]
    private static let bundledModels = WorldModelLibrary(bundle: .main)
    private let models: WorldModelLibrary
    private let performers = NSHashTable<WorldToySocket>.weakObjects()
    private let logger = Logger(subsystem: "MiniFarm", category: "WorldModels")
    private struct Idle {
        weak var entity: Entity?
        let player: AnimationPlaybackController
    }
    private var idles: [Idle] = []
    private var playIdle = false

    func setIdleMotion(_ enabled: Bool) {
        if playIdle && !enabled {
            for socket in performers.allObjects { setAction(nil, on: socket) }
        }
        idles.removeAll { loop in
            guard loop.entity?.scene != nil else { loop.player.stop(); return true }
            if playIdle != enabled {
                if enabled { loop.player.resume() } else { loop.player.pause() }
            }
            return false
        }
        playIdle = enabled
    }

    init(bundle: Bundle = .main) {
        models = bundle == .main ? Self.bundledModels : WorldModelLibrary(bundle: bundle)
    }

    func group(_ parent: Entity? = nil, at p: WPoint = .zero) -> Entity {
        let e = Entity()
        e.position = p
        parent?.addChild(e)
        return e
    }

    private func part(_ key: String, _ color: Int, _ parent: Entity, _ p: WPoint,
                      _ scale: WPoint, make: () -> MeshResource) -> Entity {
        let mesh: MeshResource
        if let found = meshes[key] { mesh = found }
        else { mesh = make(); meshes[key] = mesh }
        let material = materials[color] ?? SimpleMaterial(color: UIColor(farmRGB: color), roughness: 0.88, isMetallic: false)
        materials[color] = material
        let e = ModelEntity(mesh: mesh, materials: [material])
        parent.addChild(e)
        e.position = p
        e.scale = scale
        return e
    }

    @discardableResult func box(_ parent: Entity, _ p: WPoint, _ size: WPoint, _ color: Int,
                                round: Float = 0.07) -> Entity {
        part("box\(round)", color, parent, p, size) { .generateBox(size: 1, cornerRadius: round) }
    }

    @discardableResult func oval(_ parent: Entity, _ p: WPoint, _ size: WPoint, _ color: Int) -> Entity {
        part("sphere", color, parent, p, size) { .generateSphere(radius: 0.5) }
    }

    @discardableResult func drum(_ parent: Entity, _ p: WPoint, _ size: WPoint, _ color: Int) -> Entity {
        part("cylinder", color, parent, p, size) { .generateCylinder(height: 1, radius: 0.5) }
    }

    func tilt(_ e: Entity, _ angle: Float, _ axis: WPoint = [0, 0, 1]) {
        e.orientation = simd_quatf(angle: angle, axis: axis)
    }

    @discardableResult func stick(_ parent: Entity, from a: WPoint, to b: WPoint, width: Float, color: Int) -> Entity {
        let v = b - a
        let e = drum(parent, (a + b) / 2, [width, simd_length(v), width], color)
        e.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(v))
        return e
    }

    func shadow(_ p: Entity, _ size: Float, z: Float = 0) {
        oval(p, [0, 0.006, z], [size, 0.018, size * 0.56], 0x84945a)
    }

    func tree(_ p: Entity, season: String, fruit: Bool, level: Int = 1) {
        let autumn = season == "season.autumn", winter = season == "season.winter"
        let greens = autumn ? [0xc1803b, 0xcc9c45, 0xe2af57] :
            winter ? [0x91aea0, 0xb4c6af, 0xd5dfcf] : [0x638e53, 0x80a958, 0x99ba69]
        shadow(p, 2.4)
        stick(p, from: [0, 0, 0], to: [0.1, 1.85, 0], width: 0.38, color: Self.darkWood)
        stick(p, from: [0.04, 0.95, 0], to: [-0.64, 1.78, 0.12], width: 0.22, color: Self.timber)
        stick(p, from: [0.05, 1.1, 0], to: [0.7, 2.05, -0.2], width: 0.2, color: Self.timber)
        for (i, pos) in ([[-0.63, 1.95, 0.12], [0.56, 2.06, -0.25], [0, 2.52, 0], [0.25, 1.94, 0.43]] as [WPoint]).enumerated() {
            oval(p, pos, [1.54, 1.26, 1.35], greens[i % 3])
        }
        if fruit || level > 1 || season == "season.spring" {
            for i in 0..<8 {
                let angle = Float(i) * 2.4
                let pos = WPoint(cos(angle) * 0.98, 2.1 + 0.48 * sin(angle * 0.7), sin(angle) * 0.72)
                oval(p, pos, [0.18, 0.2, 0.18], fruit || autumn ? Self.clay : 0xf6d9bd)
            }
        }
    }

    func flower(_ p: Entity, at pos: WPoint = .zero, color: Int = 0xe89383) {
        let g = group(p, at: pos)
        drum(g, [0, 0.22, 0], [0.055, 0.44, 0.055], 0x57794a)
        tilt(oval(g, [-0.09, 0.24, 0], [0.24, 0.09, 0.1], Self.leaf), -0.6)
        for i in 0..<5 {
            let a = Float(i) * .pi * 0.4
            oval(g, [cos(a) * 0.1, 0.46 + sin(a) * 0.09, 0], [0.16, 0.16, 0.11], color)
        }
        oval(g, [0, 0.46, 0.07], [0.13, 0.13, 0.09], Self.straw)
    }

    /// 1 unit long, facing +Z. Ears, bill, snout, wool, comb, collar and mane
    /// remain readable even before the corresponding USDZ has finished loading.
    func animal(_ id: String, _ p: Entity) {
        let bird = ["animal.chicken", "animal.duck", "animal.bird"].contains(id)
        let pig = id == "animal.pig", dog = id == "animal.dog", cow = id == "animal.cow"
        let horse = id == "animal.horse", rabbit = id == "animal.rabbit", sheep = id == "animal.sheep"
        if id == "animal.bee" {
            oval(p, [0, 0.36, 0], [0.7, 0.52, 1], Self.straw)
            oval(p, [0, 0.36, 0.1], [0.71, 0.53, 0.23], Self.darkWood)
            for s: Float in [-1, 1] { oval(p, [s * 0.28, 0.64, -0.02], [0.52, 0.09, 0.64], Self.cream) }
            return
        }
        let fur = pig ? 0xeaa394 : (dog || horse || id == "animal.cat" ? 0xaa714e : Self.cream)
        oval(p, [0, 0.51, -0.15], [0.73, bird ? 0.79 : 0.6, 0.98], fur)
        for s: Float in [-1, 1] {
            for z: Float in (bird ? [0] : [-0.45, 0.16]) {
                box(p, [s * 0.23, 0.22, z], [0.16, 0.41, 0.2], bird ? Self.straw : fur, round: 0.3)
                oval(p, [s * 0.23, 0.09, z + 0.04], [0.2, 0.16, bird ? 0.28 : 0.22], bird ? Self.straw : (dog ? Self.cream : fur))
            }
        }
        oval(p, [0, 0.87, 0.3], [0.65, 0.66, 0.58], bird || cow || sheep ? Self.cream : fur)
        if cow || sheep {
            for pos in ([[-0.27, 0.64, -0.38], [0.25, 0.65, -0.06], [0, 0.77, -0.46]] as [WPoint]) {
                oval(p, pos, [0.34, 0.29, 0.33], cow ? Self.ink : 0xfff4e1)
            }
        }
        if bird {
            oval(p, [0, 0.81, 0.61], [id == "animal.duck" ? 0.35 : 0.19, 0.13, 0.25], 0xe6a24b)
            for i in 0..<3 {
                if id == "animal.chicken" { oval(p, [0, 1.18, 0.2 + Float(i) * 0.1], [0.11, 0.22, 0.13], Self.clay) }
            }
            for s: Float in [-1, 1] {
                oval(p, [s * 0.32, 0.57, -0.15], [0.18, 0.42, 0.62], 0xe4c59b)
            }
            tilt(oval(p, [0, 0.69, -0.62], [0.32, 0.47, 0.34], 0xb38460), -0.3, [1, 0, 0])
        } else {
            for s: Float in [-1, 1] {
                let tall = rabbit || (dog && s > 0) || horse
                let ear = oval(p, [s * 0.27, tall ? 1.19 : 0.97, 0.25],
                               [0.21, tall ? (rabbit ? 0.53 : 0.33) : 0.4, 0.17], dog || cow ? Self.darkWood : fur)
                tilt(ear, tall ? -s * 0.24 : -s * 0.64)
            }
            oval(p, [0, 0.79, 0.57], [pig || cow ? 0.47 : 0.4, 0.28, 0.3], pig || cow ? 0xe2a09a : Self.cream)
            oval(p, [0, 0.86, 0.71], [pig ? 0.21 : 0.14, 0.095, 0.08], pig ? 0xba7a73 : Self.ink)
            tilt(oval(p, [0.13, 0.64, -0.65], [0.16, 0.46, 0.19], fur), -0.65, [1, 0, 0])
            if dog {
                oval(p, [0, 0.675, 0.23], [0.67, 0.17, 0.55], Self.teal)
                tilt(box(p, [0.01, 0.59, 0.49], [0.22, 0.24, 0.05], Self.teal), 0.78)
                oval(p, [0.13, 0.96, 0.55], [0.24, 0.29, 0.08], Self.darkWood)
            }
        }
        for s: Float in [-1, 1] {
            oval(p, [s * 0.147, 0.97, 0.562], [0.09, 0.108, 0.066], Self.ink)
            oval(p, [s * 0.147 - 0.014, 0.994, 0.593], [0.023, 0.023, 0.013], 0xffffff)
        }
    }

    @discardableResult func toy(_ id: String, in parent: Entity, at p: WPoint = .zero,
                                span: Float = 1, yaw: Float = 0, topSurface: Bool = false,
                                facing: WorldFront = .positiveZ,
                                fallback: ((Entity) -> Void)? = nil) -> Entity {
        let socket = WorldToySocket()
        parent.addChild(socket)
        socket.position = p; socket.assetID = id; socket.front = facing; socket.span = span
        tilt(socket, yaw, [0, 1, 0])
        socket.addChild(socket.rest)
        let proxy = group(socket.rest)
        let facingParts = group(proxy)
        if let fallback { fallback(facingParts) } else { prop(id, in: facingParts) }
        let proxyFront: WorldFront = id.hasPrefix("veh.") || id.hasPrefix("imp.") ? .positiveX : .positiveZ
        facingParts.orientation = proxyFront.turn(to: facing)
        normalize(proxy, span: span, topSurface: topSurface)
        guard let asset = models.assets[id], let task = load(asset) else { return socket }
        Task { [weak socket, weak proxy] in
            guard let template = await task.value, let socket, let proxy else { return }
            let model = template.clone(recursive: true)
            let holder = mounted(model, asset: asset, socket: socket, topSurface: topSurface)
            socket.rest.addChild(holder)
            proxy.removeFromParent()
            // The Blender export puts the clip on a child, not the USDZ root.
            if id.hasPrefix("animal."), let idle = model.findEntity(named: "Idle"),
               let clip = idle.availableAnimations.first {
                let player = idle.playAnimation(clip.repeat(), startsPaused: !playIdle)
                idles.append(Idle(entity: idle, player: player))
            }
        }
        return socket
    }

    private func load(_ asset: WorldModelLibrary.Asset) -> Task<Entity?, Never>? {
        guard let url = models.folder?.appendingPathComponent(asset.file) else { return nil }
        if let task = templates[url] { return task }
        let task = Task<Entity?, Never> {
            do { return try await Entity(contentsOf: url) }
            catch {
                logger.error("Could not load \(asset.file, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        templates[url] = task
        return task
    }

    private func mounted(_ model: Entity, asset: WorldModelLibrary.Asset, socket: WorldToySocket, topSurface: Bool = false) -> Entity {
        let mount = group()
        let turn = asset.frontAxis?.turn(to: socket.front) ?? simd_quatf(angle: 0, axis: [0,1,0])
        // Use the exported first-frame bounds, not the invalid pre-playback pose
        // of a wheel variant. Do not rotate or rescale a root with its own clip.
        let extent = asset.boundsMax - asset.boundsMin
        let k = socket.span / max(0.0001, max(extent.x, max(extent.y, extent.z)))
        var center = (asset.boundsMin + asset.boundsMax) / 2
        center.y = topSurface ? asset.boundsMax.y : asset.boundsMin.y
        mount.orientation = turn; mount.scale = .init(repeating: k); mount.position = -turn.act(center * k)
        mount.name = asset.id
        mount.addChild(model)
        return mount
    }

    func setAction(_ motion: String?, on entity: Entity, looping: Bool = false) {
        guard let socket = entity as? WorldToySocket, socket.action != motion else { return }
        socket.generation += 1
        let generation = socket.generation
        socket.completion?.cancel(); socket.completion = nil
        socket.player?.stop(); socket.player = nil
        socket.variant?.removeFromParent(); socket.variant = nil
        socket.rest.isEnabled = true; socket.action = motion
        guard let motion else { performers.remove(socket); return }
        let id = "anim." + socket.assetID + "." + motion
        guard let asset = models.assets[id], asset.variantOf == socket.assetID, let task = load(asset) else { return }
        performers.add(socket)
        Task { [weak socket] in
            guard let template = await task.value, let socket, socket.generation == generation, let scene = socket.scene else { return }
            let model = template.clone(recursive: true)
            guard let clip = model.availableAnimations.first else {
                logger.error("Missing root animation in \(asset.file, privacy: .public)")
                return
            }
            let mount = mounted(model, asset: asset, socket: socket)
            socket.addChild(mount); socket.variant = mount
            if !looping {
                socket.completion = scene.subscribe(to: AnimationEvents.PlaybackCompleted.self, on: model) { [weak self, weak socket] _ in
                    guard let socket, socket.generation == generation else { return }
                    self?.setAction(nil, on: socket)
                }
            }
            socket.player = model.playAnimation(looping ? clip.repeat() : clip)
            socket.rest.isEnabled = false
        }
    }

    private func normalize(_ e: Entity, span: Float, topSurface: Bool) {
        let b = e.visualBounds(relativeTo: e)
        let length = max(b.extents.x, b.extents.y, b.extents.z)
        guard length.isFinite, length > 0.0001 else { return }
        let k = span / length
        e.scale = .init(repeating: k)
        e.position = -k * [b.center.x, topSurface ? b.max.y : b.min.y, b.center.z]
    }
}
