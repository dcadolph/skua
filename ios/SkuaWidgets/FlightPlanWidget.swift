import SwiftUI
import WidgetKit

// ItineraryWidget puts the Flight Plan on the home screen: the next moments that
// matter, the app's flagship read of the day. It is both a mode of the
// configurable widget and the whole of the dedicated Flight Plan widget.
struct ItineraryWidget: View {
    let entry: SkuaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let fc = entry.forecast {
            let stops = FlightPlan.stops(for: fc, lightning: entry.lightning)
            switch family {
            case .systemSmall: small(stops)
            case .systemLarge: large(fc, stops)
            default: medium(stops)
            }
        } else {
            WidgetEmpty()
        }
    }

    // header is the flight-plan wordmark and the place.
    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "paperplane.fill").font(.system(size: 11, weight: .bold))
            Text("Flight plan").font(.system(size: 12, weight: .bold))
            Spacer(minLength: 0)
            Text(entry.name).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                .foregroundStyle(Theme.muted)
        }
        .foregroundStyle(Theme.cyan)
    }

    // small shows the single next stop with its countdown.
    private func small(_ stops: [Waypoint]) -> some View {
        let next = stops.first { !$0.isNow } ?? stops.first
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: "paperplane.fill").font(.system(size: 10, weight: .bold))
                Text("Next up").font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(Theme.cyan)
            Spacer(minLength: 0)
            if let w = next {
                Image(systemName: w.icon).font(.system(size: 26)).foregroundStyle(w.tint)
                Text(w.title).font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.text).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(w.isNow ? "Now" : FlightPlan.countdown(to: w.at))
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // medium lists the next few stops as a compact rail.
    private func medium(_ stops: [Waypoint]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            header
            ForEach(Array(stops.prefix(3))) { w in stopRow(w, detail: false) }
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    // large leads with the day's arc, then a rail with detail lines, and anchors
    // the bottom with the hourly strip so calm days still read as full.
    private func large(_ fc: Forecast, _ stops: [Waypoint]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Text(FlightPlan.summary(for: fc, lightning: entry.lightning))
                .font(.system(size: 13, design: .serif)).foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(Theme.hair)
            ForEach(Array(stops.prefix(5))) { w in stopRow(w, detail: true) }
            Spacer(minLength: 8)
            if !fc.hourly.isEmpty {
                Divider().overlay(Theme.hair)
                WidgetHourStrip(hours: fc.hourly, count: 6, daily: fc.daily)
            }
        }
        .padding(16)
    }

    // stopRow draws one stop: icon, title, optional detail, and its time.
    private func stopRow(_ w: Waypoint, detail: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: w.icon).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(w.tint).frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(w.title).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text).lineLimit(1)
                if detail, let d = w.detail {
                    Text(d).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 0) {
                Text(w.isNow ? "Now" : w.at.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(w.isNow ? Theme.accent : Theme.muted)
                if !w.isNow {
                    Text(FlightPlan.countdown(to: w.at)).font(.system(size: 9))
                        .foregroundStyle(Theme.muted.opacity(0.7))
                }
            }
        }
    }
}

// FlightPlanProvider drives the dedicated Flight Plan widget, always loading the
// itinerary for the app's last place.
struct FlightPlanProvider: TimelineProvider {
    // placeholder is the gallery stand-in before data loads.
    func placeholder(in context: Context) -> SkuaEntry {
        SkuaEntry(date: Date(), content: .flightPlan, name: "Austin", forecast: nil, lightning: nil)
    }

    // getSnapshot supplies a single entry for previews and transitions.
    func getSnapshot(in context: Context, completion: @escaping (SkuaEntry) -> Void) {
        Task { completion(await SkuaData.load(.flightPlan)) }
    }

    // getTimeline supplies the entry and asks to refresh in about three quarters
    // of an hour.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SkuaEntry>) -> Void) {
        Task {
            let entry = await SkuaData.load(.flightPlan)
            let next = Date().addingTimeInterval(45 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

// FlightPlanWidget puts the flagship itinerary on the home screen as its own
// tile, leading the differentiator right in the widget gallery.
struct FlightPlanWidget: Widget {
    let kind = "FlightPlanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlightPlanProvider()) { entry in
            SkuaWidgetView(entry: entry)
        }
        .configurationDisplayName("Flight plan")
        .description("The moments that matter today, as an itinerary.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}
