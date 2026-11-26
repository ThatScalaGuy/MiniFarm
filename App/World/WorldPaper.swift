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

/// How the projected day looks (Doc 08 §§4–5). Reads only the rolled weather, the season and
/// the action-driven sun arc; it never changes play. `particleScale` already folds in the
/// parent calm modes and Reduce Motion, and is 0 for "Sehr ruhig" (Doc 18 §4).
struct FarmSkyLook: Equatable {
    enum Phase: Equatable { case morning, forenoon, noon, afternoon, evening }
    enum Fall: Equatable { case none, rain, snow, leaves }

    let season: String
    let weather: String
    let sun: Double
    let phase: Phase
    let fall: Fall
    /// Drops, flakes or leaves in front of the farm.
    let particles: Int
    let clouds: Int
    let sunVisibility: Double
    let fog: Double
    let rainbow: Bool
    let snow: Double

    init(season: String, weather: String, sunProgress: Double, particleScale: Double = 1) {
        self.season = season
        self.weather = weather
        sun = sunProgress.isFinite ? min(1, max(0, sunProgress)) : 0
        phase = switch sun {
        case ..<0.2: .morning
        case ..<0.42: .forenoon
        case ..<0.58: .noon
        case ..<0.72: .afternoon
        default: .evening
        }
        fall = switch weather {
        case "rain": .rain
        case "snow": .snow
        case "wind": .leaves
        default: .none
        }
        let scale = particleScale.isFinite ? min(1, max(0, particleScale)) : 0
        let full = switch fall { case .rain: 54; case .snow: 42; case .leaves: 12; case .none: 0 }
        particles = Int((Double(full) * scale).rounded())
        clouds = ["cloud": 6, "rain": 7, "snow": 6, "rainbow": 3, "wind": 4][weather] ?? 2
        sunVisibility = ["cloud": 0.45, "rain": 0, "snow": 0.2, "fog": 0.4][weather] ?? 1
        fog = weather == "fog" ? 0.5 - 0.2 * min(1, sun / 0.6) : 0
        rainbow = weather == "rainbow"
        snow = weather == "snow" ? 1 : (season == "season.winter" ? 0.4 : 0)
    }

    /// Only falling weather moves, and only while the farm is live and motion is allowed.
    func animates(moving: Bool) -> Bool { moving && particles > 0 }
}

/// Painted sky behind the 3D farm. A new sun position glides only while motion is allowed.
struct FarmSky: View {
    var season: String
    var weather: String
    var sunProgress: Double
    var moving = false

    var body: some View {
        FarmSkyPainting(season: season, weather: weather, sun: sunProgress)
            .animation(moving ? .easeInOut(duration: 2.4) : nil, value: sunProgress)
            .accessibilityHidden(true).ignoresSafeArea()
    }
}

/// Weather in front of the 3D farm. It never takes touches, and draws one still frame unless
/// rain, snow or autumn leaves are falling during live play.
struct FarmWeather: View {
    var season: String
    var weather: String
    var sunProgress: Double
    var particleScale: Double
    var moving: Bool

    var body: some View {
        let look = FarmSkyLook(season: season, weather: weather, sunProgress: sunProgress, particleScale: particleScale)
        Group {
            if look.animates(moving: moving) {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
                    Canvas { c, size in FarmSkyArt.weather(look, in: &c, size: size, time: t) }
                }
            } else if look.particles > 0 || look.fog > 0 {
                Canvas { c, size in FarmSkyArt.weather(look, in: &c, size: size, time: 0) }
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true).ignoresSafeArea()
    }
}

private struct FarmSkyPainting: View, Animatable {
    var season: String
    var weather: String
    var sun: Double

    nonisolated var animatableData: Double {
        get { sun }
        set { sun = newValue }
    }

    var body: some View {
        let look = FarmSkyLook(season: season, weather: weather, sunProgress: sun, particleScale: 0)
        Canvas { c, size in FarmSkyArt.backdrop(look, in: &c, size: size) }
    }
}

private struct SkyRGB {
    var r, g, b: Double
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    func mix(_ o: SkyRGB, _ t: Double) -> SkyRGB {
        let t = min(1, max(0, t))
        return SkyRGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t)
    }
    var color: Color { Color(red: r, green: g, blue: b) }
    func opacity(_ a: Double) -> Color { color.opacity(a) }
}

