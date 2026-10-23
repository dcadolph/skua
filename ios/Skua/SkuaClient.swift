import CoreLocation
import Foundation
import SkuaCore

// SkuaClient calls the on-device SkuaCore aggregation library. It returns the
// same normalized shapes the app has always decoded, with no backend involved.
// SkuaCore's functions are plain C functions that report failure through a
// trailing NSError pointer, so each call checks that pointer and throws.
struct SkuaClient {
    // shared is the process-wide client, shared with widgets.
    static let shared = SkuaClient()

    // decoder handles the core's RFC 3339 timestamps.
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // forecast returns the normalized forecast for a coordinate.
    func forecast(lat: Double, lon: Double) async throws -> Forecast {
        try await call { e in SkuacoreForecast(lat, lon, e) }
    }

    // voice returns the skua's line at a maturity level, spoken in imperial or
    // metric, optionally weather-checking the user's next calendar event. It
    // speaks from the forecast the screen is showing and makes no fetch.
    func voice(forecast: Forecast, level: String,
               eventTitle: String = "", eventWhen: String = "", eventEpoch: Int64 = 0) async throws -> Voice {
        let units = imperialUnits() ? "imperial" : "metric"
        let json = try Self.encode(forecast)
        return try await call { e in
            SkuacoreVoice(json, level, units, eventTitle, eventWhen, eventEpoch, e)
        }
    }

    // partyVoice returns a party pack's line and briefing at a heat, with the
    // opener fitted to the listener's local hour, spoken from the shown forecast.
    func partyVoice(forecast: Forecast, plan: OccasionPlan,
                    eventTitle: String = "", eventWhen: String = "", eventEpoch: Int64 = 0) async throws -> Voice {
        let units = imperialUnits() ? "imperial" : "metric"
        let hour = Calendar.current.component(.hour, from: Date())
        let kind = plan.kind.rawValue
        let heat = plan.heat.rawValue
        let json = try Self.encode(forecast)
        return try await call { e in
            SkuacorePartyVoice(json, kind, heat, units, hour, eventTitle, eventWhen, eventEpoch, e)
        }
    }

    // encode writes a forecast as the RFC 3339 JSON the core reads.
    static func encode(_ forecast: Forecast) throws -> String {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return String(decoding: try enc.encode(forecast), as: UTF8.self)
    }

    // airQuality returns current air quality for a coordinate.
    func airQuality(lat: Double, lon: Double) async throws -> AirQuality {
        try await call { e in SkuacoreAirQuality(lat, lon, e) }
    }

    // alerts returns active weather alerts for a coordinate.
    func alerts(lat: Double, lon: Double) async throws -> Alerts {
        try await call { e in SkuacoreAlerts(lat, lon, e) }
    }

    // radar returns the radar frame index.
    func radar() async throws -> Radar {
        try await call { e in SkuacoreRadar(e) }
    }

    // tides returns high and low water for the nearest coast to a coordinate.
    func tides(lat: Double, lon: Double) async throws -> Tides {
        try await call { e in SkuacoreTides(lat, lon, e) }
    }

    // lightning returns near-term storm and strike risk for a coordinate.
    func lightning(lat: Double, lon: Double) async throws -> Lightning {
        try await call { e in SkuacoreLightning(lat, lon, e) }
    }

    // aurora returns the planetary Kp index and whether the northern lights are
    // likely visible from the coordinate.
    func aurora(lat: Double, lon: Double) async throws -> Aurora {
        try await call { e in SkuacoreAurora(lat, lon, e) }
    }

    // marine returns the coastal sea state for a coordinate.
    func marine(lat: Double, lon: Double) async throws -> Marine {
        try await call { e in SkuacoreMarine(lat, lon, e) }
    }

    // fact returns a "this day in history" note for the given month and day.
    func fact(month: Int, day: Int) async throws -> Fact {
        try await call { e in SkuacoreFact(month, day, e) }
    }

    // pollen returns today's and tomorrow's allergen read for a coordinate. The
    // source is ZIP-keyed, so the coordinate is resolved to a US ZIP on-device
    // with Apple's geocoder first.
    func pollen(lat: Double, lon: Double) async throws -> Pollen {
        let zip = try await Self.postalCode(lat: lat, lon: lon)
        return try await call { e in SkuacorePollen(zip, e) }
    }

    // postalCode reverse-geocodes a coordinate to its five-digit US ZIP using
    // the on-device geocoder, throwing when none is found.
    private static func postalCode(lat: Double, lon: Double) async throws -> String {
        let marks = try await CLGeocoder().reverseGeocodeLocation(
            CLLocation(latitude: lat, longitude: lon))
        guard let zip = marks.first?.postalCode, !zip.isEmpty else {
            throw URLError(.resourceUnavailable)
        }
        return String(zip.prefix(5))
    }

    // call runs a Skuacore function off the main thread, surfaces its NSError as
    // a thrown error, and decodes the returned JSON.
    private func call<T: Decodable>(_ body: @escaping (NSErrorPointer) -> String) async throws -> T {
        let json = try await Task.detached(priority: .userInitiated) { () throws -> String in
            var err: NSError?
            let json = body(&err)
            if let err { throw err }
            return json
        }.value
        return try Self.decoder.decode(T.self, from: Data(json.utf8))
    }
}
