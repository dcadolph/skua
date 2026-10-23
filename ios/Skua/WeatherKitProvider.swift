import CoreLocation
import Foundation
import OSLog
import WeatherKit

// WeatherKitProvider fetches the forecast from Apple WeatherKit on device. Its
// current conditions are observation-backed and its minute series is a real
// precipitation nowcast, which the model-only fallback cannot offer. The call
// needs no key, only the WeatherKit entitlement.
enum WeatherKitProvider {
    // source names this provider in a Forecast.
    static let source = "weatherkit-device"

    // hourlySpan is how far ahead the hourly series reaches.
    private static let hourlySpan: TimeInterval = 48 * 3600

    // dailyDays is how many days of daily forecast to request, today included.
    private static let dailyDays = 10

    // forecast returns the WeatherKit forecast for a coordinate, mapped into the
    // app's Forecast shape. One daily query starts yesterday, so the comparison
    // day and the forecast days arrive together.
    static func forecast(lat: Double, lon: Double) async throws -> Forecast {
        let now = Date()
        let cal = Calendar.current
        let hourStart = cal.dateInterval(of: .hour, for: now)?.start ?? now
        let today = cal.startOfDay(for: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        let lastDay = cal.date(byAdding: .day, value: dailyDays, to: today) ?? today
        let (current, minutes, hours, days) = try await WeatherService.shared.weather(
            for: CLLocation(latitude: lat, longitude: lon),
            including: .current, .minute,
            .hourly(startDate: hourStart, endDate: hourStart.addingTimeInterval(hourlySpan)),
            .daily(startDate: yesterday, endDate: lastDay))
        return WeatherKitMapper.forecast(
            location: Location(lat: lat, lon: lon),
            current: WKCurrentSnapshot(current),
            minutes: minutes.map { $0.forecast.map(WKMinuteSnapshot.init) },
            hours: hours.forecast.map(WKHourSnapshot.init),
            days: days.forecast.map(WKDaySnapshot.init))
    }

    // disableKey is the UserDefaults flag that forces the fallback in debug builds,
    // for testing the Open-Meteo path and for simulators without WeatherKit.
    static let disableKey = "skua.debug.noWeatherKit"

    // forecastWithFallback returns the WeatherKit forecast, or the Go core's
    // Open-Meteo forecast when WeatherKit throws or is disabled for debugging.
    static func forecastWithFallback(lat: Double, lon: Double) async throws -> Forecast {
        if !disabled() {
            do {
                let fc = try await forecast(lat: lat, lon: lon)
                log.info("weatherkit ok: as of \(fc.current.time, privacy: .public)")
                return fc
            } catch {
                log.error("weatherkit failed: using fallback: \(error.localizedDescription, privacy: .public)")
            }
        }
        return try await SkuaClient.shared.forecast(lat: lat, lon: lon)
    }

    // disabled reports whether the debug flag forces the fallback. Release builds
    // always use WeatherKit first.
    private static func disabled() -> Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: disableKey)
        #else
        return false
        #endif
    }

    // log records WeatherKit failures for device debugging.
    private static let log = Logger(subsystem: "com.douglasadolph.Skua", category: "weatherkit")

    // attribution returns Apple's required WeatherKit attribution.
    static func attribution() async throws -> WeatherAttribution {
        try await WeatherService.shared.attribution
    }
}

// WKCurrentSnapshot holds the current-conditions values the mapper reads, in the
// units the app stores. WeatherKit's own types cannot be built in a test, so the
// mapper works over these instead.
struct WKCurrentSnapshot {
    // date is the moment the observation is valid for.
    let date: Date
    // conditionCode is the WeatherCondition raw value, e.g. "heavyRain".
    let conditionCode: String
    // tempC is the air temperature in Celsius.
    let tempC: Double
    // apparentTempC is the feels-like temperature in Celsius.
    let apparentTempC: Double
    // precipMMPerHour is the precipitation intensity in millimeters per hour.
    let precipMMPerHour: Double
    // windKph is the sustained wind speed in kilometers per hour.
    let windKph: Double
    // windGustKph is the gust speed in kilometers per hour, zero when absent.
    let windGustKph: Double
    // windDirDeg is the direction the wind comes from, degrees from north.
    let windDirDeg: Double
    // humidity is the relative humidity as a 0 to 1 fraction.
    let humidity: Double
    // uvIndex is the UV index.
    let uvIndex: Int
    // pressureHPa is the sea-level pressure in hectopascals.
    let pressureHPa: Double
    // dewPointC is the dew point in Celsius.
    let dewPointC: Double
    // visibilityKm is the visibility in kilometers.
    let visibilityKm: Double
    // cloudCover is the sky cover as a 0 to 1 fraction.
    let cloudCover: Double
    // isDaylight reports whether the sun is up.
    let isDaylight: Bool
}

