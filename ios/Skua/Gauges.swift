import SwiftUI

// GaugesCard is the conditions instrument panel: circular gauges for the
// bounded readings and tiles for the rest, with a pressure trend read from the
// hourly series.
struct GaugesCard: View {
    let current: Current
    let hours: [HourlyPoint]
    let today: DailyPoint?

    var body: some View {
        GlassSection(title: "Conditions", icon: "gauge.medium", tint: Theme.green) {
            HStack(spacing: 0) {
                ring(
                    value: min(current.uvIndex, 11), range: 0...11,
                    label: "UV", reading: String(format: "%.0f", current.uvIndex),
                    tint: uvColor(current.uvIndex))
                ring(
                    value: Double(current.humidity), range: 0...100,
                    label: "Humidity", reading: "\(current.humidity)%",
                    tint: Theme.blue)
                ring(
                    value: Double(current.cloudCover), range: 0...100,
                    label: "Cloud", reading: "\(current.cloudCover)%",
                    tint: Theme.slate)
                ring(
                    value: current.windGustKph, range: 0...max(60, current.windGustKph),
                    label: "Gusts", reading: "\(mph(current.windGustKph))",
                    tint: Theme.green)
            }
            Divider().overlay(Theme.hair)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                Stat(label: "Pressure", value: pressureText, icon: "gauge.medium", tint: Theme.purple)
                Stat(label: "Dew point", value: "\(f(current.dewPointC))°", icon: "drop.fill", tint: Theme.cyan)
                Stat(label: "Visibility", value: String(format: "%.1f mi", current.visibilityKm * 0.621371), icon: "eye.fill", tint: Theme.slate)
                Stat(label: "Rain today", value: rainToday, icon: "umbrella.fill", tint: Theme.rain)
            }
        }
    }

    // ring is one circular gauge with its caption.
    private func ring(value: Double, range: ClosedRange<Double>, label: String, reading: String, tint: Color)
        -> some View {
        VStack(spacing: 6) {
            Gauge(value: min(max(value, range.lowerBound), range.upperBound), in: range) {
                EmptyView()
            } currentValueLabel: {
                Text(reading)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(tint)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .kerning(0.5)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    // pressureText renders inches of mercury with a three hour trend arrow.
    private var pressureText: String {
        let inHg = String(format: "%.2f", current.pressureHPa * 0.02953)
        guard let trend = pressureTrend else { return "\(inHg) inHg" }
        let arrow = trend > 1 ? "↑" : trend < -1 ? "↓" : "→"
        return "\(inHg) inHg \(arrow)"
    }

    // pressureTrend is the hPa change over the last three hours, nil when the
    // hourly series cannot say.
    private var pressureTrend: Double? {
        let now = Date()
        guard let idx = hours.lastIndex(where: { $0.time <= now }), idx >= 3,
            let cur = hours[idx].pressureHPa, let past = hours[idx - 3].pressureHPa
        else { return nil }
        return cur - past
    }

    // rainToday totals the day's expected precipitation in inches.
    private var rainToday: String {
        guard let sum = today?.precipSumMM else { return "0 in" }
        return String(format: "%.2f in", sum * 0.0393701)
    }

    // uvColor follows the WHO UV bands.
    private func uvColor(_ uv: Double) -> Color {
        switch uv {
        case ..<3: return Theme.green
        case ..<6: return Theme.yellow
        case ..<8: return Color(red: 0.88, green: 0.53, blue: 0.25)
        case ..<11: return Color(red: 0.84, green: 0.33, blue: 0.33)
        default: return Color(red: 0.61, green: 0.43, blue: 0.84)
        }
    }
}

// MoonCard shows the lunar phase as a drawn disc with the upcoming phase dates,
// the studied Carrot anatomy.
struct MoonCard: View {
    let moon: MoonInfo

    private static let synodic = 29.530588853

    var body: some View {
        GlassSection(title: "Moon", icon: "moon.stars.fill", tint: Theme.purple) {
            HStack(alignment: .center, spacing: 18) {
                VStack(spacing: 8) {
                    MoonDisc(phase: moon.phase)
                        .frame(width: 110, height: 110)
                    Text(moon.name)
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    Text("Illumination \(Int((moon.illumination * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(upcoming, id: \.name) { u in
                        HStack(spacing: 10) {
                            MoonDisc(phase: u.phase)
                                .frame(width: 22, height: 22)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(u.name)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Theme.text)
                                Text(u.date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // upcoming lists the next four principal phases with their dates.
    private var upcoming: [(name: String, phase: Double, date: Date)] {
        let targets: [(String, Double)] = [
            ("First quarter", 0.25), ("Full moon", 0.5), ("Last quarter", 0.75), ("New moon", 0.0),
        ]
        return targets.map { name, target in
            var delta = (target - moon.phase).truncatingRemainder(dividingBy: 1)
            if delta <= 0 { delta += 1 }
            return (name, target, Date().addingTimeInterval(delta * Self.synodic * 86400))
        }
        .sorted { $0.2 < $1.2 }
    }
}

// MoonDisc draws the lit and dark portions of the moon for a phase, terminator
// included, without any image assets.
struct MoonDisc: View {
    // phase runs 0 new moon through 0.5 full back to 1.
    let phase: Double

    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let dark = Color(red: 0.16, green: 0.18, blue: 0.28)
            let lit = Color(red: 0.92, green: 0.9, blue: 0.82)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(dark))

            // The lit fraction grows from the right while waxing and shrinks
            // from the left while waning; the terminator is a half-ellipse.
            let waxing = phase <= 0.5
            let f = phase <= 0.5 ? phase * 2 : (1 - phase) * 2
            var litPath = Path()
            let half = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
            if waxing {
                litPath.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            } else {
                litPath.addArc(center: c, radius: r, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            }
            litPath.closeSubpath()
            ctx.fill(litPath, with: .color(lit))

            // The terminator ellipse eats into or extends the lit half.
            let tw = abs(1 - 2 * f) * r
            let tRect = CGRect(x: c.x - tw, y: c.y - r, width: 2 * tw, height: 2 * r)
            let bulge = f < 0.5
            ctx.fill(
                Path(ellipseIn: tRect),
                with: .color(bulge ? dark : lit))
            _ = half
        }
        .clipShape(Circle())
    }
}
