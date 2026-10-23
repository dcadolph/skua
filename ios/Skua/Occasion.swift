import Foundation

// OccasionKind is a party pack: its own voice, palette, and art.
enum OccasionKind: String, CaseIterable, Identifiable, Codable {
    case bachelorette
    case bachelor

    // id is the raw value, which is also the key the Go voice bank uses.
    var id: String { rawValue }

    // title names the pack.
    var title: String {
        switch self {
        case .bachelorette: return "Bachelorette"
        case .bachelor: return "Bachelor"
        }
    }

    // crew is what the pack calls its people.
    var crew: String {
        switch self {
        case .bachelorette: return "Bride squad"
        case .bachelor: return "Groom's crew"
        }
    }

    // paletteID is the palette the pack paints the app with.
    var paletteID: String { rawValue }

    // art is the cartoon for the pack, tame below raunchy heat and wild from it.
    func art(heat: Heat) -> String {
        let wild = heat.rank >= Heat.raunchy.rank
        switch self {
        case .bachelorette: return wild ? "BrideSkuaWild" : "BrideSkua"
        case .bachelor: return wild ? "CrewSkuaWild" : "CrewSkua"
        }
    }
}

// Heat is how filthy a party pack talks, matching the Go voice bank.
enum Heat: String, CaseIterable, Identifiable, Codable {
    case dirty
    case kinky
    case raunchy
    case slut

    // id is the raw value.
    var id: String { rawValue }

    // rank is the dial position, zero at the tamest.
    var rank: Int { Heat.allCases.firstIndex(of: self) ?? 0 }

    // title is the dial label.
    var title: String { rawValue.capitalized }
}

// OccasionPlan is one scheduled party: which pack, how hot, and when.
struct OccasionPlan: Codable, Equatable {
    // kind is the party pack.
    var kind: OccasionKind
    // heat is the voice's filth setting.
    var heat: Heat
    // start is when the pack takes over.
    var start: Date
    // end is when the pack hands the app back.
    var end: Date

    // isLive reports whether the plan covers the given moment.
    func isLive(at now: Date = Date()) -> Bool { now >= start && now < end }

    // weekend builds a plan running from the start of today through the end of
    // the coming Sunday, the usual shape of a party trip.
    static func weekend(_ kind: OccasionKind, heat: Heat = .dirty, from now: Date = Date()) -> OccasionPlan {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let weekday = cal.component(.weekday, from: start)
        let toSunday = (8 - weekday) % 7
        let sunday = cal.date(byAdding: .day, value: toSunday, to: start) ?? start
        let end = cal.date(byAdding: .day, value: 1, to: sunday) ?? sunday
        return OccasionPlan(kind: kind, heat: heat, start: start, end: end)
    }
}

// OccasionStore keeps the scheduled party in the shared defaults, so the app
// and its widgets agree on whether a party is running.
enum OccasionStore {
    // key is the shared defaults key for the encoded plan.
    private static let key = "skua.occasion"

    // load returns the saved plan, live or not.
    static func load() -> OccasionPlan? {
        guard let data = SharedStore.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(OccasionPlan.self, from: data)
    }

    // save stores a plan, or clears it when nil.
    static func save(_ plan: OccasionPlan?) {
        guard let plan, let data = try? JSONEncoder().encode(plan) else {
            SharedStore.defaults.removeObject(forKey: key)
            return
        }
        SharedStore.defaults.set(data, forKey: key)
    }

    // active returns the saved plan only while it is live.
    static func active(at now: Date = Date()) -> OccasionPlan? {
        guard let plan = load(), plan.isLive(at: now) else { return nil }
        return plan
    }
}
