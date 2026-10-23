import SwiftUI

// DailyCard is the 7 day list with temperature range bars; a tap on any day
// expands its full detail.
struct DailyCard: View {
    let days: [DailyPoint]
    // style picks the row treatment: bars for the range track, compact for text.
    var style: String = "bars"
    @State private var expanded: Set<Date> = []

    var body: some View {
        GlassSection(title: "7-day", icon: "calendar", tint: Theme.accent) {
            let weekLow = days.map(\.lowC).min() ?? 0
            let weekHigh = days.map(\.highC).max() ?? 1
            let span = max(1, weekHigh - weekLow)
            VStack(spacing: 0) {
                ForEach(days) { d in
                    dayRow(d, weekLow: weekLow, span: span)
                    if expanded.contains(d.date) {
                        dayDetail(d)
                    }
                }
            }
        }
    }

    // dayRow is one tappable summary line.
    private func dayRow(_ d: DailyPoint, weekLow: Double, span: Double) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) {
                if expanded.contains(d.date) {
                    expanded.remove(d.date)
                } else {
                    expanded.insert(d.date)
                }
            }
            Haptics.tick()
        } label: {
            HStack(spacing: 10) {
                        Text(d.date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .frame(width: 40, alignment: .leading)
                        Image(systemName: conditionSymbol(d.condition, night: false))
                            .font(.system(size: 14))
                            .foregroundStyle(tempColor(d.highC))
                            .frame(width: 22)
                        Text("\(d.precipProb)%")
                            .font(.caption)
                            .foregroundStyle(d.precipProb >= 30 ? Theme.rain : Theme.muted)
                            .frame(width: 34, alignment: .trailing)
                        Text("\(f(d.lowC))°")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(tempColor(d.lowC))
                            .frame(width: 32, alignment: .trailing)
                        if style == "compact" {
                            Text(d.condition)
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            GeometryReader { geo in
                                let x = (d.lowC - weekLow) / span * geo.size.width
                                let w = max(8, (d.highC - d.lowC) / span * geo.size.width)
                                Capsule()
                                    .fill(Theme.hair)
                                    .frame(height: 5)
                                    .frame(maxHeight: .infinity, alignment: .center)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [tempColor(d.lowC), tempColor(d.highC)],
                                            startPoint: .leading, endPoint: .trailing)
                                    )
                                    .frame(width: w, height: 5)
                                    .offset(x: x)
                                    .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .frame(height: 20)
                        }
                Text("\(f(d.highC))°")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(tempColor(d.highC))
                    .frame(width: 34, alignment: .trailing)
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // dayDetail is the expanded readout for one day.
    private func dayDetail(_ d: DailyPoint) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let hi = d.apparentHighC, let lo = d.apparentLowC {
                Stat(label: "Feels", value: "\(f(lo))° to \(f(hi))°", icon: "thermometer.medium", tint: Theme.accent)
            }
            if let sum = d.precipSumMM {
                Stat(label: "Rain total", value: String(format: "%.2f in", sum * 0.0393701), icon: "drop.fill", tint: Theme.rain)
            }
            Stat(label: "UV max", value: String(format: "%.0f", d.uvIndexMax), icon: "sun.max.fill", tint: Theme.yellow)
            if let wind = d.windMaxKph {
                Stat(label: "Wind max", value: "\(mph(wind)) \(unitSpeed())", icon: "wind", tint: Theme.green)
            }
            if let gust = d.windGustMaxKph {
                Stat(label: "Gusts", value: "\(mph(gust)) \(unitSpeed())", icon: "wind.circle.fill", tint: Theme.teal)
            }
            if let daylight = d.daylightSec {
                Stat(label: "Daylight", value: String(format: "%.1f h", daylight / 3600), icon: "sun.horizon.fill", tint: Theme.accent)
            }
            Stat(label: "Sunrise", value: d.sunrise.formatted(date: .omitted, time: .shortened), icon: "sunrise.fill", tint: Theme.accent)
            Stat(label: "Sunset", value: d.sunset.formatted(date: .omitted, time: .shortened), icon: "sunset.fill", tint: Theme.accent)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Theme.hair.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// DetailsCard is the stat grid with sunrise and sunset.
struct DetailsCard: View {
    let current: Current
    let today: DailyPoint?

    var body: some View {
        GlassSection(title: "Details grid", icon: "square.grid.2x2.fill", tint: Theme.muted) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                Stat(label: "UV index", value: String(format: "%.1f", current.uvIndex))
                Stat(label: "Dew point", value: "\(f(current.dewPointC))°")
                Stat(label: "Wind gust", value: "\(mph(current.windGustKph)) \(unitSpeed())")
                Stat(label: "Pressure", value: String(format: "%.2f inHg", current.pressureHPa * 0.02953))
                Stat(label: "Visibility", value: String(format: "%.1f mi", current.visibilityKm * 0.621371))
                Stat(label: "Cloud cover", value: "\(current.cloudCover)%")
                if let today {
                    Stat(label: "Sunrise", value: today.sunrise.formatted(date: .omitted, time: .shortened))
                    Stat(label: "Sunset", value: today.sunset.formatted(date: .omitted, time: .shortened))
                }
            }
        }
    }
}

