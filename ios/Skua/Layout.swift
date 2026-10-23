import Foundation
import SwiftUI

// ComponentInstance is one placed dashboard component. Instances carry their
// own config, so the same kind can appear twice with different settings, like
// two graphs pinned to different series.
struct ComponentInstance: Codable, Identifiable, Equatable {
    // id makes each placement unique.
    var id: UUID
    // kind names the component type.
    var kind: String
    // on reports whether the component shows.
    var on: Bool
    // config carries per-instance settings, like a graph's series or a list's
    // style.
    var config: [String: String]

    init(kind: String, on: Bool = true, config: [String: String] = [:]) {
        self.id = UUID()
        self.kind = kind
        self.on = on
        self.config = config
    }
}

// SavedLayout is one named dashboard composition the user can switch to.
struct SavedLayout: Codable, Identifiable, Equatable {
    // id makes the layout addressable.
    var id: UUID
    // name is the user's label for it.
    var name: String
    // components is the composition.
    var components: [ComponentInstance]
}

// ComponentKind describes one entry in the add-component catalog.
struct ComponentKind: Identifiable {
    // id is the kind key.
    let id: String
    // name labels the catalog entry.
    let name: String
    // icon is the catalog symbol.
    let icon: String
    // tint colors the catalog symbol.
    let tint: Color
    // multi allows more than one instance.
    let multi: Bool
}

// componentCatalog is every component the dashboard can hold.
let componentCatalog: [ComponentKind] = [
    ComponentKind(id: "flight", name: "Flight plan", icon: "paperplane.fill", tint: Theme.cyan, multi: false),
    ComponentKind(id: "plans", name: "Plans", icon: "checklist", tint: Theme.violet, multi: false),
    ComponentKind(id: "nowcast", name: "Nowcast", icon: "umbrella.fill", tint: Theme.rain, multi: false),
    ComponentKind(id: "graph", name: "Graph", icon: "chart.xyaxis.line", tint: Theme.accent, multi: true),
    ComponentKind(id: "gauges", name: "Conditions", icon: "gauge.medium", tint: Theme.green, multi: false),
    ComponentKind(id: "daily", name: "7-day", icon: "calendar", tint: Theme.accent, multi: false),
    ComponentKind(id: "moon", name: "Moon", icon: "moon.stars.fill", tint: Theme.purple, multi: false),
    ComponentKind(id: "sun", name: "Sun", icon: "sun.horizon.fill", tint: Theme.yellow, multi: false),
    ComponentKind(id: "air", name: "Air quality", icon: "aqi.medium", tint: Theme.green, multi: false),
    ComponentKind(id: "pollen", name: "Allergens", icon: "allergens", tint: Theme.amber, multi: false),
    ComponentKind(id: "tides", name: "Tides", icon: "water.waves", tint: Theme.cyan, multi: false),
    ComponentKind(id: "lightning", name: "Lightning", icon: "bolt.fill", tint: Theme.yellow, multi: false),
    ComponentKind(id: "uv", name: "UV index", icon: "sun.max.trianglebadge.exclamationmark.fill", tint: Theme.amber, multi: false),
    ComponentKind(id: "aurora", name: "Aurora", icon: "sparkles", tint: Theme.purple, multi: false),
    ComponentKind(id: "wind", name: "Wind", icon: "wind", tint: Theme.teal, multi: false),
    ComponentKind(id: "comfort", name: "Comfort", icon: "humidity.fill", tint: Theme.cyan, multi: false),
    ComponentKind(id: "marine", name: "Sea state", icon: "water.waves", tint: Theme.cyan, multi: false),
    ComponentKind(id: "fact", name: "On this day", icon: "book.fill", tint: Theme.violet, multi: false),
    ComponentKind(id: "details", name: "Details grid", icon: "square.grid.2x2.fill", tint: Theme.slate, multi: false),
]

// kindMeta looks a catalog entry up.
func kindMeta(_ id: String) -> ComponentKind {
    componentCatalog.first { $0.id == id }
        ?? ComponentKind(id: id, name: id.capitalized, icon: "square", tint: Theme.muted, multi: false)
}

// LayoutPreset is one named prebuilt composition.
struct LayoutPreset: Identifiable {
    let id: String
    let name: String
    let build: () -> [ComponentInstance]
}

