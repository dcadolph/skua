import CoreLocation
import SwiftUI
import UIKit
import WidgetKit

// StyleStore owns the app's look: the everyday theme and any scheduled party.
// Every change re-resolves Theme and bumps token, which the root view keys on
// so the whole interface redraws in the new palette.
@MainActor
final class StyleStore: ObservableObject {
    // plan is the saved party, live or not.
    @Published private(set) var plan: OccasionPlan? = OccasionStore.load()
    // themeID is the chosen everyday palette.
    @Published private(set) var themeID: String = Palette.named(SharedStore.defaults.string(forKey: Theme.themeKey)).id
    // token changes whenever the resolved palette changes.
    @Published private(set) var token: String = Theme.active.id

    // live is the party running right now, nil outside its dates.
    var live: OccasionPlan? { plan.flatMap { $0.isLive() ? $0 : nil } }

    // setPlan saves or clears the party and repaints.
    func setPlan(_ new: OccasionPlan?) {
        OccasionStore.save(new)
        plan = new
        refresh()
    }

    // setTheme saves the everyday palette and repaints.
    func setTheme(_ id: String) {
        SharedStore.defaults.set(id, forKey: Theme.themeKey)
        themeID = id
        refresh()
    }

    // refresh re-resolves the palette, so a party that just ended hands the app
    // back, and tells the widgets.
    func refresh() {
        Theme.reload()
        if token != Theme.active.id {
            token = Theme.active.id
        }
        objectWillChange.send()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// PartyBanner is the strip under the header while a party runs: the crew, the
// heat, and a tap to the controls.
struct PartyBanner: View {
    let plan: OccasionPlan
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(plan.kind.art(heat: plan.heat))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(plan.kind.title) weekend")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.text)
                    Text("\(plan.kind.crew), heat set to \(plan.heat.title.lowercased())")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                HeatFlames(heat: plan.heat)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// HeatFlames shows the heat as a row of lit flames, one per step.
struct HeatFlames: View {
    let heat: Heat

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Heat.allCases) { h in
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(h.rank <= heat.rank ? Theme.accent : Theme.muted.opacity(0.3))
            }
        }
    }
}

// PartySection is the party control panel: pick a pack, set the dates, turn
// the heat dial, and share the forecast with the group chat.
struct PartySection: View {
    @ObservedObject var style: StyleStore
    @ObservedObject var store: WeatherStore
    @State private var share: ShareItem?

