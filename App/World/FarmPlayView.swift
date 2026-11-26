import RealityKit
import SwiftUI
import UIKit

/// Safe-area HUD over a camera-framed RealityKit farm. All model mutations travel
/// through `send`; view state only remembers navigation, gestures and presentation.
struct FarmPlayView: View {
    let state: FarmWorldState
    let send: (FarmWorldIntent) -> Void
    @State private var diorama = FarmDiorama()
    @State private var place: String?
    @State private var page = 0
    @State private var sheet: Sheet?
    @State private var lastTouch = Date.distantPast
    @State private var lastID = ""
    @State private var waitingForNightStory = false
    @State private var response: Reaction?
    @State private var nextFind: [String: String] = [:]
    @Environment(\.accessibilityReduceMotion) private var systemStill
    @Environment(\.scenePhase) private var scenePhase

    private enum Sheet { case map, book, night }
    private struct Reaction: Equatable {
        var key = UUID()
        var picture: String
        var label: String
    }
    private var paused: Bool { state.paused || scenePhase != .active || sheet != nil }
    private var motion: Bool { !state.reduceMotion && !systemStill && !state.quiet && !paused }
    private var site: WorldSite? { WorldSite.at(state.active?.offering.locationID ?? place) }
    private var discoveries: [WorldSticker] {
        guard state.active == nil, let site else { return [] }
        return state.book.filter { $0.id.hasPrefix("hofbook.discovery.") && $0.locationID == site.id }
    }
    private var discovery: WorldSticker? {
        discoveries.first(where: { $0.id == nextFind[site?.id ?? ""] }) ??
            discoveries.first(where: { !$0.discovered }) ?? discoveries.first
    }
    private var offers: [WorldOffering] {
        let visible = state.offerings.filter { site == nil ? $0.isWish : $0.locationID == site?.id }
        var seen: Set<String> = []
        return visible.filter { seen.insert($0.locationID + "/" + $0.activityID).inserted }
    }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 470
            let size: CGFloat = state.largeControls ? (compact ? 80 : 96) :
                (state.stage == .seedling ? (compact ? 68 : 88) : (compact ? 64 : 72))
            let perPage = geo.size.width < 520 || compact || state.stage == .seedling ? 2 : 3
            let targets = state.hasDrivingJob ? [] : WorldObject.targets(turn: state.active, site: site, page: page, perPage: perPage, beds: state.beds)
            ZStack {
                FarmSky(season: state.season, weather: state.weather, evening: state.sunProgress >= 0.72)
                ZStack {
                    // Keep one RealityView alive across rotation. Moving its root
                    // into a second view races with teardown of the old GPU scene.
                    stage(targets: targets, size: size)
                        .padding(.horizontal, compact ? size * 0.8 : 0)
                        .padding(.top, compact ? 8 : size)
                        .padding(.bottom, (state.hasDrivingJob ? 2 : (compact ? 27 : size)) + (state.caption?.isEmpty == false ? 40 : 0))
                    VStack(spacing: 0) {
                        topBar(size: size, compact: compact)
                        if site?.id == "loc.shop" {
                            HStack(spacing: 5) {
                                Image(systemName: "handbag.fill").foregroundStyle(FarmPaper.clay)
                                Text("\(state.coins)").font(.system(.body, design: .rounded, weight: .bold)).monospacedDigit()
                            }
                            .foregroundStyle(FarmPaper.pine)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(FarmPaper.cream, in: Capsule())
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Taler im Geldbeutel").accessibilityValue("\(state.coins)")
                            .accessibilityIdentifier("world.wallet")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        Spacer(minLength: 0)
                        if let caption = state.caption, !caption.isEmpty {
                            Text(caption).font(.system(.callout, design: .rounded, weight: .semibold))
                                .multilineTextAlignment(.center).foregroundStyle(FarmPaper.pine)
                                .padding(.horizontal, 14).padding(.vertical, 4)
                                .background(FarmPaper.cream, in: Capsule()).lineLimit(2)
                                .accessibilityIdentifier("world.caption")
                        }
                        if !state.hasDrivingJob { bottomBar(size: size, perPage: perPage) }
                    }
                }
                .padding(.horizontal, compact ? 4 : 7).padding(.vertical, 2)
                .accessibilityHidden(sheet != nil)
                if sheet == .map {
                    map(size: size)
                } else if sheet == .book {
                    WorldBook(entries: state.book, size: size, send: send) { sheet = nil }
                } else if sheet == .night {
                    night(size: size)
                }
            }
            .background(FarmPaper.cream)
            .onChange(of: state.active?.helpLevel) { _, new in
                if let new, new >= 2, let turn = state.active,
                   let index = turn.choices.firstIndex(where: { $0.id == turn.targetID }) {
                    page = index / perPage
                }
            }
        }
        .onAppear { place = state.active?.offering.locationID ?? state.locationID }
        .onChange(of: state.nightStory != nil, initial: true) { _, available in
            if available { sheet = .night }
        }
        .onChange(of: state.eveningDue && state.active == nil, initial: true) { _, due in
            if due && sheet != .night { waitingForNightStory = false; sheet = .night }
        }
        .onChange(of: state.locationID) { _, id in place = id }
        .onChange(of: state.active?.offering.locationID) { _, id in if let id { place = id } }
        .onChange(of: state.active?.stepID) { _, _ in page = 0; diorama.resetDrag() }
        .task(id: hintKey) {
            guard let seconds = state.secondsUntilIdleHint, !state.hasDrivingJob, !paused else { return }
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard !Task.isCancelled else { return }
            send(.idleHint(seconds: seconds))
        }
        .task(id: response?.key) {
            guard response != nil else { return }
            do { try await Task.sleep(for: .seconds(1.6)) } catch { return }
            response = nil
        }
    }

    private var hintKey: String {
        "\(state.active?.offering.id ?? "")|\(state.active?.stepID ?? "")|\(state.active?.helpLevel ?? 0)|\(state.secondsUntilIdleHint ?? 0)|\(lastTouch.timeIntervalSinceReferenceDate)|\(paused)|\(state.hasDrivingJob)"
    }

    private func stage(targets: [WorldObject], size: CGFloat) -> some View {
        GeometryReader { geo in
            let f = WorldFraming(size: geo.size, site: site, level: state.farmLevel)
            ZStack {
                RealityView { content in
                    diorama.install(&content)
                    diorama.render(state: state, site: site, targets: targets, framing: f, motion: false, detail: discovery)
                } update: { _ in
                    diorama.render(state: state, site: site, targets: targets, framing: f, motion: motion, detail: discovery)
                }
                .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { tap in
                    guard !state.hasDrivingJob, !paused else { return }
                    if let obj = targets.first(where: { "pick:" + $0.id == tap.entity.name }) { perform(obj) }
                    else if tap.entity.name == "pelle" { askPelle() }
                })
                .accessibilityHidden(true)
                if let site {
                    if let turn = state.active, let job = FarmDriveWork.job(for: turn, farmLevel: state.farmLevel) {
                        FarmDriveView(job: job, turn: turn, state: state, site: site, framing: f, root: diorama.root,
                                      paused: paused, onHorn: { send(.horn) },
                                      onFinish: { send(.perform(turn.targetID)) })
                            .id([turn.offering.id, turn.stepID, turn.targetID ?? ""].joined(separator: "/"))
                    } else if state.active == nil {
                        details(site: site, framing: f, size: size)
                    } else {
                        ForEach(targets) { obj in objectButton(obj, framing: f, size: size) }
                    }
                } else {
                    ForEach(WorldSite.all.filter { state.locationIDs.contains($0.id) }, id: \.id) { place in
                        let point = f.project(place.center + [0, 0.64, 0])
                        Button { visit(place.id) } label: {
                            Color.clear.frame(width: size, height: size).contentShape(Rectangle())
                        }.buttonStyle(.plain).position(point)
                            .accessibilityLabel(place.name).accessibilityIdentifier("world.place." + place.id)
                    }
                    wishBubbles(framing: f, size: size)
                }
                if let response {
                    Group {
                        if response.picture.hasPrefix("hofbook.discovery.") {
                            Image(systemName: WorldFind.symbol(response.picture)).foregroundStyle(FarmPaper.pine)
                        } else { FarmPictogram(id: response.picture) }
                    }.frame(width: 33, height: 33)
                        .padding(7).background(FarmPaper.cream, in: Capsule())
                        .overlay(Capsule().strokeBorder(FarmPaper.edge.opacity(0.38), lineWidth: 1))
                        .frame(maxHeight: .infinity, alignment: .top).allowsHitTesting(false)
                        .accessibilityLabel(response.label)
                }
            }
        }
    }

    private func wishBubbles(framing f: WorldFraming, size: CGFloat) -> some View {
                    let limit = state.stage == .seedling ? 2 : 3
                    var occupied: [CGPoint] = []
                    var places: Set<String> = []
                    let bubbles: [(WorldOffering, CGPoint)] = offers.filter { $0.isWish && places.insert($0.locationID).inserted }
                        .prefix(limit).compactMap { offer in
                            guard let s = WorldSite.at(offer.locationID) else { return nil }
                            let base = f.project(s.center + [0, 1.1, 0])
                            let d = min(size, 80)
                            var p = CGPoint(x: min(max(d/2, base.x), f.size.width-d/2),
                                            y: max(d/2, base.y-d*0.77))
                            if occupied.contains(where: { abs($0.x-p.x) < d && abs($0.y-p.y) < d*0.62 }) {
                                p.y = max(d/2, p.y-d*0.78)
                            }
                            occupied.append(p)
                            return (offer, p)
                        }
                    return ForEach(Array(bubbles.enumerated()), id: \.element.0.id) { _, pair in
                        let (offer, p) = pair
                        Button { start(offer) } label: {
                            VStack(spacing: -4) {
                                HStack(spacing: 1) {
                                    FarmPictogram(id: offer.subjectID ?? WorldSite.at(offer.locationID)?.animal ?? offer.locationID)
                                        .frame(width: 26, height: 26)
                                    FarmPictogram(id: offer.activityID).frame(width: 27, height: 27)
                                }.padding(4).background(FarmPaper.cream, in: Capsule())
                                    .overlay(Capsule().strokeBorder(FarmPaper.edge.opacity(0.5), lineWidth: 1))
                                Image(systemName: "arrowtriangle.down.fill").font(.system(size: 9)).foregroundStyle(FarmPaper.edge)
                            }.frame(width: size, height: 64).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel(WorldVignette.all[offer.activityID]?.label ?? "Wunsch")
                            .accessibilityIdentifier("world.wish." + offer.id).position(p)
                    }
    }

    private func objectButton(_ obj: WorldObject, framing f: WorldFraming, size: CGFloat) -> some View {
        let lift = min(0.41, WorldObject.propSpan(obj.model, otherwise: 0.82) / 2)
        let point = f.project(obj.point + [0, lift, 0])
        let help = state.active?.helpLevel ?? 0
        return Button { perform(obj) } label: {
            ZStack(alignment: .bottom) {
                Color.clear
                if let symbol = obj.symbol, !symbol.isEmpty {
                    Group {
                        if symbol.unicodeScalars.allSatisfy(\.isASCII) { Image(systemName: symbol) }
                        else { Text(symbol) }
                    }.font(.system(size: 17, weight: .bold))
                        .foregroundStyle(FarmPaper.pine)
                        .padding(4).background(FarmPaper.cream, in: Capsule())
                        .overlay(Capsule().strokeBorder(FarmPaper.edge.opacity(0.45), lineWidth: 1))
                }
                if obj.isTarget, help >= 2 {
                    Image(systemName: "hand.point.up.left.fill").font(.title2).foregroundStyle(FarmPaper.pine)
                        .padding(4).background(FarmPaper.cream, in: Circle()).offset(x: size*0.31, y: 5)
                }
            }
            .frame(width: size, height: size).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .simultaneousGesture(DragGesture(minimumDistance: state.stage == .seedling ? 12 : 8)
                .onChanged { value in diorama.drag(obj, translation: value.translation) }
                .onEnded { value in
                    defer { diorama.resetDrag() }
                    guard let site else { return }
                    let drop = f.project(diorama.dropPoint(site) + [0, 0.32, 0])
                    let end = CGPoint(x: point.x+value.translation.width, y: point.y+value.translation.height)
                    let radius: CGFloat = state.stage == .seedling || help >= 2 ? 100 : (state.stage == .shoot ? 70 : 45)
                    let cares = state.active?.offering.activityID == "act.animal.pet"
                    if hypot(end.x-drop.x, end.y-drop.y) <= radius || cares { perform(obj) }
                })
            .accessibilityLabel(obj.label).accessibilityIdentifier("world.target." + obj.id).position(point)
    }

    @ViewBuilder private func details(site: WorldSite, framing f: WorldFraming, size: CGFloat) -> some View {
        if site.id == "loc.shop" || site.id == "loc.plaza" {
            sceneButton(at: f.project(site.center + [-0.08, 0.46, 1.19]), size: size, label: "Dekokiste öffnen",
                        id: "world.decorationBox", picture: "shippingbox.fill") { send(.decorationBox) }
        }
        if site.id == "loc.plaza" {
            sceneButton(at: f.project(site.center + [-0.55, 1.52, -0.51]), size: size, label: "Hofbaum und Hofbuch",
                        id: "world.tree", picture: "book.fill") { sheet = .book }
        }
        if let find = discovery {
            sceneButton(at: f.project(site.center + WorldFind.point + [0, 0.3, 0]), size: size,
                        label: find.label, id: "world.discover." + find.id, picture: "magnifyingglass") {
                if let i = discoveries.firstIndex(where: { $0.id == find.id }) {
                    nextFind[site.id] = discoveries[(i+1) % discoveries.count].id
                }
                send(.discover(find.id)); response = Reaction(picture: find.modelID, label: find.label)
            }
        }
        let beds = state.beds.filter { $0.locationID == site.id }
        if !beds.isEmpty {
            let grid = WorldBedGrid(count: beds.count, field: site.id == "loc.field")
            ForEach(Array(beds.enumerated()), id: \.element.id) { index, bed in
                Button {
                    let act = bed.cropID == nil ? "act.field.sow" : (bed.growth == "ripe" ? "act.field.harvest" : "act.field.water")
                    startMatching(act)
                } label: {
                    Color.clear.frame(width: max(44, size * 0.68), height: max(44, size * 0.68)).contentShape(Rectangle())
                }.buttonStyle(.plain).position(f.project(site.center + grid.center(index: index) + [0, 0.23, 0]))
                    .accessibilityLabel("Beet \(index+1)")
                    .accessibilityValue(bed.cropID == nil ? (bed.growth == "plowed" ? "Gepflügte Erde" : "Erde") :
                                            "\(bed.growth), \(bed.watered ? "gegossen" : "nicht gegossen")")
                    .accessibilityIdentifier("world.bed." + bed.id)
            }
        } else if site.animal != nil {
            sceneButton(at: f.project(site.center + [0.68, 0.65, 0.01]), size: size, label: site.name + ", Tier versorgen",
                        id: "world.resident", picture: nil) { startMatching("act.animal.pet") }
                .accessibilityValue(state.caredFor.contains(where: { $0.hasPrefix(site.animal ?? "none") }) ? "Heute versorgt" : "Auf dem Hof")
        } else if site.id == "loc.shop" {
            sceneButton(at: f.project(site.center + [0, 0.95, 0.01]), size: size, label: "Hofladenregal",
                        id: "world.shelf", picture: nil) { startMatching("act.shop.stock") }
                .accessibilityValue("\(state.shelf.values.reduce(0, +)) Waren")
        }
    }

    private func sceneButton(at point: CGPoint, size: CGFloat, label: String, id: String, picture: String?,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Color.clear
                if let picture {
                    Image(systemName: picture).font(.title3).foregroundStyle(FarmPaper.pine).padding(5).background(FarmPaper.cream, in: Circle())
                        .offset(x: size*0.2, y: -size*0.22)
                }
            }.frame(width: size, height: size).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(label).accessibilityIdentifier(id).position(point)
    }

    private func topBar(size: CGFloat, compact: Bool) -> some View {
        HStack(spacing: 0) {
            WorldButton(icon: "house.fill", label: "Hofübersicht", id: "world.home", size: size) {
                send(.leaveActivity); place = nil; page = 0; sheet = nil
            }
            Spacer(minLength: 1)
            Button { waitingForNightStory = false; sheet = .night } label: {
                HStack(spacing: 5) {
                    Image(systemName: skySymbol).font(.system(size: compact ? 23 : 28, weight: .semibold))
                    if !compact {
                        ForEach(0..<3) { i in
                            Circle().fill(Double(i+1)/3 <= state.sunProgress ? FarmPaper.clay : FarmPaper.edge.opacity(0.2)).frame(width: 6, height: 6)
                        }
                    }
                }.foregroundStyle(FarmPaper.pine)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(state.invitesRest ? Color(red: 0.97, green: 0.84, blue: 0.63) : FarmPaper.cream, in: Capsule())
                    .frame(minWidth: 64, minHeight: 64).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(state.invitesRest ? "Pelle lädt zum Schlafengehen ein" : "Sonnenbogen und Feierabend").accessibilityIdentifier("world.day")
            Spacer(minLength: 1)
            WorldButton(icon: "book.fill", label: "Hofbuch", id: "world.book", size: size) { sheet = .book }
            WorldButton(icon: "pause.fill", label: "Pause", id: "world.pause", size: size) { send(.pause) }
        }
    }

    private var skySymbol: String {
        if state.invitesRest { return "moon.stars.fill" }
        if state.sunProgress >= 0.82 { return "sunset.fill" }
        return ["cloud": "cloud.fill", "rain": "cloud.drizzle.fill", "rainbow": "rainbow", "fog": "cloud.fog.fill",
                "snow": "cloud.snow.fill", "wind": "wind"][state.weather] ?? "sun.max.fill"
    }

    private func bottomBar(size: CGFloat, perPage: Int) -> some View {
        HStack(spacing: 2) {
            Button {
                askPelle()
            } label: {
                ZStack {
                    Circle().fill(FarmPaper.pine)
                    Circle().strokeBorder(FarmPaper.cream, lineWidth: 3).padding(3)
                    FarmPictogram(id: "animal.dog").padding(size*0.12)
                }.padding(4).frame(width: size, height: size).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Pelle hilft").accessibilityIdentifier("world.help")
            if let turn = state.active {
                Spacer(minLength: 0)
                let count = max(1, (turn.choices.count + perPage-1)/perPage)
                if count > 1 {
                    WorldButton(icon: "arrow.triangle.2.circlepath", label: "Andere Gegenstände", id: "world.moreTargets", size: size) {
                        page = (page+1) % count
                    }
                }
                HStack(spacing: 5) {
                    FarmPictogram(id: turn.offering.activityID).frame(width: 34, height: 34)
                    ForEach(0..<min(8, max(1, turn.stepCount)), id: \.self) { i in
                        Circle().fill(i <= turn.stepIndex ? FarmPaper.pine : FarmPaper.edge.opacity(0.24)).frame(width: 6, height: 6)
                    }
                }.padding(8).background(FarmPaper.cream, in: Capsule())
                    .accessibilityLabel("Bildfolge, Schritt \(turn.stepIndex+1) von \(turn.stepCount)")
                Spacer(minLength: 0)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(offers) { offer in
                            let art = WorldVignette.all[offer.activityID]
                            Button { start(offer) } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: size * 0.26).fill(FarmPaper.edge.opacity(0.46)).offset(y: 2)
                                    RoundedRectangle(cornerRadius: size * 0.26).fill(FarmPaper.cream)
                                    RoundedRectangle(cornerRadius: size * 0.26).strokeBorder(FarmPaper.edge.opacity(0.49), lineWidth: 1.5)
                                    HStack(spacing: -4) {
                                        FarmPictogram(id: offer.subjectID ?? WorldSite.at(offer.locationID)?.animal ?? offer.locationID)
                                            .frame(width: size*0.44, height: size*0.44)
                                        FarmPictogram(id: offer.activityID).frame(width: size*0.43, height: size*0.43)
                                    }
                                }.frame(width: size*1.09, height: size*0.72).padding(.vertical, size*0.14)
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel(art?.label ?? "Wunsch")
                                .accessibilityIdentifier("world.offer." + offer.id)
                        }
                    }
                }.scrollIndicators(.hidden)
            }
            WorldButton(icon: "map.fill", label: "Orte auf dem Hof", id: "world.map", size: size) { sheet = .map }
        }.frame(height: size)
    }

    private func map(size: CGFloat) -> some View {
        ZStack {
            FarmPaper.cream.ignoresSafeArea()
            VStack {
                HStack {
                    WorldButton(icon: "arrow.uturn.backward", label: "Zurück", id: "world.map.close", size: size) { sheet = nil }
                    Spacer()
                    Image(systemName: "map.fill").font(.largeTitle).foregroundStyle(FarmPaper.pine)
                    Spacer()
                    Color.clear.frame(width: size, height: 1)
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: size+12, maximum: size*1.6))], spacing: 12) {
                        ForEach(WorldSite.all.filter { state.locationIDs.contains($0.id) }, id: \.id) { s in
                            Button { visit(s.id) } label: {
                                FarmPictogram(id: s.id).padding(8).frame(width: size, height: size)
                                    .background(.white.opacity(0.77), in: RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(.plain).accessibilityLabel(s.name).accessibilityIdentifier("world.map." + s.id)
                        }
                    }.padding()
                }
            }.padding(6).frame(maxWidth: 810)
        }.accessibilityAddTraits(.isModal)
    }

    @ViewBuilder private func night(size: CGFloat) -> some View {
        if let story = state.nightStory {
            FarmNightStoryView(story: story, reduceMotion: systemStill || state.reduceMotion || state.quiet, speak: { send(.readStory($0)) }) {
                send(.closeNightStory); sheet = nil; waitingForNightStory = false
            }
        } else { bedtime(size: size) }
    }

    private func bedtime(size: CGFloat) -> some View {
        ZStack {
            Color(red: 0.22, green: 0.32, blue: 0.39).ignoresSafeArea()
            VStack(spacing: 4) {
                HStack {
                    WorldButton(icon: "arrow.uturn.backward", label: "Zurück zum Hof", id: "world.night.close", size: size) {
                        sheet = nil; waitingForNightStory = false
                    }
                    Spacer()
                    if site?.id == "loc.plaza" && !waitingForNightStory {
                        WorldButton(icon: "leaf.arrow.triangle.circlepath", label: "Nächste Jahreszeit", id: "world.season", size: size) {
                            send(.nextSeason); sheet = nil
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: size*0.89)).foregroundStyle(.yellow, .white)
                FarmPictogram(id: "animal.dog").frame(width: size, height: size)
                WorldButton(icon: waitingForNightStory ? "moon.zzz.fill" : "bed.double.fill", label: "Schlafen gehen",
                            id: "world.sleep", size: size*1.08) {
                    guard !waitingForNightStory else { return }
                    waitingForNightStory = true; send(.endDay); place = nil
                }.disabled(waitingForNightStory)
                Spacer(minLength: 0)
            }.padding(.horizontal, 10)
        }.accessibilityAddTraits(.isModal)
    }

    private func visit(_ id: String) {
        if state.active != nil { send(.leaveActivity) }
        sheet = nil; page = 0; place = id
        send(.visit(id))
    }

    private func start(_ offer: WorldOffering) {
        page = 0; place = offer.locationID; sheet = nil
        send(.begin(offer.id))
    }

    private func startMatching(_ activity: String) {
        if let offer = offers.first(where: { $0.activityID == activity }) ?? offers.first { start(offer) }
        else { send(.help) }
    }

    private func askPelle() {
        if state.active == nil, let wish = offers.first { start(wish) }
        else { send(.help) }
    }

    private func perform(_ obj: WorldObject) {
        guard !state.hasDrivingJob, !paused, let turn = state.active, let site else { return }
        let key = turn.offering.id + turn.stepID + obj.id
        guard lastID != key || Date.now.timeIntervalSince(lastTouch) >= 0.15 else { return }
        lastID = key; lastTouch = .now
        if turn.targetID == nil || obj.isTarget {
            diorama.respond(to: obj, turn: turn, site: site, motion: motion)
            response = Reaction(picture: turn.offering.activityID, label: obj.label)
            if state.haptics { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55) }
        }
        send(.perform(obj.choiceID))
    }
}