private enum FarmSkyArt {
    /// Sky by sun arc: rose-gold morning, clear midday, warm afternoon, orange to violet evening.
    private static let day: [(Double, SkyRGB, SkyRGB)] = [
        (0.0, SkyRGB(0.78, 0.85, 0.94), SkyRGB(0.99, 0.85, 0.80)),
        (0.22, SkyRGB(0.67, 0.84, 0.94), SkyRGB(0.95, 0.95, 0.88)),
        (0.5, SkyRGB(0.60, 0.81, 0.94), SkyRGB(0.93, 0.96, 0.91)),
        (0.66, SkyRGB(0.68, 0.82, 0.92), SkyRGB(0.99, 0.91, 0.74)),
        (0.82, SkyRGB(0.71, 0.67, 0.85), SkyRGB(0.99, 0.79, 0.58)),
        (1.0, SkyRGB(0.58, 0.55, 0.79), SkyRGB(0.98, 0.72, 0.60)),
    ]
    private static let mood: [String: (SkyRGB, SkyRGB, Double)] = [
        "cloud": (SkyRGB(0.80, 0.84, 0.88), SkyRGB(0.92, 0.92, 0.89), 0.35),
        "rain": (SkyRGB(0.66, 0.73, 0.80), SkyRGB(0.84, 0.87, 0.88), 0.6),
        "snow": (SkyRGB(0.82, 0.86, 0.91), SkyRGB(0.95, 0.96, 0.97), 0.6),
        "fog": (SkyRGB(0.84, 0.87, 0.89), SkyRGB(0.93, 0.94, 0.95), 0.85),
        "wind": (SkyRGB(0.72, 0.83, 0.90), SkyRGB(0.98, 0.89, 0.72), 0.25),
        "rainbow": (SkyRGB(0.58, 0.80, 0.95), SkyRGB(0.95, 0.97, 0.93), 0.25),
    ]
    private static let rainbow = [SkyRGB(0.93, 0.55, 0.50), SkyRGB(0.96, 0.72, 0.47), SkyRGB(0.97, 0.89, 0.55),
                                  SkyRGB(0.62, 0.82, 0.58), SkyRGB(0.55, 0.73, 0.88), SkyRGB(0.66, 0.60, 0.82)]
    private static let leaves = [SkyRGB(0.86, 0.47, 0.22), SkyRGB(0.93, 0.68, 0.27), SkyRGB(0.74, 0.35, 0.21), SkyRGB(0.81, 0.60, 0.30)]
    private static let ink = SkyRGB(0.36, 0.30, 0.22)
    private static let mist = SkyRGB(0.97, 0.96, 0.93)
    private static let cloudSpots: [(Double, Double, Double)] = [
        (0.13, 0.16, 0.055), (0.78, 0.10, 0.04), (0.92, 0.30, 0.054), (0.42, 0.06, 0.045),
        (0.60, 0.21, 0.04), (0.02, 0.34, 0.045), (0.30, 0.28, 0.036),
    ]

    static func colors(_ look: FarmSkyLook) -> (top: SkyRGB, horizon: SkyRGB) {
        let upper = day.firstIndex { $0.0 >= look.sun } ?? day.count - 1
        let a = day[max(0, upper - 1)], b = day[upper]
        let t = b.0 > a.0 ? (look.sun - a.0) / (b.0 - a.0) : 0
        var top = a.1.mix(b.1, t), horizon = a.2.mix(b.2, t)
        if let tint = mood[look.weather] {
            top = top.mix(tint.0, tint.2)
            horizon = horizon.mix(tint.1, tint.2)
        }
        if look.season == "season.autumn" { horizon = horizon.mix(SkyRGB(0.98, 0.88, 0.70), 0.25) }
        if look.season == "season.winter" { top = top.mix(SkyRGB(0.80, 0.88, 0.94), 0.3) }
        return (top, horizon)
    }

