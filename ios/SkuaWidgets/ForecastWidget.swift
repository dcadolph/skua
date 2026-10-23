import SwiftUI
import WidgetKit

// SkuaEntry is one rendered moment for the widget timeline, carrying whatever the
// chosen content needs to draw.
struct SkuaEntry: TimelineEntry {
    // date is when this entry becomes current.
    let date: Date
    // content is the chosen readout.
    let content: WidgetContent
    // name labels the place.
    let name: String
    // forecast is the weather to show, nil while loading or on failure.
    let forecast: Forecast?
    // lightning is the storm read, loaded only for storm-aware content.
    let lightning: Lightning?
}

// SkuaData loads a widget entry for the app's last place, fetching only what the
// chosen content needs so a simple readout does not pay for a storm lookup.
enum SkuaData {
    // load reads the last place, then the forecast and, for storm content, the
    // near-term lightning risk.
    static func load(_ content: WidgetContent) async -> SkuaEntry {
        let loc = SharedStore.lastLocation()
        let forecast = try? await WeatherKitProvider.forecastWithFallback(lat: loc.lat, lon: loc.lon)
        var lightning: Lightning?
        if content == .flightPlan || content == .lightning {
            lightning = try? await SkuaClient.shared.lightning(lat: loc.lat, lon: loc.lon)
        }
        return SkuaEntry(
            date: Date(), content: content, name: loc.name, forecast: forecast, lightning: lightning)
    }
}

// SkuaProvider drives the configurable widget, keyed off the chosen content.
struct SkuaProvider: AppIntentTimelineProvider {
    // placeholder is the gallery stand-in before data loads.
    func placeholder(in context: Context) -> SkuaEntry {
        SkuaEntry(date: Date(), content: .conditions, name: "Austin", forecast: nil, lightning: nil)
    }

    // snapshot supplies a single entry for previews and transitions.
    func snapshot(for configuration: SkuaWidgetIntent, in context: Context) async -> SkuaEntry {
        await SkuaData.load(configuration.content)
    }

    // timeline supplies the entry and asks to refresh in about three quarters of
    // an hour.
    func timeline(for configuration: SkuaWidgetIntent, in context: Context) async -> Timeline<SkuaEntry> {
        let entry = await SkuaData.load(configuration.content)
        let next = Date().addingTimeInterval(45 * 60)
        return Timeline(entries: [entry], policy: .after(next))
    }
}

// ForecastWidget is the configurable home-screen widget. A long press picks what
// it shows, matching the in-app interface maker.
struct ForecastWidget: Widget {
    let kind = "ForecastWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SkuaWidgetIntent.self, provider: SkuaProvider()) { entry in
            SkuaWidgetView(entry: entry)
        }
        .configurationDisplayName("Skua")
        .description("Your weather, your way.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryInline, .accessoryCircular, .accessoryRectangular,
        ])
    }
}

// SkuaWidgetView renders the entry for the widget family and chosen content,
// spanning the home screen and the lock screen, and applies the right background.
struct SkuaWidgetView: View {
    var entry: SkuaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content.skuaBackground(family)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryInline: AccessoryInline(entry: entry)
        case .accessoryCircular: AccessoryCircular(entry: entry)
        case .accessoryRectangular: AccessoryRectangular(entry: entry)
        default:
            switch entry.content {
            case .conditions: ConditionsWidget(entry: entry)
            case .flightPlan: ItineraryWidget(entry: entry)
            case .lightning: LightningWidget(entry: entry)
            }
        }
    }
}

// WidgetSky is the ember-over-charcoal backdrop shared by every size.
struct WidgetSky: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.10, green: 0.06, blue: 0.05), Theme.ground],
            startPoint: .topTrailing, endPoint: .bottomLeading)
    }
}

