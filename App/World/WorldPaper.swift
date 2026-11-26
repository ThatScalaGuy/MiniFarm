import SwiftUI

enum FarmPaper {
    static let cream = Color(red: 1, green: 0.964, blue: 0.867)
    static let edge = Color(red: 0.36, green: 0.30, blue: 0.22)
    static let pine = Color(red: 0.18, green: 0.32, blue: 0.27)
    static let clay = Color(red: 0.70, green: 0.37, blue: 0.25)
}

struct WorldButton: View {
    var icon: String
    var label: String
    var id: String
    var size: CGFloat
    var tone: Color = FarmPaper.cream
    var ink: Color = FarmPaper.pine
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(FarmPaper.edge.opacity(0.58)).offset(y: 3)
                Circle().fill(tone)
                Circle().strokeBorder(FarmPaper.edge.opacity(0.65), lineWidth: 1.5)
                Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1).padding(4)
                Image(systemName: icon).font(.system(size: size * 0.34, weight: .semibold, design: .rounded)).foregroundStyle(ink)
            }
            .padding(size * 0.105)
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(label).accessibilityIdentifier(id)
    }
}

struct FarmSky: View {
    var season: String
    var weather: String
    var evening: Bool

    var body: some View {
        Canvas { c, sz in
            let w = sz.width, h = sz.height
            let winter = season == "season.winter", fall = season == "season.autumn"
            let sky = evening || fall ? Color(red: 0.97, green: 0.85, blue: 0.71) :
                Color(red: winter ? 0.77 : 0.76, green: 0.87, blue: 0.9)
            let bottom = winter ? Color(red: 0.91, green: 0.94, blue: 0.93) :
                Color(red: 0.95, green: 0.93, blue: 0.8)
            c.fill(Path(CGRect(origin: .zero, size: sz)), with: .linearGradient(
                Gradient(colors: [sky, bottom]), startPoint: .zero, endPoint: CGPoint(x: w*0.2, y: h)))
            for (x, y, r) in [(0.13, 0.16, 0.055), (0.78, 0.10, 0.034), (0.92, 0.3, 0.054)] {
                let r = min(w, h) * r
                for i in 0..<3 {
                    let s = i == 1 ? 1.35 : 1
                    let rect = CGRect(x: x*w+CGFloat(i)*r*0.72, y: y*h-r*s, width: r*1.6, height: r*s)
                    c.fill(Path(ellipseIn: rect), with: .color(.white.opacity(weather == "cloud" ? 0.78 : 0.49)))
                }
            }
            for i in 0..<2 {
                let y = h * (i == 0 ? 0.65 : 0.76)
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addQuadCurve(to: CGPoint(x: w*0.5, y: y-h*0.03), control: CGPoint(x: w*0.18, y: y-h*0.12))
                p.addQuadCurve(to: CGPoint(x: w, y: y-h*0.04), control: CGPoint(x: w*0.8, y: y+h*0.09))
                p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath()
                c.fill(p, with: .color((winter ? Color.white : Color(red: 0.62, green: 0.73, blue: 0.59)).opacity(i == 0 ? 0.17 : 0.12)))
            }
        }.accessibilityHidden(true).ignoresSafeArea()
    }
}

