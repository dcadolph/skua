import SwiftUI
import UIKit
import WeatherKit

// SettingsSheet is the app's control panel: units, alerts, haptics, smart
// layouts, the app icon gallery, and about.
struct SettingsSheet: View {
    // style owns the everyday theme and any running party.
    @ObservedObject var style: StyleStore
    // forecastSource is the source string of the last loaded forecast, if any.
    let forecastSource: String?
    // onChanged fires after any setting that affects the dashboard, so the
    // caller can reload.
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var imperial = imperialUnits()
    @State private var notify = UserDefaults.standard.object(forKey: "skua.notify") as? Bool ?? true
    @State private var haptics = UserDefaults.standard.object(forKey: "skua.haptics") as? Bool ?? true
    @State private var smartStorm = UserDefaults.standard.bool(forKey: "skua.smartstorm")
    @State private var activeIcon = UIApplication.shared.alternateIconName
    @State private var attribution: WeatherAttribution?
    @Environment(\.colorScheme) private var colorScheme

    // icons is the gallery: bundle icon name to display name, nil for primary.
    private let icons: [(name: String?, label: String, preview: String)] = [
        (nil, "Cloud Perch", "CloudPerch"),
        ("Bolt", "Sky Punch", "Bolt"),
        ("Ember", "Ember", "Ember"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("General") {
                    HStack(spacing: 10) {
                        chip("ruler.fill", Theme.blue)
                        Text("Units")
                        Spacer()
                        Picker("", selection: $imperial) {
                            Text("°F, mph").tag(true)
                            Text("°C, kph").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 170)
                    }
                    Toggle(isOn: $notify) {
                        HStack(spacing: 10) {
                            chip("bell.badge.fill", Theme.warn)
                            Text("Severe weather alerts")
                        }
                    }
                    .tint(Theme.accent)
                    Toggle(isOn: $haptics) {
                        HStack(spacing: 10) {
                            chip("waveform", Theme.teal)
                            Text("Haptics")
                        }
                    }
                    .tint(Theme.accent)
                }
                Section {
                    Toggle(isOn: $smartStorm) {
                        HStack(spacing: 10) {
                            chip("cloud.bolt.rain.fill", Theme.violet)
                            Text("Smart storm layout")
                        }
                    }
                    .tint(Theme.accent)
                } footer: {
                    Text("When rain or storms are active, the dashboard switches itself to the Stormrider layout, then back when it clears.")
                }
                Section {
                    ForEach(Palette.choosable, id: \.id) { p in
                        Button {
                            style.setTheme(p.id)
                            Haptics.tick()
                        } label: {
                            HStack(spacing: 12) {
                                HStack(spacing: 0) {
                                    p.ground
                                    p.accent
                                    p.teal
                                    p.rain
                                }
                                .frame(width: 44, height: 22)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                Text(p.name)
                                    .foregroundStyle(Theme.text)
                                Spacer()
                                if style.themeID == p.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Theme")
                } footer: {
                    Text(style.live == nil ? "Colors for every screen and the widgets." : "A party pack is running, so its colors win until it ends.")
                }
                Section("App icon") {
                    ForEach(icons, id: \.label) { icon in
                        Button {
                            UIApplication.shared.setAlternateIconName(icon.name)
                            activeIcon = icon.name
                            Haptics.tick()
                        } label: {
                            HStack(spacing: 12) {
                                if let img = UIImage(named: icon.preview) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                Text(icon.label)
                                    .foregroundStyle(Theme.text)
                                Spacer()
                                if activeIcon == icon.name {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                    }
                }
                if forecastSource == WeatherKitProvider.source {
                    Section("Weather data") {
                        if let attribution {
                            VStack(alignment: .leading, spacing: 8) {
                                AsyncImage(
                                    url: colorScheme == .dark
                                        ? attribution.combinedMarkDarkURL
                                        : attribution.combinedMarkLightURL
                                ) { image in
                                    image.resizable().scaledToFit()
                                } placeholder: {
                                    Color.clear
                                }
                                .frame(height: 16)
                                Link("Other data sources", destination: attribution.legalPageURL)
                                    .font(.footnote)
                            }
                        } else {
                            Text("Apple Weather")
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                Section("About") {
                    HStack(spacing: 10) {
                        chip("bird.fill", Theme.accent)
                        Text("Skua")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                            .foregroundStyle(Theme.muted)
                    }
                    Link(destination: URL(string: "https://skuaweather.com")!) {
                        HStack(spacing: 10) {
                            chip("globe", Theme.blue)
                            Text("skuaweather.com")
                        }
                    }
                    Text("A skua is a stout seabird that rides storm fronts and fears nothing in the sky. Fitting.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
            .task {
                if forecastSource == WeatherKitProvider.source {
                    attribution = try? await WeatherKitProvider.attribution()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: imperial) { v in
                UserDefaults.standard.set(v, forKey: "skua.imperial")
                Haptics.tick()
                onChanged()
            }
            .onChange(of: notify) { v in
                UserDefaults.standard.set(v, forKey: "skua.notify")
            }
            .onChange(of: haptics) { v in
                UserDefaults.standard.set(v, forKey: "skua.haptics")
            }
            .onChange(of: smartStorm) { v in
                UserDefaults.standard.set(v, forKey: "skua.smartstorm")
                onChanged()
            }
        }
        .preferredColorScheme(.dark)
    }

    // chip is the colored icon square that gives settings rows identity.
    private func chip(_ icon: String, _ tint: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(tint, in: RoundedRectangle(cornerRadius: 7))
    }
}