// layoutPresets is the free preset gallery.
let layoutPresets: [LayoutPreset] = [
    LayoutPreset(id: "skua", name: "Skua") {
        [
            ComponentInstance(kind: "flight"),
            ComponentInstance(kind: "gauges"),
            ComponentInstance(kind: "graph", config: ["series": "temp"]),
            ComponentInstance(kind: "daily", config: ["style": "bars"]),
            ComponentInstance(kind: "pollen"),
            ComponentInstance(kind: "lightning"),
            ComponentInstance(kind: "tides"),
        ]
    },
    LayoutPreset(id: "full", name: "Everything") {
        [
            ComponentInstance(kind: "flight"),
            ComponentInstance(kind: "plans"),
            ComponentInstance(kind: "lightning"),
            ComponentInstance(kind: "nowcast"),
            ComponentInstance(kind: "graph", config: ["series": "temp"]),
            ComponentInstance(kind: "gauges"),
            ComponentInstance(kind: "daily", config: ["style": "bars"]),
            ComponentInstance(kind: "moon"),
            ComponentInstance(kind: "sun"),
            ComponentInstance(kind: "tides"),
            ComponentInstance(kind: "air"),
            ComponentInstance(kind: "pollen"),
            ComponentInstance(kind: "uv"),
            ComponentInstance(kind: "wind"),
            ComponentInstance(kind: "comfort"),
            ComponentInstance(kind: "aurora"),
            ComponentInstance(kind: "marine"),
            ComponentInstance(kind: "fact"),
        ]
    },
    LayoutPreset(id: "storm", name: "Stormrider") {
        [
            ComponentInstance(kind: "lightning"),
            ComponentInstance(kind: "nowcast"),
            ComponentInstance(kind: "graph", config: ["series": "rain"]),
            ComponentInstance(kind: "graph", config: ["series": "gusts"]),
            ComponentInstance(kind: "gauges"),
            ComponentInstance(kind: "daily", config: ["style": "bars"]),
        ]
    },
    LayoutPreset(id: "data", name: "Data Hound") {
        [
            ComponentInstance(kind: "graph", config: ["series": "temp"]),
            ComponentInstance(kind: "graph", config: ["series": "pressure"]),
            ComponentInstance(kind: "gauges"),
            ComponentInstance(kind: "details"),
            ComponentInstance(kind: "daily", config: ["style": "compact"]),
            ComponentInstance(kind: "moon"),
            ComponentInstance(kind: "air"),
        ]
    },
    LayoutPreset(id: "minimal", name: "Minimal") {
        [
            ComponentInstance(kind: "daily", config: ["style": "compact"])
        ]
    },
    LayoutPreset(id: "beach", name: "Beachgoer") {
        [
            ComponentInstance(kind: "marine"),
            ComponentInstance(kind: "tides"),
            ComponentInstance(kind: "uv"),
            ComponentInstance(kind: "wind"),
            ComponentInstance(kind: "gauges"),
            ComponentInstance(kind: "daily", config: ["style": "bars"]),
        ]
    },
    LayoutPreset(id: "skywatch", name: "Skywatch") {
        [
            ComponentInstance(kind: "aurora"),
            ComponentInstance(kind: "moon"),
            ComponentInstance(kind: "sun"),
            ComponentInstance(kind: "fact"),
            ComponentInstance(kind: "daily", config: ["style": "compact"]),
        ]
    },
]

// LayoutStore holds the user's named layouts and the active composition.
@MainActor
final class LayoutStore: ObservableObject {
    // layouts is every saved composition.
    @Published var layouts: [SavedLayout] {
        didSet { persist() }
    }
    // activeID names the layout in use.
    @Published var activeID: UUID {
        didSet { persist() }
    }
    // components is the working composition, mirrored into the active layout.
    @Published var components: [ComponentInstance] {
        didSet {
            if let i = layouts.firstIndex(where: { $0.id == activeID }) {
                layouts[i].components = components
            }
        }
    }

    // LayoutFile is the persisted shape.
    private struct LayoutFile: Codable {
        var layouts: [SavedLayout]
        var active: UUID
    }

