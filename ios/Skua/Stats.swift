import Foundation

// Stats tracks lifetime usage and weather extremes on device: the high scores
// and statistics the Skua tab brags about.
enum Stats {
    // record folds one successful forecast into the running stats.
    static func record(forecast: Forecast, place: String) {
        let d = UserDefaults.standard
        if d.object(forKey: "skua.stat.first") == nil {
            d.set(Date(), forKey: "skua.stat.first")
        }
        d.set(d.integer(forKey: "skua.stat.fetches") + 1, forKey: "skua.stat.fetches")

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var days = Set(d.stringArray(forKey: "skua.stat.days") ?? [])
        days.insert(fmt.string(from: Date()))
        d.set(Array(days), forKey: "skua.stat.days")

        var cities = Set(d.stringArray(forKey: "skua.stat.cities") ?? [])
        cities.insert(place)
        d.set(Array(cities), forKey: "skua.stat.cities")

        let temp = Double(f(forecast.current.tempC))
        if d.object(forKey: "skua.stat.hot") == nil || temp > d.double(forKey: "skua.stat.hot") {
            d.set(temp, forKey: "skua.stat.hot")
        }
        if d.object(forKey: "skua.stat.cold") == nil || temp < d.double(forKey: "skua.stat.cold") {
            d.set(temp, forKey: "skua.stat.cold")
        }
        let gust = Double(mph(forecast.current.windGustKph))
        if gust > d.double(forKey: "skua.stat.gust") {
            d.set(gust, forKey: "skua.stat.gust")
        }
        if forecast.current.uvIndex > d.double(forKey: "skua.stat.uv") {
            d.set(forecast.current.uvIndex, forKey: "skua.stat.uv")
        }
    }

    // firstUse is the install-and-first-fetch date, nil before any fetch.
    static var firstUse: Date? {
        UserDefaults.standard.object(forKey: "skua.stat.first") as? Date
    }

    // daysUsed counts distinct days the app fetched weather.
    static var daysUsed: Int {
        (UserDefaults.standard.stringArray(forKey: "skua.stat.days") ?? []).count
    }

    // fetches counts lifetime forecast loads.
    static var fetches: Int {
        UserDefaults.standard.integer(forKey: "skua.stat.fetches")
    }

    // cities counts distinct places viewed.
    static var cities: Int {
        (UserDefaults.standard.stringArray(forKey: "skua.stat.cities") ?? []).count
    }

    // hottest is the highest temperature seen, nil before any fetch.
    static var hottest: Double? {
        UserDefaults.standard.object(forKey: "skua.stat.hot") as? Double
    }

    // coldest is the lowest temperature seen, nil before any fetch.
    static var coldest: Double? {
        UserDefaults.standard.object(forKey: "skua.stat.cold") as? Double
    }

    // biggestGust is the strongest gust seen in mph.
    static var biggestGust: Double {
        UserDefaults.standard.double(forKey: "skua.stat.gust")
    }

    // highestUV is the highest UV index seen.
    static var highestUV: Double {
        UserDefaults.standard.double(forKey: "skua.stat.uv")
    }
}
