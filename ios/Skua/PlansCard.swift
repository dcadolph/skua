import CoreLocation
import SwiftUI

// PlansCard is your life on the forecast: runs, rides, camps, and trips, each
// scouted by the bird with a verdict for its exact window and place.
struct PlansCard: View {
    @ObservedObject var plans: PlansStore
    @ObservedObject var places: PlacesStore
    let fallback: CLLocationCoordinate2D

    @State private var scouts: [UUID: PlanScout] = [:]
    @State private var expanded: Set<UUID> = []
    @State private var showAdd = false

    var body: some View {
        GlassSection(title: "Plans", icon: "checklist", tint: Theme.violet) {
            if plans.plans.isEmpty {
                Text("Tell the bird what you are up to and it will scout the weather for it.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            VStack(spacing: 0) {
                ForEach(plans.plans) { plan in
                    planRow(plan)
                    if expanded.contains(plan.id), let scout = scouts[plan.id] {
                        detail(plan, scout)
                    }
                }
            }
            Button {
                showAdd = true
                Haptics.tick()
            } label: {
                Label("Add plan", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.violet)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.violet.opacity(0.16), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showAdd) {
            PlanAddSheet(plans: plans, places: places)
        }
        .task(id: plans.plans) {
            for plan in plans.plans where scouts[plan.id] == nil {
                scouts[plan.id] = await scoutPlan(plan, fallback: fallback)
            }
        }
        .refreshableVerdicts(plans: plans, fallback: fallback, scouts: $scouts)
    }

    // planRow is one plan with its verdict pill.
    private func planRow(_ plan: Plan) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) {
                if expanded.contains(plan.id) {
                    expanded.remove(plan.id)
                } else {
                    expanded.insert(plan.id)
                }
            }
            Haptics.tick()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: plan.kind.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(plan.kind.tint)
                    .frame(width: 28, height: 28)
                    .background(plan.kind.tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text(plan.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text)
                    Text("\(plan.whenText)  \(plan.place?.name ?? "Wherever you are")")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                if let scout = scouts[plan.id] {
                    Text(scout.verdict.grade)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(scout.verdict.color, in: Capsule())
                } else {
                    ProgressView().tint(Theme.muted).scaleEffect(0.7)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                plans.remove(plan.id)
            } label: {
                Label("Delete plan", systemImage: "trash")
            }
        }
    }

    // detail is the expanded scout: the bird's line, the window's numbers, a
    // coastal tide note for swims, and a better time to go when one exists.
    private func detail(_ plan: Plan, _ scout: PlanScout) -> some View {
        let v = scout.verdict
        return VStack(alignment: .leading, spacing: 8) {
            Text(v.line)
                .font(.system(.footnote, design: .serif))
                .foregroundStyle(Theme.text)
            HStack(spacing: 14) {
                Stat(label: "Temps", value: "\(v.lo)° to \(v.hi)°", icon: "thermometer.medium", tint: Theme.accent)
                Stat(label: "Rain", value: "\(v.rainMax)%", icon: "drop.fill", tint: Theme.rain)
                Stat(label: "Gusts", value: "\(v.gustMax) \(unitSpeed())", icon: "wind", tint: Theme.green)
                Stat(label: "UV", value: String(format: "%.0f", v.uvMax), icon: "sun.max.fill", tint: Theme.yellow)
            }
            if let tide = scout.tide {
                Label(tide.line, systemImage: "water.waves")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(tide.color)
            }
            if let suggestion = scout.suggestion {
                shiftRow(plan, suggestion)
            }
        }
        .padding(10)
        .background(Theme.hair.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // shiftRow is the bird's better-time pitch, one tap to accept the move.
    private func shiftRow(_ plan: Plan, _ suggestion: ShiftSuggestion) -> some View {
        Button {
            plans.shift(plan.id, byHours: suggestion.deltaHours)
            scouts[plan.id] = nil
            Haptics.tick()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(suggestion.deltaHours > 0 ? "Push it later?" : "Go earlier?")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(0.4)
                        .foregroundStyle(Theme.muted)
                    Text(suggestion.line)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Text(suggestion.grade)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(suggestion.color, in: Capsule())
            }
            .padding(9)
            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// refreshableVerdicts recomputes stale verdicts when plans change.
private extension View {
    func refreshableVerdicts(
        plans: PlansStore, fallback: CLLocationCoordinate2D, scouts: Binding<[UUID: PlanScout]>
    ) -> some View {
        onChange(of: plans.plans) { newPlans in
            let ids = Set(newPlans.map(\.id))
            scouts.wrappedValue = scouts.wrappedValue.filter { ids.contains($0.key) }
        }
    }
}

// PlanAddSheet creates a plan: what, when, how long, and where.
struct PlanAddSheet: View {
    @ObservedObject var plans: PlansStore
    @ObservedObject var places: PlacesStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var kind: PlanKind = .run
    @State private var start = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var days = 0
    @State private var hoursLen = 2
    @State private var placeID: String = "current"

    var body: some View {
        NavigationStack {
            Form {
                Section("What") {
                    TextField("Name it, like Morning run", text: $title)
                    Picker("Kind", selection: $kind) {
                        ForEach(PlanKind.allCases) { k in
                            Label(k.label, systemImage: k.icon).tag(k)
                        }
                    }
                }
                Section("When") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(relativeStarts(), id: \.label) { preset in
                                Button {
                                    start = preset.date
                                    Haptics.tick()
                                } label: {
                                    Text(preset.label)
                                        .font(.system(size: 12, weight: .semibold))
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 6)
                                        .background(Theme.violet.opacity(0.18), in: Capsule())
                                        .foregroundStyle(Theme.purple)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    DatePicker("Starts", selection: $start)
                    Stepper("Days: \(days)", value: $days, in: 0...14)
                    if days == 0 {
                        Stepper("Hours: \(hoursLen)", value: $hoursLen, in: 1...12)
                    }
                }
                Section("Where") {
                    Picker("Place", selection: $placeID) {
                        Text("Wherever you are").tag("current")
                        ForEach(places.places) { p in
                            Text(p.name).tag(p.id)
                        }
                    }
                }
            }
            .navigationTitle("New plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let place = places.places.first { $0.id == placeID }
                        let name = title.trimmingCharacters(in: .whitespaces)
                        plans.add(
                            Plan(
                                id: UUID(),
                                title: name.isEmpty ? kind.label : name,
                                kind: kind,
                                start: start,
                                hours: days > 0 ? days * 24 : hoursLen,
                                place: place))
                        Haptics.tick()
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
