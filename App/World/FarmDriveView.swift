import RealityKit
import SwiftUI

private struct DriveLane {
    let right: Float
    let left: Float
    let z: Float
    let ground: Float
    let depth: Float
    let strips: [ClosedRange<Float>]

    init(job: FarmDriveWork, turn: WorldTurn, beds: [WorldBed]) {
        if job == .clearSnow {
            (right, left, z, ground, depth) = (1.78, -1.78, 1.32, 0.093, 0.58)
            strips = [left...right]
        } else {
            let local = beds.filter { $0.locationID == turn.offering.locationID }
            let grid = WorldBedGrid(count: local.count, field: true)
            let ids = Set(turn.workBeds)
            let centers = local.indices.filter { ids.contains(local[$0].id) }.map { grid.center(index: $0) }
            depth = grid.depth
            ground = 0.31
            z = centers.first?.z ?? 0
            strips = centers.map { ($0.x - grid.width * 0.45)...($0.x + grid.width * 0.45) }
            right = strips.map(\.upperBound).max() ?? 0
            left = strips.map(\.lowerBound).min() ?? 0
        }
    }

    var length: Float { right - left }
    func x(_ travel: Double) -> Float { right - Float(travel) * length }
    var workSpans: [ClosedRange<Double>] {
        guard length > 0 else { return [] }
        return strips.map { Double((right - $0.upperBound) / length)...Double((right - $0.lowerBound) / length) }
    }
}

@MainActor
private final class DriveRig {
    private let workshop = WorldWorkshop()
    private let container = Entity()
    private let hitch = Entity()
    private var wheels: [Entity] = []
    private var surfaces: [(entity: Entity, bounds: ClosedRange<Float>)] = []
    private var guides: [(dot: Entity, x: Float)] = []

    func install(in root: Entity, site: WorldSite, lane: DriveLane, job: FarmDriveWork) {
        if container.parent === root { return }
        root.addChild(container)
        container.position = site.center
        container.addChild(hitch)
        wheels = [workshop.toy(job.vehicle, in: hitch, span: job == .combine ? 1.16 : 0.97, facing: .negativeX)]
        if let implement = job.implement {
            let inFront = job == .lift || job == .clearSnow
            wheels.append(workshop.toy(implement, in: hitch, at: [inFront ? -0.60 : 0.66, 0, 0],
                                       span: 0.67, facing: .negativeX))
        }
        let soil = job == .water ? 0x604c37 : job == .clearSnow ? 0xcba57c : 0x694b34
        for bounds in lane.strips {
            let patch = workshop.group(container)
            for s: Float in [-1, 0, 1] {
                workshop.box(patch, [0, 0.017, s * lane.depth * 0.21], [1, 0.034, lane.depth * 0.14], soil)
                if job == .sow {
                    workshop.oval(patch, [s * 0.28, 0.043, s * lane.depth * 0.21], [0.12, 0.035, 0.04], WorldWorkshop.straw)
                }
            }
            surfaces.append((patch, bounds))
            let width = bounds.upperBound - bounds.lowerBound
            let count = max(1, Int((width / 0.28).rounded()))
            for i in 0..<count {
                let x = bounds.lowerBound + (Float(i) + 0.5) * width / Float(count)
                let dot = workshop.oval(container, [x, lane.ground + 0.025, lane.z], [0.11, 0.035, 0.075], 0xf9d899)
                guides.append((dot, x))
            }
        }
        // Small boundary flags mark the row even before the tractor moves.
        for x in [lane.right, lane.left] {
            let f = workshop.group(container, at: [x, lane.ground, lane.z - lane.depth * 0.47])
            workshop.box(f, [0, 0.19, 0], [0.035, 0.38, 0.035], WorldWorkshop.darkWood)
            workshop.box(f, [-0.09, 0.32, 0], [0.19, 0.12, 0.038], WorldWorkshop.straw)
        }
    }

    func draw(_ motion: FarmDriveMotion, lane: DriveLane, still: Bool) {
        let x = lane.x(motion.travel)
        hitch.position = [x, lane.ground + 0.025, lane.z + Float(motion.lateral) * min(0.35, lane.depth * 0.39)]
        workshop.tilt(hitch, still ? 0 : Float(motion.steering) * 0.28, [0, 1, 0])
        for (patch, bounds) in surfaces {
            let end = max(bounds.lowerBound, min(x, bounds.upperBound))
            let width = bounds.upperBound - end
            patch.isEnabled = width > 0.001
            patch.position = [(end + bounds.upperBound) * 0.5, lane.ground, lane.z]
            patch.scale = [max(0.001, width), 1, 1]
        }
        for (dot, markerX) in guides { dot.isEnabled = markerX < x }
    }

    func setWheels(turning: Bool) {
        for socket in wheels { workshop.setAction(turning ? "wheels" : nil, on: socket, looping: true) }
    }

