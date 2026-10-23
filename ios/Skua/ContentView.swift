import CoreLocation
import SwiftUI
import UIKit

// Haptics wraps the selection tick used by the scrubber and pickers.
enum Haptics {
    private static let gen = UISelectionFeedbackGenerator()

    // tick fires one selection change when haptics are enabled.
    static func tick() {
        if UserDefaults.standard.object(forKey: "skua.haptics") as? Bool ?? true {
            gen.selectionChanged()
        }
    }
}

// ContentView is the app: an animated sky with swipeable pages on top.
struct ContentView: View {
    @StateObject private var store = WeatherStore()
    @StateObject private var location = LocationProvider()
    @StateObject private var layout = LayoutStore()
    @StateObject private var places = PlacesStore()
    @StateObject private var plans = PlansStore()
    @StateObject private var calendar = CalendarStore()
    @StateObject private var family = FamilyStore()
    @StateObject private var style = StyleStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("skua.level") private var level = "dry"
    @State private var page = 0
    @State private var scrub: Int?
    @State private var radarPlaying = true
    @State private var radarFrame = 0
    @State private var radarSatellite = false
    @State private var showLayout = false
    @State private var showPlaces = false
    @State private var showSettings = false
    @State private var pollenDetail: Pollen?
    @State private var heroWidth: CGFloat = 320
    @State private var scrubHorizontal: Bool?
    @State private var stormComps: [ComponentInstance] = layoutPresets[1].build()