// WKMinuteSnapshot is one minute of the precipitation nowcast.
struct WKMinuteSnapshot {
    // date is the start of the minute.
    let date: Date
    // precipMMPerHour is the precipitation intensity in millimeters per hour.
    let precipMMPerHour: Double
}

// WKHourSnapshot holds one hour of forecast in the app's units.
struct WKHourSnapshot {
    // date is the start of the hour.
    let date: Date
    // conditionCode is the WeatherCondition raw value.
    let conditionCode: String
    // tempC is the air temperature in Celsius.
    let tempC: Double
    // apparentTempC is the feels-like temperature in Celsius.
    let apparentTempC: Double
    // precipMM is the expected precipitation amount for the hour in millimeters.
    let precipMM: Double
    // precipChance is the precipitation probability as a 0 to 1 fraction.
    let precipChance: Double
    // windKph is the sustained wind speed in kilometers per hour.
    let windKph: Double
    // windGustKph is the gust speed in kilometers per hour, nil when absent.
    let windGustKph: Double?
    // humidity is the relative humidity as a 0 to 1 fraction.
    let humidity: Double
    // pressureHPa is the sea-level pressure in hectopascals.
    let pressureHPa: Double
    // dewPointC is the dew point in Celsius.
    let dewPointC: Double
    // cloudCover is the sky cover as a 0 to 1 fraction.
    let cloudCover: Double
    // uvIndex is the UV index.
    let uvIndex: Int
}

// WKDaySnapshot holds one day of forecast in the app's units.
struct WKDaySnapshot {
    // date is the start of the day in the location's time zone.
    let date: Date
    // sunrise is the sunrise time, nil in polar day or night.
    let sunrise: Date?
    // sunset is the sunset time, nil in polar day or night.
    let sunset: Date?
    // conditionCode is the WeatherCondition raw value.
    let conditionCode: String
    // highC is the day's high in Celsius.
    let highC: Double
    // lowC is the day's low in Celsius.
    let lowC: Double
    // uvIndexMax is the day's peak UV index.
    let uvIndexMax: Int
    // precipSumMM is the day's expected precipitation in millimeters.
    let precipSumMM: Double
    // precipChance is the precipitation probability as a 0 to 1 fraction.
    let precipChance: Double
    // windMaxKph is the day's wind speed in kilometers per hour.
    let windMaxKph: Double
    // windGustMaxKph is the day's gust speed in kilometers per hour, nil when absent.
    let windGustMaxKph: Double?
}

extension WKCurrentSnapshot {
    // init reads the values out of a WeatherKit CurrentWeather.
    init(_ w: CurrentWeather) {
        self.init(
            date: w.date,
            conditionCode: w.condition.rawValue,
            tempC: w.temperature.converted(to: .celsius).value,
            apparentTempC: w.apparentTemperature.converted(to: .celsius).value,
            precipMMPerHour: WeatherKitMapper.mmPerHour(w.precipitationIntensity),
            windKph: w.wind.speed.converted(to: .kilometersPerHour).value,
            windGustKph: w.wind.gust?.converted(to: .kilometersPerHour).value ?? 0,
            windDirDeg: w.wind.direction.converted(to: .degrees).value,
            humidity: w.humidity,
            uvIndex: w.uvIndex.value,
            pressureHPa: w.pressure.converted(to: .hectopascals).value,
            dewPointC: w.dewPoint.converted(to: .celsius).value,
            visibilityKm: w.visibility.converted(to: .kilometers).value,
            cloudCover: w.cloudCover,
            isDaylight: w.isDaylight)
    }
}

