import CoreLocation
import Foundation
import SwiftUI

// PlanKind is the flavor of a plan, driving its icon and the bird's advice.
enum PlanKind: String, Codable, CaseIterable, Identifiable {
    case run, ride, hike, camp, swim, trip, event

    var id: String { rawValue }

    // icon marks the kind.
    var icon: String {
        switch self {
        case .run: return "figure.run"
        case .ride: return "bicycle"
        case .hike: return "figure.hiking"
        case .camp: return "tent.fill"
        case .swim: return "figure.open.water.swim"
        case .trip: return "airplane"
        case .event: return "star.fill"
        }
    }

    // tint colors the kind.
    var tint: Color {
        switch self {
        case .run: return Theme.green
        case .ride: return Theme.teal
        case .hike: return Theme.amber
        case .camp: return Theme.purple
        case .swim: return Theme.rain
        case .trip: return Theme.cyan
        case .event: return Theme.yellow
        }
    }

    // label names the kind.
    var label: String { rawValue.capitalized }
}

// Plan is one thing you intend to do in the weather.
struct Plan: Codable, Identifiable, Equatable {
    var id: UUID
    // title is your name for it.
    var title: String
    // kind flavors the advice.
    var kind: PlanKind
    // start is when it begins.
    var start: Date
    // hours is how long it runs.
    var hours: Int
    // place pins a saved location, nil meaning wherever you are.
    var place: SavedPlace?

    // end is when it wraps.
    var end: Date { start.addingTimeInterval(Double(hours) * 3600) }

    // whenText renders the window compactly.
    var whenText: String {
        if hours >= 24 {
            let endDay = start.addingTimeInterval(Double(hours - 1) * 3600)
            return "\(start.formatted(.dateTime.month(.abbreviated).day())) to \(endDay.formatted(.dateTime.month(.abbreviated).day()))"
        }
        if Calendar.current.isDateInToday(start) {
            return "Today \(start.formatted(date: .omitted, time: .shortened))"
        }
        return start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour())
    }
}

// PlanVerdict is the bird's read on a plan's window.
struct PlanVerdict {
    // grade is Good, Fair, or Rough.
    let grade: String
    // color matches the grade.
    let color: Color
    // line is the bird's call.
    let line: String
    // lo and hi bound the display temperatures for the window.
    let lo: Int
    let hi: Int
    // rainMax is the peak rain chance.
    let rainMax: Int
    // gustMax is the peak gust in display units.
    let gustMax: Int
    // uvMax is the peak UV.
    let uvMax: Double
}

// PlansStore persists the plans.
@MainActor
final class PlansStore: ObservableObject {
    // plans is the list, soonest first.
    @Published var plans: [Plan] {
        didSet { save() }
    }

