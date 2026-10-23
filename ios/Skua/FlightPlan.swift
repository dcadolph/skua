import SwiftUI

// FlightTile is one thing on the flight plan: a weather moment, or one of your own
// plans graded against the forecast. Plans are personal, so they lead.
enum FlightTile: Identifiable {
    case moment(Waypoint)
    case plan(Plan, PlanVerdict)
    case event(CalEvent, PlanVerdict)

    var id: String {
        switch self {
        case .moment(let w): return "m-" + w.id
        case .plan(let p, _): return "p-\(p.id)"
        case .event(let e, _): return "e-\(e.id)"
        }
    }
    // at orders the tiles on the timeline.
    var at: Date {
        switch self {
        case .moment(let w): return w.at
        case .plan(let p, _): return p.start
        case .event(let e, _): return e.start
        }
    }
}

// FlightPlanCard reads the day as a plan, not a forecast: a plain-language read of
// the arc, then the few things worth planning around, your own plans first, graded
// against the weather, then the weather moments. Tapping any of them opens detail.
struct FlightPlanCard: View {
    let forecast: Forecast
    // lightning folds a storm into the read and the moments when risk is on the board.
    var lightning: Lightning? = nil
    // plans are your upcoming plans, graded and surfaced ahead of the weather.
    var plans: [Plan] = []
    // events are your upcoming calendar events, graded like plans.
    var events: [CalEvent] = []
    // selected is the tile opened into a detail sheet.
    @State private var selected: FlightTile?

    // tiles weaves what is yours (plans, then calendar events) first, graded against
    // the weather, then fills with the top weather moments, capped and time sorted.
    private var tiles: [FlightTile] {
        let now = Date()
        let soon = now.addingTimeInterval(20 * 3600)
        let planTiles: [FlightTile] = plans
            .filter { $0.start > now && $0.start < soon }
            .compactMap { p in
                gradeWindow(forecast, start: p.start, end: p.end, kind: p.kind).map { .plan(p, $0) }
            }
        let eventTiles: [FlightTile] = events
            .filter { $0.start > now && $0.start < soon }
            .compactMap { e in
                gradeEvent(forecast, event: e).map { .event(e, $0) }
            }
        let personal = (planTiles + eventTiles).sorted { $0.at < $1.at }
        let shownPersonal = Array(personal.prefix(3))
        let need = max(0, 3 - shownPersonal.count)
        let moments = FlightPlan.keyMoments(for: forecast, lightning: lightning)
            .prefix(need).map { FlightTile.moment($0) }
        return (shownPersonal + moments).sorted { $0.at < $1.at }
    }

    var body: some View {
        GlassSection(title: "Flight plan", icon: "paperplane.fill", tint: Theme.cyan) {
            Text(FlightPlan.summary(for: forecast, lightning: lightning))
                .font(.system(size: 21, weight: .regular, design: .serif))
                .foregroundStyle(Theme.text)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            let all = tiles
            if !all.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(all) { t in
                        Button {
                            selected = t
                            Haptics.tick()
                        } label: {
                            tile(t)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 16)
            }
            WeekAhead(forecast: forecast)
        }
        .sheet(item: $selected) { t in
            switch t {
            case .moment(let w):
                FlightMomentSheet(moment: w, forecast: forecast)
            case .plan(let p, let v):
                PlanMomentSheet(plan: p, verdict: v, forecast: forecast)
            case .event(let e, let v):
                EventMomentSheet(event: e, verdict: v, forecast: forecast)
            }
        }
    }

    // tile renders one flight tile: a plan graded by color, or a weather moment.
    private func tile(_ t: FlightTile) -> some View {
        let content: (icon: String, tint: Color, label: String, at: Date, sub: String)
        switch t {
        case .plan(let p, let v):
            content = (p.kind.icon, v.color, p.kind.label, p.start, planHint(v.grade))
        case .event(let e, let v):
            content = ("calendar", v.color, e.title, e.start, eventHint(v.grade))
        case .moment(let w):
            let brief = FlightPlan.brief(for: w)
            content = (w.icon, w.tint, brief.label, w.at, brief.sub)
        }
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                Image(systemName: content.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(content.tint)
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.muted.opacity(0.4))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(content.label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                Text(content.at.formatted(.dateTime.hour()))
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.text)
            }
            if !content.sub.isEmpty {
                Text(content.sub)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110, alignment: .topLeading)
        .padding(12)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // planHint is the tile read for a graded plan, which you can move.
    private func planHint(_ grade: String) -> String {
        switch grade {
        case "Good": return "clear runway"
        case "Fair": return "doable, barely"
        default: return "rough — move it"
        }
    }

