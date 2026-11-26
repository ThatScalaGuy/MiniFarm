import SwiftUI

struct FarmLevelParcelView: View {
    let parcel: FarmLevelParcel
    let reduceMotion: Bool
    let speak: (String) -> Void
    let close: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemStill
    @State private var opened = false
    private var words: String {
        opened ? "Schau, das gibt es jetzt auf deinem Hof: " + parcel.gifts.map(storyLabel).joined(separator: ". ") + "."
        : "Dein Hof ist gewachsen! Lale bringt dir ein Paket. Tipp auf die Schleife oder zieh an ihr."
    }

    var body: some View {
        GeometryReader { g in
            let w = min(g.size.width-28, 640)
            let h = min(g.size.height-105, w*0.72, 360)
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                ZStack {
                    ParcelLane()
                    FarmPictogram(id: "npc.lale")
                        .frame(width: h*0.64, height: h*0.64)
                        .position(x: w*0.25, y: h*0.56)
                        .accessibilityHidden(true)
                    if opened {
                        HStack(spacing: 2) {
                            ForEach(parcel.gifts, id: \.self) { gift in
                                let side = min(h*0.43, w*0.16)
                                FarmPictogram(id: gift).frame(width: side, height: side)
                                    .background(FarmPaper.cream, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }.position(x: w*0.69, y: h*0.54)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("ritual.parcel.contents")
                    } else {
                        Button(action: open) {
                            ParcelDrawing().padding(4)
                                .frame(width: min(w*0.48,h*0.96), height: min(w*0.48,h*0.96))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(DragGesture(minimumDistance: 12).onEnded { _ in open() })
                        .accessibilityLabel("Lales Paket öffnen").accessibilityHint("Tippe oder zieh an der Schleife.")
                        .accessibilityIdentifier("ritual.parcel.open")
                        .position(x: w*0.68, y: h*0.54)
                    }
                }
                .frame(width: w, height: h)
                .clipShape(RoundedRectangle(cornerRadius: 23))
                .overlay { RoundedRectangle(cornerRadius: 23).strokeBorder(FarmPaper.cream, lineWidth: 5) }
                HStack(spacing: 16) {
                    StoryControl(symbol: "speaker.wave.2.fill", label: "Pelle liest vor", id: "ritual.parcel.read") { speak(words) }
                    StoryControl(symbol: "house.fill", label: "Zurück zum Hof", id: "ritual.parcel.close", action: close)
                }
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(FarmPaper.pine.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Hofpaket")
        .accessibilityAddTraits(.isModal)
        .onAppear { speak(words) }
    }

    private func open() {
        guard !opened else { return }
        withAnimation((reduceMotion || systemStill) ? nil : .easeInOut(duration: 0.35)) { opened = true }
        speak(words)
    }
}

private struct ParcelLane: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Color(red: 0.79, green: 0.90, blue: 0.88)
                Ellipse().fill(Color(red: 0.66,green: 0.78,blue: 0.57))
                    .frame(width: w*1.45,height: h*0.99).position(x: w*0.39,y: h*1.04)
                FarmPictogram(id: "loc.plaza").opacity(0.76)
                    .frame(width: h*0.44,height: h*0.44).position(x: w*0.12,y: h*0.39)
                Ellipse().fill(Color(red: 0.89,green: 0.76,blue: 0.57))
                    .frame(width: w*0.82,height: h*0.25).position(x: w*0.5,y: h*0.86)
            }
        }.accessibilityHidden(true)
    }
}

private struct ParcelDrawing: View {
    var body: some View {
        Canvas { c, size in
            c.scaleBy(x: size.width/100, y: size.height/100)
            let edge = FarmPaper.edge
            func shape(_ points: [CGPoint], _ color: Color) {
                var p = Path()
                p.addLines(points); p.closeSubpath()
                c.fill(p,with: .color(color))
                c.stroke(p,with: .color(edge),style: StrokeStyle(lineWidth: 2,lineJoin: .round))
            }
            shape([.init(x: 11,y: 41),.init(x: 49,y: 31),.init(x: 89,y: 42),.init(x: 89,y: 75),
                   .init(x: 51,y: 89),.init(x: 11,y: 76)],Color(red: 0.86,green: 0.63,blue: 0.39))
            shape([.init(x: 9,y: 37),.init(x: 47,y: 26),.init(x: 91,y: 37),.init(x: 50,y: 51)],
                  Color(red: 0.97,green: 0.79,blue: 0.54))
            shape([.init(x: 9,y: 37),.init(x: 50,y: 51),.init(x: 91,y: 37),.init(x: 91,y: 44),
                   .init(x: 50,y: 59),.init(x: 9,y: 45)],Color(red: 0.91,green: 0.69,blue: 0.46))
            let ribbon = Color(red: 0.28,green: 0.57,blue: 0.54)
            shape([.init(x: 45,y: 37),.init(x: 53,y: 35),.init(x: 74,y: 42),.init(x: 74,y: 81),
                   .init(x: 65,y: 84),.init(x: 65,y: 45)],ribbon)
            shape([.init(x: 46,y: 35),.init(x: 54,y: 38),.init(x: 34,y: 45),.init(x: 34,y: 84),
                   .init(x: 25,y: 81),.init(x: 25,y: 43)],ribbon)
            var bow = Path()
            bow.move(to: CGPoint(x: 49,y: 35))
            bow.addQuadCurve(to: CGPoint(x: 26,y: 18),control: CGPoint(x: 25,y: 34))
            bow.addQuadCurve(to: CGPoint(x: 49,y: 33),control: CGPoint(x: 29,y: 4))
            bow.addQuadCurve(to: CGPoint(x: 69,y: 16),control: CGPoint(x: 63,y: 2))
            bow.addQuadCurve(to: CGPoint(x: 49,y: 35),control: CGPoint(x: 76,y: 31))
            c.stroke(bow,with: .color(edge),style: StrokeStyle(lineWidth: 6,lineCap: .round,lineJoin: .round))
            c.stroke(bow,with: .color(ribbon),style: StrokeStyle(lineWidth: 3.4,lineCap: .round,lineJoin: .round))
        }.accessibilityHidden(true)
    }
}
