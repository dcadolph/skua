import SwiftUI

// Palette is one full set of interface colors. Every view reads colors through
// Theme, which forwards to the active palette, so a palette swap recolors the
// whole app and its widgets.
struct Palette {
    // id is the stable key the palette is stored under.
    let id: String
    // name is the label shown in the theme picker.
    let name: String
    // ground is the deepest background.
    let ground: Color
    // surface is the card background.
    let surface: Color
    // elevated is the raised control background.
    let elevated: Color
    // text is the primary foreground.
    let text: Color
    // muted is the secondary foreground.
    let muted: Color
    // accent is the brand color for buttons, selections, and highlights.
    let accent: Color
    // hair is the thin card outline.
    let hair: Color
    // warn is the alarm color.
    let warn: Color
    // rain is the precipitation hue.
    let rain: Color
    // blue is the cool data hue.
    let blue: Color
    // cyan is the bright cool data hue.
    let cyan: Color
    // teal is the sea data hue.
    let teal: Color
    // green is the calm data hue.
    let green: Color
    // yellow is the sun data hue.
    let yellow: Color
    // amber is the warm data hue.
    let amber: Color
    // purple is the night data hue.
    let purple: Color
    // violet is the storm data hue.
    let violet: Color
    // slate is the neutral data hue.
    let slate: Color
    // glow tints the sky backdrop, clear for none.
    let glow: Color
}

extension Palette {
    // storm is the house look: deep blacks under glass with a saturated pop
    // palette that gives every data family its own color.
    static let storm = Palette(
        id: "storm", name: "Storm",
        ground: Color(red: 0.008, green: 0.008, blue: 0.016),
        surface: Color(red: 0.035, green: 0.04, blue: 0.065),
        elevated: Color(red: 0.07, green: 0.08, blue: 0.12),
        text: Color(red: 0.94, green: 0.95, blue: 0.98),
        muted: Color(red: 0.56, green: 0.6, blue: 0.7),
        accent: Color(red: 1.0, green: 0.498, blue: 0.196),
        hair: Color.white.opacity(0.12),
        warn: Color(red: 1.0, green: 0.302, blue: 0.427),
        rain: Color(red: 0.22, green: 0.663, blue: 1.0),
        blue: Color(red: 0.29, green: 0.56, blue: 1.0),
        cyan: Color(red: 0.2, green: 0.85, blue: 0.95),
        teal: Color(red: 0.18, green: 0.87, blue: 0.78),
        green: Color(red: 0.24, green: 0.87, blue: 0.6),
        yellow: Color(red: 1.0, green: 0.8, blue: 0.2),
        amber: Color(red: 1.0, green: 0.68, blue: 0.25),
        purple: Color(red: 0.7, green: 0.56, blue: 1.0),
        violet: Color(red: 0.56, green: 0.38, blue: 0.99),
        slate: Color(red: 0.6, green: 0.66, blue: 0.78),
        glow: .clear)

    // beach is sand and sea: a sandy accent over deep ocean blue.
    static let beach = Palette(
        id: "beach", name: "Beach",
        ground: Color(red: 0.0, green: 0.02, blue: 0.04),
        surface: Color(red: 0.02, green: 0.06, blue: 0.09),
        elevated: Color(red: 0.04, green: 0.11, blue: 0.15),
        text: Color(red: 0.97, green: 0.96, blue: 0.92),
        muted: Color(red: 0.6, green: 0.7, blue: 0.72),
        accent: Color(red: 0.96, green: 0.8, blue: 0.56),
        hair: Color.white.opacity(0.13),
        warn: Color(red: 1.0, green: 0.4, blue: 0.38),
        rain: Color(red: 0.3, green: 0.72, blue: 1.0),
        blue: Color(red: 0.25, green: 0.6, blue: 0.95),
        cyan: Color(red: 0.25, green: 0.88, blue: 0.92),
        teal: Color(red: 0.2, green: 0.85, blue: 0.75),
        green: Color(red: 0.4, green: 0.86, blue: 0.58),
        yellow: Color(red: 1.0, green: 0.86, blue: 0.4),
        amber: Color(red: 1.0, green: 0.7, blue: 0.4),
        purple: Color(red: 0.66, green: 0.62, blue: 1.0),
        violet: Color(red: 0.5, green: 0.48, blue: 0.98),
        slate: Color(red: 0.6, green: 0.72, blue: 0.76),
        glow: Color(red: 0.1, green: 0.6, blue: 0.65))

