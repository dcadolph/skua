import XCTest

@testable import Skua

final class FlightPlanTests: XCTestCase {
    // forecast builds a fixture whose condition string says Clear while the rate says rain.
    private func forecast(precipMM: Double, hourlyPrecipMM: Double, hourlyProb: Int) -> Forecast {
        let now = Date()
        let current = Current(
            time: now, condition: "Clear", tempC: 22, apparentTempC: 22, precipMM: precipMM,
            windKph: 8, humidity: 80, windDirDeg: 180, uvIndex: 1, pressureHPa: 1012,
            dewPointC: 18, visibilityKm: 10, windGustKph: 12, cloudCover: 90, isDay: true)
        let hourly = (1...6).map { i in
            HourlyPoint(
                time: now.addingTimeInterval(Double(i) * 3600), condition: "Clear", tempC: 22,
                apparentTempC: 22, precipMM: hourlyPrecipMM, windKph: 8, windGustKph: nil,
                humidity: nil, pressureHPa: nil, dewPointC: nil, cloudCover: nil, uvIndex: nil,
                precipProb: hourlyProb)
        }
        let daily = DailyPoint(
            date: now, sunrise: now.addingTimeInterval(-6 * 3600),
            sunset: now.addingTimeInterval(6 * 3600), condition: "Clear", highC: 25, lowC: 18,
            apparentHighC: nil, apparentLowC: nil, uvIndexMax: 5, precipSumMM: nil,
            windMaxKph: nil, windGustMaxKph: nil, daylightSec: nil, precipProb: 20)
        return Forecast(
            source: "test", location: Location(lat: 30.27, lon: -97.74), moon: nil,
            yesterday: nil, current: current, minutely: nil, hourly: hourly, daily: [daily])
    }

    // testRainingNowOverridesClearCondition checks a clear condition string with a
    // rainy rate never reads as a quiet day.
    func testRainingNowOverridesClearCondition() {
        let wet = forecast(precipMM: 2, hourlyPrecipMM: 1, hourlyProb: 80)
        let text = FlightPlan.summary(for: wet)
        XCTAssertFalse(text.contains("Nothing dramatic"), text)
        XCTAssertTrue(text.contains("rain"), text)
    }

    // testRainingNowNamesWhenItStops checks a dry hour ahead is named.
    func testRainingNowNamesWhenItStops() {
        let letsUp = forecast(precipMM: 2, hourlyPrecipMM: 0, hourlyProb: 5)
        let text = FlightPlan.summary(for: letsUp)
        XCTAssertTrue(text.contains("raining now"), text)
        XCTAssertTrue(text.contains("lets up"), text)
    }
}
