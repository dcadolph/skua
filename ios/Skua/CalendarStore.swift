import EventKit
import Foundation

// CalEvent is a calendar event distilled to what the flight plan needs: a titled,
// timed block it can grade against the weather.
struct CalEvent: Identifiable, Equatable {
    // id is the event's stable identifier.
    let id: String
    // title is the event's name.
    let title: String
    // start is when it begins.
    let start: Date
    // end is when it ends.
    let end: Date
    // location is the event's place text, when set.
    let location: String?
}

// CalendarStore reads the device calendar with permission and exposes the next
// stretch of timed events, so the flight plan can put weather on your actual day.
@MainActor
final class CalendarStore: ObservableObject {
    // events is the upcoming timed events, soonest first.
    @Published var events: [CalEvent] = []
    // authorized reports whether calendar access was granted.
    @Published var authorized = false

    // nextEvent is the soonest event starting within the next eighteen hours, for
    // the bird to weather-check. Nil when nothing is coming up that soon.
    var nextEvent: CalEvent? {
        let now = Date()
        let horizon = now.addingTimeInterval(18 * 3600)
        return events.first { $0.start > now && $0.start < horizon }
    }

    private let store = EKEventStore()

    // request asks for calendar access once and loads events on grant. It is safe
    // to call every launch; the system only prompts the first time.
    func request() {
        store.requestFullAccessToEvents { [weak self] granted, _ in
            Task { @MainActor in
                self?.authorized = granted
                if granted { self?.load() }
            }
        }
    }

    // load pulls the next 18 hours of timed events across all calendars.
    func load() {
        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now, end: now.addingTimeInterval(18 * 3600), calendars: nil)
        let found: [CalEvent] = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .compactMap { ev in
                guard let start = ev.startDate, let end = ev.endDate, let title = ev.title, !title.isEmpty
                else { return nil }
                let id = ev.eventIdentifier ?? "\(Int(start.timeIntervalSince1970))-\(title)"
                return CalEvent(id: id, title: title, start: start, end: end, location: ev.location)
            }
            .sorted { $0.start < $1.start }
        events = Array(found.prefix(8))
    }
}
