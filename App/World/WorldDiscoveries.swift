import RealityKit

/// Little objects on the "look closer" spot at each place. The catalog owns
/// facts and discovery status; this table only chooses a tactile illustration.
enum WorldFind {
    static let point: WPoint = [1.72, 0.07, 1.28]
    static let models: [String: String] = [
        "windwheel":"deco.windmill", "mailbox":"mailbox", "treebark":"sticks", "wellpulley":"spool",
        "anttrail":"ants", "snailtrail":"snail", "canrose":"tool.can", "dewdrop":"dew",
        "nestcup":"nest", "roost":"perch", "dustbath":"soil", "shell":"item.egg",
        "shopbell":"bell", "scale":"scale", "awning":"awning", "wicker":"tool.basket",
        "hitch":"imp.plow", "reflector":"lantern", "socket":"spool", "tirevalve":"wheel",
        "earthworm":"worm", "scarecrow":"scarecrow", "stubble":"grass", "poppy":"flower",
        "feedrack":"trough", "saltlick":"salt", "troughfloat":"watertrough", "tailtuft":"tool.brush",
        "wooltuft":"item.wool", "clover":"leaf", "mushroomring":"mushrooms", "dandelion":"dandelion",
        "wallow":"soil", "bristles":"tool.brush", "straw":"item.hay", "pigtrack":"tracks",
        "appleseed":"crop.apple.seed", "lichen":"stones", "nesthole":"birdhouse", "treeguard":"gate",
        "ovendoor":"oven", "millstone":"wheel", "sieve":"sieve", "presscloth":"quilt",
        "glasspane":"glass", "vent":"gate", "drainhole":"sieve", "tomatosupport":"sticks",
        "skater":"ants", "lilypad":"leaf", "frogleap":"frog", "dragonfly":"dragonfly",
        "goatrock":"stones", "goatbeard":"tool.brush", "browse":"leaf", "scratchingpost":"post",
        "hoofprint":"tracks", "currycomb":"tool.brush", "burrow":"burrow", "spokes":"wheel",
        "waxcell":"item.honeycomb", "landingboard":"perch", "waggledance":"animal.bee", "extractor":"churn",
        "crateslats":"crate", "cobble":"path", "pennant":"kite", "coin":"coin",
    ]

    static func model(_ id: String) -> String {
        models[String(id.split(separator: ".").last ?? "")] ?? "tile"
    }

    static func symbol(_ id: String) -> String {
        switch model(id) {
        case "mailbox", "mail": "envelope.fill"
        case "spool", "wheel", "sieve", "coin": "circle.hexagongrid.fill"
        case "ants", "dragonfly": "ant.fill"
        case "snail", "worm": "ladybug.fill"
        case "dew", "watertrough", "well": "drop.fill"
        case "soil", "tracks", "burrow": "pawprint.fill"
        case "tool.basket", "nest", "crate": "basket.fill"
        case "bell", "lantern": "bell.fill"
        case "scale": "scalemass.fill"
        case "item.egg", "item.wool", "salt": "oval.fill"
        case "flower", "dandelion", "mushrooms": "camera.macro"
        case "animal.bee", "item.honeycomb": "hexagon.fill"
        case "tool.brush": "paintbrush.fill"
        case "glass", "quilt", "awning": "square.grid.2x2.fill"
        case "imp.plow", "churn", "press": "gearshape.fill"
        case "deco.windmill": "fanblades.fill"
        case "sticks", "gate", "perch", "post": "tree.fill"
        case "birdhouse", "oven": "house.fill"
        case "stones", "path": "circle.hexagongrid.fill"
        default: "leaf.fill"
        }
    }
}

extension WorldWorkshop {
    func foundObject(_ id: String, in p: Entity) {
        let cream = Self.cream, wood = Self.timber, blue = Self.teal
        switch id {
        case "deco.windmill": decoration(id, in: p, season: "season.spring")
        case "spool", "wheel":
            tilt(drum(p, [0, 0.42, 0], [0.85, 0.18, 0.85], wood), .pi/2, [1,0,0])
            tilt(drum(p, [0, 0.42, 0.115], [0.62, 0.08, 0.62], Self.darkWood), .pi/2, [1,0,0])
            for i in 0..<3 { tilt(box(p, [0, 0.42, 0.17], [0.62, 0.046, 0.05], cream), Float(i)*(.pi/3)) }
        case "ants":
            for i in 0..<4 {
                let x = Float(i)*0.25
                for j in 0..<3 { oval(p, [x, 0.08, Float(j)*0.075 + sin(x*6)*0.18], [0.11, 0.1, 0.13], Self.darkWood) }
            }
        case "snail":
            oval(p, [0, 0.14, 0], [0.83, 0.28, 0.37], 0xbb9877)
            oval(p, [-0.12, 0.39, 0], [0.49, 0.5, 0.47], 0xbb7e54)
            for z: Float in [-0.08, 0.08] {
                stick(p, from: [0.29, 0.22, z], to: [0.39, 0.47, z*1.6], width: 0.046, color: wood)
            }
        case "dew": oval(p, [0, 0.29, 0], [0.49, 0.59, 0.47], 0x86bdc0)
        case "scale":
            box(p, [0, 0.14, 0], [0.65, 0.26, 0.58], blue)
            drum(p, [0, 0.36, 0], [0.92, 0.12, 0.72], cream)
            oval(p, [0, 0.18, 0.3], [0.25, 0.25, 0.05], cream)
        case "awning": awning(p)
        case "salt": box(p, [0, 0.21, 0], [0.58, 0.4, 0.47], cream, round: 0.2)
        case "mushrooms":
            for i in 0..<4 {
                let a = Float(i)*1.57, pos = WPoint(0.32*cos(a), 0, 0.27*sin(a))
                drum(p, pos+[0,0.1,0], [0.1,0.2,0.1], cream)
                oval(p, pos+[0,0.22,0], [0.29,0.18,0.28], Self.clay)
            }
        case "tracks", "burrow":
            oval(p,[0,0.12,0],[0.96,0.25,0.73],wood)
            for x: Float in [-0.18,0.18] { oval(p,[x,0.24,0.06],[0.2,0.034,0.29],Self.darkWood) }
        case "sieve":
            drum(p, [0,0.11,0], [0.86,0.2,0.86],cream)
            for i in 0..<7 { oval(p,[0.27*cos(Float(i)*2.4),0.22,0.26*sin(Float(i)*2.4)],[0.10,0.02,0.1],Self.darkWood) }
        case "glass": box(p, [0,0.38,0], [0.89,0.73,0.1],cream); box(p,[0,0.38,0.06],[0.73,0.56,0.05],0x93c0c3)
        case "frog":
            oval(p,[0,0.23,0],[0.67,0.46,0.74],Self.leaf)
            for s: Float in [-1,1] {
                oval(p,[s*0.2,0.42,0.23],[0.24,0.25,0.24],Self.leaf)
                oval(p,[s*0.2,0.46,0.34],[0.092,0.091,0.06],Self.ink)
                oval(p,[s*0.29,0.1,0.03],[0.26,0.16,0.59],Self.leaf)
            }
        case "dragonfly":
            oval(p,[0,0.21,0],[0.15,0.14,0.8],blue)
            for s: Float in [-1,1] {
                for z: Float in [-0.14,0.11] { oval(p,[s*0.22,0.25,z],[0.48,0.055,0.22],0xbae0da) }
            }
        case "coin": drum(p,[0,0.06,0],[0.59,0.12,0.59],Self.straw)
        default: prop(id, in: p)
        }
    }
}