    private static let storageKey = "skua.layouts.v5"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let file = try? JSONDecoder().decode(LayoutFile.self, from: data), !file.layouts.isEmpty {
            layouts = file.layouts
            activeID = file.active
            components = file.layouts.first { $0.id == file.active }?.components
                ?? file.layouts[0].components
        } else if let data = UserDefaults.standard.data(forKey: "skua.layout.v3"),
            let old = try? JSONDecoder().decode([ComponentInstance].self, from: data), !old.isEmpty {
            let first = SavedLayout(id: UUID(), name: "My layout", components: old)
            layouts = [first]
            activeID = first.id
            components = old
        } else {
            let first = SavedLayout(id: UUID(), name: "Skua", components: layoutPresets[0].build())
            layouts = [first]
            activeID = first.id
            components = first.components
        }
    }

    // switchTo makes a saved layout active.
    func switchTo(_ id: UUID) {
        guard let layout = layouts.first(where: { $0.id == id }) else { return }
        activeID = id
        components = layout.components
    }

    // saveCurrent snapshots the working composition under a new name and makes
    // it active.
    func saveCurrent(as name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let layout = SavedLayout(id: UUID(), name: trimmed, components: components)
        layouts.append(layout)
        activeID = layout.id
    }

    // deleteLayout removes a saved layout, keeping at least one.
    func deleteLayout(_ id: UUID) {
        guard layouts.count > 1 else { return }
        layouts.removeAll { $0.id == id }
        if activeID == id, let first = layouts.first {
            switchTo(first.id)
        }
    }

    // add appends a new instance of a kind to the working composition.
    func add(_ kind: String) {
        var config: [String: String] = [:]
        if kind == "graph" { config["series"] = "temp" }
        if kind == "daily" { config["style"] = "bars" }
        components.append(ComponentInstance(kind: kind, config: config))
    }

    // remove drops an instance.
    func remove(_ id: UUID) {
        components.removeAll { $0.id == id }
    }

    // setConfig updates one instance setting.
    func setConfig(_ id: UUID, key: String, value: String) {
        guard let i = components.firstIndex(where: { $0.id == id }) else { return }
        components[i].config[key] = value
    }

    // apply replaces the working composition with a preset.
    func apply(_ preset: LayoutPreset) {
        components = preset.build()
    }

    // canAdd reports whether the catalog entry is addable.
    func canAdd(_ kind: ComponentKind) -> Bool {
        kind.multi || !components.contains { $0.kind == kind.id }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(LayoutFile(layouts: layouts, active: activeID)) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// LayoutSheet is the interface maker: your named layouts, presets, and the
// component list with add, reorder, restyle, and remove.
struct LayoutSheet: View {
    @ObservedObject var layout: LayoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var askName = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section("My layouts") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(layout.layouts) { l in
                                Button {
                                    layout.switchTo(l.id)
                                    Haptics.tick()
                                } label: {
                                    Text(l.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            l.id == layout.activeID
                                                ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.accent.opacity(0.14)),
                                            in: Capsule())
                                        .foregroundStyle(l.id == layout.activeID ? Color.black : Theme.accent)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        layout.deleteLayout(l.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .disabled(layout.layouts.count == 1)
                                }
                            }
                            Button {
                                newName = ""
                                askName = true
                            } label: {
                                Label("Save as new", systemImage: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .foregroundStyle(Theme.text)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                Section("Presets") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(layoutPresets) { p in
                                Button {
                                    layout.apply(p)
                                    Haptics.tick()
                                } label: {
                                    Text(p.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Theme.violet.opacity(0.2), in: Capsule())
                                        .foregroundStyle(Theme.purple)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    ForEach($layout.components) { $comp in
                        row($comp)
                    }
                    .onMove { from, to in
                        layout.components.move(fromOffsets: from, toOffset: to)
                        Haptics.tick()
                    }
                    .onDelete { idx in
                        for i in idx {
                            layout.remove(layout.components[i].id)
                        }
                    }
                } header: {
                    Text("Components. Drag to reorder, swipe to remove.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Interface maker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(componentCatalog) { kind in
                            Button {
                                layout.add(kind.id)
                                Haptics.tick()
                            } label: {
                                Label(kind.name, systemImage: kind.icon)
                            }
                            .disabled(!layout.canAdd(kind))
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Name this layout", isPresented: $askName) {
                TextField("Layout name", text: $newName)
                Button("Save") {
                    layout.saveCurrent(as: newName)
                    Haptics.tick()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
    }

    // row is one component line with its toggle and per-kind style control.
    private func row(_ comp: Binding<ComponentInstance>) -> some View {
        let meta = kindMeta(comp.wrappedValue.kind)
        return HStack(spacing: 10) {
            Image(systemName: meta.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(meta.tint)
                .frame(width: 24, height: 24)
                .background(meta.tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 1) {
                Text(meta.name)
                if let sub = subtitle(comp.wrappedValue) {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            styleMenu(comp)
            Toggle("", isOn: comp.on)
                .labelsHidden()
                .tint(Theme.accent)
        }
    }

    // subtitle summarizes an instance's config.
    private func subtitle(_ comp: ComponentInstance) -> String? {
        switch comp.kind {
        case "graph":
            let id = comp.config["series"] ?? "temp"
            return graphSeriesList().first { $0.id == id }?.label
        case "daily":
            return comp.config["style"] == "compact" ? "Compact" : "Range bars"
        default:
            return nil
        }
    }

    // styleMenu is the per-kind configuration control.
    @ViewBuilder
    private func styleMenu(_ comp: Binding<ComponentInstance>) -> some View {
        switch comp.wrappedValue.kind {
        case "graph":
            Menu {
                ForEach(graphSeriesList()) { s in
                    Button(s.label) {
                        layout.setConfig(comp.wrappedValue.id, key: "series", value: s.id)
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Theme.muted)
            }
        case "daily":
            Menu {
                Button("Range bars") {
                    layout.setConfig(comp.wrappedValue.id, key: "style", value: "bars")
                }
                Button("Compact") {
                    layout.setConfig(comp.wrappedValue.id, key: "style", value: "compact")
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Theme.muted)
            }
        default:
            EmptyView()
        }
    }
}