extension WKMinuteSnapshot {
    // init reads the values out of a WeatherKit MinuteWeather.
    init(_ m: MinuteWeather) {
        self.init(date: m.date, precipMMPerHour: WeatherKitMapper.mmPerHour(m.precipitationIntensity))
    }
}

extension WKHourSnapshot {
    // init reads the values out of a WeatherKit HourWeather.
    init(_ h: HourWeather) {
        self.init(
            date: h.date,
            conditionCode: h.condition.rawValue,
            tempC: h.temperature.converted(to: .celsius).value,
            apparentTempC: h.apparentTemperature.converted(to: .celsius).value,
            precipMM: h.precipitationAmount.converted(to: .millimeters).value,
            precipChance: h.precipitationChance,
            windKph: h.wind.speed.converted(to: .kilometersPerHour).value,
            windGustKph: h.wind.gust?.converted(to: .kilometersPerHour).value,
            humidity: h.humidity,
            pressureHPa: h.pressure.converted(to: .hectopascals).value,
            dewPointC: h.dewPoint.converted(to: .celsius).value,
            cloudCover: h.cloudCover,
            uvIndex: h.uvIndex.value)
    }
}

extension WKDaySnapshot {
    // init reads the values out of a WeatherKit DayWeather.
    init(_ d: DayWeather) {
        self.init(
            date: d.date,
            sunrise: d.sun.sunrise,
            sunset: d.sun.sunset,
            conditionCode: d.condition.rawValue,
            highC: d.highTemperature.converted(to: .celsius).value,
            lowC: d.lowTemperature.converted(to: .celsius).value,
            uvIndexMax: d.uvIndex.value,
            precipSumMM: d.precipitationAmount.converted(to: .millimeters).value,
            precipChance: d.precipitationChance,
            windMaxKph: d.wind.speed.converted(to: .kilometersPerHour).value,
            windGustMaxKph: d.wind.gust?.converted(to: .kilometersPerHour).value)
    }
}

// WeatherKitMapper turns WeatherKit snapshots into the app's Forecast. It is pure
// so the mapping is testable without the network.
enum WeatherKitMapper {
    // nowcastBucket is the width of one minutely point, matching the fallback's
    // 15-minute series so thresholds and the nowcast chart read the same.
    static let nowcastBucket: TimeInterval = 15 * 60

    // forecast maps the snapshots into a Forecast. A day that began a full day or
    // more before the observation becomes yesterday, and hours that ended before
    // the current hour are dropped.
    static func forecast(location: Location, current: WKCurrentSnapshot, minutes: [WKMinuteSnapshot]?,
                         hours: [WKHourSnapshot], days: [WKDaySnapshot]) -> Forecast {
        var daily = days.map(dailyPoint)
        var yesterday: DailyPoint?
        while daily.count > 1, current.date.timeIntervalSince(daily[0].date) >= 24 * 3600 {
            yesterday = daily.removeFirst()
        }
        let hourly = hours
            .filter { current.date.timeIntervalSince($0.date) < 3600 }
            .map(hourlyPoint)
        return Forecast(
            source: WeatherKitProvider.source,
            location: location,
            moon: moon(at: current.date),
            yesterday: yesterday,
            current: currentPoint(current),
            minutely: minutely(minutes ?? []),
            hourly: hourly,
            daily: daily)
    }

    // currentPoint maps the current snapshot. The precipitation rate in mm/h is
    // stored as the current interval's precipitation, as the Go core does for
    // WeatherKit.
    static func currentPoint(_ c: WKCurrentSnapshot) -> Current {
        Current(
            time: c.date,
            condition: humanize(c.conditionCode),
            tempC: c.tempC,
            apparentTempC: c.apparentTempC,
            precipMM: c.precipMMPerHour,
            windKph: c.windKph,
            humidity: percent(c.humidity),
            windDirDeg: Int(c.windDirDeg.rounded()),
            uvIndex: Double(c.uvIndex),
            pressureHPa: c.pressureHPa,
            dewPointC: c.dewPointC,
            visibilityKm: c.visibilityKm,
            windGustKph: c.windGustKph,
            cloudCover: percent(c.cloudCover),
            isDay: c.isDaylight)
    }