// Stat is one labeled value, with an optional tinted icon chip that gives the
// number a color identity.
struct Stat: View {
    let label: String
    let value: String
    var icon: String? = nil
    var tint: Color = Theme.muted

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 7))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 9.5, weight: .medium))
                    .kerning(0.5)
                    .foregroundStyle(Theme.muted)
                Text(value)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// AirCard is the air quality readout.
struct AirCard: View {
    let air: AirQuality

    var body: some View {
        GlassSection(title: "Air quality", icon: "aqi.medium", tint: Theme.green) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(air.usAqi)")
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .foregroundStyle(aqiColor(air.usAqi))
                VStack(alignment: .leading, spacing: 0) {
                    Text(air.category).font(.headline).foregroundStyle(Theme.text)
                    Text("US AQI").font(.caption).foregroundStyle(Theme.muted)
                }
            }
            HStack(spacing: 18) {
                Stat(label: "PM2.5", value: String(format: "%.1f", air.pm25))
                Stat(label: "PM10", value: String(format: "%.0f", air.pm10))
                Stat(label: "Ozone", value: String(format: "%.0f", air.ozone))
                Stat(label: "NO2", value: String(format: "%.0f", air.no2))
            }
        }
    }

    // aqiColor maps a US AQI value to its standard category color.
    private func aqiColor(_ aqi: Int) -> Color {
        switch aqi {
        case ...50: return Color(red: 0.247, green: 0.714, blue: 0.545)
        case ...100: return Color(red: 0.878, green: 0.69, blue: 0.251)
        case ...150: return Color(red: 0.878, green: 0.525, blue: 0.251)
        case ...200: return Color(red: 0.839, green: 0.329, blue: 0.329)
        case ...300: return Color(red: 0.608, green: 0.427, blue: 0.839)
        default: return Color(red: 0.545, green: 0.227, blue: 0.227)
        }
    }
}

// PollenCard is the allergen readout: today's index and triggers, with a peek at
// tomorrow.
struct PollenCard: View {
    let pollen: Pollen

    var body: some View {
        GlassSection(title: "Allergens", icon: "allergens", tint: Theme.amber) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(String(format: "%.1f", pollen.today.index))
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .foregroundStyle(pollenColor(pollen.today.index))
                VStack(alignment: .leading, spacing: 0) {
                    Text(pollen.today.category).font(.headline).foregroundStyle(Theme.text)
                    Text("Pollen index").font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(String(format: "%.1f", pollen.tomorrow.index))
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(pollenColor(pollen.tomorrow.index))
                    Text("Tomorrow").font(.caption).foregroundStyle(Theme.muted)
                }
            }
            PollenScaleBar(index: pollen.today.index)
            if !pollen.today.triggers.isEmpty {
                HStack(spacing: 8) {
                    ForEach(pollen.today.triggers, id: \.self) { trigger in
                        Text(trigger)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Theme.amber.opacity(0.15), in: Capsule())
                            .foregroundStyle(Theme.text)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

}

// pollenColor maps a Pollen.com index of zero to twelve to the shared severity
// colors, matching the air-quality bands.
func pollenColor(_ index: Double) -> Color {
    switch index {
    case ..<2.5: return Color(red: 0.247, green: 0.714, blue: 0.545)
    case ..<4.9: return Color(red: 0.878, green: 0.69, blue: 0.251)
    case ..<7.3: return Color(red: 0.878, green: 0.525, blue: 0.251)
    case ..<9.7: return Color(red: 0.839, green: 0.329, blue: 0.329)
    default: return Color(red: 0.545, green: 0.227, blue: 0.227)
    }
}

// PollenScaleBar is the zero to twelve severity gradient with a marker at the
// index, shared by the card and its detail.
struct PollenScaleBar: View {
    let index: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.247, green: 0.714, blue: 0.545),
                            Color(red: 0.878, green: 0.69, blue: 0.251),
                            Color(red: 0.878, green: 0.525, blue: 0.251),
                            Color(red: 0.839, green: 0.329, blue: 0.329),
                            Color(red: 0.545, green: 0.227, blue: 0.227),
                        ],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(height: 6)
                    .frame(maxHeight: .infinity, alignment: .center)
                Circle()
                    .fill(Theme.text)
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 2))
                    .offset(x: min(max(0, geo.size.width * index / 12 - 6.5), geo.size.width - 13))
            }
        }
        .frame(height: 14)
    }
}

