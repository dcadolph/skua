import Foundation

// These types mirror the JSON the Skua backend returns.

// Location is a geographic coordinate.
struct Location: Codable, Equatable {
    let lat: Double
    let lon: Double
}

// Current holds present weather conditions.
struct Current: Codable {
    let time: Date
    let condition: String
    let tempC: Double
    let apparentTempC: Double
    let precipMM: Double
    let windKph: Double
    let humidity: Int
    let windDirDeg: Int
    let uvIndex: Double
    let pressureHPa: Double
    let dewPointC: Double
    let visibilityKm: Double
    let windGustKph: Double
    let cloudCover: Int
    let isDay: Bool
}

// MinutelyPoint is expected precipitation for one short interval.
struct MinutelyPoint: Codable {
    let time: Date
    let precipMM: Double
}

// HourlyPoint is the forecast for a single hour, carrying every graphable
// series. The enriched fields are optional so an older backend still decodes.
struct HourlyPoint: Codable, Identifiable {
    let time: Date
    let condition: String
    let tempC: Double
    let apparentTempC: Double?
    let precipMM: Double
    let windKph: Double
    let windGustKph: Double?
    let humidity: Int?
    let pressureHPa: Double?
    let dewPointC: Double?
    let cloudCover: Int?
    let uvIndex: Double?
    let precipProb: Int
    var id: Date { time }
}

// DailyPoint is the forecast for a single day.
struct DailyPoint: Codable, Identifiable {
    let date: Date
    let sunrise: Date
    let sunset: Date
    let condition: String
    let highC: Double
    let lowC: Double
    let apparentHighC: Double?
    let apparentLowC: Double?
    let uvIndexMax: Double
    let precipSumMM: Double?
    let windMaxKph: Double?
    let windGustMaxKph: Double?
    let daylightSec: Double?
    let precipProb: Int
    var id: Date { date }
}

// MoonInfo is the computed lunar phase.
struct MoonInfo: Codable {
    let phase: Double
    let illumination: Double
    let name: String
    let index: Int
}

// Forecast is the normalized weather result.
// NullableArray decodes a JSON array and treats an explicit null as empty. The
// on-device core is Go, which marshals a nil slice as null rather than [], so a
// valid but empty list would otherwise fail to decode. A malformed array still
// throws, keeping a real decode failure visible instead of silently emptying it.
@propertyWrapper
struct NullableArray<Element: Codable>: Codable {
    // wrappedValue is the decoded list, empty when the source was null.
    var wrappedValue: [Element]

    // init wraps an existing list.
    init(wrappedValue: [Element]) { self.wrappedValue = wrappedValue }

    // init decodes the list, mapping a null value to an empty list.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            wrappedValue = []
            return
        }
        wrappedValue = try container.decode([Element].self)
    }

    // encode writes the list back out.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

// KeyedDecodingContainer decodes a missing NullableArray key as an empty list,
// so a field the core omits when empty reads the same as one sent as null.
extension KeyedDecodingContainer {
    // decode treats an absent key for a NullableArray as an empty list.
    func decode<Element: Codable>(_ type: NullableArray<Element>.Type, forKey key: Key) throws -> NullableArray<Element> {
        try decodeIfPresent(type, forKey: key) ?? NullableArray(wrappedValue: [])
    }
}

// Forecast is the normalized forecast the app renders.
struct Forecast: Codable {
    let source: String
    let location: Location
    let moon: MoonInfo?
    let yesterday: DailyPoint?
    let current: Current
    let minutely: [MinutelyPoint]?
    @NullableArray var hourly: [HourlyPoint]
    @NullableArray var daily: [DailyPoint]
}

// Voice is the skua's line and briefing.
struct Voice: Codable {
    let line: String
    let briefing: String
}

// AirQuality holds current air-quality conditions.
struct AirQuality: Codable {
    let time: Date
    let category: String
    let usAqi: Int
    let pm25: Double
    let pm10: Double
    let ozone: Double
    let no2: Double
    let uvIndex: Double
}

// Pollen is the day's allergen read: an index, a category, and the named triggers.
struct Pollen: Codable, Identifiable {
    let date: Date
    let zip: String
    let city: String
    let state: String
    let today: PollenDay
    let tomorrow: PollenDay
    var id: String { zip }
}

// PollenDay is one day's allergen level and the plants driving it.
struct PollenDay: Codable {
    let index: Double
    let category: String
    @NullableArray var triggers: [String]
}

// Aurora is the current auroral activity: the planetary Kp index, a plain-word
// level, and whether the northern lights are likely visible from here.
struct Aurora: Codable {
    let time: Date
    let kp: Double
    let level: String
    let visible: Bool
}

// Fact is a "this day in history" note from Wikipedia, in the year it happened.
struct Fact: Codable {
    let year: Int
    let text: String
    let title: String
}

// Marine is the coastal sea state: wave and swell height, period, and direction.
// Available is false inland, where the card hides itself.
struct Marine: Codable {
    let available: Bool
    let time: Date
    let waveHeightM: Double
    let waveDirectionDeg: Int
    let wavePeriodS: Double
    let swellHeightM: Double
    let swellPeriodS: Double
}

// RadarFrame is one radar tile layer.
struct RadarFrame: Codable, Identifiable {
    let time: Date
    let path: String
    let future: Bool
    var id: String { path }
}

// Radar is the set of renderable radar frames, past then forecast, plus the
// infrared satellite frames for the alternate view.
struct Radar: Codable {
    let host: String
    @NullableArray var frames: [RadarFrame]
    @NullableArray var satellite: [RadarFrame]
}

// Alert is one active weather alert.
struct WeatherAlert: Codable, Identifiable {
    let event: String
    let headline: String
    let severity: String
    let urgency: String
    let area: String
    let onset: Date
    let ends: Date
    let description: String
    let instruction: String
    var id: String { event + area + headline }
}

// Alerts is the set of active alerts, most severe first.
struct Alerts: Codable {
    let alerts: [WeatherAlert]
}

// TideEvent is a single high or low water extreme.
struct TideEvent: Codable, Identifiable {
    let time: Date
    let type: String
    let heightFt: Double
    var id: Date { time }
    // isHigh reports whether this extreme is a high tide.
    var isHigh: Bool { type == "high" }
}

// Lightning is the near-term thunderstorm and strike risk. level 0 (none) hides
// the panel; 1 to 4 climb from a low watch to extreme.
struct Lightning: Codable {
    let risk: String
    let level: Int
    let imminent: Bool
    let next: Date
    let hasNext: Bool
    let peakCapeJPerKg: Double
    let stormHours: Int
    let headline: String
}

// Tides holds high and low water for the coast nearest a location. available is
// false inland, which is how the dashboard knows to hide the panel.
struct Tides: Codable {
    let available: Bool
    let stationId: String
    let stationName: String
    let state: String
    let distanceKm: Double
    let datum: String
    let units: String
    let events: [TideEvent]
}
