import CoreLocation
import SwiftUI

// SavedPlace is one saved location.
struct SavedPlace: Codable, Identifiable, Equatable {
    let name: String
    let lat: Double
    let lon: Double
    var id: String { "\(name)|\(lat)|\(lon)" }
}

// GeoResult is one hit from the Open-Meteo geocoder.
struct GeoResult: Codable, Identifiable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let admin1: String?
    let country: String?

    // label renders the place with its region for the results list.
    var label: String {
        [name, admin1, country].compactMap { $0 }.joined(separator: ", ")
    }
}

// geoSearch queries the free Open-Meteo geocoder.
func geoSearch(_ query: String) async -> [GeoResult] {
    var comps = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
    comps.queryItems = [
        URLQueryItem(name: "name", value: query),
        URLQueryItem(name: "count", value: "8"),
    ]
    struct Response: Codable { let results: [GeoResult]? }
    guard let (data, _) = try? await URLSession.shared.data(from: comps.url!),
        let resp = try? JSONDecoder().decode(Response.self, from: data)
    else { return [] }
    return resp.results ?? []
}

// PlacesStore persists the saved location list.
@MainActor
final class PlacesStore: ObservableObject {
    // places is the saved list.
    @Published var places: [SavedPlace] {
        didSet { save() }
    }

    private static let storageKey = "skua.places"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let saved = try? JSONDecoder().decode([SavedPlace].self, from: data) {
            places = saved
        } else {
            places = []
        }
    }

    // add saves a place once.
    func add(_ p: SavedPlace) {
        if !places.contains(p) {
            places.append(p)
        }
    }

    // remove drops a place.
    func remove(_ p: SavedPlace) {
        places.removeAll { $0 == p }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(places) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// LocationSheet searches for places and switches the dashboard between them.
struct LocationSheet: View {
    @ObservedObject var places: PlacesStore
    // onPick receives the chosen coordinate and name.
    let onPick: (CLLocationCoordinate2D, String) -> Void
    // onMyLocation re-requests the device position.
    let onMyLocation: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [GeoResult] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onMyLocation()
                        dismiss()
                    } label: {
                        Label("My location", systemImage: "location.fill")
                            .foregroundStyle(Theme.accent)
                    }
                }
                if !results.isEmpty {
                    Section("Results") {
                        ForEach(results) { r in
                            Button {
                                let place = SavedPlace(name: r.name, lat: r.latitude, lon: r.longitude)
                                places.add(place)
                                onPick(CLLocationCoordinate2D(latitude: r.latitude, longitude: r.longitude), r.name)
                                dismiss()
                            } label: {
                                Text(r.label)
                            }
                        }
                    }
                }
                if !places.places.isEmpty {
                    Section("Saved") {
                        ForEach(places.places) { p in
                            Button {
                                onPick(CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon), p.name)
                                dismiss()
                            } label: {
                                Text(p.name)
                            }
                        }
                        .onDelete { idx in
                            for i in idx {
                                places.remove(places.places[i])
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search a place")
            .onChange(of: query) { q in
                Task {
                    guard q.count >= 2 else {
                        results = []
                        return
                    }
                    results = await geoSearch(q)
                }
            }
            .navigationTitle("Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
