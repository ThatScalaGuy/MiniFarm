import SwiftUI

struct FarmFestivalAlbumView: View {
    let album: FarmFestivalAlbum
    let speak: (String) -> Void
    let close: () -> Void

    @State private var page = 0
    private var photo: FarmLife.Photo { album.photos[page] }
    private var words: String {
        let names = photo.subjects.map(storyLabel).joined(separator: ". ")
        return "\(album.title), am Hoftag \(photo.day). \(FestivalBackdrop(photo.backdrop).description) Mit dabei: \(names)."
    }

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width-28, (geo.size.height-100)*1.6, 690)
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                FestivalPrint(photo: photo).frame(width: width, height: width / 1.6)
                    .accessibilityElement(children: .ignore).accessibilityLabel(words)
                    .accessibilityIdentifier("ritual.photo.print")
                HStack(spacing: 6) {
                    if page > 0 {
                        StoryControl(symbol: "chevron.left", label: "Früheres Festfoto", id: "ritual.photo.previous") { page -= 1 }
                    }
                    StoryControl(symbol: "speaker.wave.2.fill", label: "Pelle liest das Foto vor", id: "ritual.photo.read") { speak(words) }
                    if page + 1 < album.photos.count {
                        StoryControl(symbol: "chevron.right", label: "Nächstes Festfoto", id: "ritual.photo.next") { page += 1 }
                    }
                    StoryControl(symbol: "book.pages.fill", label: "Zurück ins Hofbuch", id: "ritual.photo.close", action: close)
                }
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity,maxHeight: .infinity)
        }
        .background(Color(red: 0.26,green: 0.33,blue: 0.29).ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Festalbum")
        .accessibilityAddTraits(.isModal)
        .onAppear { speak(words) }
        .onChange(of: page) { _, _ in speak(words) }
    }
}

private enum FestivalBackdrop {
    case blossoms, iceStand, feastTable, lanternPath, farm

    init(_ id: String) {
        switch id {
        case "tree": self = .blossoms
        case "ice.stand": self = .iceStand
        case "feast.table": self = .feastTable
        case "lantern.path": self = .lanternPath
        default: self = .farm
        }
    }
    var description: String {
        switch self {
        case .blossoms: "Wir feiern mit einer Blütenkette am Hofbaum."
        case .iceStand: "Wir tanzen an Tildas Eisstand."
        case .feastTable: "Drei Lichter leuchten auf unserem Festtisch."
        case .lanternPath: "Über unserer Decke leuchten Stern- und Mondlaternen."
        case .farm: "Unser Fest auf dem Hof."
        }
    }
    var landscape: (sky: Color, grass: Color, emblem: String) {
        switch self {
        case .blossoms: (.init(red: 0.80,green: 0.91,blue: 0.91),.init(red: 0.69,green: 0.80,blue: 0.53),"loc.orchard")
        case .iceStand: (.init(red: 0.74,green: 0.87,blue: 0.90),.init(red: 0.62,green: 0.77,blue: 0.51),"loc.shop")
        case .feastTable: (.init(red: 0.98,green: 0.83,blue: 0.64),.init(red: 0.77,green: 0.71,blue: 0.48),"crop.pumpkin")
        case .lanternPath: (.init(red: 0.31,green: 0.40,blue: 0.53),.init(red: 0.83,green: 0.87,blue: 0.85),"act.nature.snowman")
        case .farm: (.init(red: 0.81,green: 0.89,blue: 0.88),.init(red: 0.68,green: 0.77,blue: 0.56),"loc.plaza")
        }
    }
}

private struct FestivalPrint: View {
    let photo: FarmLife.Photo
    private var backdrop: FestivalBackdrop { FestivalBackdrop(photo.backdrop) }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                backdrop.landscape.sky
                Ellipse().fill(backdrop.landscape.grass)
                    .frame(width: w*1.23,height: h*0.96).position(x: w*0.40,y: h*0.97)
                FarmPictogram(id: backdrop.landscape.emblem)
                    .frame(width: w*0.25, height: h*0.52).position(x: w*0.16,y: h*0.47)
                Garland(backdrop: backdrop).frame(width: w, height: h*0.28).position(x: w*0.5, y: h*0.13)
                let count = max(1, photo.subjects.count)
                let side = min(w*0.84/CGFloat(count), h*0.53)
                HStack(spacing: -side*0.06) {
                    ForEach(Array(photo.subjects.enumerated()), id: \.offset) { i, id in
                        FarmPictogram(id: id).frame(width: side,height: side)
                            .offset(y: i.isMultiple(of: 2) ? -h*0.024 : 0)
                    }
                }.position(x: w*0.53,y: h*0.65)
                foreground(width: w, height: h)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .padding(.bottom,8)
        .background(FarmPaper.cream,in: RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.22),radius: 4,y: 4)
    }

    @ViewBuilder private func foreground(width w: CGFloat, height h: CGFloat) -> some View {
        switch backdrop {
        case .blossoms:
            HStack(spacing: -4) {
                ForEach(0..<4) { i in
                    Image(systemName: "camera.macro")
                        .symbolRenderingMode(.palette).foregroundStyle(i.isMultiple(of: 2) ? .white : .yellow, FarmPaper.pine)
                        .font(.system(size: h*0.08))
                        .offset(y: i == 1 || i == 2 ? h*0.015 : 0)
                }
            }.position(x: w*(photo.subjects.count == 3 ? 0.31 : 0.38),y: h*0.78)
        case .iceStand:
            FarmPictogram(id: "item.icecream").frame(width: h*0.24,height: h*0.24)
                .position(x: w*0.83,y: h*0.80)
        case .feastTable:
            RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.59,green: 0.38,blue: 0.24))
                .frame(width: w*0.72,height: h*0.09).position(x: w*0.54,y: h*0.86)
            ForEach(0..<3) { i in
                FarmPictogram(id: "act.nature.lantern").frame(width: h*0.18,height: h*0.18)
                    .position(x: w*(0.37+Double(i)*0.18),y: h*0.75)
            }
        case .lanternPath:
            Capsule().fill(Color(red: 0.52,green: 0.65,blue: 0.67))
                .frame(width: w*0.72,height: h*0.12).position(x: w*0.52,y: h*0.84)
        case .farm: EmptyView()
        }
    }
}

private struct Garland: View {
    let backdrop: FestivalBackdrop

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            Path { p in
                p.move(to: .zero)
                p.addQuadCurve(to: CGPoint(x: w,y: 0),control: CGPoint(x: w/2,y: h*1.13))
            }.stroke(FarmPaper.edge,lineWidth: 2)
            ForEach(0..<6) { i in
                let t = (CGFloat(i)+0.5)/6
                let y = h*(2*t*(1-t)*1.13+0.13)
                if backdrop == .lanternPath {
                    Image(systemName: i.isMultiple(of: 2) ? "star.fill" : "moon.fill")
                        .foregroundStyle(.yellow).font(.system(size: h*0.31)).position(x: t*w,y: y)
                } else {
                    Path { p in
                        p.move(to: CGPoint(x: t*w-w*0.027, y: y-h*0.16))
                        p.addLine(to: CGPoint(x: t*w+w*0.024, y: y-h*0.13))
                        p.addLine(to: CGPoint(x: t*w,y: y+h*0.16)); p.closeSubpath()
                    }.fill(i.isMultiple(of: 2) ? FarmPaper.clay : FarmPaper.cream)
                }
            }
        }.accessibilityHidden(true)
    }
}
