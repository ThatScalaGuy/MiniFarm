import SwiftUI

struct FarmDecorationView: View {
    let game: FarmGame
    let send: (FarmIntent) -> Void
    let close: () -> Void

    @State private var shelf = WorkshopShelf.box
    @State private var path: [Page] = []
    @State private var coinToken = UUID()

    private enum Page: Hashable {
        case category(String), offer(String), parcel(String), destinations(String)
        case spot(String), exchange(piece: String, spot: String)
    }

    private var visible: [FarmDecoration] { game.catalog.decorations.filter { $0.level <= game.state.level } }
    private var life: FarmLife { game.state.life }
    private var canPlace: Bool {
        game.catalog.activities.contains { $0.id == "act.farm.decorate" && $0.level <= game.state.level }
    }
    private func item(_ id: String) -> FarmDecoration? { visible.first { $0.id == id } }
    private func stock(_ id: String) -> Int { life.inventory[id, default: 0] }
    private func position(_ id: String) -> FarmChoice? { FarmLife.positions.first { $0.id == id } }
    private func placed(_ id: String) -> FarmDecoration? { life.placements[id].flatMap { item($0.decorationID) } }

    var body: some View {
        ZStack {
            WorkshopInk.ink.opacity(0.5).ignoresSafeArea().accessibilityHidden(true)
            VStack(spacing: 8) {
                HStack {
                    if path.isEmpty {
                        FarmPictogram(id: "act.farm.decorate")
                            .frame(width: 64, height: 64)
                            .accessibilityLabel("Deko-Werkstatt")
                            .accessibilityAddTraits(.isHeader)
                    } else {
                        key("Zurück", id: "back", action: back) { glyph("chevron.backward") }
                            .frame(width: 64)
                    }
                    Spacer(minLength: 2)
                    balance
                    Spacer(minLength: 2)
                    key("Werkstatt schließen", id: "close", action: close) { glyph("xmark") }
                        .frame(width: 64)
                        .keyboardShortcut(.cancelAction)
                }
                ScrollView {
                    VStack(spacing: 12) {
                        if let page = path.last {
                            detail(page)
                        } else {
                            grid(minimum: 64) {
                                ForEach(WorkshopShelf.allCases.filter { $0 != .yard || canPlace }, id: \.self) { tab in
                                    key(tab.title, id: "tab.\(tab.rawValue)", selected: tab == shelf) {
                                        shelf = tab
                                    } label: {
                                        if let art = tab.art {
                                            FarmPictogram(id: art).frame(width: 48, height: 48)
                                        } else {
                                            glyph(tab.symbol)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: canPlace ? 340 : 260)
                            Divider().accessibilityHidden(true)
                            shelfContents
                        }
                    }
                    .padding(4)
                }
                .id(path.last)
            }
            .foregroundStyle(WorkshopInk.ink)
            .padding(12)
            .frame(maxWidth: 600, maxHeight: 560)
            .background(WorkshopInk.paper, in: .rect(cornerRadius: 24))
            .shadow(color: .black.opacity(0.23), radius: 10, y: 5)
            .padding(8)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, back)
        }
    }

    private var balance: some View {
        let amount = game.state.coins
        return HStack(spacing: 5) {
            Taler().frame(width: 25, height: 25)
            if amount >= 100 {
                glyph("sparkles", size: 20)
            } else if game.state.stage == .sprout {
                Image(systemName: amount == 0 ? "tray" : amount < 5 ? "tray.fill" : "tray.2.fill")
                    .overlay(alignment: .top) {
                        HStack(spacing: -5) {
                            ForEach(0..<min(5, amount), id: \.self) { _ in Taler().frame(width: 10, height: 10) }
                        }
                    }
            } else {
                Tally(amount: amount, compact: true)
            }
        }
        .frame(maxWidth: 144, minHeight: 48)
        .background(WorkshopInk.honey.opacity(0.28), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dein Talerbeutel")
        .accessibilityValue(amount >= 100 ? "Viele Taler" : "\(amount) Taler")
    }

    @ViewBuilder private var shelfContents: some View {
        switch shelf {
        case .shop:
            grid {
                ForEach(Set(visible.map(\.category)).sorted(), id: \.self) { category in
                    let sign = WorkshopShelf.category(category)
                    key(sign.title, id: "category.\(category)") { path.append(.category(category)) } label: {
                        glyph(sign.symbol)
                    }
                }
            }
        case .box: box(for: nil)
        case .yard: spots(for: nil)
        case .wishes:
            let wishes = life.wishlist.compactMap { item($0) }
            if wishes.isEmpty { invite("Auf deinem Wunschzettel ist noch Platz", symbol: "heart") }
            else { items(wishes, badge: "heart.fill") { path.append(.parcel($0.id)) } }
        }
    }

    @ViewBuilder private func detail(_ page: Page) -> some View {
        switch page {
        case .category(let category):
            items(visible.filter { $0.category == category }) { path.append(.offer($0.id)) }
        case .offer(let id), .parcel(let id):
            if let piece = item(id) {
                if life.wishlist.contains(id) || (page == .parcel(id) && stock(id) > 0) {
                    parcel(piece)
                } else { offer(piece) }
            }
        case .destinations(let id):
            if let piece = item(id), canPlace, stock(id) > 0 {
                hero(piece, label: "Platz für \(piece.title) auswählen")
                spots(for: piece)
            } else { box(for: nil) }
        case .spot(let id):
            if let spot = position(id) { work(at: spot) }
        case let .exchange(id, spotID):
            if let piece = item(id), let spot = position(spotID), let old = placed(spotID), stock(id) > 0 {
                HStack {
                    WorkshopPicture(piece: old).frame(width: 52, height: 52)
                    glyph("arrow.right", size: 18)
                    glyph("shippingbox")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(old.title) kommt zurück in die Kiste")
                key("\(piece.title) hier aufstellen: \(spot.title)", id: "exchange") {
                    place(piece, at: spot)
                } label: {
                    WorkshopPicture(piece: piece).frame(width: 48, height: 48)
                    glyph("arrow.right", size: 18)
                    glyph(spot.symbol)
                }
            }
        }
    }

    private func offer(_ piece: FarmDecoration) -> some View {
        let affordable = game.state.coins >= piece.price
        let label = affordable ? "Für \(piece.price) Taler in die Kiste legen" : "Auf den Wunschzettel legen"
        let token = "\(coinToken.uuidString):\(piece.id)"
        return VStack(spacing: 12) {
            hero(piece, label: piece.title)
                .dropDestination(for: String.self) { tokens, _ in
                    guard affordable, tokens == [token] else { return false }
                    request(piece)
                    return true
                }
            HStack {
                Taler().frame(width: 28, height: 28)
                Tally(amount: piece.price, compact: false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Preis: \(piece.price) Taler")
            if affordable {
                key(label, id: "request") { request(piece) } label: {
                    Taler().frame(width: 32, height: 32)
                    glyph("arrow.right", size: 18)
                    glyph("shippingbox")
                }
                .draggable(token) { Taler().frame(width: 48, height: 48) }
            } else {
                key(label, id: "wish") { request(piece) } label: {
                    glyph("heart")
                    glyph("arrow.right", size: 18)
                    glyph("envelope")
                }
                .accessibilityHint("Lale bringt dein Paket, sobald die Taler da sind.")
            }
            if canPlace && stock(piece.id) > 0 { chooseSpotKey(piece) }
        }
    }

    private func request(_ piece: FarmDecoration) {
        guard path.last == .offer(piece.id) || path.last == .parcel(piece.id),
              !life.wishlist.contains(piece.id) else { return }
        send(.requestDecoration(piece.id))
        path[path.count - 1] = .parcel(piece.id)
    }

    private func parcel(_ piece: FarmDecoration) -> some View {
        let waiting = life.wishlist.contains(piece.id)
        return VStack(spacing: 10) {
            HStack(spacing: 6) {
                FarmPictogram(id: "npc.lale").frame(width: 64, height: 64)
                glyph(waiting ? "envelope" : "shippingbox")
                WorkshopPicture(piece: piece).frame(width: 58, height: 58)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(waiting ? "\(piece.title) steht auf dem Wunschzettel. Lale bringt es später."
                                : "Post von Lale: \(piece.title) ist in deiner Kiste.")
            if canPlace && stock(piece.id) > 0 { chooseSpotKey(piece) }
        }
    }

    private func chooseSpotKey(_ piece: FarmDecoration) -> some View {
        key("Aus der Kiste nehmen und Platz auswählen", id: "chooseSpot") {
            path.append(.destinations(piece.id))
        } label: {
            glyph("shippingbox")
            glyph("arrow.right", size: 18)
            FarmPictogram(id: "loc.plaza").frame(width: 50, height: 50)
        }
    }

    @ViewBuilder private func box(for spot: FarmChoice?) -> some View {
        let pieces = visible.filter { stock($0.id) > 0 }
        if pieces.isEmpty { invite("Deine Kiste hat Platz für Post von Lale", symbol: "shippingbox") }
        else if !canPlace {
            grid {
                ForEach(pieces) { piece in
                    hero(piece, label: "\(piece.title), \(stock(piece.id)) in der Kiste")
                }
            }
        }
        else {
            items(pieces, badge: "shippingbox") { piece in
                if let spot { select(piece, at: spot) }
                else { path.append(.destinations(piece.id)) }
            }
        }
    }

    private func invite(_ label: String, symbol: String) -> some View {
        VStack(spacing: 12) {
            glyph(symbol).accessibilityLabel(Text(verbatim: label))
            key("Zum Schaufenster", id: "browse") { open(.shop) } label: {
                FarmPictogram(id: "loc.shop").frame(width: 54, height: 54)
            }
        }
    }

    private func items(_ pieces: [FarmDecoration], badge: String? = nil,
                       select: @escaping (FarmDecoration) -> Void) -> some View {
        grid {
            ForEach(pieces) { piece in
                let wished = life.wishlist.contains(piece.id)
                let count = stock(piece.id)
                let symbol = badge ?? (wished ? "heart.fill" : count > 0 ? "shippingbox" : nil)
                key(piece.title, id: "piece.\(piece.id)") { select(piece) } label: {
                    WorkshopPicture(piece: piece)
                        .frame(width: 48, height: 48)
                        .overlay(alignment: .bottomTrailing) {
                            if let symbol { stamp(symbol) }
                        }
                }
                .accessibilityValue([wished ? "Auf dem Wunschzettel" : nil,
                                     count > 0 ? "\(count) in der Kiste" : nil].compactMap { $0 }.joined(separator: ", "))
            }
        }
    }

    private func spots(for piece: FarmDecoration?) -> some View {
        grid {
            ForEach(FarmLife.positions) { spot in
                let old = placed(spot.id)
                key(spot.title, id: "spot.\(spot.id)") {
                    if let piece { select(piece, at: spot) }
                    else { path.append(.spot(spot.id)) }
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        glyph(spot.symbol, size: 32).frame(width: 54, height: 54)
                        if let old {
                            WorkshopPicture(piece: old)
                                .rotationEffect(.degrees(Double(turns(at: spot.id)) * 90))
                                .frame(width: 25, height: 25)
                                .background(WorkshopInk.paper, in: Circle())
                        } else { stamp("plus") }
                    }
                }
                .accessibilityValue(Text(verbatim: old?.title ?? "Freier Platz"))
            }
        }
    }

    private func select(_ piece: FarmDecoration, at spot: FarmChoice) {
        guard stock(piece.id) > 0 else { return }
        if let old = placed(spot.id) {
            if old.id == piece.id { path.append(.spot(spot.id)) }
            else { path.append(.exchange(piece: piece.id, spot: spot.id)) }
        } else { place(piece, at: spot) }
    }

    private func place(_ piece: FarmDecoration, at spot: FarmChoice) {
        guard canPlace, stock(piece.id) > 0 else { return }
        send(.placeDecoration(piece.id, positionID: spot.id))
        shelf = .yard
        path = [.spot(spot.id)]
    }

    private func turns(at id: String) -> Int {
        ((life.placements[id]?.quarterTurns ?? 0) % 4 + 4) % 4
    }

    @ViewBuilder private func work(at spot: FarmChoice) -> some View {
        if let piece = placed(spot.id) {
            let turn = turns(at: spot.id)
            hero(piece, label: "\(piece.title). \(spot.title). \(FarmLife.directions[turn].title).", turns: turn)
                .overlay(alignment: .bottomTrailing) { stamp(FarmLife.directions[turn].symbol) }
            HStack(spacing: 8) {
                key("Um eine Vierteldrehung drehen", id: "rotate") { send(.rotateDecoration(spot.id)) } label: {
                    glyph("rotate.right")
                }
                .accessibilityValue(Text(verbatim: FarmLife.directions[turn].title))
                key("Zurück in die Kiste legen", id: "putAway") {
                    send(.putAwayDecoration(spot.id))
                    open(.box)
                } label: { glyph("arrow.down"); glyph("shippingbox", size: 24) }
            }
        } else {
            glyph(spot.symbol).accessibilityLabel("Freier Platz: \(spot.title)")
            box(for: spot)
        }
    }

    private func hero(_ piece: FarmDecoration, label: String, turns: Int = 0) -> some View {
        WorkshopPicture(piece: piece)
            .rotationEffect(.degrees(Double(turns) * 90))
            .frame(width: 86, height: 86)
            .padding(8)
            .background(WorkshopInk.tile, in: .rect(cornerRadius: 20))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: label))
            .accessibilityAddTraits(.isHeader)
    }

    private func back() {
        if path.isEmpty { close() } else { path.removeLast() }
    }

    private func open(_ tab: WorkshopShelf) { shelf = tab; path.removeAll() }

    private func glyph(_ name: String, size: CGFloat = 28) -> some View {
        Image(systemName: name).font(.system(size: size, weight: .semibold, design: .rounded))
    }

    private func stamp(_ name: String) -> some View {
        glyph(name, size: 13)
            .frame(width: 21, height: 21)
            .background(WorkshopInk.paper, in: Circle())
            .accessibilityHidden(true)
    }

    private func grid<Content: View>(minimum: CGFloat = 86, @ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum), spacing: 8)], spacing: 8, content: content)
    }