    // eventHint is the tile read for a graded calendar event, which usually cannot
    // move, so it braces for the weather rather than rescheduling.
    private func eventHint(_ grade: String) -> String {
        switch grade {
        case "Good": return "clear skies"
        case "Fair": return "dress right"
        default: return "brace for it"
        }
    }
}

// FlightMomentSheet is the detail behind a tapped weather moment: the skua's deeper
// read, the shape of the hours around it, and a one-tap reminder.
struct FlightMomentSheet: View {
    let moment: Waypoint
    let forecast: Forecast
    @Environment(\.dismiss) private var dismiss
    @State private var reminded = false

    private var window: [HourlyPoint] {
        forecast.hourly.filter {
            $0.time >= moment.at.addingTimeInterval(-2 * 3600)
                && $0.time <= moment.at.addingTimeInterval(3 * 3600)
        }
    }

    var body: some View {
        MomentDetailScaffold(dismiss: dismiss) {
            DetailHeader(icon: moment.icon, tint: moment.tint, title: moment.title,
                         when: "\(moment.at.formatted(date: .omitted, time: .shortened)) · \(FlightPlan.countdown(to: moment.at))")
            BirdRead(text: FlightPlan.take(for: moment))
            if !window.isEmpty { HourWindow(hours: window) }
            if moment.at > Date() {
                RemindButton(at: moment.at, title: moment.title, message: FlightPlan.take(for: moment), reminded: $reminded)
            }
        }
    }
}

// PlanMomentSheet is the detail behind a tapped plan: the bird's verdict, a better
// time if one exists, the hours of your window, and a reminder.
struct PlanMomentSheet: View {
    let plan: Plan
    let verdict: PlanVerdict
    let forecast: Forecast
    @Environment(\.dismiss) private var dismiss
    @State private var reminded = false

    private var window: [HourlyPoint] {
        forecast.hourly.filter { $0.time >= plan.start && $0.time <= plan.end }
    }
    private var suggestion: ShiftSuggestion? { bestShift(forecast, plan: plan) }

    var body: some View {
        MomentDetailScaffold(dismiss: dismiss) {
            DetailHeader(icon: plan.kind.icon, tint: verdict.color, title: plan.title,
                         when: "\(plan.whenText) · \(FlightPlan.countdown(to: plan.start))")
            VerdictBlock(verdict: verdict)
            // A better nearby time, when one clearly beats the choice.
            if let s = suggestion {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.uturn.forward.circle.fill").font(.system(size: 15)).foregroundStyle(s.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("A better window").font(.system(size: 11, weight: .semibold)).kerning(0.5).foregroundStyle(Theme.muted)
                        Text(s.line).font(.subheadline).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(s.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if !window.isEmpty { HourWindow(hours: window) }
            if plan.start > Date() {
                RemindButton(at: plan.start, title: plan.title, message: verdict.line, reminded: $reminded)
            }
        }
    }
}

// EventMomentSheet is the detail behind a tapped calendar event: the bird's verdict
// on its weather, the hours it covers, and a reminder.
struct EventMomentSheet: View {
    let event: CalEvent
    let verdict: PlanVerdict
    let forecast: Forecast
    @Environment(\.dismiss) private var dismiss

    private var window: [HourlyPoint] {
        forecast.hourly.filter { $0.time >= event.start && $0.time <= event.end }
    }
    private var when: String {
        var s = "\(event.start.formatted(date: .omitted, time: .shortened)) · \(FlightPlan.countdown(to: event.start))"
        if let loc = event.location, !loc.isEmpty { s += " · \(loc)" }
        return s
    }

    var body: some View {
        MomentDetailScaffold(dismiss: dismiss) {
            DetailHeader(icon: "calendar", tint: verdict.color, title: event.title, when: when)
            VerdictBlock(verdict: verdict)
            if !window.isEmpty { HourWindow(hours: window) }
            OpenCalendarButton(at: event.start)
        }
    }
}

// OpenCalendarButton jumps to the event's day in the Calendar app. A calendar
// event already carries its own alerts, so a second reminder is redundant.
struct OpenCalendarButton: View {
    let at: Date
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: "calshow:\(at.timeIntervalSinceReferenceDate)") {
                openURL(url)
            }
            Haptics.tick()
        } label: {
            Label("Open in Calendar", systemImage: "calendar")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Theme.accent, in: Capsule())
        }
    }
}