// PollenDetailView is the full allergen read shown when the card is tapped:
// today and tomorrow with the scale, the triggers, and what to do about it.
struct PollenDetailView: View {
    let pollen: Pollen
    @ObservedObject var family: FamilyStore
    @Environment(\.dismiss) private var dismiss
    @State private var showFamily = false

    var body: some View {
        MomentDetailScaffold(dismiss: dismiss) {
            DetailHeader(icon: "allergens", tint: Theme.amber, title: "Allergens",
                         when: "\(pollen.city), \(pollen.state)")
            dayBlock("Today", pollen.today)
            Text(advice(pollen.today.category))
                .font(.subheadline).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            familySection
            scaleLegend
            dayBlock("Tomorrow", pollen.tomorrow)
        }
        .sheet(isPresented: $showFamily) { FamilySheet(family: family) }
    }

    // familySection calls out each family member's day, or invites setup.
    private var familySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FOR YOUR PEOPLE").font(.caption2.weight(.bold)).kerning(1).foregroundStyle(Theme.muted)
                Spacer()
                Button("Edit") { showFamily = true }
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
            }
            if family.members.isEmpty {
                Button { showFamily = true } label: {
                    Text("Add your family to get each person's allergens called out by name.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(pollenCallouts(pollen, members: family.members)) { callout in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: callout.hit ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(callout.hit ? Theme.amber : Theme.green)
                        Text(callout.note).font(.subheadline).foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // dayBlock renders one day's index, category, scale, and triggers.
    private func dayBlock(_ label: String, _ day: PollenDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(String(format: "%.1f", day.index))
                    .font(.system(size: 44, weight: .semibold, design: .serif))
                    .foregroundStyle(pollenColor(day.index))
                VStack(alignment: .leading, spacing: 0) {
                    Text(day.category).font(.title3.weight(.semibold)).foregroundStyle(Theme.text)
                    Text(label).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            PollenScaleBar(index: day.index)
            if !day.triggers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TRIGGERS").font(.caption2.weight(.bold)).kerning(1).foregroundStyle(Theme.muted)
                    HStack(spacing: 8) {
                        ForEach(day.triggers, id: \.self) { trigger in
                            Text(trigger)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Theme.amber.opacity(0.15), in: Capsule())
                                .foregroundStyle(Theme.text)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // scaleLegend explains the zero to twelve bands.
    private var scaleLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THE SCALE").font(.caption2.weight(.bold)).kerning(1).foregroundStyle(Theme.muted)
            legendRow("Low", "0 to 2.4", Color(red: 0.247, green: 0.714, blue: 0.545))
            legendRow("Low-Moderate", "2.5 to 4.8", Color(red: 0.878, green: 0.69, blue: 0.251))
            legendRow("Moderate", "4.9 to 7.2", Color(red: 0.878, green: 0.525, blue: 0.251))
            legendRow("High", "7.3 to 9.6", Color(red: 0.839, green: 0.329, blue: 0.329))
            legendRow("Very High", "9.7 to 12", Color(red: 0.545, green: 0.227, blue: 0.227))
        }
        .padding(16)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // legendRow is one band in the scale legend.
    private func legendRow(_ name: String, _ range: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(name).font(.subheadline).foregroundStyle(Theme.text)
            Spacer()
            Text(range).font(.caption).foregroundStyle(Theme.muted)
        }
    }

    // advice gives what to do about a category.
    private func advice(_ category: String) -> String {
        switch category {
        case "Low", "Low-Moderate":
            return "Most people are fine today. If you are sensitive, keep your meds handy."
        case "Moderate":
            return "Allergy-prone folks will feel it. Take your meds before heading out."
        case "High":
            return "A rough day for allergies. Limit time outside, keep the windows shut, and shower after you have been out."
        default:
            return "Miserable for the sensitive. Stay in when you can, run the AC, and mask up if you must be out."
        }
    }
}

// UVCard is the ultraviolet readout: the index, its category, and sun advice.
struct UVCard: View {
    let uv: Double

    var body: some View {
        GlassSection(title: "UV index", icon: "sun.max.trianglebadge.exclamationmark.fill", tint: Theme.amber) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(Int(uv.rounded()))")
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .foregroundStyle(uvColor(uv))
                VStack(alignment: .leading, spacing: 0) {
                    Text(uvCategory(uv)).font(.headline).foregroundStyle(Theme.text)
                    Text("Peak today").font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                Text(uvAdvice(uv))
                    .font(.caption).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 150, alignment: .trailing)
            }
        }
    }

    // uvCategory bands the index by the WHO scale.
    private func uvCategory(_ uv: Double) -> String {
        switch uv {
        case ..<3: return "Low"
        case ..<6: return "Moderate"
        case ..<8: return "High"
        case ..<11: return "Very high"
        default: return "Extreme"
        }
    }

    // uvColor maps the index to the shared severity colors.
    private func uvColor(_ uv: Double) -> Color {
        switch uv {
        case ..<3: return Color(red: 0.247, green: 0.714, blue: 0.545)
        case ..<6: return Color(red: 0.878, green: 0.69, blue: 0.251)
        case ..<8: return Color(red: 0.878, green: 0.525, blue: 0.251)
        case ..<11: return Color(red: 0.839, green: 0.329, blue: 0.329)
        default: return Color(red: 0.545, green: 0.227, blue: 0.227)
        }
    }

    // uvAdvice gives the sun-protection guidance for the index.
    private func uvAdvice(_ uv: Double) -> String {
        switch uv {
        case ..<3: return "No protection needed."
        case ..<6: return "Hat and sunscreen if out a while."
        case ..<8: return "Sunscreen, hat, shade at midday."
        case ..<11: return "Cover up, SPF 30 plus, skip midday sun."
        default: return "Full cover and shade. Limit sun."
        }
    }
}

// AuroraCard is the northern-lights readout: the planetary Kp index, a level
// word, and whether the aurora is likely visible from here.
struct AuroraCard: View {
    let aurora: Aurora

    var body: some View {
        GlassSection(title: "Aurora", icon: "sparkles", tint: Theme.purple) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(String(format: "%.0f", aurora.kp))
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.purple)
                VStack(alignment: .leading, spacing: 0) {
                    Text(aurora.level).font(.headline).foregroundStyle(Theme.text)
                    Text("Kp index").font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                Label(aurora.visible ? "Visible tonight" : "Not visible here",
                      systemImage: aurora.visible ? "eye.fill" : "eye.slash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(aurora.visible ? Theme.green : Theme.muted)
            }
        }
    }
}

