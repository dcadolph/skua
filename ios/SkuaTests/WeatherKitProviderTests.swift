import XCTest

@testable import Skua

// WeatherKitProviderTests checks the WeatherKit-to-Forecast mapping offline.
final class WeatherKitProviderTests: XCTestCase {
    // now is a fixed observation time for every case.
    private let now = Date(timeIntervalSince1970: 1_792_000_000)

    // current builds a current snapshot with the given condition and rate.
    private func current(_ code: String, rate: Double) -> WKCurrentSnapshot {
        WKCurrentSnapshot(
            date: now, conditionCode: code, tempC: 25.5, apparentTempC: 27, precipMMPerHour: rate,
            windKph: 12, windGustKph: 30, windDirDeg: 181.6, humidity: 0.874, uvIndex: 2,
            pressureHPa: 1012, dewPointC: 23, visibilityKm: 6.4, cloudCover: 0.95, isDaylight: true)
    }

    // day builds a day snapshot starting the given number of days from now.
    private func day(_ offset: Int) -> WKDaySnapshot {
        let start = now.addingTimeInterval(Double(offset) * 86_400 - 3600)
        return WKDaySnapshot(
            date: start, sunrise: start.addingTimeInterval(7 * 3600),
            sunset: start.addingTimeInterval(19 * 3600), conditionCode: "thunderstorms",
            highC: 31, lowC: 22, uvIndexMax: 8, precipSumMM: 12, precipChance: 0.7,
            windMaxKph: 20, windGustMaxKph: nil)
    }

    // testHeavyRainNow is the 2026-10-14 case: raining hard on the user. The
    // mapped forecast must say rain and carry a nonzero rate.
    func testHeavyRainNow() {
        let fc = WeatherKitMapper.forecast(
            location: Location(lat: 30.27, lon: -97.74), current: current("heavyRain", rate: 4),
            minutes: nil, hours: [], days: [])
        XCTAssertEqual(fc.current.condition, "Heavy Rain")
        XCTAssertGreaterThan(fc.current.precipMM, 0)
        XCTAssertEqual(fc.source, "weatherkit-device")
        XCTAssertEqual(fc.current.time, now)
        XCTAssertEqual(fc.current.humidity, 87)
        XCTAssertEqual(fc.current.cloudCover, 95)
        XCTAssertEqual(fc.current.windDirDeg, 182)
        XCTAssertTrue(fc.minutely?.isEmpty ?? false)
    }

    // testHumanize checks the condition words the voice banks key on.
    func testHumanize() {
        let cases = [
            "heavyRain": "Heavy Rain", "isolatedThunderstorms": "Isolated Thunderstorms",
            "drizzle": "Drizzle", "mostlyClear": "Mostly Clear", "": "Unknown",
        ]
        for (code, want) in cases {
            XCTAssertEqual(WeatherKitMapper.humanize(code), want, code)
        }
    }

    // testNowcastBuckets folds 60 minutes into four 15-minute millimeter totals.
    func testNowcastBuckets() {
        let minutes = (0..<60).map { i in
            WKMinuteSnapshot(date: now.addingTimeInterval(Double(i) * 60), precipMMPerHour: i < 30 ? 0 : 6)
        }
        let points = WeatherKitMapper.minutely(minutes)
        XCTAssertEqual(points.count, 4)
        XCTAssertEqual(points[0].precipMM, 0, accuracy: 1e-9)
        XCTAssertEqual(points[2].precipMM, 1.5, accuracy: 1e-9)
        XCTAssertEqual(points[2].time, now.addingTimeInterval(30 * 60))
    }

    // testYesterdayPeeled checks the day before the observation becomes
    // yesterday and daily starts today.
    func testYesterdayPeeled() {
        let fc = WeatherKitMapper.forecast(
            location: Location(lat: 0, lon: 0), current: current("clear", rate: 0),
            minutes: nil, hours: [], days: [day(-1), day(0), day(1)])
        XCTAssertNotNil(fc.yesterday)
        XCTAssertEqual(fc.daily.count, 2)
        XCTAssertEqual(fc.daily[0].condition, "Thunderstorms")
    }

    // testRoundTripsThroughJSON checks the mapped forecast encodes and decodes
    // with the shapes the store, widgets, and Go core read.
    func testRoundTripsThroughJSON() throws {
        let fc = WeatherKitMapper.forecast(
            location: Location(lat: 1, lon: 2), current: current("rain", rate: 2),
            minutes: nil, hours: [], days: [day(0)])
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let back = try dec.decode(Forecast.self, from: enc.encode(fc))
        XCTAssertEqual(back.current.condition, "Rain")
        XCTAssertEqual(back.daily.count, 1)
        XCTAssertNil(back.yesterday)
    }
}