    private static let storageKey = "skua.plans"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let saved = try? JSONDecoder().decode([Plan].self, from: data) {
            plans = saved.sorted { $0.start < $1.start }
        } else {
            plans = []
        }
    }

    // add inserts a plan in time order.
    func add(_ plan: Plan) {
        plans.append(plan)
        plans.sort { $0.start < $1.start }
    }

    // remove drops a plan.
    func remove(_ id: UUID) {
        plans.removeAll { $0.id == id }
    }

    // shift moves a plan's start by the given hours and reorders the list.
    func shift(_ id: UUID, byHours hours: Int) {
        guard let i = plans.firstIndex(where: { $0.id == id }) else { return }
        plans[i].start = plans[i].start.addingTimeInterval(Double(hours) * 3600)
        plans.sort { $0.start < $1.start }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(plans) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// WindowStats are the hazard-relevant peaks and floors across a set of hours.
struct WindowStats {
    // tempMinC is the lowest temperature in the window.
    let tempMinC: Double
    // tempMaxC is the highest temperature in the window.
    let tempMaxC: Double
    // feelsMaxC is the highest apparent temperature in the window.
    let feelsMaxC: Double
    // rain is the peak precipitation chance.
    let rain: Int
    // gustKph is the peak gust.
    let gustKph: Double
    // uv is the peak UV index.
    let uv: Double
}

// windowStats pulls the hazard peaks from a set of hours, nil when empty.
func windowStats(_ hours: [HourlyPoint]) -> WindowStats? {
    guard !hours.isEmpty else { return nil }
    let temps = hours.map(\.tempC)
    let feels = hours.compactMap(\.apparentTempC)
    return WindowStats(
        tempMinC: temps.min() ?? 20,
        tempMaxC: temps.max() ?? 20,
        feelsMaxC: feels.max() ?? temps.max() ?? 20,
        rain: hours.map(\.precipProb).max() ?? 0,
        gustKph: hours.compactMap(\.windGustKph).max() ?? 0,
        uv: hours.compactMap(\.uvIndex).max() ?? 0)
}

// gradeFromStats classifies a window's dominant hazard and severity.
func gradeFromStats(_ s: WindowStats) -> (grade: String, hazard: String, rough: Bool) {
    let hazard: String
    if s.rain >= 50 {
        hazard = "rain"
    } else if s.feelsMaxC >= 36 {
        hazard = "heat"
    } else if s.gustKph >= 50 {
        hazard = "wind"
    } else if s.tempMinC <= 0 {
        hazard = "cold"
    } else {
        hazard = "clear"
    }
    let rough = s.rain >= 60 || s.feelsMaxC >= 38 || s.gustKph >= 60 || s.tempMinC <= -8
    let grade = hazard == "clear" ? "Good" : rough ? "Rough" : "Fair"
    return (grade, hazard, rough)
}

// gradeColor maps a grade to its color.
func gradeColor(_ grade: String) -> Color {
    grade == "Good" ? Theme.green : grade == "Fair" ? Theme.amber : Theme.warn
}

// statsScore rates a window higher when it is drier, calmer, and milder, so two
// candidate windows can be compared.
func statsScore(_ s: WindowStats) -> Double {
    var score = 100.0
    score -= Double(s.rain) * 1.2
    if s.feelsMaxC > 30 { score -= (s.feelsMaxC - 30) * 3 }
    if s.tempMinC < 5 { score -= (5 - s.tempMinC) * 2.5 }
    if s.gustKph > 30 { score -= (s.gustKph - 30) * 0.7 }
    if s.uv > 7 { score -= (s.uv - 7) * 1.5 }
    return score
}

// gradeWindow grades one time window from an already-fetched forecast, falling
// back to the daily rows beyond the hourly horizon.
func gradeWindow(_ fc: Forecast, start: Date, end: Date, kind: PlanKind) -> PlanVerdict? {
    var stats = windowStats(fc.hourly.filter { $0.time >= start && $0.time <= end })
    if stats == nil {
        let days = fc.daily.filter { $0.date >= start.addingTimeInterval(-86400) && $0.date <= end }
        guard !days.isEmpty else { return nil }
        stats = WindowStats(
            tempMinC: days.map(\.lowC).min() ?? 20,
            tempMaxC: days.map(\.highC).max() ?? 20,
            feelsMaxC: days.compactMap(\.apparentHighC).max() ?? (days.map(\.highC).max() ?? 20),
            rain: days.map(\.precipProb).max() ?? 0,
            gustKph: days.compactMap(\.windGustMaxKph).max() ?? 0,
            uv: days.map(\.uvIndexMax).max() ?? 0)
    }
    guard let s = stats else { return nil }
    let g = gradeFromStats(s)
    return PlanVerdict(
        grade: g.grade, color: gradeColor(g.grade),
        line: planLine(kind: kind, hazard: g.hazard, rough: g.rough),
        lo: f(s.tempMinC), hi: f(s.tempMaxC),
        rainMax: s.rain, gustMax: mph(s.gustKph), uvMax: s.uv)
}

// gradeEvent grades a calendar event like a plan, but reads the window as an arc
// and advises coping instead of rescheduling, since an event on your calendar
// usually cannot simply move.
func gradeEvent(_ fc: Forecast, event: CalEvent) -> PlanVerdict? {
    guard let v = gradeWindow(fc, start: event.start, end: event.end, kind: .event) else { return nil }
    return PlanVerdict(
        grade: v.grade, color: v.color,
        line: eventLine(fc, start: event.start, end: event.end, base: v),
        lo: v.lo, hi: v.hi, rainMax: v.rainMax, gustMax: v.gustMax, uvMax: v.uvMax)
}

// eventLine reads a calendar event's window as an arc: how it starts, where it
// heads, and how to cope. It leads with survival, not a reschedule, and offers a
// shift only as a soft option, since the event may be fixed.
func eventLine(_ fc: Forecast, start: Date, end: Date, base v: PlanVerdict) -> String {
    let hours = fc.hourly.filter { $0.time >= start && $0.time <= end }
    guard let first = hours.first,
        let peak = hours.max(by: { $0.tempC < $1.tempC }),
        let stats = windowStats(hours) else { return v.line }
    let g = gradeFromStats(stats)
    let startT = f(first.tempC)
    let peakT = f(peak.tempC)
    let peakWhen = peak.time.formatted(.dateTime.hour())
    let risesIntoIt = peak.tempC - first.tempC >= 4

    switch g.hazard {
    case "heat":
        return risesIntoIt
            ? "Starts easy near \(startT)°, then bakes to \(peakT)° by \(peakWhen). Dress light, keep water close, and slide it earlier if the time's loose."
            : "Hot the whole block, up to \(peakT)°. Shade, water, and dress for it."
    case "rain":
        return g.rough
            ? "Rain sits right on it. You're likely locked in, so pack real cover and mind the footing."
            : "Showers drift through. Stash a jacket and carry on."
    case "wind":
        return g.rough
            ? "Gusts kick up mid-event. Pin down anything loose and brace."
            : "Breezy across it, nothing you can't handle."
    case "cold":
        return g.rough
            ? "Hard cold sits over it, down to \(f(stats.tempMinC))°. Layer up; it's not moving and neither is the chill."
            : "Chilly the whole way. Bring the real coat."
    default:
        return "Sky's on your side for this one. Go do your thing."
    }
}

// ShiftSuggestion is the bird's better time for a plan, a signed hour shift.
struct ShiftSuggestion {
    // deltaHours is how far to move the start, positive for later.
    let deltaHours: Int
    // line is the bird's pitch for the move.
    let line: String
    // grade is the grade at the shifted window.
    let grade: String
    // color matches the shifted grade.
    let color: Color
}

// TideNote is the coastal water read for a swim window.
struct TideNote {
    // line is the tide call.
    let line: String
    // color matches the call's mood.
    let color: Color
}

// PlanScout is the full read on a plan: its verdict, an optional better time,
// and, for coastal swims, the tide.
struct PlanScout {
    // verdict grades the chosen window.
    let verdict: PlanVerdict
    // suggestion is a better nearby start, when one clearly beats the choice.
    let suggestion: ShiftSuggestion?
    // tide is the water read for coastal swims.
    let tide: TideNote?
}

// scoutPlan fetches the forecast once, grades the window, hunts an hour or two
// away for a better start, and reads the tide for coastal swims.
func scoutPlan(_ plan: Plan, fallback: CLLocationCoordinate2D) async -> PlanScout? {
    let lat = plan.place?.lat ?? fallback.latitude
    let lon = plan.place?.lon ?? fallback.longitude
    guard let fc = try? await SkuaClient.shared.forecast(lat: lat, lon: lon) else { return nil }
    guard let verdict = gradeWindow(fc, start: plan.start, end: plan.end, kind: plan.kind) else { return nil }

    let suggestion = bestShift(fc, plan: plan)

    var tide: TideNote?
    if plan.kind == .swim,
        let t = try? await SkuaClient.shared.tides(lat: lat, lon: lon), t.available, !t.events.isEmpty {
        tide = tideNote(t, start: plan.start, end: plan.end)
    }
    return PlanScout(verdict: verdict, suggestion: suggestion, tide: tide)
}

// bestShift looks an hour or two on either side of a sub-daily plan for a
// clearly better window and pitches the move when it finds one.
func bestShift(_ fc: Forecast, plan: Plan) -> ShiftSuggestion? {
    guard plan.hours < 24 else { return nil }
    let baseHours = fc.hourly.filter { $0.time >= plan.start && $0.time <= plan.end }
    guard let base = windowStats(baseHours) else { return nil }
    let baseScore = statsScore(base)

    var best: (delta: Int, stats: WindowStats, score: Double)?
    for delta in [-2, -1, 1, 2] {
        let shiftedStart = plan.start.addingTimeInterval(Double(delta) * 3600)
        let shiftedEnd = plan.end.addingTimeInterval(Double(delta) * 3600)
        if shiftedStart < Date() { continue }
        let hours = fc.hourly.filter { $0.time >= shiftedStart && $0.time <= shiftedEnd }
        guard hours.count >= baseHours.count, let stats = windowStats(hours) else { continue }
        let score = statsScore(stats)
        if best == nil || score > best!.score { best = (delta, stats, score) }
    }
    guard let b = best, b.score > baseScore + 12 else { return nil }
    let g = gradeFromStats(b.stats)
    return ShiftSuggestion(
        deltaHours: b.delta, line: shiftReason(delta: b.delta, base: base, shifted: b.stats),
        grade: g.grade, color: gradeColor(g.grade))
}

// shiftReason names the biggest reason a shifted window beats the chosen one.
func shiftReason(delta: Int, base: WindowStats, shifted: WindowStats) -> String {
    let when: String
    switch delta {
    case 1: when = "an hour later"
    case -1: when = "an hour earlier"
    case let d where d > 0: when = "\(d) hours later"
    default: when = "\(-delta) hours earlier"
    }
    if base.rain - shifted.rain >= 20 { return "Go \(when), the rain clears by then." }
    if base.feelsMaxC - shifted.feelsMaxC >= 3 { return "Go \(when), the heat backs off." }
    if base.gustKph - shifted.gustKph >= 12 { return "Go \(when), the wind settles." }
    if shifted.tempMinC - base.tempMinC >= 3 { return "Go \(when), it warms up a touch." }
    return "Go \(when), the window looks kinder."
}

// tideNote reads the water for a swim window: which extreme lands nearest, and
// whether that means easy depth or a shallow, rocky wade.
func tideNote(_ tides: Tides, start: Date, end: Date) -> TideNote? {
    let mid = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
    guard let nearest = tides.events.min(by: {
        abs($0.time.timeIntervalSince(mid)) < abs($1.time.timeIntervalSince(mid))
    }) else { return nil }
    let at = nearest.time.formatted(date: .omitted, time: .shortened)
    let near = nearest.time >= start.addingTimeInterval(-3600)
        && nearest.time <= end.addingTimeInterval(3600)
    if nearest.isHigh {
        return TideNote(
            line: near ? "High tide around \(at), deep and easy water." : "Tide runs high near \(at).",
            color: Theme.cyan)
    }
    return TideNote(
        line: near ? "Low tide around \(at), shallow and rocky, wade with care." : "Tide runs low near \(at).",
        color: Theme.amber)
}

// planLine is the bird's call for a plan, by hazard and severity.
func planLine(kind: PlanKind, hazard: String, rough: Bool) -> String {
    switch hazard {
    case "rain":
        if kind == .camp { return rough ? "Your tent is about to be a bathtub. Rethink this." : "Pack the rain fly. The sky has opinions." }
        if kind == .trip { return rough ? "Pack for wet. The sky there is committed." : "Bring a jacket that means it." }
        if kind == .swim { return "You are getting wet regardless. The rain barely counts." }
        return rough ? "You will get soaked. Move it or embrace it." : "Rain is sniffing around. Have a backup."
    case "heat":
        if kind == .run { return rough ? "That run will cook you. Go at dawn or do not go." : "Hot one. Water, shade, and no heroics." }
        if kind == .camp { return rough ? "Camping in a furnace. Find shade and a creek." : "Warm trip. Shade matters more than views." }
        if kind == .swim { return "Hot out, cool water. Best seat in the house." }
        return rough ? "Brutal heat in that window. Reschedule if you can." : "It will be hot. Plan around the peak."
    case "wind":
        if kind == .swim { return rough ? "Wind is chopping the water up. Sit this one out." : "Some chop out there, but swimmable." }
        return rough ? "Gusts strong enough to steal your hat and your dignity." : "Blustery. Anything loose is leaving."
    case "cold":
        if kind == .swim { return rough ? "That water will steal your breath. Wetsuit or skip it." : "Bracing dip. Quick in, quick out." }
        return rough ? "Deep cold. Layer like your life depends on it, because it does." : "Cold snap. Bring the real jacket."
    default:
        switch kind {
        case .run: return "Perfect flying weather. Go stretch those legs."
        case .ride: return "Clean air, smooth skies. Ride it."
        case .hike: return "The trail wins today. Go."
        case .camp: return "The sky will behave. Pitch it."
        case .swim: return "Flat, clear, and inviting. Get in the water."
        case .trip: return "The weather is cooperating. Safe travels."
        case .event: return "The sky signed off on this one."
        }
    }
}

// relativeStarts are one-tap presets for a plan's start time, so scheduling is a
// tap instead of a date-picker slog.
func relativeStarts() -> [(label: String, date: Date)] {
    let cal = Calendar.current
    let now = Date()
    var out: [(String, Date)] = [("In 1 hour", now.addingTimeInterval(3600))]
    if let evening = cal.date(bySettingHour: 18, minute: 0, second: 0, of: now) {
        out.append(("This evening", evening > now ? evening : cal.date(byAdding: .day, value: 1, to: evening) ?? evening))
    }
    if let tomorrow = cal.date(byAdding: .day, value: 1, to: now),
        let morning = cal.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow) {
        out.append(("Tomorrow AM", morning))
    }
    if let weekend = nextWeekendMorning(from: now, cal: cal) {
        out.append(("This weekend", weekend))
    }
    return out
}

// nextWeekendMorning is the coming Saturday at 9 AM.
func nextWeekendMorning(from now: Date, cal: Calendar) -> Date? {
    for add in 0...7 {
        guard let day = cal.date(byAdding: .day, value: add, to: now) else { continue }
        if cal.component(.weekday, from: day) == 7,
            let at = cal.date(bySettingHour: 9, minute: 0, second: 0, of: day), at > now {
            return at
        }
    }
    return nil
}
