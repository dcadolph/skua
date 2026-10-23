import Foundation

// SharedStore is the App Group defaults the app and its widgets both read, so a
// widget shows the same place and backend the app last used.
enum SharedStore {
    // suiteName is the shared App Group container.
    static let suiteName = "group.com.douglasadolph.skua"

    // defaults is the shared suite, falling back to standard when unavailable.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    // saveLocation records the last shown place for the widget to pick up.
    static func saveLocation(lat: Double, lon: Double, name: String) {
        let d = defaults
        d.set(lat, forKey: "skua.lastLat")
        d.set(lon, forKey: "skua.lastLon")
        d.set(name, forKey: "skua.lastName")
    }

    // lastLocation reads the last shown place, defaulting to Austin when unset.
    static func lastLocation() -> (lat: Double, lon: Double, name: String) {
        let d = defaults
        let lat = d.double(forKey: "skua.lastLat")
        let lon = d.double(forKey: "skua.lastLon")
        if lat == 0 && lon == 0 { return (30.27, -97.74, "Austin") }
        return (lat, lon, d.string(forKey: "skua.lastName") ?? "Weather")
    }

    // apiBase reads the backend base URL, defaulting to the dev Mac.
    static func apiBase() -> String {
        defaults.string(forKey: "skua.api") ?? "http://192.168.163.219:8090"
    }
}
