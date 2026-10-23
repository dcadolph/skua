import SwiftUI

// SkyScene classifies the backdrop the sky should paint.
enum SkyScene {
    case clearDay
    case clearNight
    case cloudyDay
    case cloudyNight
    case rain
    case storm
    case snow

    // scene classifies a condition string and daylight flag.
    static func from(condition: String, isDay: Bool) -> SkyScene {
        let c = condition.lowercased()
        if c.contains("thunder") { return .storm }
        if c.contains("snow") || c.contains("sleet") { return .snow }
        if c.contains("rain") || c.contains("shower") || c.contains("drizzle") { return .rain }
        if c.contains("cloud") || c.contains("overcast") || c.contains("fog") || c.contains("mist") {
            return isDay ? .cloudyDay : .cloudyNight
        }
        return isDay ? .clearDay : .clearNight
    }

    // colors is the backdrop gradient, top to bottom: near-black charcoal
    // with only a whisper of the scene's hue.
    var colors: [Color] {
        switch self {
        case .clearDay:
            return [Color(red: 0.05, green: 0.085, blue: 0.15), Color(red: 0.01, green: 0.016, blue: 0.038)]
        case .clearNight:
            return [Color(red: 0.012, green: 0.016, blue: 0.05), Color(red: 0.003, green: 0.004, blue: 0.015)]
        case .cloudyDay:
            return [Color(red: 0.065, green: 0.075, blue: 0.1), Color(red: 0.013, green: 0.016, blue: 0.026)]
        case .cloudyNight:
            return [Color(red: 0.028, green: 0.032, blue: 0.05), Color(red: 0.007, green: 0.008, blue: 0.016)]
        case .rain:
            return [Color(red: 0.032, green: 0.045, blue: 0.075), Color(red: 0.007, green: 0.011, blue: 0.022)]
        case .storm:
            return [Color(red: 0.045, green: 0.036, blue: 0.075), Color(red: 0.009, green: 0.007, blue: 0.018)]
        case .snow:
            return [Color(red: 0.05, green: 0.06, blue: 0.088), Color(red: 0.011, green: 0.014, blue: 0.026)]
        }
    }

    // hasStars reports whether the star field shows.
    var hasStars: Bool { self == .clearNight || self == .cloudyNight }

    // hasRain reports whether rain particles fall.
    var hasRain: Bool { self == .rain || self == .storm }

    // hasSnow reports whether snow particles fall.
    var hasSnow: Bool { self == .snow }
}

// SkyView paints the full-bleed animated backdrop: a scene gradient, a star
// field on clear nights, and falling precipitation when the weather calls for
// it. The whole app sits on top of this.
struct SkyView: View {
    let scene: SkyScene
    // glow tints the top of the sky with the active palette, clear for none.
    var glow: Color = .clear

    // stars is a fixed field of positions and twinkle phases, seeded so the sky
    // is stable between redraws.
    private static let stars: [(x: Double, y: Double, r: Double, phase: Double)] = {
        var rng = SeededGenerator(seed: 0x5AC1)
        return (0..<90).map { _ in
            (
                x: Double.random(in: 0...1, using: &rng),
                y: Double.random(in: 0...0.55, using: &rng),
                r: Double.random(in: 0.5...1.4, using: &rng),
                phase: Double.random(in: 0...(2 * .pi), using: &rng)
            )
        }
    }()

    // drops is a fixed field of precipitation columns.
    private static let drops: [(x: Double, speed: Double, offset: Double, len: Double)] = {
        var rng = SeededGenerator(seed: 0xD00F)
        return (0..<70).map { _ in
            (
                x: Double.random(in: 0...1, using: &rng),
                speed: Double.random(in: 380...620, using: &rng),
                offset: Double.random(in: 0...1000, using: &rng),
                len: Double.random(in: 10...20, using: &rng)
            )
        }
    }()

    var body: some View {
        ZStack {
            LinearGradient(colors: scene.colors, startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [glow.opacity(0.28), .clear], center: .top, startRadius: 0, endRadius: 520)
            if scene.hasStars || scene.hasRain || scene.hasSnow {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { ctx, size in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        if scene.hasStars {
                            for s in Self.stars {
                                let tw = 0.35 + 0.65 * abs(sin(t * 0.8 + s.phase))
                                let rect = CGRect(
                                    x: s.x * size.width, y: s.y * size.height,
                                    width: s.r * 2, height: s.r * 2)
                                ctx.fill(
                                    Path(ellipseIn: rect),
                                    with: .color(.white.opacity(0.55 * tw)))
                            }
                        }
                        if scene.hasRain {
                            for d in Self.drops {
                                let y = (t * d.speed + d.offset)
                                    .truncatingRemainder(dividingBy: size.height + 40) - 20
                                var p = Path()
                                p.move(to: CGPoint(x: d.x * size.width, y: y))
                                p.addLine(to: CGPoint(x: d.x * size.width - 2, y: y + d.len))
                                ctx.stroke(p, with: .color(.white.opacity(0.16)), lineWidth: 1)
                            }
                        }
                        if scene.hasSnow {
                            for d in Self.drops {
                                let y = (t * d.speed * 0.18 + d.offset)
                                    .truncatingRemainder(dividingBy: size.height + 20) - 10
                                let x = d.x * size.width + sin(t + d.offset) * 8
                                ctx.fill(
                                    Path(ellipseIn: CGRect(x: x, y: y, width: 2.6, height: 2.6)),
                                    with: .color(.white.opacity(0.4)))
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// SeededGenerator is a small deterministic random source for stable scenery.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