    // bachelorette is hot pink and champagne over plum black.
    static let bachelorette = Palette(
        id: "bachelorette", name: "Bachelorette",
        ground: Color(red: 0.03, green: 0.005, blue: 0.03),
        surface: Color(red: 0.08, green: 0.02, blue: 0.07),
        elevated: Color(red: 0.14, green: 0.04, blue: 0.12),
        text: Color(red: 1.0, green: 0.94, blue: 0.97),
        muted: Color(red: 0.8, green: 0.62, blue: 0.74),
        accent: Color(red: 1.0, green: 0.24, blue: 0.62),
        hair: Color(red: 1.0, green: 0.5, blue: 0.8).opacity(0.18),
        warn: Color(red: 1.0, green: 0.32, blue: 0.36),
        rain: Color(red: 0.45, green: 0.7, blue: 1.0),
        blue: Color(red: 0.5, green: 0.6, blue: 1.0),
        cyan: Color(red: 0.4, green: 0.9, blue: 0.95),
        teal: Color(red: 0.3, green: 0.9, blue: 0.8),
        green: Color(red: 0.45, green: 0.9, blue: 0.65),
        yellow: Color(red: 0.98, green: 0.84, blue: 0.48),
        amber: Color(red: 1.0, green: 0.7, blue: 0.45),
        purple: Color(red: 0.85, green: 0.55, blue: 1.0),
        violet: Color(red: 0.7, green: 0.4, blue: 1.0),
        slate: Color(red: 0.75, green: 0.66, blue: 0.78),
        glow: Color(red: 1.0, green: 0.2, blue: 0.6))

    // bachelor is Vegas neon: electric cyan over black, with whiskey gold.
    static let bachelor = Palette(
        id: "bachelor", name: "Bachelor",
        ground: Color(red: 0.005, green: 0.01, blue: 0.02),
        surface: Color(red: 0.03, green: 0.045, blue: 0.07),
        elevated: Color(red: 0.06, green: 0.09, blue: 0.13),
        text: Color(red: 0.93, green: 0.97, blue: 1.0),
        muted: Color(red: 0.55, green: 0.66, blue: 0.74),
        accent: Color(red: 0.1, green: 0.85, blue: 1.0),
        hair: Color(red: 0.3, green: 0.9, blue: 1.0).opacity(0.16),
        warn: Color(red: 1.0, green: 0.3, blue: 0.4),
        rain: Color(red: 0.25, green: 0.65, blue: 1.0),
        blue: Color(red: 0.3, green: 0.55, blue: 1.0),
        cyan: Color(red: 0.2, green: 0.9, blue: 1.0),
        teal: Color(red: 0.2, green: 0.9, blue: 0.75),
        green: Color(red: 0.45, green: 1.0, blue: 0.45),
        yellow: Color(red: 1.0, green: 0.78, blue: 0.3),
        amber: Color(red: 0.95, green: 0.62, blue: 0.2),
        purple: Color(red: 0.75, green: 0.5, blue: 1.0),
        violet: Color(red: 0.6, green: 0.35, blue: 1.0),
        slate: Color(red: 0.6, green: 0.68, blue: 0.76),
        glow: Color(red: 0.0, green: 0.7, blue: 1.0))

    // choosable is the everyday picker list. Party palettes come with their
    // occasion and are not picked directly.
    static let choosable: [Palette] = [.storm, .beach]

    // all is every palette, for lookup by id.
    static let all: [Palette] = [.storm, .beach, .bachelorette, .bachelor]

    // named looks a palette up by id, falling back to storm.
    static func named(_ id: String?) -> Palette {
        all.first { $0.id == id } ?? .storm
    }
}

// Theme forwards to the active palette. The active palette is cached and only
// re-read through reload, so the many per-frame color reads stay cheap.
enum Theme {
    // active is the palette in force right now.
    private(set) static var active: Palette = resolve()

    // reload re-reads the chosen palette and any running occasion.
    static func reload() { active = resolve() }

