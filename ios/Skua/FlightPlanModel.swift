import SwiftUI

// Waypoint is one stop on the day's flight plan: when it lands, what it is, and
// why it matters. The dashboard card and the home-screen widget both render it.
struct Waypoint: Identifiable {
    // at is when the stop happens and orders the timeline.
    let at: Date
    // isNow pins the stop to the present, drawing "Now" instead of a clock time.
    let isNow: Bool
    // icon marks the stop.
    let icon: String
    // tint colors the stop.
    let tint: Color
    // title tells the stop.
    let title: String
    // detail is an optional second line with the bird's read or a number.
    let detail: String?
    var id: String { title + "\(at.timeIntervalSince1970)" }
}

// FlightPlan reads the day as a plan, not a forecast: when to be out, what to
// avoid, and the moments that actually change a decision. The dashboard card and
// the widget share it so both fly the day the same way.
enum FlightPlan {
    // stops composes the full itinerary for the widget timeline. keyMoments picks
    // the useful few for the card. The window (when to be out) always appears.
    static func stops(for forecast: Forecast, lightning: Lightning? = nil) -> [Waypoint] {
        var stops: [Waypoint] = []
        let now = Date()
        let c = forecast.current
        stops.append(
            Waypoint(
                at: now, isNow: true, icon: conditionSymbol(c.condition, night: !c.isDay),
                tint: tempColor(c.tempC), title: "\(f(c.tempC))° and \(c.condition.lowercased())",
                detail: "Feels \(f(c.apparentTempC))°"))

        let coming = forecast.hourly.filter { $0.time > now && $0.time < now.addingTimeInterval(18 * 3600) }

        // The single most useful stop: when to actually be outside, always shown.
        if let window = bestWindow(forecast, now: now) {
            stops.append(window)
        }

        // The next change in sky category.
        if let change = coming.first(where: { skyFamily($0.condition) != skyFamily(c.condition) }) {
            stops.append(
                Waypoint(
                    at: change.time, isNow: false, icon: conditionSymbol(change.condition, night: false),
                    tint: Theme.slate, title: "\(change.condition) moves in", detail: nil))
        }

        // The rain window opening, and where it clears again.
        if let wetIdx = coming.firstIndex(where: { $0.precipProb >= 40 }) {
            let wet = coming[wetIdx]
            stops.append(
                Waypoint(
                    at: wet.time, isNow: false, icon: "umbrella.fill", tint: Theme.rain,
                    title: "Rain likely", detail: "\(wet.precipProb)% chance"))
            if let clear = coming[wetIdx...].first(where: { $0.precipProb < 25 }) {
                stops.append(
                    Waypoint(
                        at: clear.time, isNow: false, icon: "sun.max.fill", tint: Theme.yellow,
                        title: "Rain clears", detail: "skies open back up"))
            }
        }

        // Peak heat still ahead, framed as a hazard with how fast the sun burns.
        if let peak = coming.max(by: { feels($0) < feels($1) }), feels(peak) > feels(c) + 1 {
            var detail = "\(f(peak.tempC))° feels like \(f(feels(peak)))°"
            if let uv = peak.uvIndex, uv >= 4 {
                detail = "feels \(f(feels(peak)))°, UV \(Int(uv.rounded())), burn ~\(uvBurnMinutes(uv))m"
            }
            stops.append(
                Waypoint(
                    at: peak.time, isNow: false, icon: "thermometer.sun.fill",
                    tint: tempColor(peak.tempC), title: "Peak heat, \(f(peak.tempC))°", detail: detail))

            // On a hot day, when it finally eases back to something bearable.
            if feels(peak) >= 30,
                let ease = coming.first(where: { $0.time > peak.time && $0.tempC <= peak.tempC - 5 }) {
                stops.append(
                    Waypoint(
                        at: ease.time, isNow: false, icon: "thermometer.medium", tint: Theme.rain,
                        title: "Heat eases", detail: "back to \(f(ease.tempC))°"))
            }
        }

        // The next sun event, plus the golden hour just before a sunset.
        if let today = forecast.daily.first {
            if today.sunrise > now {
                stops.append(
                    Waypoint(
                        at: today.sunrise, isNow: false, icon: "sunrise.fill", tint: Theme.yellow,
                        title: "Sunrise", detail: nil))
            } else if today.sunset > now {
                let golden = today.sunset.addingTimeInterval(-40 * 60)
                if golden > now {
                    stops.append(
                        Waypoint(
                            at: golden, isNow: false, icon: "camera.fill", tint: Theme.amber,
                            title: "Golden hour", detail: "warm light, long shadows"))
                }
                stops.append(
                    Waypoint(
                        at: today.sunset, isNow: false, icon: "sunset.fill", tint: Theme.amber,
                        title: "Sunset", detail: nil))
            }
        }

        // A storm rolling in, when lightning risk is on the board.
        if let l = lightning, l.hasNext, l.next > now, l.next < now.addingTimeInterval(18 * 3600) {
            stops.append(
                Waypoint(
                    at: l.next, isNow: false, icon: "cloud.bolt.fill", tint: lightningColor(l.level),
                    title: l.imminent ? "Storms closing in" : "Storm risk builds",
                    detail: l.stormHours > 0 ? "\(l.stormHours)h of storms" : nil))
        }

        // Wind picking up, when a gust jumps well above the current breeze.
        if let windy = coming.first(where: {
            let g = $0.windGustKph ?? $0.windKph
            return g >= 40 && g >= c.windGustKph + 16
        }) {
            let g = windy.windGustKph ?? windy.windKph
            stops.append(
                Waypoint(
                    at: windy.time, isNow: false, icon: "wind", tint: Theme.teal,
                    title: "Wind picks up", detail: "gusts to \(mph(g)) \(unitSpeed())"))
        }

        // Pressure diving, the barometer's tell that the weather is about to turn.
        if let drop = coming.first(where: { ($0.pressureHPa ?? c.pressureHPa) <= c.pressureHPa - 5 }) {
            stops.append(
                Waypoint(
                    at: drop.time, isNow: false, icon: "barometer", tint: Theme.violet,
                    title: "Pressure dropping", detail: "weather turning"))
        }

        // A clear, dark, low-moon window, the night sky at its best.
        if let today = forecast.daily.first, (forecast.moon?.illumination ?? 1) <= 0.45,
            let star = coming.first(where: { $0.time > today.sunset && ($0.cloudCover ?? 100) <= 20 }) {
            stops.append(
                Waypoint(
                    at: star.time, isNow: false, icon: "moon.stars.fill", tint: Theme.purple,
                    title: "Clear night for stars", detail: "dark sky, low moon"))
        }

        // The coldest hour still ahead, framed by how cold it gets.
        if let low = coming.min(by: { $0.tempC < $1.tempC }) {
            let icon: String
            let title: String
            let tint: Color
            if low.tempC <= 0 {
                icon = "thermometer.snowflake"
                title = "Freeze, down to \(f(low.tempC))°"
                tint = Theme.blue
            } else if low.tempC <= 2.5 {
                icon = "snowflake"
                title = "Frost, low of \(f(low.tempC))°"
                tint = Theme.cyan
            } else {
                icon = "moon.zzz.fill"
                title = "Overnight low \(f(low.tempC))°"
                tint = Theme.purple
            }
            stops.append(Waypoint(at: low.time, isNow: false, icon: icon, tint: tint, title: title, detail: nil))
        }

        return Array(stops.sorted { $0.at < $1.at }.prefix(8))
    }

