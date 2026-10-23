import SwiftUI

// DayPlan is the skua's read on one upcoming day: its one-word character, a grade,
// the raw day behind it, and the most comfortable daylight hour to be out. The week
// strip renders a row per day and taps into a fuller read.
struct DayPlan: Identifiable {
    // day is the raw daily forecast this reads.
    let day: DailyPoint
    // label is the day's character in a word shown in the strip, like Scorcher or
    // Clear. It varies across a run of similar days so a hot week is not one word
    // repeated down the list.
    var label: String
    // category is the day's canonical character, stable where label varies. It
    // drives the voice lines and the week read.
    let category: String
    // tint colors the character.
    let tint: Color
    // grade is Good, Fair, or Rough, from the day's window.
    let grade: String
    // score ranks the day against the others, higher being kinder to be out in.
    let score: Double
    // best is the most comfortable daylight hour, when the hourly reaches that far.
    let best: HourlyPoint?
    var id: Date { day.date }
    // date is when the day is, for naming and ordering.
    var date: Date { day.date }
}

// FlightWeek reads the days past today as small arcs: which day to bank on, which
// to dodge, and a per-day character and window. It lives app-side because it leans
// on the plan-grading engine, which the widget target does not compile.
enum FlightWeek {
    // upcoming is how many days past today the week reads.
    private static let upcoming = 6

    // plans reads the days past today into per-day arcs. Today is left out: the
    // flight-plan tiles above already fly it. Capped for a clean strip.
    static func plans(for forecast: Forecast) -> [DayPlan] {
        let base = Array(forecast.daily.dropFirst().prefix(upcoming)).map { day -> DayPlan in
            let stats = WindowStats(
                tempMinC: day.lowC, tempMaxC: day.highC,
                feelsMaxC: day.apparentHighC ?? day.highC,
                rain: day.precipProb,
                gustKph: day.windGustMaxKph ?? day.windMaxKph ?? 0,
                uv: day.uvIndexMax)
            let graded = gradeFromStats(stats)
            let mark = character(hazard: graded.hazard, stats: stats, day: day)
            return DayPlan(
                day: day, label: mark.label, category: mark.label, tint: mark.tint,
                grade: graded.grade, score: statsScore(stats),
                best: bestDaylightHour(for: day, in: forecast))
        }
        return varyLabels(base)
    }

    // heatWords are the strip words for a run of hot days, strongest first, so a
    // week of furnaces reads with variety instead of one repeated adjective.
    private static let heatWords = ["Scorcher", "Brutal", "Baking", "Sweltering", "Roaster", "Sizzler"]

    // wetWords are the strip words for a run of wet days, wettest first.
    private static let wetWords = ["Washout", "Soaker", "Drizzly", "Showers", "Spotty", "Damp"]

    // varyLabels breaks up runs of the same character so a hot or wet week does not
    // read as a single word repeated. Days sharing a category are ranked by
    // intensity and given distinct words from that category's pool, strongest
    // first. A lone day of a category keeps its canonical word.
    private static func varyLabels(_ plans: [DayPlan]) -> [DayPlan] {
        var result = plans
        assignPool(&result, categories: ["Scorcher", "Hot"], words: heatWords) {
            $0.day.apparentHighC ?? $0.day.highC
        }
        assignPool(&result, categories: ["Washout", "Wet", "Showers"], words: wetWords) {
            Double($0.day.precipProb)
        }
        return result
    }

    // assignPool spreads a word pool across the days whose category is in the set,
    // ordered by intensity so the strongest day takes the first word. It leaves a
    // single such day untouched, since one word does not repeat.
    private static func assignPool(
        _ plans: inout [DayPlan], categories: Set<String>, words: [String],
        intensity: (DayPlan) -> Double
    ) {
        let indices = plans.indices.filter { categories.contains(plans[$0].category) }
        guard indices.count > 1 else { return }
        let ranked = indices.sorted { intensity(plans[$0]) > intensity(plans[$1]) }
        for (rank, index) in ranked.enumerated() {
            plans[index].label = words[min(rank, words.count - 1)]
        }
    }

    // read is the week in one plain line: the day to bank on and the day to dodge,
    // in the skua's voice. Nil when there are too few days to compare.
    static func read(_ days: [DayPlan]) -> String? {
        guard days.count >= 2 else { return nil }
        guard let best = days.max(by: { $0.score < $1.score }),
            let worst = days.min(by: { $0.score < $1.score }) else { return nil }
        let bestName = dayName(best.date)
        let worstName = dayName(worst.date)
        let spread = best.score - worst.score
        let worstBad = worst.grade == "Rough" || isWet(worst.category)
        let bestGood = best.grade == "Good" && best.score >= 55

        if bestGood, worstBad, best.id != worst.id {
            return "\(bestName)'s the one to bank on. \(worstName) \(knock(worst)), so plan around it."
        }
        if worstBad, best.id != worst.id {
            return "\(worstName) \(knock(worst)). Bank the better days around it."
        }
        if bestGood {
            return "\(bestName)'s the pick of the week. The rest are fine, just nothing to write home about."
        }
        if spread < 8 {
            return "A steady stretch out there. No standout, no disaster, same beak every morning."
        }
        return "\(bestName) edges out the week. Not dramatic, but it's your best shot at outside."
    }

