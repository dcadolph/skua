import SwiftUI

// TideCard shows the nearest coast's tide story: the next high or low with a
// countdown, a smooth curve placing this moment on the tide, today's extremes,
// and the station it came from.
struct TideCard: View {
    let tides: Tides

    var body: some View {
        GlassSection(title: "Tides", icon: "water.waves", tint: Theme.cyan) {
            if let next = nextEvent {
                hero(next)
            }
            TideCurve(events: tides.events)
                .frame(height: 118)
            if !todayEvents.isEmpty {
                Divider().overlay(Theme.hair)
                todayRow
            }
            footer
        }
    }

    // hero is the headline readout for the next extreme.
    private func hero(_ next: TideEvent) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: next.isHigh ? "arrow.up.forward" : "arrow.down.forward")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(next.isHigh ? Theme.cyan : Theme.blue)
                .frame(width: 40, height: 40)
                .background((next.isHigh ? Theme.cyan : Theme.blue).opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(next.isHigh ? "High tide" : "Low tide")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                Text("\(next.time.formatted(date: .omitted, time: .shortened)) · \(heightText(next.heightFt))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(countdownText(to: next.time))
                    .font(.system(size: 25, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.cyan)
                Text(next.isHigh ? "until high" : "until low")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    // todayRow lays out each of today's extremes as a compact cell.
    private var todayRow: some View {
        HStack(spacing: 6) {
            ForEach(todayEvents) { e in
                VStack(spacing: 3) {
                    Image(systemName: e.isHigh ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(e.isHigh ? Theme.cyan : Theme.slate)
                    Text(e.time.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(heightText(e.heightFt))
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // footer credits the source station and its distance.
    private var footer: some View {
        Text(stationLine)
            .font(.caption2)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // nextEvent is the first extreme still ahead of now.
    private var nextEvent: TideEvent? {
        let now = Date()
        return tides.events.first { $0.time > now }
    }

    // todayEvents are the extremes falling on the local calendar day.
    private var todayEvents: [TideEvent] {
        let cal = Calendar.current
        return tides.events.filter { cal.isDateInToday($0.time) }
    }

    // stationLine names the station, its state, distance, and datum.
    private var stationLine: String {
        var s = tides.stationName
        if !tides.state.isEmpty { s += ", \(tides.state)" }
        s += " · \(distanceText(tides.distanceKm)) · \(tides.datum)"
        return s
    }
}

// TideCurve draws a smooth raised-cosine interpolation of the tide across a
// window centered on now, filled under the line, with this moment marked and
// each visible extreme dotted and timed.
struct TideCurve: View {
    let events: [TideEvent]

    var body: some View {
        Canvas { ctx, size in
            guard events.count >= 2 else { return }
            let now = Date()
            let windowStart = now.addingTimeInterval(-3 * 3600)
            let windowEnd = now.addingTimeInterval(13 * 3600)
            let span = windowEnd.timeIntervalSince(windowStart)

            let heights = events.map(\.heightFt)
            let lo = heights.min() ?? 0
            let hi = heights.max() ?? 1
            let range = max(0.3, hi - lo)
            let plotLo = lo - range * 0.12
            let plotHi = hi + range * 0.12
            let top: CGFloat = 18
            let bottom = size.height - 18

            func x(_ d: Date) -> CGFloat {
                CGFloat(d.timeIntervalSince(windowStart) / span) * size.width
            }
            func y(_ h: Double) -> CGFloat {
                let f = (h - plotLo) / (plotHi - plotLo)
                return bottom - CGFloat(f) * (bottom - top)
            }

            // Sample the eased curve across the window into a path.
            let steps = max(2, Int(size.width / 2))
            var line = Path()
            for i in 0...steps {
                let t = windowStart.addingTimeInterval(span * Double(i) / Double(steps))
                guard let h = tideHeight(at: t, events: events) else { continue }
                let pt = CGPoint(x: x(t), y: y(h))
                if i == 0 { line.move(to: pt) } else { line.addLine(to: pt) }
            }

            // Fill under the line with a cyan wash.
            var area = line
            area.addLine(to: CGPoint(x: size.width, y: bottom))
            area.addLine(to: CGPoint(x: 0, y: bottom))
            area.closeSubpath()
            ctx.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: [Theme.cyan.opacity(0.32), Theme.cyan.opacity(0.02)]),
                    startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: bottom)))
            ctx.stroke(line, with: .color(Theme.cyan), style: StrokeStyle(lineWidth: 2, lineJoin: .round))

            // Dot and time-stamp each extreme inside the window.
            for e in events where e.time >= windowStart && e.time <= windowEnd {
                let pt = CGPoint(x: x(e.time), y: y(e.heightFt))
                ctx.fill(
                    Path(ellipseIn: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)),
                    with: .color(e.isHigh ? Theme.cyan : Theme.slate))
                let label = Text(tick(e.time))
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(Theme.muted)
                ctx.draw(label, at: CGPoint(x: pt.x, y: e.isHigh ? pt.y - 12 : pt.y + 12), anchor: .center)
            }

            // Mark now with a hairline and a dot riding the curve.
            if let h = tideHeight(at: now, events: events) {
                let nx = x(now)
                var rule = Path()
                rule.move(to: CGPoint(x: nx, y: top - 4))
                rule.addLine(to: CGPoint(x: nx, y: bottom))
                ctx.stroke(rule, with: .color(Theme.text.opacity(0.25)),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                let np = CGPoint(x: nx, y: y(h))
                ctx.fill(Path(ellipseIn: CGRect(x: np.x - 8, y: np.y - 8, width: 16, height: 16)),
                    with: .color(Theme.cyan.opacity(0.25)))
                ctx.fill(Path(ellipseIn: CGRect(x: np.x - 4.5, y: np.y - 4.5, width: 9, height: 9)),
                    with: .color(Theme.cyan))
            }
        }
    }

    // tick is a compact time stamp for a curve label, like "3:42p".
    private func tick(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        return f.string(from: d).lowercased().replacingOccurrences(of: "m", with: "")
    }
}

// tideHeight interpolates the water level at t with a raised cosine between the
// bracketing extremes, which matches how tides ease through slack water.
func tideHeight(at t: Date, events: [TideEvent]) -> Double? {
    guard let first = events.first, let last = events.last else { return nil }
    if t <= first.time { return first.heightFt }
    if t >= last.time { return last.heightFt }
    for i in 0..<(events.count - 1) {
        let a = events[i]
        let b = events[i + 1]
        if t >= a.time && t <= b.time {
            let seg = b.time.timeIntervalSince(a.time)
            let u = seg > 0 ? t.timeIntervalSince(a.time) / seg : 0
            let eased = (1 - cos(.pi * u)) / 2
            return a.heightFt + (b.heightFt - a.heightFt) * eased
        }
    }
    return nil
}

// heightText renders a tide height in the chosen units.
func heightText(_ ft: Double) -> String {
    imperialUnits() ? String(format: "%.1f ft", ft) : String(format: "%.1f m", ft * 0.3048)
}

// distanceText renders a station distance in the chosen units.
func distanceText(_ km: Double) -> String {
    imperialUnits()
        ? "\(Int((km * 0.621371).rounded())) mi"
        : "\(Int(km.rounded())) km"
}
