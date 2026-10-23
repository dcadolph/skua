import XCTest

@testable import Skua

final class RainCallTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // current builds a fixture with the given condition and rate.
    private func current(_ condition: String, precipMM: Double) -> Current {
        Current(
            time: now, condition: condition, tempC: 22, apparentTempC: 22, precipMM: precipMM,
            windKph: 8, humidity: 80, windDirDeg: 180, uvIndex: 1, pressureHPa: 1012,
            dewPointC: 18, visibilityKm: 10, windGustKph: 12, cloudCover: 90, isDay: true)
    }

    // series builds count 15-minute points starting at now, wet at the given offsets in minutes.
    private func series(count: Int, wetAt: [Int] = []) -> [MinutelyPoint] {
        (0..<count).map { i in
            MinutelyPoint(
                time: now.addingTimeInterval(Double(i) * 900),
                precipMM: wetAt.contains(i * 15) ? 0.5 : 0)
        }
    }

    // testRainingNowWithDryMinutely covers the 2026-10-14 case.
    func testRainingNowWithDryMinutely() {
        let got = RainCall.make(
            current: current("Rain", precipMM: 2.0), minutely: series(count: 8), now: now)
        XCTAssertEqual(got, "Rain now")
    }

    // testHeavyRateWithClearCondition checks the rate alone triggers the call.
    func testHeavyRateWithClearCondition() {
        let got = RainCall.make(
            current: current("Clear", precipMM: 0.3), minutely: series(count: 8), now: now)
        XCTAssertEqual(got, "Rain now")
    }

    // testRainAheadAtThirtyMinutes checks the countdown.
    func testRainAheadAtThirtyMinutes() {
        let got = RainCall.make(
            current: current("Clear", precipMM: 0),
            minutely: series(count: 8, wetAt: [30]), now: now)
        XCTAssertEqual(got, "Rain ~30m")
    }

    // testRainWithinOneMinuteIsNow checks the one-minute floor.
    func testRainWithinOneMinuteIsNow() {
        let got = RainCall.make(
            current: current("Clear", precipMM: 0),
            minutely: series(count: 4, wetAt: [0]), now: now)
        XCTAssertEqual(got, "Rain now")
    }

    // testDryForAnHour checks the dry span from sixty minutes of data.
    func testDryForAnHour() {
        let got = RainCall.make(
            current: current("Clear", precipMM: 0), minutely: series(count: 4), now: now)
        XCTAssertEqual(got, "Dry next 60m")
    }

    // testEmptyMinutely checks that no series gives no call.
    func testEmptyMinutely() {
        let got = RainCall.make(current: current("Clear", precipMM: 0), minutely: [], now: now)
        XCTAssertNil(got)
    }

    // testRainInSpanUnderway counts rain in a span that began just before now.
    func testRainInSpanUnderway() {
        let now = Date(timeIntervalSince1970: 1_792_000_040)
        let cur = Current(
            time: now, condition: "Cloudy", tempC: 20, apparentTempC: 20, precipMM: 0, windKph: 0,
            humidity: 50, windDirDeg: 0, uvIndex: 0, pressureHPa: 1013, dewPointC: 10,
            visibilityKm: 10, windGustKph: 0, cloudCover: 100, isDay: true)
        let pts = [MinutelyPoint(time: now.addingTimeInterval(-40), precipMM: 0.8)]
        XCTAssertEqual(RainCall.make(current: cur, minutely: pts, now: now), "Rain now")
    }
}
