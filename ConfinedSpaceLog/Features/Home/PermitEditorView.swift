import SwiftUI
import SwiftData

/// The written permit itself: the space, the purpose, the authorised window, the hazards, the
/// isolation and the ventilation. Everything 1910.146(f) asks a permit to carry, in the order a
/// supervisor filling one in at the space would reach for it.
///
/// Reachable both for a brand-new draft (`isNew: true`, presented from the board) and to amend an
/// existing one (`isNew: false`, presented from "Edit details"). Editing is blocked once a permit
/// is cancelled — a retained record does not get rewritten.
struct PermitEditorView: View {
    @Bindable var permit: Permit
    var isNew: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ConfinedSpace.spaceID) private var spaces: [ConfinedSpace]
    @Query private var allPermits: [Permit]

    /// The space can only be changed on a draft — `Permit.adopt` copies the space's hazards and
    /// acceptable conditions forward, and doing that after the permit is issued would silently
    /// rewrite a record that has already authorised entry.
    private var canReassignSpace: Bool { permit.status == .draft }

    var body: some View {
        NavigationStack {
            Form {
                if canReassignSpace {
                    Section {
                        Picker("Space", selection: spaceSelection) {
                            Text("Choose a space").tag(nil as ConfinedSpace?)
                            ForEach(spaces) { space in
                                Text(space.title).tag(space as ConfinedSpace?)
                            }
                        }
                    } header: {
                        Text("Space being entered")
                    } footer: {
                        Text("Hazards, isolation and the acceptable entry conditions are copied from the space and can still be adjusted below.")
                    }
                } else {
                    Section("Space being entered") {
                        LabeledContent("Space", value: permit.spaceTitle)
                    }
                }

                Section("The permit") {
                    TextField("Permit number", text: $permit.permitNumber)
                    TextField("Purpose of entry", text: $permit.purpose, axis: .vertical)
                        .lineLimit(1...4)
                    DatePicker("Authorised from", selection: $permit.authorisedFrom)
                    DatePicker("Authorised until", selection: $permit.authorisedTo)
                    TextField("Attendant", text: $permit.attendantName)
                        .textContentType(.name)
                }

                Section("Hazards of the space") {
                    HazardChips(selection: hazardSelection)
                    TextField("Other hazards not listed", text: $permit.otherHazards, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Isolation of hazardous energy") {
                    TextField("Lockout points, blanks, blinds, valves, breakers", text: $permit.isolationMeasures, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("Ventilation") {
                    TextField("How the space is being ventilated", text: $permit.ventilation, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("Rescue and emergency services") {
                    TextField("Who and how they are summoned", text: $permit.rescueServices, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("Communication procedure") {
                    TextField("How entrants and the attendant stay in contact", text: $permit.communicationProcedure, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("Equipment provided") {
                    TextField("PPE, retrieval, ventilation, testing equipment", text: $permit.equipment, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("Additional permits in effect") {
                    TextField("Hot work, lockout/tagout, excavation, etc.", text: $permit.additionalPermits, axis: .vertical)
                        .lineLimit(1...4)
                }
                Section("Other information") {
                    TextField("Optional", text: $permit.otherInformation, axis: .vertical)
                        .lineLimit(1...4)
                }
                Section("Notes") {
                    TextField("Optional", text: $permit.notes, axis: .vertical)
                        .lineLimit(1...4)
                }
                Section("Photo") {
                    PhotoField(data: $permit.photoData, label: "photo of the space or the manway")
                }
            }
            .navigationTitle(isNew ? "New Permit" : "Edit Permit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { save() } }
            }
        }
    }

    private var spaceSelection: Binding<ConfinedSpace?> {
        Binding(get: { permit.space }, set: { permit.adopt($0) })
    }

    private var hazardSelection: Binding<Set<SpaceHazard>> {
        Binding(get: { Set(permit.hazards) }, set: { permit.hazards = Array($0) })
    }

    private func save() {
        if isNew { context.insert(permit) }
        try? context.save()
        WidgetSync.update(with: allPermits)
        dismiss()
    }
}

/// Hazards, wrapped rather than a segmented control — 1910.146 names sixteen of them and none of
/// their labels tolerate being cut off ("Converging walls or sloping floor" as "Converging…"
/// helps nobody standing at the manway).
private struct HazardChips: View {
    @Binding var selection: Set<SpaceHazard>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            group("Atmospheric", SpaceHazard.atmospheric)
            group("Physical", SpaceHazard.physical)
        }
    }

    private func group(_ title: String, _ hazards: [SpaceHazard]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Wrap(spacing: 8, lineSpacing: 8) {
                ForEach(hazards) { hazard in
                    let isSelected = selection.contains(hazard)
                    Button {
                        if isSelected { selection.remove(hazard) } else { selection.insert(hazard) }
                    } label: {
                        Text(hazard.name)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 30)
                            .background(isSelected ? Color.orange.opacity(0.18) : Color(.secondarySystemFill), in: Capsule())
                            .foregroundStyle(isSelected ? Color.orange : Color.primary)
                            .overlay(Capsule().strokeBorder(isSelected ? Color.orange.opacity(0.55) : .clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }
}
