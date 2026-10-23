import CoreLocation
import Foundation
import WidgetKit

// WeatherStore loads everything the dashboard shows and republishes it.
@MainActor
final class WeatherStore: ObservableObject {
    // forecast is the current normalized forecast.
    @Published var forecast: Forecast?
    // voice is the skua's line and briefing.
    @Published var voice: Voice?
    // air is the current air quality.
    @Published var air: AirQuality?
    // alerts is the active alert set.
    @Published var alerts: [WeatherAlert] = []
    // radar is the radar frame index.
    @Published var radar: Radar?
    // tides is the nearest coast's high and low water, nil when inland or unloaded.
    @Published var tides: Tides?
    // lightning is the near-term storm and strike risk, nil until loaded.
    @Published var lightning: Lightning?
    // pollen is today's and tomorrow's allergen read, nil until loaded.
    @Published var pollen: Pollen?
    // aurora is the current auroral activity, nil until loaded.
    @Published var aurora: Aurora?
    // marine is the coastal sea state, nil until loaded and unavailable inland.
    @Published var marine: Marine?
    // fact is today's "this day in history" note, nil until loaded.
    @Published var fact: Fact?
    // failed reports whether the last load hit an error.
    @Published var failed = false
    // placeName labels the location being shown.
    @Published var placeName = "Austin"
    // isDeviceFix reports whether the shown location is the GPS fix rather than a saved place.
    @Published private(set) var isDeviceFix = false

    // fetchedAt is when the shown forecast was loaded, nil before the first load.
    @Published private(set) var fetchedAt: Date?

    // staleAfter is how old the forecast may get before a return to the
    // foreground reloads it.
    static let staleAfter: TimeInterval = 10 * 60

    // coordinate is the location being shown, defaulting to Austin until a fix
    // arrives.
    private(set) var coordinate = CLLocationCoordinate2D(latitude: 30.27, longitude: -97.74)

    // load fetches every panel's data concurrently for the active coordinate. The
    // forecast comes from WeatherKit when it answers and Open-Meteo otherwise, and
    // the voice is spoken from that same forecast once it lands.
    func load(level: String, next: CalEvent? = nil) async {
        failed = false
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let client = SkuaClient.shared
        async let fc = WeatherKitProvider.forecastWithFallback(lat: lat, lon: lon)
        async let aq = client.airQuality(lat: lat, lon: lon)
        async let al = client.alerts(lat: lat, lon: lon)
        async let rd = client.radar()
        async let td = client.tides(lat: lat, lon: lon)
        async let lt = client.lightning(lat: lat, lon: lon)
        async let pl = client.pollen(lat: lat, lon: lon)
        async let au = client.aurora(lat: lat, lon: lon)
        async let mr = client.marine(lat: lat, lon: lon)
        let md = Calendar.current.dateComponents([.month, .day], from: Date())
        async let ft = client.fact(month: md.month ?? 1, day: md.day ?? 1)
        do {
            let got = try await fc
            forecast = got
            fetchedAt = Date()
            Stats.record(forecast: got, place: placeName)
        } catch {
            failed = true
        }
        await reloadVoice(level: level, next: next)
        air = try? await aq
        alerts = (try? await al)?.alerts ?? []
        radar = try? await rd
        tides = try? await td
        lightning = try? await lt
        pollen = try? await pl
        aurora = try? await au
        marine = try? await mr
        fact = try? await ft
        Notifier.notify(alerts: alerts)
        Notifier.notifyLightning(lightning, place: placeName)
    }

    // reloadIfStale reloads when the shown forecast is older than staleAfter, so
    // an app left open since the morning does not keep showing the morning.
    func reloadIfStale(level: String, next: CalEvent? = nil) async {
        if let fetchedAt, Date().timeIntervalSince(fetchedAt) < Self.staleAfter { return }
        await load(level: level, next: next)
    }

    // reloadVoice respeaks the line from the shown forecast, used when the level
    // or party changes. It makes no fetch and leaves the voice alone when there is
    // no forecast yet.
    func reloadVoice(level: String, next: CalEvent? = nil) async {
        guard let forecast else { return }
        let ev = Self.voiceEvent(next)
        let client = SkuaClient.shared
        if let plan = OccasionStore.active() {
            voice = try? await client.partyVoice(
                forecast: forecast, plan: plan, eventTitle: ev.0, eventWhen: ev.1, eventEpoch: ev.2)
            return
        }
        voice = try? await client.voice(
            forecast: forecast, level: level, eventTitle: ev.0, eventWhen: ev.1, eventEpoch: ev.2)
    }

    // voiceEvent breaks a calendar event into the primitives the voice takes: a
    // title, a local time string, and the start as Unix seconds. Empty when nil.
    private static func voiceEvent(_ event: CalEvent?) -> (String, String, Int64) {
        guard let event else { return ("", "", 0) }
        let when = event.start.formatted(date: .omitted, time: .shortened)
        return (event.title, when, Int64(event.start.timeIntervalSince1970))
    }

    // use switches to a coordinate and label, remembering it for background
    // alert checks.
    func use(_ coord: CLLocationCoordinate2D, name: String, deviceFix: Bool = false) {
        coordinate = coord
        placeName = name
        isDeviceFix = deviceFix
        SharedStore.saveLocation(lat: coord.latitude, lon: coord.longitude, name: name)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // useFix switches to the GPS fix right away, labeled "My location", so a load
    // started next reads the new coordinate.
    func useFix(_ coord: CLLocationCoordinate2D) {
        use(coord, name: "My location", deviceFix: true)
    }

    // nameFix renames the GPS fix to its locality by reverse geocoding, leaving
    // "My location" when the geocoder has nothing or the place has changed since.
    func nameFix(_ coord: CLLocationCoordinate2D) async {
        guard let city = await cityName(for: coord) else { return }
        guard isDeviceFix, coordinate.latitude == coord.latitude,
            coordinate.longitude == coord.longitude
        else { return }
        use(coord, name: city, deviceFix: true)
    }

    // cityName reverse geocodes a coordinate to its locality, nil when the geocoder has
    // nothing.
    func cityName(for coord: CLLocationCoordinate2D) async -> String? {
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let marks = try? await CLGeocoder().reverseGeocodeLocation(loc)
        return marks?.first?.locality
    }
}

// LocationProvider asks for the device position once and republishes it.
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    // fix is the resolved device coordinate, nil until located.
    @Published var fix: CLLocationCoordinate2D?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // request asks for permission and a single position.
    func request() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    // locationManagerDidChangeAuthorization retries once permission lands.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    // locationManager did update publishes the first fix.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.first {
            DispatchQueue.main.async { self.fix = loc.coordinate }
        }
    }

    // locationManager failure is quietly ignored; the Austin fallback stands.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