    func remove() {
        setWheels(turning: false)
        wheels.removeAll()
        container.removeFromParent()
        container.children.removeAll()
        hitch.children.removeAll()
        surfaces.removeAll()
        guides.removeAll()
    }
}

struct FarmDriveView: View {
    let job: FarmDriveWork
    let turn: WorldTurn
    let state: FarmWorldState
    let site: WorldSite
    let framing: WorldFraming
    let root: Entity
    let paused: Bool
    let onHorn: () -> Void
    let onFinish: () -> Void

    @State private var rig = DriveRig()
    @State private var motion = FarmDriveMotion()
    @State private var honks = 0
    @State private var hornVisible = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemStill

    private var lane: DriveLane { DriveLane(job: job, turn: turn, beds: state.beds) }
    private var stopped: Bool { paused || scenePhase != .active }
    private var still: Bool { state.quiet || state.reduceMotion || systemStill }
    private var compact: Bool { framing.size.height < 300 }
    private var control: CGFloat { state.largeControls ? (compact ? 66 : 86) : (compact ? 56 : 69) }
    private var percent: Int { Int((100 * motion.progress).rounded(.down)) }
    private var activeClock: Bool { !stopped && motion.needsTicks }
    private var animateWheels: Bool { !stopped && !still && motion.wheelsTurning }
    private func project(_ x: Float, _ y: Float, _ z: Float) -> CGPoint {
        framing.project(site.center + [x, y, z])
    }

    var body: some View {
        let row = lane
        let a = project(row.right, row.ground, row.z), b = project(row.left, row.ground, row.z)
        let middle = CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
        ZStack {
            if !stopped {
                rowControl(span: max(75, a.x - b.x), slope: (a.y - b.y) / max(1, a.x - b.x))
                    .position(middle)
                if hornVisible {
                    let p = project(row.x(motion.travel), row.ground + 1.0, row.z)
                    Image(systemName: "music.note.list").font(.title2.bold()).foregroundStyle(FarmPaper.pine)
                        .padding(7).background(FarmPaper.cream, in: Capsule()).position(p)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                VStack(spacing: 0) {
                    progressBadge
                    Spacer(minLength: 0)
                    controls
                }
            }
        }
        .frame(width: framing.size.width, height: framing.size.height)
        .onAppear {
            if motion.travel == 0 && motion.pilot == .child { motion = FarmDriveMotion(strips: row.workSpans) }
            rig.install(in: root, site: site, lane: row, job: job)
            rig.draw(motion, lane: row, still: still)
            rig.setWheels(turning: animateWheels)
        }
        .onDisappear { rig.remove() }
        .onChange(of: motion) { _, new in rig.draw(new, lane: row, still: still) }
        .onChange(of: animateWheels) { _, turning in rig.setWheels(turning: turning) }
        .onChange(of: stopped) { _, value in if value { motion.suspend() } }
        .task(id: activeClock) {
            guard activeClock else { return }
            let clock = ContinuousClock()
            var previous = clock.now
            while !Task.isCancelled && motion.needsTicks {
                do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
                guard !Task.isCancelled else { return }
                let now = clock.now
                let elapsed = (now - previous).components
                motion.tick(seconds: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18)
                previous = now
            }
        }
        .task(id: !stopped && motion.pilot == .finished) {
            guard !stopped, motion.pilot == .finished else { return }
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            if !Task.isCancelled, motion.takeCompletion() { onFinish() }
        }
        .task(id: honks) {
            guard honks > 0 else { return }
            do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
            hornVisible = false
        }
    }

    @ViewBuilder
    private func rowControl(span: CGFloat, slope: CGFloat) -> some View {
        let label = state.stage == .seedling ? "Diese Reihe fahren" : "Traktor auf der Spur ziehen"
        if state.stage != .bloom {
            ZStack {
                Color.clear
                if motion.progress == 0 && motion.pilot == .child {
                    Image(systemName: state.stage == .seedling ? "hand.tap.fill" : "hand.draw.fill")
                        .font(.system(size: 22, weight: .bold)).padding(7)
                        .background(FarmPaper.cream, in: Circle())
                        .overlay(Circle().strokeBorder(FarmPaper.edge.opacity(0.5)))
                }
            }
            .foregroundStyle(FarmPaper.pine)
            .frame(width: min(framing.size.width, span + 56), height: compact ? 56 : 80)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { point in
                let dx = point.translation.width, dy = point.translation.height
                motion.drag(stage: state.stage, along: -(dx + dy * slope) / (span * (1 + slope * slope)),
                            across: (dy - dx * slope) / 80)
            }.onEnded { _ in
                motion.releaseDrag()
                motion.tapRow(stage: state.stage)
            })
            .accessibilityElement(children: .ignore).accessibilityLabel(label)
            .accessibilityAddTraits(.isButton).accessibilityIdentifier("world.drive.row")
            .accessibilityAction {
                if state.stage == .seedling { motion.tapRow(stage: state.stage) }
                else {
                    motion.drag(stage: state.stage, along: 0.30, across: 0)
                    motion.releaseDrag()
                }
            }
        }
    }