    // take is the skua's read on a single day, for the day's detail sheet.
    static func take(for dp: DayPlan) -> String {
        let n = dayName(dp.date)
        switch dp.category {
        case "Washout": return "\(n) drowns. Stay in, keep dry, and don't come crying to me for an umbrella."
        case "Wet", "Showers": return "\(n) turns wet in patches. Keep a jacket close and your plans loose."
        case "Scorcher": return "\(n) is a furnace. Do your outside business at dawn or not at all."
        case "Hot": return "\(n) runs hot. Chase shade and drink more than you think you need."
        case "Frozen": return "\(n) freezes hard. Layer like you owe it money and mind the pipes."
        case "Cold": return "\(n) bites. Real-coat weather, not the fashion one."
        case "Windy": return "\(n) howls. Anything you leave loose is mine by nightfall."
        case "Fog": return "\(n) fogs in. Lights on, slow down, and don't trust the distance."
        case "Cloudy": return "\(n) stays gray, but it holds off. No real excuse not to get out."
        default: return "\(n) behaves. Nothing to dodge, so use it before the week turns."
        }
    }

    // daylight is a day's daytime hours, thinned to keep the detail list short.
    static func daylight(for day: DailyPoint, in forecast: Forecast) -> [HourlyPoint] {
        let hours = daylightRaw(for: day, in: forecast)
        guard hours.count > 7 else { return hours }
        return hours.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element)
    }

    // dayName names a day for prose: Tomorrow, then the weekday.
    static func dayName(_ date: Date) -> String {
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    // shortDay names a day for a tight row: Tmrw, then the short weekday.
    static func shortDay(_ date: Date) -> String {
        if Calendar.current.isDateInTomorrow(date) { return "Tmrw" }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }

    // character turns a day's dominant hazard into a punchy word and a color.
    private static func character(hazard: String, stats s: WindowStats, day: DailyPoint) -> (label: String, tint: Color) {
        switch hazard {
        case "rain": return s.rain >= 70 ? ("Washout", Theme.rain) : ("Wet", Theme.rain)
        case "heat": return s.feelsMaxC >= 35 ? ("Scorcher", tempColor(day.highC)) : ("Hot", tempColor(day.highC))
        case "cold": return s.tempMinC <= -6 ? ("Frozen", Theme.blue) : ("Cold", Theme.blue)
        case "wind": return ("Windy", Theme.teal)
        default:
            let cond = day.condition.lowercased()
            if s.rain >= 35 { return ("Showers", Theme.rain) }
            if cond.contains("fog") || cond.contains("mist") { return ("Fog", Theme.slate) }
            if cond.contains("cloud") || cond.contains("overcast") { return ("Cloudy", Theme.slate) }
            // A plain clear day reads calm. Green is saved for the week's pick.
            return ("Clear", Theme.muted)
        }
    }

    // knock names how a bad day misbehaves, for the week read.
    private static func knock(_ dp: DayPlan) -> String {
        switch dp.category {
        case "Washout": return "drowns"
        case "Wet", "Showers": return "turns wet"
        case "Scorcher", "Hot": return "cooks"
        case "Frozen", "Cold": return "bites"
        case "Windy": return "howls"
        default: return "sulks"
        }
    }

    // isWet reports whether a label reads as a wet day.
    private static func isWet(_ category: String) -> Bool {
        category == "Washout" || category == "Wet" || category == "Showers"
    }

    // bestDaylightHour is the most comfortable daytime hour, when the hourly
    // forecast still reaches that day.
    private static func bestDaylightHour(for day: DailyPoint, in forecast: Forecast) -> HourlyPoint? {
        daylightRaw(for: day, in: forecast).max(by: { hourScore($0) < hourScore($1) })
    }

    // hourScore rates a single hour for being outside, reusing the window scorer.
    private static func hourScore(_ h: HourlyPoint) -> Double {
        guard let s = windowStats([h]) else { return 0 }
        return statsScore(s)
    }

    // daylightRaw is a day's daytime hours, from sunrise to sunset when known,
    // else the whole calendar day.
    private static func daylightRaw(for day: DailyPoint, in forecast: Forecast) -> [HourlyPoint] {
        if day.sunset > day.sunrise, day.sunrise.timeIntervalSince1970 > 0 {
            return forecast.hourly.filter { $0.time >= day.sunrise && $0.time <= day.sunset }
        }
        let end = day.date.addingTimeInterval(86400)
        return forecast.hourly.filter { $0.time >= day.date && $0.time < end }
    }
}

