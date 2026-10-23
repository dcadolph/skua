import SwiftUI

// FamilyMember is one person in the household and the allergens they react to,
// so the bird can call out their day by name.
struct FamilyMember: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var triggers: [String]
}

// FamilyStore holds the household roster on device. Nothing leaves the phone.
@MainActor
final class FamilyStore: ObservableObject {
    // members is the saved roster.
    @Published var members: [FamilyMember] = []

    // storageKey is where the roster persists.
    private static let storageKey = "skua.family"

    // init loads the saved roster.
    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let saved = try? JSONDecoder().decode([FamilyMember].self, from: data) {
            members = saved
        }
    }

    // save writes the roster back to storage.
    private func save() {
        if let data = try? JSONEncoder().encode(members) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // upsert inserts or updates a member.
    func upsert(_ member: FamilyMember) {
        if let i = members.firstIndex(where: { $0.id == member.id }) {
            members[i] = member
        } else {
            members.append(member)
        }
        save()
    }

    // remove drops a member.
    func remove(_ member: FamilyMember) {
        members.removeAll { $0.id == member.id }
        save()
    }
}

// allergenOptions is the common allergen vocabulary the picker offers, chosen to
// match the names the pollen source reports.
let allergenOptions = [
    "Cedar", "Juniper", "Ragweed", "Grass", "Oak", "Elm", "Mold", "Mulberry",
    "Pine", "Ash", "Cottonwood", "Pecan", "Sagebrush", "Chenopods", "Birch", "Maple",
]

// triggerMatches reports whether a person's trigger and a reported trigger name
// refer to the same thing, tolerating plural and qualified names like
// "Mountain Cedar" against "Cedar".
func triggerMatches(_ personTrigger: String, _ reported: String) -> Bool {
    let a = personTrigger.lowercased()
    let b = reported.lowercased()
    return a.contains(b) || b.contains(a)
}

// FamilyCallout is a per-person read on the day's allergens.
struct FamilyCallout: Identifiable {
    let id: UUID
    let name: String
    let hit: Bool
    let note: String
}

// pollenCallouts builds a per-person allergen read for the day. Members whose
// triggers are active get a pointed note; the rest get an all-clear.
func pollenCallouts(_ pollen: Pollen, members: [FamilyMember]) -> [FamilyCallout] {
    members.map { member in
        let hits = pollen.today.triggers.filter { reported in
            member.triggers.contains { triggerMatches($0, reported) }
        }
        let note: String
        if hits.isEmpty {
            note = "Clear of \(member.name.possessive) triggers today. Breathe easy."
        } else {
            let list = hits.joined(separator: ", ")
            switch pollen.today.index {
            case ..<4.9:
                note = "\(list) is around, but light. \(member.name) probably skates by."
            case ..<7.3:
                note = "\(list) is up. \(member.name) will notice. Meds before heading out."
            default:
                note = "\(list) is high. Rough one for \(member.name). Antihistamine, sunglasses, and shut the windows."
            }
        }
        return FamilyCallout(id: member.id, name: member.name, hit: !hits.isEmpty, note: note)
    }
}

// possessive returns the possessive form of a name for the callouts.
private extension String {
    var possessive: String { hasSuffix("s") ? self + "'" : self + "'s" }
}

// FamilySheet edits the household roster and each person's allergens.
struct FamilySheet: View {
    @ObservedObject var family: FamilyStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing: FamilyMember?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(family.members) { member in
                        Button {
                            editing = member
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(member.name).font(.headline).foregroundStyle(Theme.text)
                                Text(member.triggers.isEmpty ? "No allergens set" : member.triggers.joined(separator: ", "))
                                    .font(.caption).foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .onDelete { idx in
                        idx.map { family.members[$0] }.forEach(family.remove)
                    }
                } footer: {
                    Text("Add the people you check the weather for. The bird calls out each one's allergens by name.")
                }
                Button {
                    editing = FamilyMember(name: "", triggers: [])
                } label: {
                    Label("Add a person", systemImage: "plus.circle.fill")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .navigationTitle("Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $editing) { member in
                MemberEditor(member: member) { family.upsert($0) }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MemberEditor edits one person's name and the allergens they react to.
struct MemberEditor: View {
    @State var member: FamilyMember
    let onSave: (FamilyMember) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("Name", text: $member.name)
                        .font(.title3.weight(.semibold))
                        .textInputAutocapitalization(.words)
                        .padding(14)
                        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text("REACTS TO").font(.caption.weight(.bold)).kerning(1).foregroundStyle(Theme.muted)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                        ForEach(allergenOptions, id: \.self) { option in
                            let on = member.triggers.contains(option)
                            Button {
                                if on { member.triggers.removeAll { $0 == option } }
                                else { member.triggers.append(option) }
                                Haptics.tick()
                            } label: {
                                Text(option)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(on ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.elevated),
                                               in: Capsule())
                                    .foregroundStyle(on ? Color.black : Theme.text)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.ground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(member); dismiss() }
                        .disabled(member.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