// WindCard shows the current wind speed and gusts with a compass pointing the way
// the wind is blowing.
struct WindCard: View {
    let current: Current

    var body: some View {
        GlassSection(title: "Wind", icon: "wind", tint: Theme.teal) {
            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(Theme.muted.opacity(0.3), lineWidth: 2)
                    Text("N").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.muted).offset(y: -28)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.teal)
                        .rotationEffect(.degrees(Double(current.windDirDeg) + 180))
                }
                .frame(width: 68, height: 68)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(mph(current.windKph))")
                            .font(.system(size: 30, weight: .semibold, design: .serif))
                            .foregroundStyle(Theme.text)
                        Text(unitSpeed()).font(.caption).foregroundStyle(Theme.muted)
                    }
                    Text("From the \(cardinal(current.windDirDeg))").font(.subheadline).foregroundStyle(Theme.muted)
                    Text("Gusts \(mph(current.windGustKph)) \(unitSpeed())").font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // cardinal names the compass direction a bearing points from.
    private func cardinal(_ deg: Int) -> String {
        let names = ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"]
        return names[Int((Double(deg) + 22.5) / 45) % 8]
    }
}

// ComfortCard reads humidity and dew point as a plain verdict on how the air
// feels, rather than repeating the raw gauges.
struct ComfortCard: View {
    let current: Current

