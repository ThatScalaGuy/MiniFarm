import RealityKit

@MainActor
extension WorldWorkshop {
    func decoration(_ id: String, in p: Entity, season: String) {
        let code = id.utf8.reduce(0) { ($0 + Int($1)) % 251 }
        let color = [0xe19e83, 0xe3bf76, 0x91aabe, 0xb391a8, 0x88a68c][code % 5]
        let kind = id.split(separator: ".").dropFirst().first
        switch kind {
        case "fence": fence(p, from: [-0.53, 0, 0], to: [0.53, 0, 0], posts: 2 + code % 3)
        case "path": prop(id.hasSuffix("planks") ? "sticks" : "path", in: p)
        case "bench": prop("bench", in: p)
        case "table":
            for x: Float in [-0.34, 0.34] {
                for z: Float in [-0.23, 0.23] { box(p, [x, 0.26, z], [0.1, 0.52, 0.1], Self.timber) }
            }
            box(p, [0, 0.57, 0], [0.94, 0.13, 0.7], Self.timber)
            box(p, [0.09, 0.65, 0], [0.47, 0.04, 0.72], color)
        case "tree": tree(p, season: season, fruit: id.hasSuffix("apple"))
        case "flower":
            for i in 0..<(2 + code % 3) { flower(p, at: [Float(i)*0.21, 0, 0.14*sin(Float(i)*3)], color: color) }
        case "lantern", "light":
            box(p, [0, 0.46, 0], [0.13, 0.92, 0.13], Self.timber)
            box(p, [0, 0.92, 0], [0.43, 0.4, 0.36], Self.straw)
            box(p, [0, 1.16, 0], [0.52, 0.09, 0.46], color)
        case "windmill":
            box(p, [0, 0.52, 0], [0.12, 1.04, 0.12], Self.timber)
            for i in 0..<4 {
                let a = Float(i) * .pi / 2
                tilt(box(p, [0.22*cos(a), 0.96+0.22*sin(a), 0.09], [0.45, 0.18, 0.06], i.isMultiple(of: 2) ? color : Self.cream), a)
            }
        default:
            box(p, [0, 0.36, 0], [0.12, 0.72, 0.14], Self.timber)
            box(p, [0.11, 0.69, 0], [0.6, 0.42, 0.12], color)
            oval(p, [0.11, 0.69, 0.09], [0.22, 0.22, 0.07], Self.cream)
        }
    }