// VerdictBlock shows a graded window: the grade badge, its range, and the bird's call.
struct VerdictBlock: View {
    let verdict: PlanVerdict
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(verdict.grade.uppercased())
                    .font(.system(size: 11, weight: .bold)).kerning(0.5)
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(verdict.color, in: Capsule())
                Text("\(verdict.lo)°–\(verdict.hi)°")
                    .font(.system(size: 13, weight: .semibold, design: .serif)).foregroundStyle(Theme.text)
                if verdict.rainMax >= 20 {
                    Text("· \(verdict.rainMax)% rain").font(.system(size: 12)).foregroundStyle(Theme.rain)
                }
                Spacer(minLength: 0)
            }
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bird.fill").font(.system(size: 14)).foregroundStyle(Theme.accent)
                Text(verdict.line).font(.system(.body, design: .serif))
                    .foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MomentDetailScaffold is the shared sheet chrome for a moment or plan detail.
struct MomentDetailScaffold<Content: View>: View {
    let dismiss: DismissAction
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) { content }
                    .padding(20)
            }
            .background(Theme.ground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// DetailHeader restates a moment or plan: mark, title, and when.
struct DetailHeader: View {
    let icon: String
    let tint: Color
    let title: String
    let when: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 54, height: 54)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(.title3, design: .serif)).foregroundStyle(Theme.text)
                Text(when).font(.subheadline).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
    }
}

// BirdRead is the skua's plain read block.
struct BirdRead: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bird.fill").font(.system(size: 14)).foregroundStyle(Theme.accent)
            Text(text).font(.system(.body, design: .serif)).foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// HourWindow lays out the hours of a window so it has a shape.
struct HourWindow: View {
    let hours: [HourlyPoint]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The window").font(.system(size: 12, weight: .semibold)).kerning(0.6).foregroundStyle(Theme.muted)
            ForEach(hours) { h in
                HStack(spacing: 12) {
                    Text(h.time.formatted(.dateTime.hour()))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.muted).frame(width: 54, alignment: .leading)
                    Image(systemName: conditionSymbol(h.condition, night: false))
                        .font(.system(size: 15)).symbolRenderingMode(.multicolor).frame(width: 22)
                    Text("\(f(h.tempC))°").font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.text).frame(width: 42, alignment: .leading)
                    Text(h.condition).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                    Spacer(minLength: 0)
                    if h.precipProb >= 20 {
                        Text("\(h.precipProb)%").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.rain)
                    }
                }
            }
        }
    }
}

// RemindButton schedules a one-off notification for a moment or plan.
struct RemindButton: View {
    let at: Date
    let title: String
    let message: String
    // lead is how far before `at` the reminder fires, in seconds. Zero fires at
    // the time itself; an appointment wants a head start.
    var lead: TimeInterval = 0
    @Binding var reminded: Bool

    var body: some View {
        Button {
            Notifier.scheduleReminder(at: at.addingTimeInterval(-lead), title: title, body: message)
            Haptics.tick()
            withAnimation(.snappy) { reminded = true }
        } label: {
            Label(
                reminded ? "Reminder set" : remindLabel,
                systemImage: reminded ? "checkmark.circle.fill" : "bell.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(reminded ? Theme.green : Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(reminded ? AnyShapeStyle(Theme.elevated) : AnyShapeStyle(Theme.accent), in: Capsule())
        }
        .disabled(reminded)
    }

    // remindLabel names the button by when it will fire: a lead time reads as
    // minutes before, otherwise the exact time.
    private var remindLabel: String {
        if lead >= 60 {
            return "Remind me \(Int(lead / 60)) min before"
        }
        return "Remind me at \(at.formatted(date: .omitted, time: .shortened))"
    }
}