    var body: some View {
        GlassSection(title: "Comfort", icon: "humidity.fill", tint: Theme.cyan) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(verdict(current.dewPointC))
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(current.humidity)%").font(.headline).foregroundStyle(Theme.text)
                    Text("Humidity").font(.caption).foregroundStyle(Theme.muted)
                }
            }
            Text(note(current.dewPointC)).font(.caption).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // verdict bands the dew point into a one-word read of the air.
    private func verdict(_ dewC: Double) -> String {
        switch dewC * 1.8 + 32 {
        case ..<50: return "Dry"
        case ..<60: return "Comfortable"
        case ..<65: return "Sticky"
        case ..<70: return "Muggy"
        default: return "Oppressive"
        }
    }

    // note explains the verdict in a sentence.
    private func note(_ dewC: Double) -> String {
        switch dewC * 1.8 + 32 {
        case ..<50: return "The air is dry. Easy to be out in, and it will feel cooler than the number."
        case ..<60: return "The air sits easy today. No stick, no strain."
        case ..<65: return "A little sticky. You will notice it working outside."
        case ..<70: return "Muggy. The air holds water, so it feels warmer than it reads."
        default: return "Oppressive. Heavy, wet air. Slow down and keep water close."
        }
    }
}

// MarineCard shows the coastal sea state: wave height, swell, and period. It is
// only built when the marine read is available, which is near a coast.
struct MarineCard: View {
    let marine: Marine

    var body: some View {
        GlassSection(title: "Sea state", icon: "water.waves", tint: Theme.cyan) {
            HStack(spacing: 18) {
                Stat(label: "Waves", value: height(marine.waveHeightM), icon: "water.waves", tint: Theme.cyan)
                Stat(label: "Swell", value: height(marine.swellHeightM), icon: "water.waves.and.arrow.down", tint: Theme.teal)
                Stat(label: "Period", value: "\(Int(marine.wavePeriodS.rounded())) s", icon: "timer", tint: Theme.muted)
            }
        }
    }

    // height renders a meter value in feet or meters to match the unit setting.
    private func height(_ meters: Double) -> String {
        if imperialUnits() {
            return String(format: "%.0f ft", meters * 3.28084)
        }
        return String(format: "%.1f m", meters)
    }
}

// FactCard is the bird's daily note from history: what happened on this date.
struct FactCard: View {
    let fact: Fact

    var body: some View {
        GlassSection(title: "On this day", icon: "book.fill", tint: Theme.violet) {
            Text(fact.text)
                .font(.subheadline)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            if fact.year > 0 {
                Text(String(fact.year))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}

// AlertsCard lists active severe weather alerts.
struct AlertsCard: View {
    let alerts: [WeatherAlert]

    var body: some View {
        GlassSection(title: "Alerts", icon: "exclamationmark.triangle.fill", tint: Theme.warn) {
            ForEach(alerts) { a in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        if !a.description.isEmpty {
                            Text(a.description).font(.footnote).foregroundStyle(Theme.muted)
                        }
                        if !a.instruction.isEmpty {
                            Text(a.instruction).font(.footnote.weight(.semibold)).foregroundStyle(Theme.text)
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.event)
                            .font(.headline)
                            .foregroundStyle(severityColor(a.severity))
                        Text(a.area)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .tint(Theme.muted)
            }
        }
    }

    // severityColor maps NWS severity to the shared color language.
    private func severityColor(_ s: String) -> Color {
        switch s {
        case "Extreme", "Severe": return Theme.warn
        case "Moderate": return Theme.amber
        default: return Theme.muted
        }
    }
}

// Chip is a small outlined metadata pill.
struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
    }
}
