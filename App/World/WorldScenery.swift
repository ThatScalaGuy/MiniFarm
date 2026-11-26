import RealityKit

extension WorldWorkshop {
    func fence(_ parent: Entity, from a: WPoint, to b: WPoint, posts: Int) {
        let count = max(2, posts)
        for i in 0..<count {
            let pos = a + (b - a) * (Float(i) / Float(count - 1))
            box(parent, pos + [0, 0.31, 0], [0.13, 0.62, 0.14], 0xd9b684)
        }
        for y: Float in [0.24, 0.47] {
            stick(parent, from: a + [0, y, 0], to: b + [0, y, 0], width: 0.1, color: 0xe6c692)
        }
    }

    func soil(_ p: Entity, _ size: SIMD2<Float>, season: String) {
        let grass: Int = switch season {
        case "season.summer": 0x92b762
        case "season.autumn": 0xc1ad63
        case "season.winter": 0xe0e9dc
        default: 0xa4c579
        }
        box(p, [0, -0.54, 0], [size.x - 0.13, 0.81, size.y - 0.13], 0xa77c55, round: 0.105)
        box(p, [0, -0.28, 0], [size.x, 0.5, size.y], 0xbe986a, round: 0.105)
        box(p, [0, -0.1, 0], [size.x + 0.02, 0.21, size.y + 0.02], grass, round: 0.105)
        for i in 0..<15 {
            let x = Float(i - 7) * (size.x * 0.053)
            oval(p, [x, -0.46 + 0.07 * sin(Float(i)*2), size.y * 0.49], [0.27, 0.13, 0.13], 0xcbab84)
        }
    }

    func lane(_ p: Entity, from a: WPoint, to b: WPoint, width: Float = 0.68) {
        let d = b - a
        let e = box(p, (a + b) / 2 + [0, 0.028, 0], [width, 0.042, simd_length(d) + 0.25], 0xd8bc8e, round: 0.23)
        tilt(e, atan2(d.x, d.z), [0, 1, 0])
        let n = Int(simd_length(d) / 0.9)
        for i in 0..<n {
            let pos = a + d * ((Float(i) + 0.55) / Float(n)) + [sin(Float(i) * 4) * width * 0.22, 0.061, 0]
            oval(p, pos, [0.22, 0.028, 0.15], 0xe7cd9d)
        }
    }

    func cottage(_ p: Entity, color: Int, roof: Int, open: Bool) {
        box(p, [0, 0.13, 0], [1.8, 0.25, 1.37], Self.darkWood)
        box(p, [0, 0.76, -0.61], [1.73, 1.27, 0.14], color)
        for s: Float in [-1, 1] {
            box(p, [s * 0.8, 0.74, 0], [0.15, 1.25, 1.28], color)
            box(p, [s * 0.8, 0.76, 0.61], [0.15, 1.34, 0.15], Self.cream)
        }
        if open {
            for s: Float in [-1, 1] {
                tilt(box(p, [s*0.48, 1.57, -0.53], [1.16, 0.16, 0.51], roof), -s*0.45)
                stick(p, from: [s*0.86, 1.37, 0.61], to: [0, 1.81, 0.61], width: 0.1, color: Self.timber)
            }
            for y: Float in [0.36, 0.66, 0.96] { box(p, [0, y, -0.52], [1.49, 0.045, 0.055], Self.timber) }
            let nest = group(p, at: [-0.29, 0.24, -0.13])
            prop("nest", in: nest)
            nest.scale = .init(repeating: 0.7)
            let egg = oval(p, [-0.27, 0.5, -0.13], [0.2, 0.27, 0.2], Self.cream)
            tilt(egg, -0.16)
            stick(p, from: [-0.68, 0.83, -0.22], to: [0.68, 0.83, -0.22], width: 0.09, color: Self.darkWood)
        }
        if !open {
            box(p, [0, 0.75, 0.59], [1.64, 1.26, 0.14], color)
            box(p, [-0.29, 0.57, 0.69], [0.58, 0.96, 0.1], Self.darkWood)
            for s: Float in [-1, 1] {
                box(p, [-0.29 + s * 0.32, 0.59, 0.75], [0.08, 1.1, 0.08], Self.cream)
                stick(p, from: [-0.29 + s * 0.26, 0.16, 0.77], to: [-0.29 - s * 0.26, 0.98, 0.77], width: 0.06, color: Self.cream)
            }
            box(p, [0.5, 0.88, 0.69], [0.4, 0.43, 0.1], Self.cream)
            box(p, [0.5, 0.87, 0.75], [0.29, 0.31, 0.04], 0x8cbdbc)
            for s: Float in [-1, 1] {
                tilt(box(p, [s * 0.48, 1.57, 0], [1.16, 0.19, 1.65], roof), -s * 0.45)
            }
        }
    }