    // summary is the day's read in one plain-language line: the recommendation, not
    // just the weather. This is the wedge, so it leads the card.
    static func summary(for forecast: Forecast, lightning: Lightning? = nil) -> String {
        let c = forecast.current
        let now = Date()
        let cond = c.condition.lowercased()
        let coming = forecast.hourly.filter { $0.time > now && $0.time < now.addingTimeInterval(14 * 3600) }
        let window = bestWindow(forecast, now: now)
        let windowAt = window.map { $0.at.formatted(.dateTime.hour()) }

        if let l = lightning, l.hasNext, l.next > now, l.next < now.addingTimeInterval(14 * 3600) {
            let t = l.next.formatted(.dateTime.hour())
            if let window, let windowAt, window.at < l.next {
                return "Storms muscle in by \(t). Take the \(windowAt) window, then get under a roof like a creature with sense."
            }
            return "Storms building by \(t). Stay near cover, unless you're auditioning to be a lightning rod."
        }
        if isRaining(c) {
            if let dry = coming.first(where: { $0.precipMM < rainRateMM && $0.precipProb < 25 }) {
                let t = dry.time.formatted(.dateTime.hour())
                return "It's raining now, and it lets up around \(t). Stay put till then, the sky means it."
            }
            return "It's raining now, and the afternoon stays wet. Grab a jacket and make peace with it."
        }
        if let wet = coming.first(where: { $0.precipProb >= 55 }) {
            let t = wet.time.formatted(.dateTime.hour())
            return "\(capFirst(cond)) now, rain by \(t). The dry hours are yours till then, so quit dawdling."
        }
        if let peak = coming.max(by: { feels($0) < feels($1) }), feels(peak) >= 32 {
            let pt = peak.time.formatted(.dateTime.hour())
            if let windowAt {
                return "\(f(peak.tempC))° by \(pt) and the afternoon's a griddle. Do your living around \(windowAt) or melt, no judgment."
            }
            return "\(f(peak.tempC))° by \(pt). Brutal. Shade, water, and exactly zero heroics."
        }
        if let low = coming.min(by: { $0.tempC < $1.tempC }), low.tempC <= 2 {
            return "Down to \(f(low.tempC))° today. Dress like you mean it or shiver like you don't."
        }
        if let window, window.title == "Best", let windowAt {
            return "Genuinely gorgeous around \(windowAt), \(window.detail ?? "mild and calm"). Get out there before I have to nag."
        }
        if let windowAt {
            return "Nothing dramatic today. \(windowAt)'s your pick if you need an excuse to go outside."
        }
        return "Calm and dull, in the best way. Nothing out here is going to bite you."
    }