    var body: some View {
        GlassSection(title: "Party mode", icon: "party.popper.fill", tint: Theme.accent) {
            Picker("Pack", selection: packBinding) {
                Text("Off").tag(OccasionKind?.none)
                ForEach(OccasionKind.allCases) { Text($0.title).tag(OccasionKind?.some($0)) }
            }
            .pickerStyle(.segmented)
            if let plan = style.plan {
                heatDial(plan)
                DatePicker("Starts", selection: dateBinding(\.start), displayedComponents: [.date, .hourAndMinute])
                    .font(.subheadline)
                    .foregroundStyle(Theme.text)
                DatePicker("Ends", selection: dateBinding(\.end), in: plan.start..., displayedComponents: [.date, .hourAndMinute])
                    .font(.subheadline)
                    .foregroundStyle(Theme.text)
                if !plan.isLive() {
                    Text(plan.end <= Date() ? "This party is over. Pick new dates to run it again." : "Scheduled. The pack takes over when it starts.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                if style.live != nil, store.voice != nil, store.forecast != nil {
                    Button {
                        Task { share = await renderShare() }
                    } label: {
                        Label("Send the forecast to the group chat", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("A party pack takes over the voice, the colors, and the bird for a weekend, then hands the app back on its own.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .sheet(item: $share) { ActivityView(items: [$0.file]) }
    }

    // heatDial is the four-step filth slider.
    private func heatDial(_ plan: OccasionPlan) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("Heat")
                    .font(.subheadline)
                    .foregroundStyle(Theme.text)
                Spacer()
                HeatFlames(heat: plan.heat)
            }
            Slider(value: heatBinding, in: 0...Double(Heat.allCases.count - 1), step: 1)
                .tint(Theme.accent)
            HStack {
                ForEach(Heat.allCases) { h in
                    Text(h.title)
                        .font(.system(size: 11, weight: h == plan.heat ? .bold : .medium))
                        .foregroundStyle(h == plan.heat ? Theme.accent : Theme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // packBinding switches packs, starting a fresh weekend when turned on.
    private var packBinding: Binding<OccasionKind?> {
        Binding {
            style.plan?.kind
        } set: { kind in
            Haptics.tick()
            guard let kind else {
                style.setPlan(nil)
                return
            }
            if var plan = style.plan {
                plan.kind = kind
                style.setPlan(plan)
            } else {
                style.setPlan(.weekend(kind))
            }
            reloadVoice()
        }
    }

    // heatBinding maps the slider position onto a heat.
    private var heatBinding: Binding<Double> {
        Binding {
            Double(style.plan?.heat.rank ?? 0)
        } set: { value in
            guard var plan = style.plan else { return }
            let heat = Heat.allCases[min(Heat.allCases.count - 1, max(0, Int(value.rounded())))]
            guard heat != plan.heat else { return }
            Haptics.tick()
            plan.heat = heat
            style.setPlan(plan)
            reloadVoice()
        }
    }

    // dateBinding edits one end of the party's window.
    private func dateBinding(_ path: WritableKeyPath<OccasionPlan, Date>) -> Binding<Date> {
        Binding {
            style.plan?[keyPath: path] ?? Date()
        } set: { date in
            guard var plan = style.plan else { return }
            plan[keyPath: path] = date
            if plan.end <= plan.start {
                plan.end = Calendar.current.date(byAdding: .day, value: 1, to: plan.start) ?? plan.start
            }
            style.setPlan(plan)
            reloadVoice()
        }
    }

    // reloadVoice refetches the line so a pack or heat change lands at once.
    private func reloadVoice() {
        let level = UserDefaults.standard.string(forKey: "skua.level") ?? "dry"
        Task { await store.reloadVoice(level: level) }
    }

    // renderShare draws the share card to a PNG file. A named file previews
    // and attaches cleanly in Messages, where a bare image often does not.
    @MainActor
    private func renderShare() async -> ShareItem? {
        guard let plan = style.live, let voice = store.voice, let fc = store.forecast else { return nil }
        let place = store.isDeviceFix
            ? await store.cityName(for: store.coordinate) ?? store.placeName : store.placeName
        let card = PartyShareCard(plan: plan, voice: voice, forecast: fc, place: place)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let png = renderer.uiImage?.pngData() else { return nil }
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("skua-\(plan.kind.rawValue)-forecast.png")
        do {
            try png.write(to: file, options: .atomic)
        } catch {
            return nil
        }
        return ShareItem(file: file)
    }
}

// ShareItem wraps a rendered card file so a sheet can present it.
struct ShareItem: Identifiable {
    // id distinguishes successive renders.
    let id = UUID()
    // file is the rendered share card on disk.
    let file: URL
}

// ActivityView presents the system share sheet.
struct ActivityView: UIViewControllerRepresentable {
    // items is what gets shared.
    let items: [Any]

    // makeUIViewController builds the share sheet.
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    // updateUIViewController has nothing to update.
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// PartyShareCard is the image the crew passes around: the bird, the numbers,
// and the line, in the party's colors. It avoids materials, which do not
// render off screen.
struct PartyShareCard: View {
    let plan: OccasionPlan
    let voice: Voice
    let forecast: Forecast
    let place: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.kind.crew.uppercased())
                        .font(.system(size: 12, weight: .heavy))
                        .kerning(2)
                        .foregroundStyle(Theme.accent)
                    Text(place)
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.text)
                    Text(Date().formatted(.dateTime.weekday(.wide).hour().minute()))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(plan.kind.art(heat: plan.heat))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(f(forecast.current.tempC))°")
                    .font(.system(size: 64, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.text)
                VStack(alignment: .leading, spacing: 2) {
                    Text(forecast.current.condition)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.text)
                    if let today = forecast.daily.first {
                        Text("High \(f(today.highC))°, low \(f(today.lowC))°")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            Text(voice.line)
                .font(.system(size: 21, weight: .regular, design: .serif))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(voice.briefing)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Skua forecast, \(plan.kind.title.lowercased()) edition")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Spacer()
                HeatFlames(heat: plan.heat)
            }
        }
        .padding(22)
        .frame(width: 380)
        .background(
            ZStack {
                Theme.ground
                RadialGradient(colors: [Theme.glow.opacity(0.45), .clear], center: .topTrailing, startRadius: 10, endRadius: 360)
            }
        )
    }
}