    static func sunPoint(_ look: FarmSkyLook, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * (0.08 + 0.84 * look.sun), y: size.height * (0.36 - 0.21 * sin(.pi * look.sun)))
    }

    static func backdrop(_ look: FarmSkyLook, in c: inout GraphicsContext, size sz: CGSize) {
        let w = sz.width, h = sz.height, m = min(w, h)
        let sky = colors(look)
        let dusk = min(1, max(0, (look.sun - 0.66) / 0.2))
        c.fill(Path(CGRect(origin: .zero, size: sz)), with: .linearGradient(
            Gradient(colors: [sky.top.color, sky.horizon.color]),
            startPoint: CGPoint(x: w * 0.35, y: 0), endPoint: CGPoint(x: w * 0.5, y: h * 0.75)))

        if look.sun >= 0.88, look.sunVisibility > 0.3 {
            let a = min(1, (look.sun - 0.88) / 0.1) * 0.8
            for (x, y) in [(0.22, 0.07), (0.66, 0.05), (0.88, 0.15)] {
                c.fill(sparkle(CGPoint(x: x * w, y: y * h), m * 0.013), with: .color(Color(red: 1, green: 0.97, blue: 0.85).opacity(a)))
            }
        }

        if look.sunVisibility > 0 {
            let p = sunPoint(look, in: sz), r = m * 0.05
            let tone = SkyRGB(0.99, 0.84, 0.60).mix(SkyRGB(0.99, 0.89, 0.52), look.sun * 2).mix(SkyRGB(0.98, 0.62, 0.40), dusk)
            let v = look.sunVisibility
            c.fill(Path(ellipseIn: CGRect(x: p.x - r * 2.4, y: p.y - r * 2.4, width: r * 4.8, height: r * 4.8)),
                   with: .radialGradient(Gradient(colors: [tone.opacity(0.42 * v), tone.opacity(0)]),
                                         center: p, startRadius: r * 0.8, endRadius: r * 2.4))
            let disc = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            c.fill(disc, with: .color(tone.opacity(v)))
            c.stroke(disc, with: .color(SkyRGB(0.93, 0.62, 0.36).opacity(0.45 * v)), lineWidth: max(1, m * 0.003))
        }

        if look.rainbow {
            let r = max(m * 0.6, w * 0.36), band = r * 0.04
            let center = CGPoint(x: w * 0.5, y: h * 0.17 + r)
            for (i, tone) in rainbow.enumerated() {
                var arc = Path()
                arc.addArc(center: center, radius: r - band * (CGFloat(i) + 0.5),
                           startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                c.stroke(arc, with: .color(tone.opacity(0.72)), lineWidth: band + 0.5)
            }
        }

        if look.fog > 0 {
            c.fill(Path(CGRect(x: 0, y: h * 0.3, width: w, height: h * 0.7)), with: .linearGradient(
                Gradient(colors: [mist.opacity(0), mist.opacity(min(0.8, look.fog * 1.4))]),
                startPoint: CGPoint(x: 0, y: h * 0.3), endPoint: CGPoint(x: 0, y: h * 0.72)))
            // Soft horizontal mist bands, the same picture as the fog symbol in the day badge.
            var bands = Path()
            for (x, y, length) in [(0.06, 0.16, 0.34), (0.52, 0.11, 0.3), (0.26, 0.24, 0.44), (0.64, 0.3, 0.32), (-0.04, 0.37, 0.3)] {
                bands.move(to: CGPoint(x: x * w, y: y * h))
                bands.addLine(to: CGPoint(x: (x + length) * w, y: y * h))
            }
            c.drawLayer { layer in
                layer.addFilter(.blur(radius: m * 0.008))
                layer.stroke(bands, with: .color(.white.opacity(min(0.9, look.fog * 1.8))),
                             style: StrokeStyle(lineWidth: m * 0.028, lineCap: .round))
            }
        }

        let grey: SkyRGB = switch look.fall {
        case .rain: SkyRGB(0.76, 0.80, 0.86)
        case .snow: SkyRGB(0.88, 0.90, 0.94)
        default: look.weather == "cloud" ? SkyRGB(0.97, 0.97, 0.98) : SkyRGB(1, 1, 1)
        }
        let puff = grey.mix(SkyRGB(1, 0.85, 0.78), dusk * (look.fall == .none ? 0.45 : 0.2))
        let alpha = ["cloud": 0.88, "rain": 0.94, "snow": 0.92, "fog": 0.35][look.weather] ?? 0.6
        let stretch: CGFloat = look.weather == "wind" ? 1.6 : 1
        for (x, y, s) in cloudSpots.prefix(look.clouds) {
            let r = m * s * (look.fall == .rain || look.fall == .snow ? 1.25 : 1)
            let base = CGPoint(x: x * w, y: y * h)
            let middle = base.x + r * 1.52 * stretch
            if look.fall == .rain {
                var shafts = Path()
                for j in 0..<5 {
                    let start = CGPoint(x: middle - r * 1.1 + CGFloat(j) * r * 0.55, y: base.y + r * 0.1)
                    shafts.move(to: start)
                    shafts.addLine(to: CGPoint(x: start.x + h * 0.022, y: start.y + h * 0.11))
                }
                c.stroke(shafts, with: .color(SkyRGB(0.50, 0.64, 0.78).opacity(0.5)),
                         style: StrokeStyle(lineWidth: max(1.5, m * 0.004), lineCap: .round, dash: [m * 0.014, m * 0.018]))
            } else if look.fall == .snow {
                var flakes = Path()
                for j in 0..<7 {
                    let q = CGPoint(x: middle - r * 1.2 + CGFloat(j) * r * 0.4, y: base.y + r * (0.45 + 0.55 * CGFloat(j % 2) + 0.3 * CGFloat(j % 3)))
                    let d = max(2.2, m * 0.006)
                    flakes.addEllipse(in: CGRect(x: q.x - d, y: q.y - d, width: d * 2, height: d * 2))
                }
                c.fill(flakes, with: .color(.white.opacity(0.95)))
                c.stroke(flakes, with: .color(SkyRGB(0.56, 0.65, 0.77).opacity(0.55)), lineWidth: 0.8)
            }
            var shape = Path()
            for i in 0..<3 {
                let lift = i == 1 ? 1.35 : 1
                shape.addEllipse(in: CGRect(x: base.x + CGFloat(i) * r * 0.72 * stretch, y: base.y - r * lift,
                                            width: r * 1.6 * stretch, height: r * lift))
            }
            shape.addEllipse(in: CGRect(x: base.x + r * 0.2, y: base.y - r * 0.55, width: r * 2.7 * stretch, height: r * 0.7))
            c.fill(shape, with: .color(puff.opacity(alpha)))
            if look.fall != .none {
                c.fill(Path(ellipseIn: CGRect(x: base.x + r * 0.85 * stretch, y: base.y - r * 1.28, width: r * 1.1, height: r * 0.5)),
                       with: .color(.white.opacity(0.38)))
            }
        }

        if look.weather == "wind" {
            var gusts = Path()
            for (x, y, length) in [(0.05, 0.22, 0.22), (0.58, 0.15, 0.2), (0.70, 0.45, 0.24)] {
                let a = CGPoint(x: x * w, y: y * h), e = CGPoint(x: a.x + length * w, y: a.y - m * 0.01)
                gusts.move(to: a)
                gusts.addCurve(to: e, control1: CGPoint(x: a.x + length * w * 0.35, y: a.y - m * 0.03),
                               control2: CGPoint(x: a.x + length * w * 0.7, y: a.y + m * 0.02))
                gusts.addQuadCurve(to: CGPoint(x: e.x - m * 0.002, y: e.y - m * 0.034), control: CGPoint(x: e.x + m * 0.032, y: e.y - m * 0.012))
                gusts.addQuadCurve(to: CGPoint(x: e.x - m * 0.014, y: e.y - m * 0.016), control: CGPoint(x: e.x - m * 0.022, y: e.y - m * 0.036))
            }
            c.stroke(gusts, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: max(2, m * 0.006), lineCap: .round, lineJoin: .round))
        }

        let ground: SkyRGB = switch look.season {
        case "season.autumn": SkyRGB(0.78, 0.64, 0.42)
        case "season.winter": SkyRGB(0.97, 0.98, 1)
        default: SkyRGB(0.62, 0.73, 0.59)
        }
        let hill = ground.mix(SkyRGB(0.97, 0.98, 1), look.snow)
        for i in 0..<2 {
            let y = h * (i == 0 ? 0.65 : 0.76)
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y))
            p.addQuadCurve(to: CGPoint(x: w * 0.5, y: y - h * 0.03), control: CGPoint(x: w * 0.18, y: y - h * 0.12))
            p.addQuadCurve(to: CGPoint(x: w, y: y - h * 0.04), control: CGPoint(x: w * 0.8, y: y + h * 0.09))
            p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath()
            c.fill(p, with: .color(hill.opacity((i == 0 ? 0.17 : 0.12) + look.snow * (i == 0 ? 0.33 : 0.3))))
        }
    }

    static func weather(_ look: FarmSkyLook, in c: inout GraphicsContext, size sz: CGSize, time t: Double) {
        let w = sz.width, h = sz.height, m = min(w, h), n = look.particles
        let s = min(1.8, max(1, m / 420))
        if look.fog > 0 {
            c.drawLayer { veil in
                veil.addFilter(.blur(radius: m * 0.04))
                for (y, k) in [(0.42, 0.5), (0.66, 0.75), (0.86, 0.9)] {
                    veil.fill(Path(ellipseIn: CGRect(x: -0.2 * w, y: (y - 0.07) * h, width: 1.4 * w, height: 0.14 * h)),
                              with: .color(mist.opacity(look.fog * k)))
                }
            }
        }
        guard n > 0, w > 0, h > 0 else { return }
        switch look.fall {
        case .rain:
            var streaks = Path()
            for i in 0..<n {
                let length = max(10, h * 0.026) * (0.8 + 0.4 * unit(i, 2))
                let span = h + length
                let y = (unit(i, 4) * span + t * h * (0.42 + 0.14 * unit(i, 3))).truncatingRemainder(dividingBy: span) - length
                let x = (w * (Double(i) + 0.15 + 0.7 * unit(i, 1)) / Double(n) + y * 0.16).truncatingRemainder(dividingBy: w)
                streaks.move(to: CGPoint(x: x, y: y))
                streaks.addLine(to: CGPoint(x: x + length * 0.16, y: y + length))
            }
            c.stroke(streaks, with: .color(SkyRGB(0.40, 0.57, 0.74).opacity(0.5)),
                     style: StrokeStyle(lineWidth: max(1.4, m * 0.0035), lineCap: .round))
        case .snow:
            var flakes = Path()
            for i in 0..<n {
                let r = (2.0 + 2.6 * unit(i, 2)) * s
                let span = h + r * 2
                let y = (unit(i, 4) * span + t * h * (0.045 + 0.035 * unit(i, 3))).truncatingRemainder(dividingBy: span) - r
                let x = w * (Double(i) + 0.15 + 0.7 * unit(i, 1)) / Double(n)
                    + sin(t * (0.45 + 0.3 * unit(i, 3)) + 6.283 * unit(i, 2)) * 12 * s
                flakes.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            c.fill(flakes, with: .color(.white.opacity(0.95)))
            c.stroke(flakes, with: .color(SkyRGB(0.56, 0.65, 0.77).opacity(0.55)), lineWidth: 0.8 * s)
        case .leaves:
            for i in 0..<n {
                let size = (9 + 6 * unit(i, 2)) * s
                let span = w + size * 4
                let x = (unit(i, 1) * span + t * w * (0.06 + 0.04 * unit(i, 3))).truncatingRemainder(dividingBy: span) - size * 2
                let y = h * (0.12 + 0.76 * (Double(i) + 0.5) / Double(n)) + sin(t * 0.8 + 6.283 * unit(i, 3)) * h * 0.025
                var leaf = c
                leaf.translateBy(x: x, y: y)
                leaf.rotate(by: .radians(6.283 * unit(i, 4) + sin(t * 1.1 + 6.283 * unit(i, 1)) * 0.6))
                var blade = Path()
                blade.move(to: CGPoint(x: -size, y: 0))
                blade.addQuadCurve(to: CGPoint(x: size, y: 0), control: CGPoint(x: 0, y: -size * 0.75))
                blade.addQuadCurve(to: CGPoint(x: -size, y: 0), control: CGPoint(x: 0, y: size * 0.75))
                var rib = Path()
                rib.move(to: CGPoint(x: -size * 1.25, y: 0))
                rib.addLine(to: CGPoint(x: size * 0.7, y: 0))
                leaf.fill(blade, with: .color(leaves[i % leaves.count].color))
                leaf.stroke(blade, with: .color(ink.opacity(0.55)), lineWidth: 1)
                leaf.stroke(rib, with: .color(ink.opacity(0.45)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
            }
        case .none:
            break
        }
    }

    private static func sparkle(_ p: CGPoint, _ r: CGFloat) -> Path {
        var star = Path()
        star.move(to: CGPoint(x: p.x, y: p.y - r))
        star.addQuadCurve(to: CGPoint(x: p.x + r, y: p.y), control: CGPoint(x: p.x + r * 0.2, y: p.y - r * 0.2))
        star.addQuadCurve(to: CGPoint(x: p.x, y: p.y + r), control: CGPoint(x: p.x + r * 0.2, y: p.y + r * 0.2))
        star.addQuadCurve(to: CGPoint(x: p.x - r, y: p.y), control: CGPoint(x: p.x - r * 0.2, y: p.y + r * 0.2))
        star.addQuadCurve(to: CGPoint(x: p.x, y: p.y - r), control: CGPoint(x: p.x - r * 0.2, y: p.y - r * 0.2))
        return star
    }

    /// Stable per-particle numbers in 0..<1, so a still frame is the same every time.
    private static func unit(_ i: Int, _ salt: Int) -> Double {
        var x = UInt64(truncatingIfNeeded: i &* 0x9E37_79B1 &+ salt &* 0x85EB_CA77)
        x ^= x >> 33; x &*= 0xFF51_AFD7_ED55_8CCD; x ^= x >> 33; x &*= 0xC4CE_B9FE_1A85_EC53; x ^= x >> 33
        return Double(x % 10_000) / 10_000
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