    // resolve picks the running occasion's palette first, then the chosen theme.
    private static func resolve() -> Palette {
        if let plan = OccasionStore.active() {
            return Palette.named(plan.kind.paletteID)
        }
        return Palette.named(SharedStore.defaults.string(forKey: themeKey))
    }

    // themeKey is the shared defaults key for the chosen everyday palette.
    static let themeKey = "skua.theme"

    // The colors below forward to the active palette.
    static var ground: Color { active.ground }
    static var surface: Color { active.surface }
    static var elevated: Color { active.elevated }
    static var text: Color { active.text }
    static var muted: Color { active.muted }
    static var accent: Color { active.accent }
    static var hair: Color { active.hair }
    static var warn: Color { active.warn }
    static var rain: Color { active.rain }
    static var blue: Color { active.blue }
    static var cyan: Color { active.cyan }
    static var teal: Color { active.teal }
    static var green: Color { active.green }
    static var yellow: Color { active.yellow }
    static var amber: Color { active.amber }
    static var purple: Color { active.purple }
    static var violet: Color { active.violet }
    static var slate: Color { active.slate }
    static var glow: Color { active.glow }
}

// tempColor maps a Celsius temperature onto the cold-to-hot ramp, matching the
// web client's scale exactly.
func tempColor(_ c: Double) -> Color {
    let cold = (0.369, 0.627, 1.0)
    let mild = (0.278, 0.82, 0.651)
    let warm = (0.961, 0.655, 0.259)
    let hot = (1.0, 0.365, 0.365)

    func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> Color {
        Color(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
    }
    switch c {
    case ...0: return mix(cold, cold, 0)
    case ...12: return mix(cold, mild, c / 12)
    case ...24: return mix(mild, warm, (c - 12) / 12)
    case ...36: return mix(warm, hot, (c - 24) / 12)
    default: return mix(hot, hot, 0)
    }
}

// conditionSymbol maps a condition string to an SF Symbol, night aware.
func conditionSymbol(_ condition: String, night: Bool) -> String {
    let c = condition.lowercased()
    if c.contains("thunder") { return "cloud.bolt.rain.fill" }
    if c.contains("snow") || c.contains("sleet") || c.contains("ice") || c.contains("freez") {
        return "cloud.snow.fill"
    }
    if c.contains("drizzle") { return "cloud.drizzle.fill" }
    if c.contains("rain") || c.contains("shower") { return "cloud.rain.fill" }
    if c.contains("fog") || c.contains("mist") { return "cloud.fog.fill" }
    if c.contains("overcast") { return "cloud.fill" }
    if c.contains("partly") || c.contains("mainly") || c.contains("cloud") {
        return night ? "cloud.moon.fill" : "cloud.sun.fill"
    }
    if c.contains("clear") || c.contains("sunny") {
        return night ? "moon.stars.fill" : "sun.max.fill"
    }
    return "cloud.fill"
}

// imperialUnits reports the chosen measurement system, imperial by default.
func imperialUnits() -> Bool {
    UserDefaults.standard.object(forKey: "skua.imperial") as? Bool ?? true
}

// f converts Celsius to the display temperature in the chosen units.
func f(_ c: Double) -> Int {
    imperialUnits() ? Int((c * 1.8 + 32).rounded()) : Int(c.rounded())
}

// mph converts kph to the display speed in the chosen units.
func mph(_ kph: Double) -> Int {
    imperialUnits() ? Int((kph * 0.621371).rounded()) : Int(kph.rounded())
}

// unitSpeed is the speed label for the chosen units.
func unitSpeed() -> String { imperialUnits() ? "mph" : "kph" }

// unitTemp is the temperature label for the chosen units.
func unitTemp() -> String { imperialUnits() ? "°F" : "°C" }

// lightningColor climbs from a calm yellow watch to an angry red as risk rises.
func lightningColor(_ level: Int) -> Color {
    switch level {
    case 1: return Theme.yellow
    case 2: return Theme.amber
    case 3: return Theme.accent
    case 4: return Theme.warn
    default: return Theme.muted
    }
}

// countdownText renders the wait until a moment as "2h 14m", "47m", or "Now".
func countdownText(to date: Date) -> String {
    let s = Int(date.timeIntervalSinceNow)
    if s <= 0 { return "Now" }
    let h = s / 3600
    let m = (s % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
}
