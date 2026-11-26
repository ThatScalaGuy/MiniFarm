import CoreGraphics
import simd

typealias WPoint = SIMD3<Float>

struct WorldBedGrid {
    let columns: Int
    let rows: Int
    var width: Float { 3.8 / Float(columns) }
    var depth: Float { 2.35 / Float(rows) }

    init(count: Int, field: Bool) {
        columns = field ? (count > 48 ? 12 : count > 16 ? 8 : 4) : (count > 6 ? 6 : 3)
        rows = max(1, (count + columns - 1) / columns)
    }
    func center(index i: Int) -> WPoint {
        [(Float(i % columns) - Float(columns-1) / 2) * width, 0.03,
         (Float(i / columns) - Float(rows-1) / 2) * depth - 0.4]
    }
}

struct WorldSite: Equatable {
    let id: String
    let name: String
    let picture: String
    let center: WPoint
    let animal: String?

    init(_ key: String, _ name: String, _ picture: String, _ x: Float, _ z: Float, animal: String? = nil) {
        id = "loc." + key
        self.name = name
        self.picture = picture
        center = [x, 0, z]
        self.animal = animal
    }

    static let all = [
        WorldSite("plaza", "Hofplatz", "🌳", -2.3, -2.5),
        WorldSite("garden", "Gemüsegarten", "🥕", -4.1, 2.3),
        WorldSite("henhouse", "Hühnerhaus", "🐔", 3.3, -2.5, animal: "animal.chicken"),
        WorldSite("shop", "Hofladen", "🧺", 3.0, 2.8),
        WorldSite("garage", "Maschinenhalle", "🚜", -8.0, 4.7),
        WorldSite("field", "Acker", "🌾", -7.7, -3.8),
        WorldSite("cowbarn", "Kuhstall", "🐄", 8.1, -4.3, animal: "animal.cow"),
        WorldSite("sheepmeadow", "Schafweide", "🐑", -6.1, -7.9, animal: "animal.sheep"),
        WorldSite("pigsty", "Schweinekoben", "🐖", 9.5, 2.1, animal: "animal.pig"),
        WorldSite("orchard", "Obstwiese", "🍎", 1.3, -7.7),
        WorldSite("kitchen", "Hofküche", "🍞", 1.2, 8.1),
        WorldSite("greenhouse", "Gewächshaus", "🌱", -12.5, 0.0),
        WorldSite("pond", "Ententeich", "🦆", 8.3, 7.8, animal: "animal.duck"),
        WorldSite("goatpen", "Ziegengehege", "🐐", 9.6, -9.1, animal: "animal.goat"),
        WorldSite("paddock", "Pferdekoppel", "🐴", -14.6, -7.8, animal: "animal.horse"),
        WorldSite("apiary", "Bienenwiese", "🐝", -9.9, 9.9, animal: "animal.bee"),
        WorldSite("village", "Dorfmarkt", "🏘️", 15.4, 3.7),
    ]

    static func at(_ id: String?) -> WorldSite? { all.first { $0.id == id } }
}

struct WorldFraming: Equatable {
    let size: CGSize
    let center: WPoint
    let eye: WPoint
    let back: WPoint
    let right: WPoint
    let up: WPoint
    static let fov: Float = 27
    private var focal: Float { Float(size.height) / (2 * tan(Self.fov * .pi / 360)) }

    static func island(level: Int) -> SIMD2<Float> {
        let ring = Float(min(5, max(1, level)) - 1)
        return [16 + 6 * ring, 12 + 4 * ring]
    }

    init(size: CGSize, site: WorldSite?, level: Int) {
        self.size = size
        let pitch: Float = (site == nil ? 39 : (site?.animal == nil ? 34 : 27)) * .pi / 180
        let yaw: Float = (site == nil ? 21 : 9) * .pi / 180
        let back = WPoint(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
        let right = WPoint(cos(yaw), 0, -sin(yaw))
        let up = simd_cross(back, right)
        self.back = back
        self.right = right
        self.up = up
        let ext = Self.island(level: level)
        let width = site == nil ? ext.x : 5.6
        let depth = site == nil ? ext.y : 3.8
        let height: Float = site == nil ? 2.5 : 2.35
        center = (site?.center ?? .zero) + [0, site == nil ? 0.55 : 0.78, site == nil ? 0 : 0.24]
        let tanY = tan(Self.fov * .pi / 360)
        let tanX = tanY * Float(max(1, size.width) / max(1, size.height))
        var distance: Float = 1
        // Fit the actual eight corners instead of guessing a distance from the
        // diagonal. The horizontal FOV is often the limiting one on a phone.
        for x in [-width / 2, width / 2] {
            for z in [-depth / 2, depth / 2] {
                for y: Float in [-0.8, height] {
                    let r = (site?.center ?? .zero) + [x, y, z] - center
                    let span = max(abs(simd_dot(r, right)) / (0.93 * tanX),
                                   abs(simd_dot(r, up)) / (0.94 * tanY))
                    distance = max(distance, span + simd_dot(r, back))
                }
            }
        }
        eye = center + distance * back
    }

    func project(_ p: WPoint) -> CGPoint {
        let r = p - eye
        let k = focal / max(0.001, -simd_dot(r, back))
        return CGPoint(x: size.width / 2 + CGFloat(simd_dot(r, right) * k),
                       y: size.height / 2 - CGFloat(simd_dot(r, up) * k))
    }
}