// ConditionsWidget is the temperature-first readout with an hourly strip.
struct ConditionsWidget: View {
    let entry: SkuaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemLarge: large
        default: medium
        }
    }

    // small is the compact place, temperature, condition, and range.
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetPlace(name: entry.name)
            Spacer(minLength: 2)
            if let c = entry.forecast?.current {
                tempRow(c, size: 52)
                Text(c.condition).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 2)
            WidgetRange(daily: entry.forecast?.daily.first)
        }
        .padding(14)
    }

    // medium pairs the readout with the next four hours.
    private var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetPlace(name: entry.name)
                Spacer(minLength: 0)
                if let c = entry.forecast?.current {
                    tempRow(c, size: 46)
                    Text(c.condition).font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                WidgetRange(daily: entry.forecast?.daily.first)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            WidgetHourStrip(hours: entry.forecast?.hourly ?? [], count: 4, daily: entry.forecast?.daily ?? [])
        }
        .padding(14)
    }

    // large stacks the readout, a six-hour strip, and the range.
    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    WidgetPlace(name: entry.name)
                    if let c = entry.forecast?.current { tempRow(c, size: 58) }
                }
                Spacer()
                if let c = entry.forecast?.current {
                    VStack(alignment: .trailing, spacing: 3) {
                        Image(systemName: conditionSymbol(c.condition, night: !c.isDay))
                            .font(.system(size: 30)).symbolRenderingMode(.multicolor)
                        Text(c.condition).font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.muted).lineLimit(1)
                        WidgetRange(daily: entry.forecast?.daily.first)
                    }
                }
            }
            Divider().overlay(Theme.hair)
            WidgetHourStrip(hours: entry.forecast?.hourly ?? [], count: 6, daily: entry.forecast?.daily ?? [])
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    // tempRow is the serif temperature with a muted degree mark.
    private func tempRow(_ c: Current, size: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 2) {
            Text("\(f(c.tempC))").font(.system(size: size, weight: .semibold, design: .serif))
            Text("°").font(.system(size: size * 0.42, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.muted)
        }
        .foregroundStyle(Theme.text)
    }
}