    // countdown renders a compact wait until a stop, like "in 2h" or "in 15m".
    static func countdown(to date: Date) -> String {
        let s = Int(date.timeIntervalSinceNow)
        if s < 3600 { return "in \(max(1, s / 60))m" }
        return "in \(s / 3600)h"
    }

    // keyMoments picks the few upcoming moments worth planning around, ranked by
    // usefulness and capped small, then ordered by time. The present moment is
    // left out: the hero already shows what it is right now.
    static func keyMoments(for forecast: Forecast, lightning: Lightning? = nil) -> [Waypoint] {
        let upcoming = stops(for: forecast, lightning: lightning).filter { !$0.isNow }
        let top = upcoming.sorted { rank($0) < rank($1) }.prefix(3)
        return top.sorted { $0.at < $1.at }
    }

    // rank scores a stop by how much it changes a plan, most useful first. The
    // window and real hazards beat pretty sun events.
    private static func rank(_ w: Waypoint) -> Int {
        switch w.icon {
        case "cloud.bolt.fill": return 0
        case "figure.walk": return 1
        case "umbrella.fill": return 2
        case "thermometer.sun.fill": return 3
        case "thermometer.snowflake", "snowflake": return 3
        case "wind": return 4
        case "barometer": return 5
        case "thermometer.medium": return 6
        case "sun.max.fill": return 7
        case "moon.stars.fill": return 8
        case "camera.fill": return 9
        case "sunset.fill", "sunrise.fill": return 10
        case "moon.zzz.fill": return 11
        default: return 12
        }
    }

    // brief gives a moment its tile copy: a short label and a plain read of what to
    // do about it, so the tile is advice at a glance, not a data point.
    static func brief(for w: Waypoint) -> (label: String, sub: String) {
        switch w.icon {
        case "figure.walk": return (w.title, w.detail ?? "best time to be out")
        case "cloud.bolt.fill": return ("Storms", "run for cover")
        case "umbrella.fill": return ("Rain", "jacket weather")
        case "sun.max.fill": return ("Clears", "sky reopens")
        case "thermometer.sun.fill":
            return ("Peak", "\(w.title.replacingOccurrences(of: "Peak heat, ", with: "")), hide")
        case "thermometer.medium": return ("Eases", w.detail ?? "it lets up")
        case "camera.fill": return ("Golden", "prime light")
        case "sunset.fill": return ("Sunset", "curtain call")
        case "sunrise.fill": return ("Sunrise", "up you get")
        case "moon.stars.fill": return ("Stars", "look up")
        case "barometer": return ("Turning", "trouble brews")
        case "wind": return ("Wind", w.detail ?? "hold your hat")
        case "thermometer.snowflake": return ("Freeze", "cover up")
        case "snowflake": return ("Frost", "bring 'em in")
        case "moon.zzz.fill": return ("Low", w.title.replacingOccurrences(of: "Overnight low ", with: ""))
        default: return ("Shift", w.detail ?? "sky moves")
        }
    }