    private func key<Content: View>(_ title: String, id: String, selected: Bool = false,
                                    action: @escaping () -> Void, @ViewBuilder label: () -> Content) -> some View {
        Button(action: action) {
            HStack(spacing: 4, content: label)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(selected ? WorkshopInk.meadow : WorkshopInk.tile, in: .rect(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16).strokeBorder(WorkshopInk.ink.opacity(selected ? 0.75 : 0.22),
                                                                     lineWidth: selected ? 3 : 1)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("decoration.\(id)")
    }
}

private enum WorkshopShelf: String, CaseIterable {
    case box, shop, wishes, yard
    var title: String {
        switch self {
        case .box: "Dekokiste"; case .shop: "Schaufenster"; case .wishes: "Wunschzettel"; case .yard: "Plätze auf dem Hof"
        }
    }
    var symbol: String { self == .wishes ? "heart.square" : "shippingbox" }
    var art: String? { self == .shop ? "loc.shop" : self == .yard ? "loc.plaza" : nil }

    static func category(_ id: String) -> (title: String, symbol: String) {
        switch id {
        case "paths": ("Wege und Zäune", "figure.walk")
        case "furniture": ("Hofmöbel", "chair.fill")
        case "plants": ("Blumen und Bäume", "camera.macro")
        case "lights": ("Lichter", "lightbulb.fill")
        case "play": ("Zum Spielen", "fanblades.fill")
        case "shop": ("Für den Hofladen", "storefront.fill")
        case "accessories": ("Tierschmuck", "pawprint.fill")
        case "stickers": ("Traktor-Sticker", "star.fill")
        case "seasonal": ("Jahreszeitenschmuck", "leaf.fill")
        default: ("Weitere Schmuckstücke", "sparkles")
        }
    }
}

private enum WorkshopInk {
    static let ink = Color(red: 0.22, green: 0.17, blue: 0.10)
    static let paper = Color(red: 1, green: 0.97, blue: 0.87)
    static let tile = Color(red: 0.96, green: 0.89, blue: 0.73)
    static let meadow = Color(red: 0.76, green: 0.84, blue: 0.66)
    static let honey = Color(red: 0.94, green: 0.71, blue: 0.27)
}

private struct Taler: View {
    var body: some View {
        Circle()
            .fill(WorkshopInk.honey)
            .overlay { Circle().strokeBorder(WorkshopInk.ink.opacity(0.7)) }
            .overlay { Image(systemName: "suit.club.fill").resizable().scaledToFit().scaleEffect(0.59) }
            .foregroundStyle(WorkshopInk.ink)
            .accessibilityHidden(true)
    }
}

/// Five dots per group, with a gutter before the next five. No balance is stored here.
private struct Tally: View {
    let amount: Int
    let compact: Bool
    var body: some View {
        let columns = compact ? 10 : 5
        let dot: CGFloat = compact ? 3 : 7
        let gap: CGFloat = compact ? 2 : 4
        let count = min(100, max(0, amount))
        Canvas { context, _ in
            for i in 0..<count {
                let col = i % columns, row = i / columns
                let rect = CGRect(x: CGFloat(col) * (dot + gap) + CGFloat(col / 5) * gap,
                                  y: CGFloat(row) * (dot + gap), width: dot, height: dot)
                context.fill(Path(ellipseIn: rect), with: .color(WorkshopInk.ink))
            }
        }
        .frame(width: CGFloat(min(count, columns)) * (dot + gap) + gap,
               height: max(dot, CGFloat((count + columns - 1) / columns) * (dot + gap)))
        .accessibilityHidden(true)
    }
}

/// Decoration IDs do not currently have their own art-catalog entries. Prefer the actual
/// farm drawing for a matching subject; otherwise give the piece its own shape and colour.
private struct WorkshopPicture: View {
    let piece: FarmDecoration

    var body: some View {
        let key = String(piece.id.dropFirst("deco.".count))
        Group {
            if FarmPictogram.entry(for: piece.id) != nil {
                FarmPictogram(id: piece.id)
            } else if let flower = Self.flowers[key] {
                blossom(petals: flower.0, color: flower.1)
            } else if key.hasPrefix("shop.awning.") {
                awning(String(key.dropFirst("shop.awning.".count)))
            } else if let sketch = ToySketch(rawValue: key) {
                sketch
            } else if let art = Self.pictures[key] {
                FarmPictogram(id: art)
            } else {
                let motif = Self.motifs[key] ?? (WorkshopShelf.category(piece.category).symbol, WorkshopInk.ink)
                Image(systemName: motif.0)
                    .resizable().scaledToFit()
                    .foregroundStyle(motif.1)
                    .padding(4)
            }
        }
        .accessibilityLabel(Text(verbatim: piece.title))
    }

    private static let bark = Color(red: 0.45, green: 0.29, blue: 0.17)
    private static let green = Color(red: 0.26, green: 0.45, blue: 0.28)
    private static let blue = Color(red: 0.24, green: 0.46, blue: 0.62)
    private static let berry = Color(red: 0.72, green: 0.33, blue: 0.37)
    private static let gold = Color(red: 0.67, green: 0.44, blue: 0.09)
    private static let violet = Color(red: 0.47, green: 0.35, blue: 0.61)
    private static let stone = Color(red: 0.41, green: 0.44, blue: 0.46)

    private static let pictures = [
        "birdhouse": "act.nature.birdhouse", "weathercock": "animal.chicken", "hobbyhorse": "animal.horse",
        "shop.sign.apple": "crop.apple", "shop.sign.bread": "item.bread", "shop.sign.cow": "animal.cow",
        "shop.box.spring": "season.spring", "shop.box.summer": "act.nature.flowers", "shop.box.autumn": "season.autumn",
        "acc.cap": "item.beanie", "acc.pompom": "item.wool",
        "sticker.ladybug": "animal.ladybug", "sticker.wheat": "crop.wheat",
        "season.spring.nest": "item.egg", "season.spring.swallow": "animal.bird",
        "season.summer.chain": "crop.sunflower", "season.summer.blanket": "crop.strawberry",
        "season.autumn.pumpkin": "crop.pumpkin", "season.autumn.kite": "act.nature.kite",
        "season.autumn.sheaf": "crop.wheat", "season.winter.lantern": "act.nature.lantern",
    ]

    private static let flowers: [String: (Int, Color)] = [
        "flower.daisy": (10, .white), "flower.tulip": (3, berry), "flower.crocus": (4, violet),
        "flower.pansy": (5, .indigo), "flower.marigold": (9, .orange), "flower.cornflower": (8, blue),
        "flower.poppy": (4, berry), "flower.lavender": (6, violet), "flower.hollyhock": (5, .pink),
        "flower.cosmos": (8, .pink), "flower.waterlily": (6, .white), "flower.heather": (3, violet),
    ]

    private static let motifs: [String: (String, Color)] = [
        "fence.willow": ("square.grid.3x3", bark),
        "fence.gate": ("door.left.hand.open", bark), "fence.rail": ("equal", bark),
        "fence.stone": ("square.grid.3x2.fill", stone), "path.stones": ("circle.hexagongrid.fill", stone),
        "path.gravel": ("circle.grid.3x3.fill", stone), "path.planks": ("rectangle.split.3x1.fill", bark),
        "path.mosaic": ("leaf.fill", stone), "path.bricks": ("square.grid.3x2.fill", berry),
        "bench.log": ("chair.lounge.fill", bark), "bench.stool": ("chair.fill", gold),
        "bench.backrest": ("chair.fill", berry), "bench.curved": ("circle.dashed", bark),
        "bench.wicker": ("chair.lounge.fill", gold), "table.crate": ("table.furniture.fill", bark),
        "table.painted": ("table.furniture.fill", blue), "table.picnic": ("fork.knife", bark),
        "table.chess": ("checkerboard.rectangle", bark), "table.stump": ("tree.fill", bark),
        "tree.birch": ("tree", stone), "tree.rowan": ("tree.fill", berry), "tree.hazel": ("leaf.fill", green),
        "tree.willow": ("tree", green), "tree.maple": ("leaf.fill", .orange), "tree.linden": ("tree.fill", green),
        "lantern.jar": ("light.cylindrical.ceiling.fill", gold), "lantern.paper": ("lightbulb.fill", .orange),
        "lantern.star": ("star.fill", gold), "lantern.rail": ("lamp.table.fill", bark),
        "lantern.string": ("lightbulb.2.fill", gold), "lantern.post": ("lamp.floor.fill", bark),
        "lantern.window": ("window.casement", blue), "lantern.arch": ("rainbow", gold),
        "windmill": ("fanblades.fill", green), "swing": ("figure.play", bark),
        "musicbox": ("music.note.house.fill", bark), "windchime": ("music.note.list", blue),
        "hopscotch": ("square.grid.2x2", blue), "marbletrack": ("point.topleft.down.to.point.bottomright.curvepath", bark),
        "sundial": ("sun.max.fill", gold), "acc.ribbon": ("scribble.variable", blue),
        "acc.rosette": ("rosette", berry), "acc.bell": ("bell.fill", gold), "acc.strawhat": ("hat.widebrim.fill", gold),
        "acc.neckerchief": ("triangle.fill", blue), "acc.crown": ("crown.fill", green),
        "acc.star": ("star.fill", gold), "acc.scarf": ("wind", violet), "acc.saddlecloth": ("suit.club.fill", green),
        "sticker.star": ("star.fill", gold), "sticker.flower": ("camera.macro", violet),
        "sticker.heart": ("heart.fill", berry), "sticker.rainbow": ("rainbow", blue),
        "sticker.paw": ("pawprint.fill", bark), "sticker.cloud": ("cloud.fill", blue),
        "season.spring.garland": ("camera.macro", berry), "season.spring.arch": ("rainbow", green),
        "season.summer.boat": ("sailboat.fill", bark), "season.summer.sunshade": ("beach.umbrella.fill", blue),
        "season.autumn.leaves": ("leaf.circle.fill", .orange), "season.winter.snowflake": ("snowflake", blue),
        "season.winter.icicle": ("drop.fill", blue),
    ]

    private enum ToySketch: String, View {
        case fence = "fence.picket", wheel = "waterwheel", carousel, bow = "acc.bow", sled = "season.winter.sled"

        var body: some View {
            Canvas { ctx, size in
                ctx.scaleBy(x: size.width / 48, y: size.height / 48)
                func draw(_ points: [CGPoint], color: Color, filled: Bool = false) {
                    var line = Path()
                    line.addLines(points)
                    if filled {
                        line.closeSubpath(); ctx.fill(line, with: .color(color))
                    } else {
                        ctx.stroke(
                            line, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                }
                func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
                let wood = WorkshopPicture.bark
                switch self {
                case .fence:
                    for y: CGFloat in [23, 32] { draw([p(2, y), p(46, y)], color: wood) }
                    for x: CGFloat in [4, 15, 26, 37] {
                        draw([p(x, 38), p(x, 16), p(x + 3, 10), p(x + 6, 16), p(x + 6, 38)], color: wood, filled: true)
                    }
                case .wheel:
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: 7, y: 5, width: 34, height: 34)),
                        with: .color(wood), lineWidth: 4)
                    for i in 0..<8 {
                        let angle = Double(i) * .pi / 4
                        draw([p(24, 22), p(24 + 18 * cos(angle), 22 + 18 * sin(angle))], color: wood)
                    }
                    draw([p(4, 43), p(14, 40), p(24, 43), p(34, 40), p(44, 43)], color: WorkshopPicture.blue)
                case .carousel:
                    draw([p(4, 20), p(24, 6), p(44, 20)], color: WorkshopPicture.berry, filled: true)
                    for x: CGFloat in [11, 24, 37] { draw([p(x, 20), p(x, 39)], color: wood) }
                    draw([p(5, 40), p(43, 40)], color: wood)
                    for x: CGFloat in [7, 33] {
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x, y: 29, width: 9, height: 5)), with: .color(WorkshopPicture.gold))
                    }
                case .bow:
                    for x: CGFloat in [5, 43] {
                        draw([p(x, 13), p(24, 24), p(x, 35)], color: WorkshopPicture.berry, filled: true)
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: 20, y: 20, width: 8, height: 8)), with: .color(wood))
                case .sled:
                    draw([p(9, 21), p(36, 21)], color: wood)
                    for x: CGFloat in [14, 30] { draw([p(x, 21), p(x + 3, 30)], color: wood) }
                    draw([p(6, 32), p(36, 32), p(42, 28), p(43, 25)], color: WorkshopPicture.stone)
                }
            }
        }
    }

    private func blossom(petals: Int, color: Color) -> some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 48, y: size.height / 48)
            ctx.fill(
                Path(roundedRect: CGRect(x: 23, y: 18, width: 3, height: 27), cornerRadius: 2),
                with: .color(Self.green))
            ctx.fill(Path(ellipseIn: CGRect(x: 25, y: 31, width: 14, height: 6)), with: .color(Self.green))
            ctx.translateBy(x: 24, y: 18)
            for _ in 0..<petals {
                let petal = Path(ellipseIn: CGRect(x: -4.5, y: -15, width: 9, height: 16))
                ctx.fill(petal, with: .color(color))
                ctx.stroke(petal, with: .color(WorkshopInk.ink.opacity(0.35)), lineWidth: 1)
                ctx.rotate(by: .degrees(360 / Double(petals)))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: -5, y: -5, width: 10, height: 10)), with: .color(WorkshopInk.honey))
        }
    }

    private func awning(_ variant: String) -> some View {
        let colors = [
            "red": Self.berry, "yellow": WorkshopInk.honey, "green": Self.green, "blue": Self.blue,
            "orange": .orange, "purple": Self.violet, "stripes": Self.blue, "dots": Self.violet,
        ]
        return Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 48, y: size.height / 48)
            ctx.stroke(Path(CGRect(x: 7, y: 19, width: 34, height: 22)), with: .color(Self.bark), lineWidth: 3)
            let color = colors[variant] ?? Self.green
            for i in 0..<5 {
                let x = CGFloat(i) * 8 + 4
                var stripe = Path()
                stripe.move(to: CGPoint(x: x + 1, y: 9))
                stripe.addLine(to: CGPoint(x: x + 9, y: 9))
                stripe.addLine(to: CGPoint(x: x + 8, y: 20))
                stripe.addQuadCurve(to: CGPoint(x: x, y: 20), control: CGPoint(x: x + 4, y: 27))
                stripe.closeSubpath()
                ctx.fill(stripe, with: .color(variant == "stripes" && i.isMultiple(of: 2) ? .white : color))
                if variant == "dots" {
                    ctx.fill(Path(ellipseIn: CGRect(x: x + 2, y: 14, width: 3, height: 3)), with: .color(.white))
                }
            }
        }
    }
}