struct WorldBook: View {
    let entries: [WorldSticker]
    let size: CGFloat
    let send: (FarmWorldIntent) -> Void
    let close: () -> Void
    @State private var page = 0
    @State private var selected: WorldSticker?
    private struct Chapter: Identifiable {
        let key: String
        let title: String
        let symbol: String
        var id: String { key }
    }
    private static let chapters = [
        Chapter(key: "plant", title: "Pflanzen", symbol: "leaf.fill"),
        Chapter(key: "animal", title: "Tiere", symbol: "pawprint.fill"),
        Chapter(key: "machine", title: "Maschinen", symbol: "steeringwheel"),
        Chapter(key: "npc", title: "Freunde", symbol: "person.2.fill"),
        Chapter(key: "season", title: "Jahreszeiten", symbol: "sun.max.fill"),
        Chapter(key: "discovery", title: "Entdeckungen", symbol: "magnifyingglass"),
    ]
    @State private var chapter: String?

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 460
            let available = Self.chapters.filter { category in entries.contains { $0.id.hasPrefix("hofbook." + category.key + ".") } }
            let key = chapter ?? available.first?.key
            let section = key.map { k in entries.filter { $0.id.hasPrefix("hofbook." + k + ".") } } ?? entries
            let n = compact ? 3 : 4
            let pages = max(1, (section.count+n-1)/n)
            let current = min(page, pages-1)
            let spread = Array(section.dropFirst(current*n).prefix(n))
            let card = min(compact ? 112 : 148, max(64, (geo.size.width-100)/CGFloat(compact ? 3 : 2)))
            ZStack {
                Color(red: 0.25, green: 0.35, blue: 0.28).opacity(0.94).ignoresSafeArea()
                VStack(spacing: 4) {
                    HStack {
                        WorldButton(icon: "arrow.uturn.backward", label: "Zurück zum Hof", id: "world.book.close", size: size, action: close)
                        Spacer()
                        ScrollView(.horizontal) {
                            HStack(spacing: 0) {
                                ForEach(available) { c in
                                    WorldButton(icon: c.symbol, label: c.title, id: "world.book.chapter." + c.key, size: 64,
                                                tone: c.key == key ? FarmPaper.pine : FarmPaper.cream,
                                                ink: c.key == key ? FarmPaper.cream : FarmPaper.pine) {
                                        chapter = c.key; page = 0; selected = nil
                                    }
                                }
                            }
                        }.scrollIndicators(.hidden)
                    }
                    Spacer(minLength: 0)
                    if spread.isEmpty {
                        Image(systemName: "leaf.fill").font(.system(size: card * 0.5)).foregroundStyle(FarmPaper.pine.opacity(0.25))
                            .accessibilityLabel("Hier wachsen deine Entdeckungen")
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(card), spacing: 12), count: compact ? min(3, spread.count) : 2), spacing: 14) {
                            ForEach(spread) { sticker in
                                Button {
                                    guard sticker.discovered else { return }
                                    selected = sticker
                                    send(.readSticker(sticker.id))
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 19).fill(sticker.discovered ? .white.opacity(0.73) : FarmPaper.edge.opacity(0.075))
                                        RoundedRectangle(cornerRadius: 19).strokeBorder(FarmPaper.edge.opacity(0.23), style: StrokeStyle(lineWidth: 1.6, dash: [4, 5]))
                                        Group {
                                            if sticker.id.hasPrefix("hofbook.discovery.") {
                                                Image(systemName: WorldFind.symbol(sticker.id))
                                                    .resizable().scaledToFit().foregroundStyle(FarmPaper.pine).padding(10)
                                            } else { FarmPictogram(id: sticker.modelID) }
                                        }
                                            .saturation(sticker.discovered ? 1 : 0)
                                            .brightness(sticker.discovered ? 0 : -0.85)
                                            .opacity(sticker.discovered ? 1 : 0.18)
                                            .padding(11)
                                        if selected?.id == sticker.id {
                                            Image(systemName: "speaker.wave.2.fill").foregroundStyle(FarmPaper.pine)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(7)
                                        }
                                    }.frame(width: card, height: card*0.84).contentShape(Rectangle())
                                }.buttonStyle(.plain).disabled(!sticker.discovered)
                                    .accessibilityLabel(sticker.discovered ? sticker.label : "Noch unentdeckt")
                                    .accessibilityIdentifier("world.sticker." + sticker.id)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    HStack {
                        if current > 0 {
                            WorldButton(icon: "chevron.left", label: "Vorige Buchseite", id: "world.book.previous", size: size) { page = current-1; selected = nil }
                        }
                        Spacer()
                        Image(systemName: "bookmark.fill").foregroundStyle(FarmPaper.clay)
                        Spacer()
                        if current+1 < pages {
                            WorldButton(icon: "chevron.right", label: "Nächste Buchseite", id: "world.book.next", size: size) { page = current+1; selected = nil }
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 3)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22).fill(FarmPaper.edge).offset(y: 6)
                        RoundedRectangle(cornerRadius: 22).fill(FarmPaper.cream)
                        Rectangle().fill(.linearGradient(colors: [.clear, FarmPaper.edge.opacity(0.14), .clear], startPoint: .leading, endPoint: .trailing)).frame(width: 18)
                    }
                }
                .padding(compact ? 8 : 20).frame(maxWidth: 760, maxHeight: 690)
            }
        }
        .accessibilityAddTraits(.isModal)
    }
}