    // minutely folds the minute nowcast into 15-minute points holding the
    // expected millimeters for each span, the same unit the fallback reports.
    static func minutely(_ minutes: [WKMinuteSnapshot]) -> [MinutelyPoint] {
        guard let first = minutes.first else { return [] }
        var points: [MinutelyPoint] = []
        var bucketStart = first.date
        var sum = 0.0
        for m in minutes {
            if m.date.timeIntervalSince(bucketStart) >= nowcastBucket {
                points.append(MinutelyPoint(time: bucketStart, precipMM: sum))
                bucketStart = bucketStart.addingTimeInterval(nowcastBucket)
                sum = 0
            }
            sum += m.precipMMPerHour / 60
        }
        points.append(MinutelyPoint(time: bucketStart, precipMM: sum))
        return points
    }

    // hourlyPoint maps one hour.
    static func hourlyPoint(_ h: WKHourSnapshot) -> HourlyPoint {
        HourlyPoint(
            time: h.date,
            condition: humanize(h.conditionCode),
            tempC: h.tempC,
            apparentTempC: h.apparentTempC,
            precipMM: h.precipMM,
            windKph: h.windKph,
            windGustKph: h.windGustKph,
            humidity: percent(h.humidity),
            pressureHPa: h.pressureHPa,
            dewPointC: h.dewPointC,
            cloudCover: percent(h.cloudCover),
            uvIndex: Double(h.uvIndex),
            precipProb: percent(h.precipChance))
    }

    // dailyPoint maps one day. Polar days with no sunrise or sunset fall back to
    // the day's start, as the fallback falls back to its zero time.
    static func dailyPoint(_ d: WKDaySnapshot) -> DailyPoint {
        let sunrise = d.sunrise ?? d.date
        let sunset = d.sunset ?? d.date
        return DailyPoint(
            date: d.date,
            sunrise: sunrise,
            sunset: sunset,
            condition: humanize(d.conditionCode),
            highC: d.highC,
            lowC: d.lowC,
            apparentHighC: nil,
            apparentLowC: nil,
            uvIndexMax: Double(d.uvIndexMax),
            precipSumMM: d.precipSumMM,
            windMaxKph: d.windMaxKph,
            windGustMaxKph: d.windGustMaxKph,
            daylightSec: max(0, sunset.timeIntervalSince(sunrise)),
            precipProb: percent(d.precipChance))
    }

    // humanize turns a condition code like "heavyRain" into "Heavy Rain", the
    // same words the Go core produces, so the voice banks and storm checks match.
    static func humanize(_ code: String) -> String {
        guard let head = code.first else { return "Unknown" }
        var out = String(head).uppercased()
        var prev = head
        for ch in code.dropFirst() {
            if ch.isUppercase && prev.isLowercase { out.append(" ") }
            out.append(ch)
            prev = ch
        }
        return out
    }

    // mmPerHour converts a precipitation intensity to millimeters per hour.
    static func mmPerHour(_ rate: Measurement<UnitSpeed>) -> Double {
        rate.converted(to: .metersPerSecond).value * 3_600_000
    }

    // percent converts a 0 to 1 fraction to a rounded 0 to 100 percentage.
    static func percent(_ frac: Double) -> Int {
        Int((frac * 100).rounded())
    }

    // synodicDays is the mean length of a lunar cycle in days.
    private static let synodicDays = 29.530588853

    // lunarEpoch is a reference new moon: January 6, 2000 at 18:14 UTC.
    private static let lunarEpoch = Date(timeIntervalSince1970: 947_182_440)

    // moonNames is the octant naming, new moon first.
    private static let moonNames = [
        "New moon", "Waxing crescent", "First quarter", "Waxing gibbous",
        "Full moon", "Waning gibbous", "Last quarter", "Waning crescent",
    ]

    // moon computes the lunar phase from the mean synodic cycle, mirroring the
    // Go core so both sources report the same phase.
    static func moon(at date: Date) -> MoonInfo {
        let days = date.timeIntervalSince(lunarEpoch) / 86_400
        var phase = (days / synodicDays).truncatingRemainder(dividingBy: 1)
        if phase < 0 { phase += 1 }
        let idx = Int((phase * 8 + 0.5).rounded(.down)) % 8
        return MoonInfo(
            phase: phase,
            illumination: (1 - cos(2 * .pi * phase)) / 2,
            name: moonNames[idx],
            index: idx)
    }
}
