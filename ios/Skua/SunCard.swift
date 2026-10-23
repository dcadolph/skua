import SwiftUI

// SunCard is the day's solar story: a dashed arc with the sun placed by the
// current time, solar noon, total daylight, and the rise and set times.
struct SunCard: View {
    let today: DailyPoint

    var body: some View {
        GlassSection(title: "Sun", icon: "sun.horizon.fill", tint: Theme.accent) {
            SunArc(sunrise: today.sunrise, sunset: today.sunset)
                .frame(height: 110)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(today.sunrise.formatted(date: .omitted, time: .shortened))
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Sunrise")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                VStack(spacing: 1) {
                    Text(solarNoon.formatted(date: .omitted, time: .shortened))
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Solar noon")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                    if let daylight = today.daylightSec {
                        Text(daylightText(daylight))
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 2)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(today.sunset.formatted(date: .omitted, time: .shortened))
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Sunset")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }

    // solarNoon is the midpoint of the day.
    private var solarNoon: Date {
        today.sunrise.addingTimeInterval(today.sunset.timeIntervalSince(today.sunrise) / 2)
    }

    // daylightText renders the daylight duration.
    private func daylightText(_ sec: Double) -> String {
        let mins = Int(sec / 60)
        return "\(mins / 60) hrs \(mins % 60) mins of daylight"
    }
}

// SunArc draws the dashed day arc with the sun positioned by the current time,
// resting on the horizon after dark.
struct SunArc: View {
    let sunrise: Date
    let sunset: Date

    var body: some View {
        Canvas { ctx, size in
            let baseY = size.height - 12
            let left = CGPoint(x: 18, y: baseY)
            let right = CGPoint(x: size.width - 18, y: baseY)
            let peak = CGPoint(x: size.width / 2, y: -size.height * 0.35)

            var horizon = Path()
            horizon.move(to: CGPoint(x: 4, y: baseY))
            horizon.addLine(to: CGPoint(x: size.width - 4, y: baseY))
            ctx.stroke(horizon, with: .color(Theme.hair), lineWidth: 1.5)

            var arc = Path()
            arc.move(to: left)
            arc.addQuadCurve(to: right, control: peak)
            ctx.stroke(
                arc, with: .color(Theme.muted.opacity(0.6)),
                style: StrokeStyle(lineWidth: 2, dash: [3, 6]))

            // The sun sits at the Bezier point for the clamped time fraction.
            let span = sunset.timeIntervalSince(sunrise)
            let t = span > 0 ? Date().timeIntervalSince(sunrise) / span : 0
            let up = t > 0 && t < 1
            let ct = min(1, max(0, t))
            let omt = 1 - ct
            let x = omt * omt * left.x + 2 * omt * ct * peak.x + ct * ct * right.x
            let y = omt * omt * left.y + 2 * omt * ct * peak.y + ct * ct * right.y
            let pos = up ? CGPoint(x: x, y: y) : CGPoint(x: ct <= 0 ? left.x : right.x, y: baseY)

            if up {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: pos.x - 13, y: pos.y - 13, width: 26, height: 26)),
                    with: .color(Theme.accent.opacity(0.25)))
            }
            ctx.fill(
                Path(ellipseIn: CGRect(x: pos.x - 7, y: pos.y - 7, width: 14, height: 14)),
                with: .color(up ? Theme.accent : Theme.muted))
        }
    }
}
