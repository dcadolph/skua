import SwiftUI

// HeroScene is a vivid, instantly readable weather world behind the hero: a
// condition-driven sky, a real sun or moon, soft clouds, rolling hills, and the
// skua perched on the crest. Bright and clear, so a glance reads the weather.
struct HeroScene: View {
    // scene classifies the sky.
    let scene: SkyScene
    // dayFraction is the sun's progress from sunrise (0) to sunset (1); outside
    // that range it is night.
    let dayFraction: Double

    var body: some View {
        ZStack {
            LinearGradient(colors: skyColors, startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    if isNight { drawStars(&ctx, size, t) }
                    drawCelestial(&ctx, size)
                    drawClouds(&ctx, size, t)
                    if scene == .rain || scene == .storm { drawRain(&ctx, size, t) }
                    if scene == .snow { drawSnow(&ctx, size, t) }
                    drawHills(&ctx, size)
                }
            }
            // A soft top scrim keeps white hero text legible on bright skies.
            LinearGradient(
                colors: [Color.black.opacity(0.26), .clear],
                startPoint: .top, endPoint: .center)
            // A soft bottom scrim keeps the voice line legible over the hills, no
            // matter where the traveling sun sits.
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.34)],
                startPoint: .center, endPoint: .bottom)
            // A gentle vignette frames the scene without dimming the day.
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.18)],
                center: .center, startRadius: 130, endRadius: 360)
        }
        .drawingGroup()
    }

    // isNight reports whether the sun is down.
    private var isNight: Bool { dayFraction < 0 || dayFraction > 1 }

    // goldenHour warms clear skies near sunrise and sunset.
    private var goldenHour: Bool {
        scene == .clearDay && ((dayFraction > -0.02 && dayFraction < 0.16) || (dayFraction > 0.84 && dayFraction < 1.02))
    }

    // skyColors is the vivid gradient for the current sky, warming at the edges
    // of the day.
    private var skyColors: [Color] {
        if goldenHour {
            return [Color(red: 0.55, green: 0.22, blue: 0.22), Color(red: 0.92, green: 0.55, blue: 0.3)]
        }
        switch scene {
        case .clearDay:
            // Bright, saturated daytime blue: rich but unmistakably daylight.
            return [Color(red: 0.13, green: 0.44, blue: 0.82), Color(red: 0.36, green: 0.64, blue: 0.92)]
        case .clearNight:
            return [Color(red: 0.012, green: 0.02, blue: 0.09), Color(red: 0.05, green: 0.08, blue: 0.2)]
        case .cloudyDay:
            return [Color(red: 0.32, green: 0.42, blue: 0.56), Color(red: 0.52, green: 0.62, blue: 0.74)]
        case .cloudyNight:
            return [Color(red: 0.03, green: 0.04, blue: 0.09), Color(red: 0.09, green: 0.11, blue: 0.2)]
        case .rain:
            return [Color(red: 0.14, green: 0.2, blue: 0.32), Color(red: 0.26, green: 0.35, blue: 0.5)]
        case .storm:
            return [Color(red: 0.1, green: 0.09, blue: 0.2), Color(red: 0.22, green: 0.19, blue: 0.36)]
        case .snow:
            return [Color(red: 0.34, green: 0.44, blue: 0.56), Color(red: 0.54, green: 0.64, blue: 0.76)]
        }
    }

    // drawCelestial paints a rayed sun by day or a crescent moon by night.
    private func drawCelestial(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let f = isNight ? 0.5 : min(1, max(0, dayFraction))
        // Travel a lower-middle arc so the sun or moon clears the temperature
        // readout at the top-left and the conditions at the top-right.
        let x = size.width * (0.30 + f * 0.40)
        let y = size.height * (0.54 - sin(f * .pi) * 0.12)

        if isNight {
            let r: CGFloat = 22
            // Glow.
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r * 2.4, y: y - r * 2.4, width: r * 4.8, height: r * 4.8)),
                with: .radialGradient(
                    Gradient(colors: [Color.white.opacity(0.18), .clear]),
                    center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 2.4))
            // Full pale disc, then a shadow disc offset to carve a crescent.
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                with: .color(Color(red: 0.92, green: 0.93, blue: 0.98)))
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r + 9, y: y - r - 3, width: 2 * r, height: 2 * r)),
                with: .color(skyColors[0]))
        } else {
            let r: CGFloat = 28
            let sun = goldenHour ? Color(red: 1.0, green: 0.85, blue: 0.5) : Color(red: 1.0, green: 0.86, blue: 0.35)
            // Warm glow.
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)),
                with: .radialGradient(
                    Gradient(colors: [sun.opacity(0.5), .clear]),
                    center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 3))
            // Rays.
            for i in 0..<12 {
                let a = Double(i) / 12 * 2 * .pi
                let inner = r * 1.35
                let outer = r * 1.85
                var ray = Path()
                ray.move(to: CGPoint(x: x + cos(a) * inner, y: y + sin(a) * inner))
                ray.addLine(to: CGPoint(x: x + cos(a) * outer, y: y + sin(a) * outer))
                ctx.stroke(ray, with: .color(sun), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            // Disc.
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                with: .color(sun))
        }
    }

    // drawClouds paints soft white cloud puffs for cloudy and wet skies.
    private func drawClouds(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let show: Bool
        switch scene {
        case .cloudyDay, .cloudyNight, .rain, .storm, .snow: show = true
        default: show = false
        }
        guard show else { return }
        let white = scene == .storm || scene == .rain
            ? Color.white.opacity(0.32) : Color.white.opacity(0.72)
        let puffs: [(cx: Double, cy: Double, s: CGFloat, speed: Double)] = [
            (0.3, 0.34, 1.0, 7),
            (0.68, 0.24, 0.8, 4.5),
            (0.5, 0.46, 1.25, 5.5),
        ]
        for p in puffs {
            let drift = (t * p.speed).truncatingRemainder(dividingBy: Double(size.width + 240)) - 120
            let cx = p.cx * size.width + drift
            let cy = p.cy * size.height
            let s = 30 * p.s
            var path = Path()
            path.addEllipse(in: CGRect(x: cx - s * 1.6, y: cy - s * 0.5, width: s * 3.2, height: s * 1.2))
            path.addEllipse(in: CGRect(x: cx - s * 0.9, y: cy - s * 0.95, width: s * 1.8, height: s * 1.6))
            path.addEllipse(in: CGRect(x: cx + s * 0.1, y: cy - s * 0.7, width: s * 1.5, height: s * 1.3))
            ctx.fill(path, with: .color(white))
        }
    }

    // drawStars scatters a twinkling field on the night sky.
    private func drawStars(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        var rng = SeededGen(seed: 0x51A7)
        for _ in 0..<60 {
            let x = Double.random(in: 0...1, using: &rng) * size.width
            let y = Double.random(in: 0...0.6, using: &rng) * size.height
            let phase = Double.random(in: 0...6.28, using: &rng)
            let tw = 0.4 + 0.6 * abs(sin(t * 0.9 + phase))
            ctx.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                with: .color(.white.opacity(0.7 * tw)))
        }
    }

    // drawRain streaks the sky during rain and storms.
    private func drawRain(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        var rng = SeededGen(seed: 0x0A17)
        for _ in 0..<50 {
            let x0 = Double.random(in: 0...1, using: &rng)
            let speed = Double.random(in: 340...560, using: &rng)
            let off = Double.random(in: 0...900, using: &rng)
            let y = (t * speed + off).truncatingRemainder(dividingBy: Double(size.height * 0.85))
            var p = Path()
            p.move(to: CGPoint(x: x0 * size.width, y: y))
            p.addLine(to: CGPoint(x: x0 * size.width - 3, y: y + 13))
            ctx.stroke(p, with: .color(.white.opacity(0.22)), lineWidth: 1)
        }
    }

    // drawSnow drifts flakes down the sky.
    private func drawSnow(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        var rng = SeededGen(seed: 0x5107)
        for _ in 0..<45 {
            let x0 = Double.random(in: 0...1, using: &rng)
            let speed = Double.random(in: 40...90, using: &rng)
            let off = Double.random(in: 0...600, using: &rng)
            let y = (t * speed + off).truncatingRemainder(dividingBy: Double(size.height * 0.85))
            let x = x0 * size.width + sin(t + off) * 8
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 3)),
                with: .color(.white.opacity(0.7)))
        }
    }

    // drawHills lays two rolling ridges so the sky meets ground, with the skua
    // on the near crest.
    private func drawHills(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let bottom = skyColors.last ?? .blue
        // Far ridge, a shade darker than the sky.
        var far = Path()
        let fy = size.height * 0.78
        far.move(to: CGPoint(x: 0, y: size.height))
        far.addLine(to: CGPoint(x: 0, y: fy + 6))
        far.addCurve(
            to: CGPoint(x: size.width, y: fy),
            control1: CGPoint(x: size.width * 0.3, y: fy - 30),
            control2: CGPoint(x: size.width * 0.66, y: fy + 22))
        far.addLine(to: CGPoint(x: size.width, y: size.height))
        far.closeSubpath()
        ctx.fill(far, with: .color(mix(bottom, .black, 0.42)))

        // Near ridge, darkest, carrying the perch peak.
        var near = Path()
        let ny = size.height * 0.9
        near.move(to: CGPoint(x: 0, y: size.height))
        near.addLine(to: CGPoint(x: 0, y: ny + 8))
        near.addCurve(
            to: CGPoint(x: size.width * 0.72, y: ny - 22),
            control1: CGPoint(x: size.width * 0.26, y: ny + 16),
            control2: CGPoint(x: size.width * 0.52, y: ny - 26))
        near.addCurve(
            to: CGPoint(x: size.width, y: ny + 8),
            control1: CGPoint(x: size.width * 0.86, y: ny - 18),
            control2: CGPoint(x: size.width * 0.95, y: ny))
        near.addLine(to: CGPoint(x: size.width, y: size.height))
        near.closeSubpath()
        ctx.fill(near, with: .color(mix(bottom, .black, 0.66)))
    }

    // mix interpolates two colors in RGB.
    private func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ua = UIColor(a), ub = UIColor(b)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        ua.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        ub.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(red: ar + (br - ar) * t, green: ag + (bg - ag) * t, blue: ab + (bb - ab) * t)
    }
}

// SeededGen is a small deterministic generator for stable scenery.
struct SeededGen: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