// LightningWidget is the storm read: a graded bolt, a severity meter, and the
// countdown to the next storm, leaning on the dashboard's risk color.
struct LightningWidget: View {
    let entry: SkuaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let l = entry.lightning, l.level > 0 {
            content(l)
        } else {
            quiet
        }
    }

    // content draws the active storm read at the current family.
    private func content(_ l: Lightning) -> some View {
        let color = lightningColor(l.level)
        return VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 9) {
            HStack(spacing: 6) {
                Image(systemName: l.imminent ? "bolt.trianglebadge.exclamationmark.fill" : "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("\(l.risk.capitalized) risk").font(.system(size: 14, weight: .bold)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(color)
            if family != .systemSmall {
                Text(l.headline).font(.system(size: 12)).foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true).lineLimit(3)
            }
            Spacer(minLength: 0)
            meter(l, color: color)
            if l.hasNext {
                VStack(alignment: .leading, spacing: 1) {
                    Text(l.imminent ? "Storm imminent" : "Next storm")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.muted)
                    Text(countdownText(to: l.next))
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.text)
                }
            }
        }
        .padding(family == .systemSmall ? 14 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // meter is the four-segment severity bar, filled to the risk level.
    private func meter(_ l: Lightning, color: Color) -> some View {
        HStack(spacing: 4) {
            ForEach(1...4, id: \.self) { seg in
                Capsule().fill(seg <= l.level ? color : Theme.hair).frame(height: 5)
            }
        }
    }

    // quiet is the calm-sky state, shown when no storm risk is on the board.
    private var quiet: some View {
        VStack(spacing: 6) {
            Image(systemName: "bolt.slash.fill").font(.system(size: 24)).foregroundStyle(Theme.muted)
            Text("Quiet skies").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
            Text(entry.name).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// WidgetPlace is the location label with a mark, shared by the widget readouts.
struct WidgetPlace: View {
    let name: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill").font(.system(size: 9, weight: .bold))
            Text(name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
        }
        .foregroundStyle(Theme.accent)
    }
}

// WidgetRange is today's high and low.
struct WidgetRange: View {
    let daily: DailyPoint?
    var body: some View {
        if let d = daily {
            HStack(spacing: 6) {
                Text("H \(f(d.highC))°")
                Text("L \(f(d.lowC))°").foregroundStyle(Theme.muted)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.text)
        }
    }
}

// WidgetHourStrip is the next few hours as time, icon, and temperature. Passing
// the daily sun events lets each hour draw a night-aware icon.
struct WidgetHourStrip: View {
    let hours: [HourlyPoint]
    let count: Int
    var daily: [DailyPoint] = []
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(hours.prefix(count))) { h in
                VStack(spacing: 4) {
                    Text(h.time.formatted(.dateTime.hour()))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.muted)
                    Image(systemName: conditionSymbol(h.condition, night: isNight(h.time, daily: daily)))
                        .font(.system(size: 15))
                        .symbolRenderingMode(.multicolor)
                    Text("\(f(h.tempC))°")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// isNight reports whether an hour falls outside daylight, using the matching
// day's sunrise and sunset when available and an hour-of-day fallback otherwise.
func isNight(_ time: Date, daily: [DailyPoint]) -> Bool {
    let cal = Calendar.current
    if let day = daily.first(where: { cal.isDate($0.date, inSameDayAs: time) }) {
        return time < day.sunrise || time >= day.sunset
    }
    let hour = cal.component(.hour, from: time)
    return hour < 6 || hour >= 20
}

// WidgetEmpty is the fallback shown when the forecast has not loaded yet.
struct WidgetEmpty: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "cloud.fill").font(.system(size: 24)).foregroundStyle(Theme.muted)
            Text("Skua").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// AccessoryInline is the lock-screen inline slot beside the clock, one glanceable
// line for the chosen content.
struct AccessoryInline: View {
    let entry: SkuaEntry

    var body: some View {
        switch entry.content {
        case .conditions:
            if let c = entry.forecast?.current {
                Label("\(f(c.tempC))° \(c.condition)", systemImage: conditionSymbol(c.condition, night: !c.isDay))
            } else {
                Text("Skua")
            }
        case .flightPlan:
            if let w = nextFlightStop(entry) {
                Label("\(w.title) \(w.at.formatted(.dateTime.hour()))", systemImage: "paperplane.fill")
            } else {
                Label("Clear run ahead", systemImage: "paperplane.fill")
            }
        case .lightning:
            if let l = entry.lightning, l.level > 0 {
                Label("\(l.risk.capitalized) storm risk", systemImage: "bolt.fill")
            } else {
                Label("No storm risk", systemImage: "bolt.slash.fill")
            }
        }
    }
}

// AccessoryCircular is the small round lock-screen slot, a single glanceable mark.
struct AccessoryCircular: View {
    let entry: SkuaEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            mark
        }
    }

    // mark is the round slot's content for the chosen readout.
    @ViewBuilder private var mark: some View {
        switch entry.content {
        case .conditions:
            if let c = entry.forecast?.current {
                VStack(spacing: -2) {
                    Image(systemName: conditionSymbol(c.condition, night: !c.isDay)).font(.system(size: 12))
                    Text("\(f(c.tempC))°").font(.system(size: 18, weight: .semibold, design: .serif))
                }
            }
        case .flightPlan:
            if let w = nextFlightStop(entry) {
                VStack(spacing: 0) {
                    Image(systemName: w.icon).font(.system(size: 15))
                    Text(FlightPlan.countdown(to: w.at).replacingOccurrences(of: "in ", with: ""))
                        .font(.system(size: 11, weight: .semibold))
                }
            } else {
                Image(systemName: "paperplane.fill").font(.system(size: 18))
            }
        case .lightning:
            if let l = entry.lightning, l.level > 0 {
                VStack(spacing: 0) {
                    Image(systemName: "bolt.fill").font(.system(size: 15))
                    Text("\(l.level)/4").font(.system(size: 11, weight: .semibold))
                }
            } else {
                Image(systemName: "bolt.slash").font(.system(size: 18))
            }
        }
    }
}