    func prop(_ id: String, in p: Entity) {
        let wood = Self.timber, cream = Self.cream, straw = Self.straw, blue = Self.teal
        if id.hasPrefix("animal.") || id == "friend" { animal(id == "friend" ? "animal.dog" : id, p); return }
        if id.hasPrefix("veh.") || id.hasPrefix("imp.") { vehicle(id, p); return }
        if id.hasPrefix("npc.") { person(id, p); return }
        if id.hasPrefix("count."), let count = Int(id.dropFirst(6)) {
            for i in 0..<min(6, count) {
                let x = Float(i % 2) * 0.45, z = Float(i / 2) * 0.43
                oval(p, [x, 0.23, z], [0.34, 0.45, 0.34], Self.cream)
            }
            return
        }
        if id.hasPrefix("crop.") || id.hasPrefix("item.seed.") {
            if id.hasPrefix("item.seed.") {
                box(p, [0, 0.42, 0], [0.64, 0.82, 0.22], 0xe6c794)
                box(p, [0, 0.75, 0.01], [0.66, 0.13, 0.24], cream)
                let g = group(p, at: [0, 0.33, 0.13])
                produce(String(id.split(separator: ".").last ?? "radish"), g)
                g.scale = .init(repeating: 0.43)
            } else {
                let parts = id.split(separator: ".")
                let phase = parts.last ?? "ripe"
                if phase == "seed" {
                    oval(p, [0, 0.12, 0], [0.8, 0.26, 0.65], 0x846546)
                    oval(p, [0, 0.23, 0], [0.14, 0.09, 0.18], straw)
                } else if phase == "sprout" || phase == "growing" {
                    leaves(p, at: .zero, count: phase == "sprout" ? 2 : 5)
                } else { produce(String(parts.dropFirst().first ?? "radish"), p) }
            }
            return
        }
        switch id {
        case "tool.can", "tool.bucket", "churn", "press", "bowl", "item.milk", "item.goatmilk",
             "item.applejuice", "item.jam", "item.honey":
            let jug = id.hasPrefix("item.")
            let color = id == "bowl" ? 0xb86450 : (jug ? cream : (id == "churn" || id == "press" ? wood : blue))
            drum(p, [0, 0.31, 0], [0.66, 0.6, 0.66], color)
            drum(p, [0, 0.62, 0], [0.7, 0.06, 0.7], jug ? Self.clay : cream)
            if id == "tool.can" {
                stick(p, from: [0.25, 0.24, 0], to: [0.62, 0.53, 0], width: 0.14, color: blue)
                tilt(drum(p, [0.64, 0.56, 0], [0.26, 0.09, 0.26], cream), -0.85)
            }
            if id == "tool.can" || id == "tool.bucket" {
                for s: Float in [-1, 1] {
                    stick(p, from: [s * 0.28, 0.58, 0], to: [s * 0.23, 0.92, 0], width: 0.07, color: Self.darkWood)
                }
                box(p, [0, 0.91, 0], [0.5, 0.095, 0.095], wood)
            } else if id == "churn" || id == "press" {
                drum(p, [0, 0.77, 0], [0.09, 0.6, 0.09], Self.darkWood)
                box(p, [0.05, 1.05, 0], [0.72, 0.12, 0.12], wood)
            } else if jug {
                drum(p, [0, 0.7, 0], [0.33, 0.14, 0.33], color)
                drum(p, [0, 0.8, 0], [0.36, 0.08, 0.36], Self.clay)
            }
        case "tool.basket", "crate", "nest", "trough":
            let nest = id == "nest"
            box(p, [0, 0.1, 0], [1, 0.18, 0.64], nest ? straw : Self.darkWood)
            for z: Float in [-0.31, 0.31] {
                for y: Float in [0.2, 0.37] { box(p, [0, y, z], [1.05, 0.14, 0.09], nest ? straw : wood) }
            }
            for x: Float in [-0.47, 0.47] {
                box(p, [x, 0.26, 0], [0.1, 0.4, 0.6], nest ? straw : wood)
                if id == "tool.basket" { stick(p, from: [x, 0.4, 0], to: [x * 0.56, 0.78, 0], width: 0.085, color: wood) }
            }
            if id == "tool.basket" { box(p, [0, 0.78, 0], [0.58, 0.09, 0.09], wood) }
        case "item.feed", "item.flour", "item.hay":
            if id == "item.hay" {
                box(p, [0, 0.31, 0], [1, 0.59, 0.55], straw)
                for x: Float in [-0.29, 0.29] { box(p, [x, 0.31, 0], [0.047, 0.6, 0.56], wood) }
            } else {
                oval(p, [0, 0.32, 0], [0.73, 0.66, 0.58], id == "item.feed" ? 0xd6a258 : cream)
                drum(p, [0, 0.58, 0], [0.47, 0.08, 0.4], Self.darkWood)
                for i in 0..<5 {
                    oval(p, [0.16 * cos(Float(i)*2), 0.62, 0.11 * sin(Float(i)*2)], [0.12, 0.13, 0.12], straw)
                }
            }
        case "bed", "lane":
            box(p, [0, 0.1, 0], [1.4, 0.2, 0.86], wood)
            box(p, [0, 0.21, 0], [1.3, 0.06, 0.77], 0x715138)
            for x: Float in [-0.4, 0, 0.4] { oval(p, [x, 0.24, 0], [0.18, 0.12, 0.57], 0x856341) }
        case "tool.hand":
            oval(p, [0, 0.33, 0], [0.49, 0.54, 0.19], cream)
            for i in 0..<4 {
                oval(p, [Float(i)*0.105 - 0.145, 0.56, 0], [0.12, 0.28 - 0.035*Float(abs(i-1)), 0.14], cream)
            }
            tilt(oval(p, [-0.24, 0.39, 0], [0.17, 0.28, 0.16], cream), 0.47)
            box(p, [0, 0.1, 0], [0.37, 0.15, 0.2], blue)
        case "tool.brush", "tool.shears":
            box(p, [0, 0.16, 0], [0.55, 0.27, 0.48], id == "tool.brush" ? straw : 0x9baaaa)
            box(p, [0.27, 0.32, 0], [0.8, 0.14, 0.2], wood)
        case "bell", "lantern":
            oval(p, [0, 0.4, 0], [0.63, 0.66, 0.63], straw)
            drum(p, [0, 0.18, 0], [0.77, 0.1, 0.77], id == "bell" ? straw : Self.clay)
            drum(p, [0, 0.77, 0], [0.18, 0.16, 0.18], Self.darkWood)
        case "mailbox", "birdhouse", "sign", "post", "scarecrow":
            box(p, [0, 0.51, 0], [0.17, 1.02, 0.17], wood)
            box(p, [0, 0.91, 0], [0.8, 0.49, 0.45], id == "mailbox" ? Self.clay : straw)
            box(p, [0, 0.97, 0.235], [0.33, 0.08, 0.04], Self.darkWood)
            if id == "birdhouse" || id == "scarecrow" { hat(p, y: 1.2) }
        case "hat": hat(p, y: 0.1)
        case "flower", "daisy", "dandelion", "bellflower":
            flower(p, color: ["daisy":cream, "dandelion":straw, "bellflower":0x9c91bd][id] ?? 0xe89383)
        case "grass", "leaf": leaves(p, at: .zero, count: id == "leaf" ? 1 : 6)
        case "soil", "stones", "path":
            for i in 0..<5 {
                oval(p, [0.3 * cos(Float(i)*2), 0.07 + Float(i)*0.015, 0.22 * sin(Float(i)*2)],
                     [0.45, 0.17, 0.32], id == "soil" ? 0x876544 : (i.isMultiple(of: 2) ? 0xa9aca0 : 0xc0b49d))
            }
        case "sticks":
            for i in 0..<3 {
                let x = Float(i) * 0.12
                stick(p, from: [-0.3+x, 0.08+x, 0.15], to: [0.3+x, 0.08, -0.22], width: 0.09, color: wood)
            }
        case "tree": tree(p, season: "season.summer", fruit: false)
        case "gate", "perch": fence(p, from: [-0.53, 0, 0], to: [0.53, 0, 0], posts: id == "gate" ? 3 : 2)
        case "bench":
            for s: Float in [-1, 1] { box(p, [s*0.37, 0.22, 0], [0.14, 0.42, 0.44], wood) }
            box(p, [0, 0.46, 0], [1.1, 0.13, 0.54], straw)
            box(p, [0, 0.69, -0.23], [1.05, 0.37, 0.09], wood)
        case "watertrough":
            prop("trough", in: p)
            box(p, [0, 0.31, 0], [0.86, 0.045, 0.52], blue)
        case "well":
            drum(p, [0, 0.31, 0], [0.92, 0.61, 0.92], 0xbfaa8d)
            drum(p, [0, 0.62, 0], [0.74, 0.04, 0.74], blue)
        case "snow.large", "snow.middle", "snow.small":
            box(p, [0, 0.02, 0], [1.1, 0.04, 0.74], 0xbccfcf)
            let r: Float = id == "snow.large" ? 0.93 : (id == "snow.middle" ? 0.67 : 0.4)
            oval(p, [0, r/2+0.03, 0], [r,r,r], cream)
        case "snowman", "snowball":
            oval(p, [0, 0.31, 0], [0.73, 0.67, 0.73], cream)
            if id == "snowman" {
                oval(p, [0, 0.79, 0], [0.53, 0.51, 0.53], cream)
                oval(p, [0, 0.81, 0.26], [0.1, 0.1, 0.14], 0xe19249)
                hat(p, y: 1.04)
            }
        case "oven":
            oval(p, [0, 0.38, 0], [1, 0.92, 0.86], Self.clay)
            box(p, [0, 0.29, 0.39], [0.55, 0.37, 0.08], Self.darkWood)
        case "kite", "mail", "quilt", "tile":
            let slab = box(p, [0, 0.35, 0], [0.8, 0.59, 0.11], id == "kite" || id == "quilt" ? blue : cream)
            if id == "kite" { tilt(slab, .pi / 4) }
            if id == "mail" {
                for s: Float in [-1, 1] {
                    stick(p, from: [s * 0.39, 0.62, 0.065], to: [0, 0.31, 0.065], width: 0.035, color: wood)
                }
            }
        case "pond": oval(p, [0, 0.06, 0], [1, 0.12, 0.75], 0x71bcb5)
        case "camera":
            box(p, [0, 0.31, 0], [0.9, 0.56, 0.32], Self.teal)
            oval(p, [0, 0.31, 0.19], [0.36, 0.36, 0.2], Self.ink)
        case "worm":
            for i in 0..<6 { oval(p, [Float(i) * 0.11, 0.11 + 0.05 * sin(Float(i)), 0], [0.18, 0.17, 0.17], Self.clay) }
        default: produce(String(id.split(separator: ".").last ?? "ball"), p)
        }
    }