// WeekAhead extends the flight plan past today: a one-line week read in the bird's
// voice, then a tappable arc per upcoming day. It self-hides with too few days.
struct WeekAhead: View {
    let forecast: Forecast
    @State private var selected: DayPlan?

    var body: some View {
        let days = FlightWeek.plans(for: forecast)
        if days.count >= 2, let read = FlightWeek.read(days) {
            let bestID = days.max(by: { $0.score < $1.score })?.id
            VStack(alignment: .leading, spacing: 12) {
                Rectangle().fill(Theme.hair).frame(height: 1).padding(.vertical, 4)
                Text("THE WEEK AHEAD")
                    .font(.system(size: 11, weight: .semibold)).kerning(1.2)
                    .foregroundStyle(Theme.muted)
                Text(read)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    ForEach(days) { dp in
                        Button {
                            selected = dp
                            Haptics.tick()
                        } label: {
                            dayRow(dp, isBest: dp.id == bestID)
                        }
                        .buttonStyle(.plain)
                        if dp.id != days.last?.id {
                            Rectangle().fill(Theme.hair).frame(height: 1)
                        }
                    }
                }
            }
            .padding(.top, 6)
            .sheet(item: $selected) { dp in DayPlanSheet(day: dp, forecast: forecast) }
        }
    }

    // dayRow is one tappable day: weekday, sky, character, rain, and the range.
    private func dayRow(_ dp: DayPlan, isBest: Bool) -> some View {
        let showBest = isBest && dp.grade == "Good"
        let label = showBest ? "Best" : dp.label
        let tint = showBest ? Theme.green : dp.tint
        return HStack(spacing: 10) {
            Text(FlightWeek.shortDay(dp.date))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 44, alignment: .leading)
            Image(systemName: conditionSymbol(dp.day.condition, night: false))
                .font(.system(size: 15))
                .symbolRenderingMode(.multicolor)
                .frame(width: 24)
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold)).kerning(0.5)
                .foregroundStyle(tint)
                .lineLimit(1)
                .frame(width: 78, alignment: .leading)
            if dp.day.precipProb >= 30 {
                Text("\(dp.day.precipProb)%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.rain)
            }
            Spacer(minLength: 4)
            Text("\(f(dp.day.lowC))°")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.muted)
            Text("\(f(dp.day.highC))°")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(tempColor(dp.day.highC))
                .frame(width: 38, alignment: .trailing)
            Image(systemName: "chevron.forward")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.muted.opacity(0.4))
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// DayPlanSheet is the detail behind a tapped day: the bird's read, the day's best
// window to be out, its stats, the shape of its daylight, and a reminder.
struct DayPlanSheet: View {
    let day: DayPlan
    let forecast: Forecast
    @Environment(\.dismiss) private var dismiss
    @State private var reminded = false

    private var hours: [HourlyPoint] { FlightWeek.daylight(for: day.day, in: forecast) }
    private var when: String {
        "\(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) · High \(f(day.day.highC))° · Low \(f(day.day.lowC))°"
    }

    var body: some View {
        MomentDetailScaffold(dismiss: dismiss) {
            DetailHeader(
                icon: conditionSymbol(day.day.condition, night: false), tint: day.tint,
                title: FlightWeek.dayName(day.date), when: when)
            BirdRead(text: FlightWeek.take(for: day))
            DayStatsRow(day: day.day)
            if let best = day.best { WindowPick(point: best) }
            if !hours.isEmpty { HourWindow(hours: hours) }
            if let best = day.best, best.time > Date() {
                RemindButton(
                    at: best.time, title: "\(FlightWeek.dayName(day.date)) — best window",
                    message: FlightWeek.take(for: day), reminded: $reminded)
            }
        }
    }
}

// DayStatsRow shows a day's headline numbers: rain odds, peak UV, and top wind.
struct DayStatsRow: View {
    let day: DailyPoint
    var body: some View {
        HStack(spacing: 10) {
            stat(icon: "umbrella.fill", tint: Theme.rain, value: "\(day.precipProb)%", unit: "rain")
            stat(icon: "sun.max.fill", tint: Theme.amber, value: "\(Int(day.uvIndexMax.rounded()))", unit: "UV")
            if let w = day.windMaxKph {
                stat(icon: "wind", tint: Theme.teal, value: "\(mph(w))", unit: unitSpeed())
            }
        }
    }

    // stat is one labeled figure in the row.
    private func stat(icon: String, tint: Color, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(tint)
            Text(value).font(.system(size: 17, weight: .semibold, design: .serif)).foregroundStyle(Theme.text)
            Text(unit).font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// WindowPick calls out the day's best hour to be outside.
struct WindowPick: View {
    let point: HourlyPoint
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "figure.walk").font(.system(size: 15)).foregroundStyle(Theme.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Best window").font(.system(size: 11, weight: .semibold)).kerning(0.5).foregroundStyle(Theme.muted)
                Text("Around \(point.time.formatted(.dateTime.hour())), \(f(point.tempC))° and \(point.condition.lowercased()).")
                    .font(.subheadline).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