    func awning(_ p: Entity, shop: Bool = true) {
        box(p, [0, 0.45, 0], [2.06, 0.84, 0.85], Self.timber)
        for x: Float in [-0.9, -0.6, -0.3, 0, 0.3, 0.6, 0.9] {
            box(p, [x, 0.45, 0.43], [0.25, 0.79, 0.055], 0xc78e56)
        }
        box(p, [0, 0.91, 0.03], [2.22, 0.14, 1.06], 0xe6bf89)
        for s: Float in [-1, 1] { box(p, [s * 0.93, 1.46, -0.22], [0.1, 1.24, 0.1], Self.darkWood) }
        for i in 0..<7 {
            let x = Float(i - 3) * 0.325
            let color = i.isMultiple(of: 2) ? (shop ? Self.clay : Self.teal) : Self.cream
            tilt(box(p, [x, 2.04, 0], [0.33, 0.12, 1.33], color), 0.15, [1, 0, 0])
            oval(p, [x, 1.88, 0.65], [0.332, 0.24, 0.12], color)
        }
    }

    func place(_ site: WorldSite, in root: Entity, state: FarmWorldState, focus: Bool, active: Bool) {
        let p = group(root, at: site.center)
        p.name = site.id
        if focus && !active && (site.id == "loc.shop" || site.id == "loc.plaza") {
            let chest = group(p, at: [-0.08, 0.035, 1.19])
            prop("crate", in: chest)
            box(chest, [0, 0.49, 0], [1.09, 0.12, 0.72], Self.teal)
            box(chest, [0, 0.39, 0.37], [0.14, 0.15, 0.055], Self.straw)
        }
        switch site.id {
        case "loc.plaza":
            let treeRoot = group(p, at: [-0.57, 0, -0.47])
            tree(treeRoot, season: state.season, fruit: false, level: state.farmLevel)
            treeRoot.scale = .init(repeating: 1 + Float(min(state.farmLevel, 5) - 1) * 0.055)
            toy("mailbox", in: p, at: [1.02, 0, 0.52], span: 1.07)
            drum(p, [1.16, 0.29, -0.75], [0.98, 0.57, 0.98], 0xc1ad8a)
            drum(p, [1.16, 0.58, -0.75], [0.77, 0.045, 0.77], 0x7aafa9)
            for s: Float in [-1, 1] { box(p, [1.16 + 0.38*s, 0.86, -0.75], [0.1, 0.69, 0.1], Self.timber) }
            box(p, [1.16, 1.21, -0.75], [1.14, 0.17, 0.86], 0xb86f4e)
            let slots: [String: WPoint] = [
                "tree": [-1.54, 0.04, 0.5], "well": [1.85, 0.04, -0.43],
                "gate": [-1.85, 0.04, 1.12], "mailbox": [1.57, 0.04, 0.99],
                "path": [0.58, 0.04, 1.44], "fence": [-1.76, 0.04, -1.24],
            ]
            for piece in state.decorations {
                guard let point = slots[piece.positionID] else { continue }
                toy(piece.decorationID, in: p, at: point, span: 0.93, yaw: Float(piece.quarterTurns % 4) * .pi / 2) {
                    self.decoration(piece.decorationID, in: $0, season: state.season)
                }
            }
        case "loc.garden", "loc.field", "loc.greenhouse":
            let beds = state.beds.filter { $0.locationID == site.id }
            let n = beds.isEmpty ? (site.id == "loc.field" ? 16 : 6) : beds.count
            let grid = WorldBedGrid(count: n, field: site.id == "loc.field")
            for i in 0..<n {
                let w = grid.width, d = grid.depth
                let b = group(p, at: grid.center(index: i))
                box(b, [0, 0.1, 0], [w*0.93, 0.21, d*0.9], 0xb5875d)
                box(b, [0, 0.21, 0], [w*0.82, 0.045, d*0.77], i < beds.count && beds[i].watered ? 0x685442 : 0x87674b)
                for r: Float in [-0.2, 0.22] {
                    oval(b, [r*w, 0.23, 0], [0.18*w, 0.12, d*0.58], 0x9a7655)
                }
                if i < beds.count, let crop = beds[i].cropID {
                    toy(crop + "." + beds[i].growth, in: b, at: [0, 0.22, 0], span: min(w, d) * 0.77)
                }
            }
            if site.id == "loc.greenhouse" {
                for s: Float in [-1, 1] {
                    for z: Float in [-1.7, 0, 1.2] {
                        stick(p, from: [s*2, 0, z], to: [s*2, 1.3, z], width: 0.09, color: Self.cream)
                        stick(p, from: [s*2, 1.3, z], to: [0, 2.1, z], width: 0.09, color: Self.cream)
                    }
                }
            } else {
                fence(p, from: [-1.9, 0, -1.7], to: [1.85, 0, -1.7], posts: 4)
                toy(site.id == "loc.field" ? "veh.tractor" : "tool.can", in: p, at: [1.88, 0, 0.65], span: site.id == "loc.field" ? 1.25 : 0.64)
            }
        case "loc.shop", "loc.village":
            let stand = toy(site.id, in: p, at: [-0.48, 0, -0.55], span: 2.8) { self.awning($0) }
            tilt(stand, -0.1, [0, 1, 0])
            toy(site.id == "loc.shop" ? "npc.tilda" : "npc.yusuf", in: p, at: [1.45, 0, -0.32], span: 1.43)
            let shelf = state.shelf.filter { $0.value > 0 }.map(\.key).sorted().prefix(4)
            for (i, item) in shelf.enumerated() {
                toy(item, in: p, at: [Float(i) * 0.48 - 1, 0.02, 0.9], span: 0.48)
            }
        case "loc.orchard":
            for (i, pos) in ([[-1.24, 0, -0.67], [1.22, 0, -0.95], [0.05, 0, 0.92]] as [WPoint]).enumerated() {
                let g = group(p, at: pos)
                tree(g, season: state.season, fruit: state.season == "season.autumn")
                g.scale = .init(repeating: i == 2 ? 0.66 : 0.81)
            }
        case "loc.garage", "loc.kitchen":
            let kitchen = site.id == "loc.kitchen"
            let build: (Entity) -> Void = { self.cottage($0, color: kitchen ? 0xdab58a : 0x8caa9c, roof: 0x786e67, open: focus) }
            toy(focus ? "cutaway" : site.id, in: p, at: [-0.55, 0, -0.81], span: 2.7, fallback: build)
            toy(kitchen ? "oven" : "veh.tractor", in: p, at: [0.67, 0, 0.4], span: 1.52)
        default:
            let pond = site.id == "loc.pond"
            if pond {
                oval(p, [0, 0.04, -0.1], [3.95, 0.11, 2.8], 0x79b5b2)
                for x: Float in [-1.2, 0.3, 1.3] { oval(p, [x, 0.11, -0.73], [0.45, 0.04, 0.38], Self.leaf) }
            } else {
                fence(p, from: [-1.8, 0, -1.44], to: [1.82, 0, -1.44], posts: 4)
                fence(p, from: [1.82, 0, -1.44], to: [1.82, 0, 0.5], posts: 3)
                if ["loc.henhouse", "loc.cowbarn", "loc.pigsty"].contains(site.id) {
                    let color = site.id == "loc.henhouse" ? 0xb56750 : 0xac7853
                    toy(focus ? "cutaway" : site.id, in: p, at: [-0.73, 0, -0.67], span: 2.09) {
                        self.cottage($0, color: color, roof: 0x657c7a, open: focus)
                    }
                } else if site.id == "loc.apiary" {
                    for i in 0..<4 {
                        drum(p, [-0.75, Float(i)*0.25+0.15, -0.56], [1.1-Float(i)*0.14, 0.3, 0.95-Float(i)*0.1], Self.straw)
                    }
                } else { toy("item.hay", in: p, at: [-1.03, 0, -0.73], span: 1.14) }
            }
            if let species = site.animal {
                let count = active ? 1 : (species == "animal.chicken" ? 3 : 2)
                let centers: [WPoint] = [[0.68, 0.12, 0.01], [-0.26, 0.12, 0.85], [1.25, 0.12, -0.88]]
                for i in 0..<count {
                    let a = toy(species, in: p, at: centers[i], span: species == "animal.chicken" ? 0.9 : 1.34,
                                yaw: Float(i) * 0.45 - 0.45)
                    a.name = "resident." + species
                }
                if state.caredFor.contains(where: { $0 == species || $0.hasPrefix(species + ".") }) {
                    toy("item.hay", in: p, at: [1.14, 0, 0.76], span: 0.46)
                }
            }
        }
    }
}