    private func leaves(_ p: Entity, at pos: WPoint, count: Int) {
        for i in 0..<count {
            let a = Float(i) * 2.4
            let end = pos + [cos(a) * 0.27, 0.37 + 0.1 * sin(a), sin(a) * 0.24]
            let v = end - pos
            let leaf = oval(p, pos + v * 0.55, [0.19, simd_length(v), 0.1], i.isMultiple(of: 2) ? 0x598955 : 0x80a458)
            leaf.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(v))
        }
    }

    private func produce(_ key: String, _ p: Entity) {
        switch key {
        case "egg", "duckegg", "wool", "ball":
            oval(p, [0, 0.32, 0], [0.49, key == "egg" || key == "duckegg" ? 0.66 : 0.5, 0.49],
                 key == "ball" ? Self.clay : Self.cream)
        case "bread", "cake", "butter", "cheese", "goatcheese", "honeycomb":
            box(p, [0, 0.22, 0], [0.74, 0.43, 0.52], key == "bread" ? 0xcf8a48 : Self.straw, round: 0.25)
        default:
            let color: Int = switch key {
            case "carrot", "pumpkin": 0xe58b40
            case "lettuce", "pea", "kale", "chives": 0x84a964
            case "corn", "wheat", "sunflower": Self.straw
            case "potato": 0xb08b5c
            default: 0xc56353
            }
            oval(p, [0, 0.26, 0], [key == "carrot" ? 0.34 : 0.62, 0.53, key == "carrot" ? 0.34 : 0.6], color)
            leaves(p, at: [0, 0.45, 0], count: 3)
        }
    }

    private func hat(_ p: Entity, y: Float) {
        drum(p, [0, y, 0], [0.91, 0.09, 0.87], Self.straw)
        drum(p, [0, y + 0.14, 0], [0.57, 0.27, 0.54], Self.straw)
    }

    func vehicle(_ id: String, _ p: Entity) {
        let color = id == "veh.combine" ? Self.straw : 0x65915c
        box(p, [0, 0.32, 0], [1.42, 0.26, 0.68], Self.darkWood)
        for s: Float in [-1, 1] {
            for (x, r): (Float, Float) in [(-0.43, 0.37), (0.51, 0.25)] {
                tilt(drum(p, [x, r, s * 0.38], [2*r, 0.2, 2*r], Self.ink), .pi / 2, [1, 0, 0])
                tilt(drum(p, [x, r, s * 0.49], [r, 0.06, r], Self.straw), .pi / 2, [1, 0, 0])
            }
        }
        if id.hasPrefix("veh.") {
            box(p, [0.34, 0.6, 0], [0.76, 0.43, 0.58], color)
            box(p, [-0.37, 0.62, 0], [0.36, 0.17, 0.48], Self.timber)
            for s: Float in [-1, 1] { box(p, [-0.54, 0.86, s * 0.23], [0.07, 0.83, 0.07], Self.cream) }
            box(p, [-0.33, 1.28, 0], [0.77, 0.1, 0.78], color)
            drum(p, [0.47, 0.97, -0.1], [0.085, 0.42, 0.085], Self.ink)
            for s: Float in [-1, 1] { oval(p, [0.72, 0.64, s * 0.19], [0.07, 0.16, 0.16], Self.cream) }
        } else if id == "imp.trailer" { box(p, [0, 0.59, 0], [1.36, 0.44, 0.7], Self.timber) }
        else if id == "imp.watertank" { oval(p, [0, 0.72, 0], [1.32, 0.75, 0.76], Self.teal) }
        else {
            box(p, [0, 0.54, 0], [1.3, 0.23, 0.75], Self.clay)
            for x: Float in [-0.45, 0, 0.45] { tilt(box(p, [x, 0.28, 0.42], [0.11, 0.43, 0.3], Self.ink), -0.4) }
        }
    }

    private func person(_ id: String, _ p: Entity) {
        let skin = id == "npc.tilda" || id == "npc.mo" ? 0xba805e : 0xdaaa86
        for s: Float in [-1, 1] {
            box(p, [s * 0.13, 0.2, 0], [0.2, 0.4, 0.24], 0x566c70)
            oval(p, [s * 0.29, 0.57, 0], [0.16, 0.47, 0.2], skin)
        }
        oval(p, [0, 0.57, 0], [0.54, 0.6, 0.41], id == "npc.tilda" ? Self.teal : Self.clay)
        oval(p, [0, 1.06, 0], [0.55, 0.6, 0.53], skin)
        oval(p, [0, 1.28, -0.03], [0.56, 0.28, 0.53], Self.darkWood)
        for s: Float in [-1, 1] { oval(p, [s * 0.11, 1.09, 0.24], [0.058, 0.07, 0.036], Self.ink) }
        if id == "npc.tilda" { oval(p, [0, 1.43, -0.02], [0.63, 0.33, 0.57], Self.cream) }
    }
}
