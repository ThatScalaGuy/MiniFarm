import SwiftUI

struct FarmNightStoryView: View {
    let story: FarmNightStory
    let reduceMotion: Bool
    let speak: (String) -> Void
    let finish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemStill
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase
    @State private var page = 0
    @State private var manual = false
    @State private var finished = false
    private var still: Bool { reduceMotion || systemStill }
    private var lastPage: Int { max(1, (story.deeds.count + 2) / 3) }
    private var visibleDeeds: [String] { Array(story.deeds.dropFirst(max(0, (page-1)*3)).prefix(3)) }
    private var words: String {
        if page == 0 {
            guard let growth = story.growth else { return "Pelle schläft. Ganz still liegt unser Hof im Mondlicht. Bald geht die Sonne auf." }
            let plant = storyLabel(growth.cropID)
            return growth.to == .ripe ? "Schau ins Beet. \(plant)! Über Nacht ist die Ernte reif geworden."
                : "Schau ins Beet. \(plant)! Über Nacht ist die Pflanze ein Stück gewachsen."
        }
        if visibleDeeds.isEmpty { return "Heute war ein ruhiger Hoftag. Guten Morgen, kleiner Hof!" }
        return "Das hast du heute gemacht: " + visibleDeeds.map(storyLabel).joined(separator: ". ") + "."
    }

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            if page == 0 {
                HStack(spacing: 8) {
                    NightPanel(growth: story.growth, morning: false, still: still)
                    Image(systemName: "chevron.right").font(.title2.bold()).foregroundStyle(.white)
                    NightPanel(growth: story.growth, morning: true, still: still)
                }
                .frame(maxWidth: 600, maxHeight: 235)
            } else {
                HStack(spacing: 8) {
                    if visibleDeeds.isEmpty {
                        FarmPictogram(id: "animal.dog").padding(8).frame(maxWidth: 140)
                    } else {
                        ForEach(visibleDeeds, id: \.self) { deed in
                            Button { manual = true; speak(storyLabel(deed)) } label: {
                                FarmPictogram(id: deed)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, maxHeight: 134)
                                    .background(FarmPaper.cream, in: RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain).accessibilityLabel(storyLabel(deed))
                            .accessibilityIdentifier("ritual.deed." + deed)
                        }
                    }
                }.frame(maxWidth: 530, maxHeight: 235)
            }
            HStack(spacing: 14) {
                StoryControl(symbol: "speaker.wave.2.fill", label: "Pelle liest vor", id: "ritual.night.read") {
                    manual = true; speak(words)
                }
                StoryControl(symbol: page == 0 ? "book.pages.fill" : "chevron.right",
                             label: page == 0 ? "Zum Tagesbild" : "Weiter", id: "ritual.night.next") {
                    manual = true; next()
                }
                StoryControl(symbol: "sun.max.fill", label: "Zum neuen Hoftag", id: "world.wake", action: dismiss)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .background {
            LinearGradient(colors: [Color(red: 0.15, green: 0.22, blue: 0.32),
                                    Color(red: 0.26, green: 0.36, blue: 0.39)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
        }
        .accessibilityAddTraits(.isModal)
        .onAppear { speak(words) }
        .onChange(of: page) { _, _ in speak(words) }
        .task(id: [page, manual ? 1 : 0, voiceOver ? 1 : 0, scenePhase == .active ? 1 : 0]) {
            guard !manual, !voiceOver, scenePhase == .active else { return }
            do { try await Task.sleep(for: .seconds(page == 0 ? 8 : 5)) } catch { return }
            guard !Task.isCancelled else { return }
            next()
        }
    }

    private func next() {
        guard !finished else { return }
        if page < lastPage {
            withAnimation(still ? nil : .easeInOut(duration: 0.35)) { page += 1 }
        } else { dismiss() }
    }

    private func dismiss() {
        guard !finished else { return }
        finished = true
        finish()
    }
}

private struct NightPanel: View {
    let growth: FarmNightStory.Growth?
    let morning, still: Bool
    @State private var grown = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            let sky = morning ? Color(red: 0.98, green: 0.86, blue: 0.67) : Color(red: 0.22, green: 0.34, blue: 0.47)
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(sky)
                Image(systemName: morning ? "sun.max.fill" : "moon.stars.fill")
                    .font(.system(size: min(w, h)*0.21)).foregroundStyle(morning ? FarmPaper.clay : FarmPaper.cream)
                    .position(x: w*0.25, y: h*0.22)
                Ellipse().fill(morning ? Color(red: 0.68, green: 0.77, blue: 0.53) : Color(red: 0.30, green: 0.45, blue: 0.44))
                    .frame(width: w*1.4, height: h*0.64).position(x: w*0.52, y: h*1.01)
                if let growth {
                    let phase = morning ? growth.to : growth.from
                    if phase == .ripe {
                        FarmPictogram(id: growth.cropID)
                            .frame(width: min(w*0.71,h*0.78), height: min(w*0.71,h*0.78))
                            .scaleEffect(still || grown || !morning ? 1 : 0.56, anchor: .bottom)
                            .position(x: w*0.53, y: h*0.56)
                    } else {
                        let size = min(w*0.74, h*0.64)
                        let scale: Double = phase == .seeded ? 0.34 : (phase == .growing ? 1.0 : 0.66)
                        let delta = morning && phase == growth.from ? 1.12 : 1.0
                        SproutArt(seed: phase == .seeded, grown: phase == .growing)
                            .frame(width: size*scale*delta, height: size*scale*delta)
                            .scaleEffect(still || grown || !morning ? 1 : 0.56, anchor: .bottom)
                            .position(x: w*0.54, y: h*0.81-size*scale*delta*0.40)
                    }
                    Ellipse().fill(Color(red: 0.57, green: 0.37, blue: 0.24))
                        .frame(width: w*0.62, height: h*0.073).position(x: w*0.53, y: h*0.85)
                } else {
                    FarmPictogram(id: morning ? "loc.plaza" : "act.animal.bed")
                        .frame(width: min(w*0.80,h*0.70), height: min(w*0.80,h*0.70))
                        .position(x: w*0.54, y: h*0.61)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(morning ? "Am Morgen" : "Am Abend")
        .accessibilityValue(growth.map { storyLabel($0.cropID) + ", " + phaseLabel(morning ? $0.to : $0.from) }
                            ?? (morning ? "Der Hof wacht auf" : "Minka schläft"))
        .onAppear {
            guard morning, !still, growth != nil else { return }
            withAnimation(.easeOut(duration: 2.6)) { grown = true }
        }
    }

    private func phaseLabel(_ phase: FarmNightStory.Growth.Phase) -> String {
        switch phase {
        case .seeded: "Saatkorn"
        case .sprouting: "Keimling"
        case .growing: "Junge Pflanze"
        case .ripe: "Reif"
        }
    }
}

private struct SproutArt: View {
    let seed, grown: Bool

    var body: some View {
        Canvas { context, bounds in
            context.scaleBy(x: bounds.width/100, y: bounds.height/100)
            if seed {
                let kernel = Path(ellipseIn: CGRect(x: 25, y: 53, width: 51, height: 31))
                context.fill(kernel, with: .color(.orange))
                context.stroke(kernel, with: .color(FarmPaper.edge), lineWidth: 5)
                return
            }
            var stem = Path()
            stem.move(to: CGPoint(x: 50,y: 94)); stem.addQuadCurve(to: CGPoint(x: 54,y: 25),control: CGPoint(x: 44,y: 54))
            context.stroke(stem,with: .color(FarmPaper.pine),style: StrokeStyle(lineWidth: 7,lineCap: .round))
            func leaf(_ p: CGPoint, _ q: CGPoint, _ a: CGPoint, _ b: CGPoint) {
                var path = Path()
                path.move(to: p); path.addQuadCurve(to: q,control: a); path.addQuadCurve(to: p,control: b)
                context.fill(path,with: .color(Color(red: 0.62,green: 0.75,blue: 0.43)))
                context.stroke(path,with: .color(FarmPaper.pine),lineWidth: 4)
            }
            leaf(.init(x: 48,y: 60),.init(x: 12,y: 28),.init(x: 17,y: 64),.init(x: 45,y: 24))
            leaf(.init(x: 53,y: 43),.init(x: 88,y: 12),.init(x: 56,y: 13),.init(x: 86,y: 43))
            if grown { leaf(.init(x: 49,y: 75),.init(x: 83,y: 49),.init(x: 52,y: 48),.init(x: 80,y: 75)) }
        }.accessibilityHidden(true)
    }
}

@MainActor func storyLabel(_ id: String) -> String {
    FarmPictogram.entry(for: id)?.label ?? id
}

struct StoryControl: View {
    let symbol, label, id: String
    let action: () -> Void

    var body: some View {
        WorldButton(icon: symbol, label: label, id: id, size: 72, action: action)
    }
}