    private var progressBadge: some View {
        HStack(spacing: 7) {
            Image(systemName: motion.pilot == .pelle ? "pawprint.fill" : "leaf.fill")
                .foregroundStyle(FarmPaper.pine)
            ProgressView(value: motion.progress)
                .tint(FarmPaper.pine).frame(width: compact ? 62 : 88)
        }
        .padding(.horizontal, 12).padding(.vertical, 7).background(FarmPaper.cream, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(motion.pilot == .pelle ? "Pelle fährt die Reihe" : "Bearbeitete Reihe")
        .accessibilityValue("\(percent)").accessibilityIdentifier("world.drive.progress")
        .allowsHitTesting(false)
    }

    private var controls: some View {
        HStack(spacing: compact ? 5 : 9) {
            if state.stage == .bloom {
                wheel
                Spacer(minLength: 0)
                gas
            } else {
                WorldButton(icon: "speaker.wave.2.fill", label: "Hupen", id: "world.drive.horn",
                            size: control, tone: Color(red: 1, green: 0.85, blue: 0.56)) {
                    guard !stopped else { return }
                    honks += 1
                    hornVisible = true
                    onHorn()
                }
                if state.stage == .seedling {
                    pace(fast: false)
                    pace(fast: true)
                }
            }

            Spacer(minLength: 0)
            Button { motion.assist() } label: {
                FarmPictogram(id: "animal.dog")
                    .frame(width: control * 0.61, height: control * 0.61)
                    .padding(5).background(FarmPaper.cream, in: Circle())
                    .overlay(Circle().strokeBorder(FarmPaper.edge.opacity(0.55), lineWidth: 2))
                    .frame(width: control, height: control).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Pelle fährt für mich")
                .accessibilityIdentifier("world.drive.pelle")
        }
        .foregroundStyle(FarmPaper.pine)
        .padding(.horizontal, compact ? 5 : 8)
    }

    private func pace(fast: Bool) -> some View {
        WorldButton(icon: fast ? "hare.fill" : "tortoise.fill",
                    label: fast ? "Etwas schneller fahren" : "Langsam fahren",
                    id: fast ? "world.drive.fast" : "world.drive.slow", size: max(44, control * 0.84),
                    tone: motion.fastRow == fast ? FarmPaper.pine : FarmPaper.cream,
                    ink: motion.fastRow == fast ? FarmPaper.cream : FarmPaper.pine) { motion.setRowPace(fast: fast) }
            .accessibilityAddTraits(motion.fastRow == fast ? .isSelected : [])
    }

    private var wheel: some View {
        Image(systemName: "steeringwheel").font(.system(size: control * 0.76, weight: .bold))
            .rotationEffect(.degrees(still ? 0 : 35 * motion.steering))
            .frame(width: control, height: control)
            .background(FarmPaper.cream, in: Circle())
            .overlay(Circle().strokeBorder(FarmPaper.edge.opacity(0.55), lineWidth: 2))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { motion.turnWheel(stage: state.stage, to: $0.translation.width / (control * 0.45)) }
                .onEnded { _ in motion.turnWheel(stage: state.stage, to: 0) })
            .accessibilityElement().accessibilityLabel("Lenkrad")
            .accessibilityValue("\(Int(motion.steering * 35)) Grad")
            .accessibilityAdjustableAction { direction in
                motion.turnWheel(stage: state.stage, to: motion.steering + (direction == .increment ? 0.25 : -0.25))
            }
            .accessibilityIdentifier("world.drive.wheel")
    }

    private var gas: some View {
        let width = min(framing.size.width * 0.33, compact ? 136 : 152)
        let inset: CGFloat = 20
        let travel = max(1, width - 2 * inset)
        return ZStack(alignment: .leading) {
            Capsule().fill(FarmPaper.cream)
            HStack {
                Image(systemName: "pause.fill")
                Spacer()
                Image(systemName: "hare.fill")
            }.padding(.horizontal, 12).foregroundStyle(FarmPaper.edge.opacity(0.72))
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(FarmPaper.cream)
                .frame(width: 32, height: 32).background(FarmPaper.pine, in: Circle())
                .offset(x: inset - 16 + travel * motion.throttle)
        }
        .frame(width: width, height: max(44, control * 0.72))
        .overlay(Capsule().strokeBorder(FarmPaper.edge.opacity(0.55), lineWidth: 2))
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged {
            motion.setGas(stage: state.stage, to: ($0.location.x - inset) / travel)
        })
        .accessibilityElement().accessibilityLabel("Gashebel").accessibilityValue("\(Int(motion.throttle * 100))")
        .accessibilityAdjustableAction { direction in
            motion.setGas(stage: state.stage, to: motion.throttle + (direction == .increment ? 0.25 : -0.25))
        }.accessibilityIdentifier("world.drive.throttle")
    }
}