    // take is the skua's plain read on what a moment means, used where there is
    // room for a sentence, like the forecast graph on scrub.
    static func take(for w: Waypoint) -> String {
        switch w.icon {
        case "figure.walk": return "This is the good stuff. Get out before the day changes its mind."
        case "camera.fill": return "Golden hour. The light goes gorgeous and everyone with a camera loses it. Worth the fuss."
        case "thermometer.sun.fill": return "Peak misery. Shade, water, and no heroics. The sun is not impressed by your grit."
        case "thermometer.medium": return "The heat finally lets up. You may resume being a person."
        case "cloud.bolt.fill": return "Storm's got your name on it. Under a roof, now, and let it tantrum."
        case "umbrella.fill": return "Rain's rolling in. Bring a jacket or become a cautionary tale."
        case "sun.max.fill": return "Skies crack back open. Breathe, you made it."
        case "sunrise.fill": return "Sunrise. New day, same sharp beak."
        case "sunset.fill": return "Sun clocks out. Steal the golden light on the way down."
        case "moon.stars.fill": return "Dark, clear, low moon. Look up, the good show is free tonight."
        case "barometer": return "Barometer's diving. Something's brewing out there, mark my words."
        case "wind": return "Wind kicks up. Anything loose is about to be someone else's problem."
        case "thermometer.snowflake": return "Hard freeze. Cover the plants, the pipes, and your dignity."
        case "snowflake": return "Frost creeping in. Bring the tender things inside before it bites them."
        case "moon.zzz.fill": return "Coldest hour of the night. Crack a window, steal the good blanket."
        default: return "Something shifts here. I'll squawk if it turns ugly."
        }
    }

    // bestWindow is the single most useful stop: when to actually be outside. It
    // always returns the most comfortable daylight hour ahead, and names it
    // honestly, from a genuine best window to the least-brutal hour of a hot day.
    private static func bestWindow(_ forecast: Forecast, now: Date) -> Waypoint? {
        guard let today = forecast.daily.first else { return nil }
        let daylight = forecast.hourly.filter {
            $0.time > now.addingTimeInterval(1800)
                && $0.time < now.addingTimeInterval(15 * 3600)
                && $0.time >= today.sunrise && $0.time <= today.sunset
        }
        guard let best = daylight.max(by: { comfortScore($0) < comfortScore($1) }) else { return nil }
        let dayPeak = daylight.map { feels($0) }.max() ?? feels(best)
        let dayLow = daylight.map { feels($0) }.min() ?? feels(best)
        let wind = mph(best.windKph) < 12 ? "calm" : "breezy"
        let title: String
        let detail: String
        if dayPeak >= 32 {
            title = "Coolest"
            detail = "\(f(best.tempC))°, and that's the mercy on offer"
        } else if dayLow <= 6 {
            title = "Mildest"
            detail = "\(f(best.tempC))°, least frozen you'll get"
        } else if comfortScore(best) >= 60 {
            title = "Best"
            detail = "\(f(best.tempC))°, \(wind), the day showing off"
        } else {
            title = "Window"
            detail = "\(f(best.tempC))°, \(wind), best on the menu"
        }
        return Waypoint(
            at: best.time, isNow: false, icon: "figure.walk", tint: Theme.green,
            title: title, detail: detail)
    }

    // comfortScore rates an hour for being outside, best near a mild, dry, calm,
    // low-sun window.
    private static func comfortScore(_ h: HourlyPoint) -> Double {
        var score = 100.0
        score -= abs(feels(h) - 21) * 3
        score -= Double(h.precipProb)
        score -= max(0, h.windKph - 25) * 0.5
        if let uv = h.uvIndex { score -= max(0, uv - 6) * 2 }
        return score
    }

    // feels is the apparent temperature in Celsius, falling back to the dry bulb.
    private static func feels(_ h: HourlyPoint) -> Double { h.apparentTempC ?? h.tempC }

    // feels is the apparent temperature for the current conditions.
    private static func feels(_ c: Current) -> Double { c.apparentTempC }

    // uvBurnMinutes estimates minutes for fair skin to burn at a UV index.
    private static func uvBurnMinutes(_ uv: Double) -> Int {
        max(10, Int(200.0 / max(1, uv)))
    }

    // capFirst uppercases the first letter of a string.
    private static func capFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }

    // rainRateMM is the precipitation rate in millimeters at or above which it counts
    // as raining, whatever the condition string says.
    static let rainRateMM = 0.1

    // isRaining reports whether it is raining right now. A measurable rate counts
    // even when the condition string lags, but snow and storms keep their own reads.
    static func isRaining(_ c: Current) -> Bool {
        switch skyFamily(c.condition) {
        case "rain": return true
        case "snow", "storm": return false
        default: return c.precipMM >= rainRateMM
        }
    }

    // skyFamily buckets a condition for change detection.
    private static func skyFamily(_ condition: String) -> String {
        let c = condition.lowercased()
        if c.contains("thunder") { return "storm" }
        if c.contains("rain") || c.contains("drizzle") || c.contains("shower") { return "rain" }
        if c.contains("snow") || c.contains("sleet") { return "snow" }
        if c.contains("fog") || c.contains("mist") { return "fog" }
        if c.contains("overcast") || c.contains("cloud") { return "clouds" }
        return "clear"
    }
}