    var body: some View {
        ZStack {
            SkyView(scene: skyScene, glow: Theme.glow)
            TabView(selection: $page) {
                today.tag(0)
                radarPage.tag(1)
                SkuaTab(store: store, style: style, level: $level).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .id(style.token)
            VStack {
                Spacer()
                tabBar
            }
        }
        .task {
            location.request()
            Notifier.requestPermission()
            calendar.request()
            await store.load(level: level, next: calendar.nextEvent)
        }
        .sheet(isPresented: $showLayout) {
            LayoutSheet(layout: layout)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(style: style, forecastSource: store.forecast?.source) {
                Task { await store.load(level: level, next: calendar.nextEvent) }
            }
        }
        .sheet(item: $pollenDetail) { PollenDetailView(pollen: $0, family: family) }
        .sheet(isPresented: $showPlaces) {
            LocationSheet(places: places) { coord, name in
                store.use(coord, name: name)
                Task { await store.load(level: level, next: calendar.nextEvent) }
            } onMyLocation: {
                location.request()
            }
        }
        .onChange(of: level) { newLevel in
            Haptics.tick()
            Task { await store.reloadVoice(level: newLevel, next: calendar.nextEvent) }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            let before = style.live
            style.refresh()
            let partyChanged = before != style.live
            Task {
                await store.reloadIfStale(level: level, next: calendar.nextEvent)
                if partyChanged {
                    await store.reloadVoice(level: level, next: calendar.nextEvent)
                }
            }
        }
        .onChange(of: calendar.events) { _ in
            Task { await store.reloadVoice(level: level, next: calendar.nextEvent) }
        }
        .onReceive(location.$fix) { fix in
            guard let fix else { return }
            store.useFix(fix)
            Task { await store.nameFix(fix) }
            Task { await store.load(level: level, next: calendar.nextEvent) }
        }
    }

    // displayed is the hour under the scrubber, or the present conditions.
    private var displayed: (temp: Double, condition: String, night: Bool, label: String, precip: Int)? {
        guard let fc = store.forecast else { return nil }
        if let i = scrub, fc.hourly.indices.contains(i) {
            let h = fc.hourly[i]
            let hour = Calendar.current.component(.hour, from: h.time)
            return (
                h.tempC, h.condition, hour < 6 || hour >= 20,
                h.time.formatted(date: .omitted, time: .shortened), h.precipProb
            )
        }
        let c = fc.current
        return (c.tempC, c.condition, !c.isDay, "Now", c.precipProb(fc))
    }

    // smartStormActive reports whether the storm layout should take over.
    private var smartStormActive: Bool {
        guard UserDefaults.standard.bool(forKey: "skua.smartstorm"),
            let c = store.forecast?.current.condition.lowercased()
        else { return false }
        return c.contains("rain") || c.contains("storm") || c.contains("drizzle")
            || c.contains("thunder")
    }

    // skyScene follows whatever hour is displayed, so scrubbing into tonight's
    // rain darkens the whole sky.
    private var skyScene: SkyScene {
        guard let d = displayed else { return .clearNight }
        return SkyScene.from(condition: d.condition, isDay: !d.night)
    }

    // dayFraction is the sun's progress from sunrise to sunset, negative before
    // dawn and above one after dusk so the hero scene shows the moon.
    private var dayFraction: Double {
        guard let today = store.forecast?.daily.first else { return 0.5 }
        let span = today.sunset.timeIntervalSince(today.sunrise)
        guard span > 0 else { return -1 }
        return Date().timeIntervalSince(today.sunrise) / span
    }

    // moonPhase drives the hero moon's shape.
    private var moonPhase: Double { store.forecast?.moon?.phase ?? 0.5 }

    // today is the main page: hero, voice, and the glass sections.
    private var today: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                if let plan = style.live {
                    PartyBanner(plan: plan) {
                        withAnimation(.snappy(duration: 0.25)) { page = 2 }
                        Haptics.tick()
                    }
                }
                if !places.places.isEmpty {
                    locationsBar
                }
                if store.failed, store.forecast == nil {
                    GlassSection(title: nil) {
                        Text("Skua cannot reach its weather right now. It will retry when you are back on the home network.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                } else if store.failed {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Offline, showing the last fetch")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                hero
                scrubTrack
                if let fc = store.forecast, scrub == nil {
                    heroFacts(fc)
                }
                if let fc = store.forecast {
                    asOfLine(fc)
                }
                if !store.alerts.isEmpty {
                    AlertsCard(alerts: store.alerts)
                }
                if let fc = store.forecast {
                    if smartStormActive {
                        HStack(spacing: 6) {
                            Image(systemName: "cloud.bolt.rain.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Storm layout active")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Theme.purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.violet.opacity(0.18), in: Capsule())
                    }
                    ForEach((smartStormActive ? stormComps : layout.components).filter(\.on)) { comp in
                        componentView(comp, forecast: fc)
                    }
                    Button {
                        showLayout = true
                        Haptics.tick()
                    } label: {
                        Label("Customize layout", systemImage: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Theme.accent, in: Capsule())
                    }
                    .padding(.top, 6)
                } else if !store.failed {
                    ProgressView().tint(Theme.accent).padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 92)
        }
        .refreshable { await store.load(level: level, next: calendar.nextEvent) }
    }

    // tabBar is the floating pill navigation with the search well beside it.
    private var tabBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                tabButton("Forecast", icon: "cloud.sun.fill", tag: 0)
                tabButton("Radar", icon: "dot.radiowaves.left.and.right", tag: 1)
                tabButton("Skua", icon: "bird.fill", tag: 2)
            }
            .padding(5)
            .background(.ultraThinMaterial, in: Capsule())
            Button {
                showPlaces = true
                Haptics.tick()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.bottom, 8)
    }

    // tabButton is one tab in the pill.
    private func tabButton(_ label: String, icon: String, tag: Int) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) { page = tag }
            Haptics.tick()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .frame(width: 74, height: 46)
            .background(page == tag ? AnyShapeStyle(Theme.accent.opacity(0.22)) : AnyShapeStyle(.clear), in: Capsule())
            .foregroundStyle(page == tag ? Theme.accent : Theme.muted)
        }
    }

    // componentView renders one placed component with its instance config.
    @ViewBuilder
    private func componentView(_ comp: ComponentInstance, forecast fc: Forecast) -> some View {
        switch comp.kind {
        case "flight":
            FlightPlanCard(forecast: fc, lightning: store.lightning, plans: plans.plans, events: calendar.events)
        case "plans":
            PlansCard(
                plans: plans, places: places,
                fallback: CLLocationCoordinate2D(
                    latitude: store.coordinate.latitude, longitude: store.coordinate.longitude))
        case "graph":
            GraphCard(
                hours: Array(fc.hourly.prefix(48)),
                seriesID: comp.config["series"] ?? "temp",
                window: Int(comp.config["window"] ?? "24") ?? 24,
                onSeriesChange: { layout.setConfig(comp.id, key: "series", value: $0) },
                onWindowChange: { layout.setConfig(comp.id, key: "window", value: "\($0)") })
        case "nowcast":
            if let minutely = fc.minutely {
                NowcastCard(minutely: minutely)
            }
        case "gauges":
            GaugesCard(current: fc.current, hours: fc.hourly, today: fc.daily.first)
        case "daily":
            DailyCard(days: Array(fc.daily.prefix(7)), style: comp.config["style"] ?? "bars")
        case "moon":
            if let moon = fc.moon {
                MoonCard(moon: moon)
            }
        case "sun":
            if let today = fc.daily.first {
                SunCard(today: today)
            }
        case "details":
            DetailsCard(current: fc.current, today: fc.daily.first)
        case "air":
            if let air = store.air {
                AirCard(air: air)
            }
        case "tides":
            if let tides = store.tides, tides.available, !tides.events.isEmpty {
                TideCard(tides: tides)
            }
        case "lightning":
            if let lightning = store.lightning, lightning.level >= 1 {
                LightningCard(lightning: lightning)
            }
        case "uv":
            if let uv = fc.daily.first?.uvIndexMax {
                UVCard(uv: uv)
            }
        case "aurora":
            if let aurora = store.aurora {
                AuroraCard(aurora: aurora)
            }
        case "wind":
            WindCard(current: fc.current)
        case "comfort":
            ComfortCard(current: fc.current)
        case "marine":
            if let marine = store.marine, marine.available {
                MarineCard(marine: marine)
            }
        case "fact":
            if let fact = store.fact {
                FactCard(fact: fact)
            }
        case "pollen":
            if let pollen = store.pollen {
                PollenCard(pollen: pollen)
                    .contentShape(Rectangle())
                    .onTapGesture { pollenDetail = pollen }
            }
        default:
            EmptyView()
        }
    }

    // locationsBar is the constant row of places, one tap to jump.
    private var locationsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                placeChip("My location", icon: "location.fill", active: store.isDeviceFix) {
                    location.request()
                }
                ForEach(places.places) { p in
                    placeChip(p.name, active: store.placeName == p.name) {
                        store.use(
                            CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon), name: p.name)
                        Task { await store.load(level: level, next: calendar.nextEvent) }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            places.remove(p)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
                Button {
                    showPlaces = true
                    Haptics.tick()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
    }

    // placeChip is one location in the bar.
    private func placeChip(
        _ name: String, icon: String? = nil, active: Bool, action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            Haptics.tick()
        } label: {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon) }
                Text(name)
            }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    active ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.ultraThinMaterial),
                    in: Capsule())
                .foregroundStyle(active ? Color.black : Theme.muted)
        }
    }

    // header names the place under a small wordmark, with the layout editor a
    // tap away.
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("SKUA")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(2)
                    .foregroundStyle(Theme.muted)
                HStack(spacing: 8) {
                    if store.isDeviceFix {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                    }
                    Text(store.placeName)
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.text)
                }
            }
            Spacer()
            Menu {
                Button {
                    showLayout = true
                } label: {
                    Label("Customize dashboard", systemImage: "square.grid.2x2")
                }
                Menu {
                    ForEach(["dry", "proper", "sassy", "salty", "feral"], id: \.self) { l in
                        Button {
                            level = l
                        } label: {
                            if l == level {
                                Label(l.capitalized, systemImage: "checkmark")
                            } else {
                                Text(l.capitalized)
                            }
                        }
                    }
                } label: {
                    Label("Personality", systemImage: "theatermasks.fill")
                }
                Button {
                    withAnimation(.snappy(duration: 0.25)) { page = 2 }
                } label: {
                    Label("Party mode", systemImage: "party.popper.fill")
                }
                Divider()
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.top, 4)
    }

    // hero is the vivid weather scene with the temperature readout and the time
    // scrubber: drag across it to travel through the day, and the sky follows.
    private var hero: some View {
        ZStack(alignment: .top) {
            HeroScene(scene: skyScene, dayFraction: dayFraction)
            heroSceneContent
                .padding(16)
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .contentShape(Rectangle())
        .background(
            GeometryReader { g in
                Color.clear
                    .onAppear { heroWidth = g.size.width }
                    .onChange(of: g.size.width) { heroWidth = $0 }
            }
        )
        .gesture(
            DragGesture(minimumDistance: 14)
                .onChanged { g in
                    // Decide direction on the first move so a vertical pull
                    // falls through to the scroll view's refresh.
                    if scrubHorizontal == nil {
                        scrubHorizontal = abs(g.translation.width) > abs(g.translation.height) * 1.3
                    }
                    guard scrubHorizontal == true else { return }
                    let idx = min(23, max(0, Int(g.location.x / max(1, heroWidth) * 24)))
                    if idx != scrub {
                        scrub = idx
                        Haptics.tick()
                    }
                }
                .onEnded { _ in
                    scrubHorizontal = nil
                    if scrub != nil {
                        withAnimation(.snappy(duration: 0.25)) { scrub = nil }
                    }
                }
        )
    }

    // heroSceneContent is the white readout laid over the sky scene.
    @ViewBuilder
    private var heroSceneContent: some View {
        if let d = displayed, let fc = store.forecast {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: -6) {
                        if scrub != nil {
                            Text(d.label)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.bottom, 4)
                        }
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: conditionSymbol(d.condition, night: d.night))
                                .font(.system(size: 34))
                                .symbolRenderingMode(.multicolor)
                            Text("\(f(d.temp))°")
                                .font(.system(size: 80, weight: .semibold, design: .serif))
                                .foregroundStyle(.white)
                                .contentTransition(scrub == nil ? .numericText() : .identity)
                                .animation(scrub == nil ? .snappy(duration: 0.2) : nil, value: f(d.temp))
                        }
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(d.condition)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Feels \(f(fc.current.apparentTempC))°")
                            .foregroundStyle(.white.opacity(0.85))
                        if let today = fc.daily.first {
                            HStack(spacing: 6) {
                                Text("\(f(today.highC))°")
                                Text("\(f(today.lowC))°")
                            }
                            .foregroundStyle(.white)
                            .fontWeight(.bold)
                        }
                        Text("Wind \(mph(fc.current.windKph)) \(unitSpeed())")
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .font(.footnote)
                    .shadow(color: .black.opacity(0.35), radius: 4)
                }

                Spacer(minLength: 8)
                if scrub == nil, let line = store.voice?.line {
                    Text(line)
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.55), radius: 6, y: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // heroFacts is the tight glanceable row of facts under the quip.
    private func heroFacts(_ fc: Forecast) -> some View {
        HStack(spacing: 8) {
            if let call = RainCall.make(
                current: fc.current, minutely: fc.minutely ?? [], now: Date())
            {
                factPill(icon: "umbrella.fill", tint: Theme.rain, text: call)
            }
            if let sun = sunLine(fc) {
                factPill(icon: sun.icon, tint: Theme.amber, text: sun.text)
            }
            if let y = yesterdayLine(fc) {
                factPill(icon: "arrow.up.arrow.down", tint: Theme.muted, text: y)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // asOfLine stamps the observation time and data source under the hero facts.
    private func asOfLine(_ fc: Forecast) -> some View {
        let label = fc.source == WeatherKitProvider.source ? "Apple Weather" : "Open-Meteo"
        let time = fc.current.time.formatted(date: .omitted, time: .shortened)
        return Text("as of \(time) · \(label)")
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // factPill is one compact fact chip.
    private func factPill(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.25), in: Capsule())
    }

    // scrubTrack is the 24 tick marks that light up while time traveling.
    private var scrubTrack: some View {
        HStack(spacing: 3) {
            ForEach(0..<24, id: \.self) { i in
                Capsule()
                    .fill(i == scrub ? Theme.accent : Theme.hair)
                    .frame(height: i == scrub ? 14 : 8)
                    .frame(maxWidth: .infinity)
            }
        }
        .opacity(scrub == nil ? 0.45 : 1)
        .frame(height: 16)
        .padding(.top, 4)
    }

    // radarRecenter bumps to recenter the map on the current place.
    @State private var radarRecenter = 0

    // radarPage is the full-screen animated radar with playback controls.
    private var radarPage: some View {
        ZStack(alignment: .bottom) {
            if let radar = store.radar {
                let frames = radarSatellite ? radar.satellite : radar.frames
                RadarMapView(
                    host: radar.host, frames: frames,
                    tileColor: radarSatellite ? "0/0_0" : "2/1_1",
                    center: CLLocationCoordinate2D(
                        latitude: store.coordinate.latitude, longitude: store.coordinate.longitude),
                    playing: radarPlaying,
                    recenterToken: radarRecenter,
                    frameIndex: $radarFrame
                )
                .ignoresSafeArea()
                radarControls(frames: frames, hasSatellite: !radar.satellite.isEmpty)
            } else {
                ProgressView().tint(Theme.accent)
            }
        }
    }

    // radarControls is the mode toggle, playback, and the timeline over the map.
    private func radarControls(frames: [RadarFrame], hasSatellite: Bool) -> some View {
        let frame = frames.indices.contains(radarFrame) ? frames[radarFrame] : frames.last
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                if hasSatellite {
                    Picker("Layer", selection: $radarSatellite) {
                        Text("Radar").tag(false)
                        Text("Satellite").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                    .onChange(of: radarSatellite) { _ in radarFrame = 0 }
                }
                Spacer()
                Button {
                    radarRecenter += 1
                    Haptics.tick()
                } label: {
                    Image(systemName: "location.fill").foregroundStyle(Theme.accent)
                }
            }
            HStack(spacing: 12) {
                Button {
                    radarPlaying.toggle()
                    Haptics.tick()
                } label: {
                    Image(systemName: radarPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
                if let frame {
                    Text(frame.time.formatted(date: .omitted, time: .shortened))
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Theme.text)
                    if frame.future {
                        Text("FORECAST")
                            .font(.system(size: 9, weight: .bold)).kerning(0.5)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.accent, in: Capsule()).foregroundStyle(.black)
                    } else {
                        Text("PAST")
                            .font(.system(size: 9, weight: .bold)).kerning(0.5)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.muted.opacity(0.3), in: Capsule()).foregroundStyle(Theme.text)
                    }
                }
                Spacer()
            }
            RadarTimeline(frames: frames, index: $radarFrame, playing: $radarPlaying)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 16)
        .padding(.bottom, 74)
    }

    // sunLine counts down to the next sun event in compact form.
    private func sunLine(_ fc: Forecast) -> (icon: String, text: String)? {
        let now = Date()
        guard let today = fc.daily.first else { return nil }
        if today.sunrise > now {
            return ("sunrise.fill", "Sunrise \(hm(today.sunrise.timeIntervalSince(now)))")
        }
        if today.sunset > now {
            return ("sunset.fill", "Sunset \(hm(today.sunset.timeIntervalSince(now)))")
        }
        if let tomorrow = fc.daily.dropFirst().first {
            return ("sunrise.fill", "Sunrise \(hm(tomorrow.sunrise.timeIntervalSince(now)))")
        }
        return nil
    }

    // yesterdayLine compares today's high to yesterday's in compact form.
    private func yesterdayLine(_ fc: Forecast) -> String? {
        guard let y = fc.yesterday, let today = fc.daily.first else { return nil }
        let diff = f(today.highC) - f(y.highC)
        if abs(diff) < 2 { return "Like yesterday" }
        return "\(abs(diff))° \(diff > 0 ? "hotter" : "cooler")"
    }

    // hm renders a duration as hours and minutes.
    private func hm(_ interval: TimeInterval) -> String {
        let mins = max(0, Int(interval / 60))
        if mins < 60 { return "\(mins)m" }
        return "\(mins / 60)h \(mins % 60)m"
    }
}

// Current.precipProb reads today's rain chance for the hero chip row.
private extension Current {
    func precipProb(_ fc: Forecast) -> Int {
        fc.daily.first?.precipProb ?? 0
    }
}

// GlassSection is the borderless translucent panel the dashboard sections use,
// with an optional tinted icon giving each section an identity.
struct GlassSection<Content: View>: View {
    let title: String?
    var icon: String? = nil
    var tint: Color = Theme.muted
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack(spacing: 7) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    Text(title)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Theme.muted)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.45))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.hair, lineWidth: 1)
        )
    }
}