// AccessoryRectangular is the wide lock-screen slot, a few lines for the chosen
// content. It leans on text and symbols since the lock screen renders one tint.
struct AccessoryRectangular: View {
    let entry: SkuaEntry

    var body: some View {
        switch entry.content {
        case .conditions: conditions
        case .flightPlan: flightPlan
        case .lightning: lightning
        }
    }

    // conditions is the place, the temperature and sky, and today's range.
    @ViewBuilder private var conditions: some View {
        if let c = entry.forecast?.current {
            VStack(alignment: .leading, spacing: 2) {
                Label(entry.name, systemImage: conditionSymbol(c.condition, night: !c.isDay))
                    .font(.system(size: 13, weight: .semibold)).widgetAccentable()
                Text("\(f(c.tempC))°  \(c.condition)").font(.system(size: 15, weight: .medium)).lineLimit(1)
                if let d = entry.forecast?.daily.first {
                    Text("H \(f(d.highC))°   L \(f(d.lowC))°").font(.system(size: 12)).opacity(0.9)
                }
            }
        } else {
            Text("Skua")
        }
    }

    // flightPlan is the next stop on the itinerary with its time and countdown.
    @ViewBuilder private var flightPlan: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Flight plan", systemImage: "paperplane.fill")
                .font(.system(size: 13, weight: .semibold)).widgetAccentable()
            if let w = nextFlightStop(entry) {
                Text(w.title).font(.system(size: 14, weight: .medium)).lineLimit(1)
                Text("\(w.at.formatted(.dateTime.hour())) · \(FlightPlan.countdown(to: w.at))")
                    .font(.system(size: 12)).opacity(0.9)
            } else {
                Text("A calm run through the day").font(.system(size: 13)).opacity(0.9).lineLimit(2)
            }
        }
    }

    // lightning is the storm risk with the countdown to the next storm.
    @ViewBuilder private var lightning: some View {
        if let l = entry.lightning, l.level > 0 {
            VStack(alignment: .leading, spacing: 2) {
                Label("\(l.risk.capitalized) storm risk", systemImage: "bolt.fill")
                    .font(.system(size: 13, weight: .semibold)).lineLimit(1).widgetAccentable()
                if l.hasNext {
                    Text(l.imminent ? "Storm imminent" : "Next storm").font(.system(size: 12)).opacity(0.9)
                    Text(countdownText(to: l.next)).font(.system(size: 15, weight: .semibold, design: .serif))
                } else {
                    Text(l.headline).font(.system(size: 12)).opacity(0.9).lineLimit(2)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Label("Quiet skies", systemImage: "bolt.slash.fill")
                    .font(.system(size: 13, weight: .semibold)).widgetAccentable()
                Text("No storm risk nearby").font(.system(size: 12)).opacity(0.9)
            }
        }
    }
}

// nextFlightStop is the next upcoming waypoint for an entry, skipping the present.
func nextFlightStop(_ entry: SkuaEntry) -> Waypoint? {
    guard let fc = entry.forecast else { return nil }
    return FlightPlan.stops(for: fc, lightning: entry.lightning).first { !$0.isNow }
}

// skuaBackground applies the ember sky on the home screen and a clear background
// on the lock screen, where the system provides its own treatment.
extension View {
    @ViewBuilder
    func skuaBackground(_ family: WidgetFamily) -> some View {
        switch family {
        case .accessoryInline:
            self
        case .accessoryCircular, .accessoryRectangular:
            containerBackground(for: .widget) { Color.clear }
        default:
            containerBackground(for: .widget) { WidgetSky() }
        }
    }
}
